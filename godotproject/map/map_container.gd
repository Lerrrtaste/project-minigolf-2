extends Node2D

"""
Map container
for a) editing or b) playing


contains a tilemap, representing the map, and mapcam for looking around
To be used it first needs to load a map with mapdata_import

Editing:
Call editor_set_editing_mode() first (will remove mapcam so the editor's camera can be used)
Can use mapdata_export to recieve a jstr which can be used to load the map+metadata again (and store it)
editor_ functions are for manipulating the map

Mapdata dict (stored in mapdata_keys for error checking):
name:String
creator_id:String
map_id:String
cells:Dictionary -> { tmap_coord:String (x,y) : tile_id:int }
game_version:int
"""

onready var map_camera = $MapCam
onready var btn_reset_zoom = $Cam/BtnResetZoom
onready var tmap = $TileMap

const Tile = preload("res://helpers/map_tile/Tile.tscn")
var tiles:Dictionary # { tmap_coord:vector2: ref:Tile }

const tiledata_script = preload("res://map/tiledata/tile_metadata.gd")
var tiledata

var loaded := false
var camera_moving := false
var camera_target:Object
var editing_mode := false
var selected:Array

var game
var mapdata:Dictionary
var mapdata_keys := ["name","creator_id","map_id","cells","game_version"]

func _ready()->void:
	game = get_node("/root/Game")
	tiledata = tiledata_script.new()
	var game = get_node("/root/Game")
	map_camera.make_current()

func _draw()->void:
	for pos in selected:
		var tmap_pos = tmap.world_to_map(pos)
		draw_rect(Rect2(tmap_pos,Vector2(32,32)),ColorN("red"),true)

func mapdata_export()->String:
	if !mapdata.has_all(mapdata_keys):
		game.show_error(-1,"Warning! Exporting incomplete Mapdata! Keys:\n%s"%mapdata.keys())
	return JSON.print(mapdata)

func mapdata_load(mapdata_load:Dictionary)->void:
	if !mapdata_load.has_all(mapdata_keys):
		game.show_error(-1,"Mapdata incomplete! Keys:\n%s"%String(mapdata_load.keys()))
		return
	if mapdata_load["game_version"] != game.GAME_VERSION:
		game.show_error(-1,"Mapdata version incompatible! Map's version: %s\nRunning version: %s"%[mapdata_load["game_version"],game.GAME_VERSION])
		return
		
	mapdata = mapdata_load
	for p in mapdata["cells"].keys():
		var tile_id:int = int(mapdata["cells"][p])
		var xx = int(p.split(',')[0])
		var yy = int(p.split(',')[1])
		_set_tile(Vector2(xx,yy),tiledata.tiles[tile_id]["tresidx"])
	loaded = true

func editor_set_editing_mode()->void:
	editing_mode = true
	remove_child(map_camera)

func editor_set_tile(tile_id:int,world_pos:Vector2)->void:
	if !editing_mode:
		game.show_error(-1,"editing_mode is not true!")
		return
	if !loaded:
		game.show_error(-1,"No mapdata loaded!")
		return
	var tmap_pos = tmap.world_to_map(world_pos)
	#print("Setting tile at pos %s to tileid %s"%[tmap_pos,tile_id])
	if tile_id == 0: #for erasing
		mapdata["cells"].erase(String(tmap_pos.x)+","+String(tmap_pos.y))
		_set_tile(tmap_pos,-1)
	else:
		mapdata["cells"][String(tmap_pos.x)+","+String(tmap_pos.y)] = tile_id
		_set_tile(tmap_pos,tiledata.tiles[tile_id]["tresidx"])

#warning: does not write to mapdata
func _set_tile(tmap_pos:Vector2,tile_id:int)->void:
	tmap.set_cell(tmap_pos.x,tmap_pos.y,tile_id)
	if tiles.has(tmap_pos):
		tiles[tmap_pos].queue_free()
		tiles.erase(tmap_pos)
	if tile_id != -1: #changing to an existing new tile
		#create tile node for collision
		var inst = Tile.instance()
		inst.initiate(tile_id,tiledata.tiles[tile_id]["collisionlayers"])
		add_child(inst)
		tiles[tmap_pos] = inst

func editor_make_selected(world_pos:Array)->void:
	selected = world_pos
	update()