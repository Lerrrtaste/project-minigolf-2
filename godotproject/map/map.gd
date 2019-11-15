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
cell_ids:Dictionary -> { tmap_coord:Vector2 : tile_id:int }
"""

onready var map_camera = $MapCam
onready var btn_reset_zoom = $Cam/BtnResetZoom
onready var tmap = $TileMap

const tiledata_script = preload("res://map/tiledata/tile_metadata.gd")
var tiledata

var loaded := false
var camera_moving := false
var camera_target:Object
var editing_mode := false
var selected:Array

var game
var mapdata:Dictionary
var mapdata_keys := ["name","creator_id","map_id","cell_ids"]

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
		game.show_error(-1,"Mapdata incomplete! Keys:\n%s"%mapdata_load.keys())
		return
	mapdata = mapdata_load
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
		mapdata["cell_ids"].erase(tmap_pos)
		tmap.set_cell(tmap_pos.x,tmap_pos.y,-1)
	else:
		mapdata["cell_ids"][tmap_pos] = tile_id
		tmap.set_cell(tmap_pos.x,tmap_pos.y,tiledata.tiles[tile_id]["tresidx"])

func editor_make_selected(world_pos:Array)->void:
	selected = world_pos
	update()