extends Control

"""
Tools for map manipulation

args
create:bool -> when true a new map the default-newmap mapdata is loaded
mapdata:Dictionary -> only when create is true

Has a map child (editor_set_editing_mode() is called) and mapcam
When loading an existing map, the mapdata needs to be loaded in the mapcontainer
space to deselect tile

Tools
0 -> select
1 -> brush
2 -> line
3 -> fill
"""

onready var map_camera = $MapCam
onready var map = $Map
onready var lst_tiles = $MapCam/LstTiles
onready var lst_tools = $MapCam/LstTools
onready var line_tool_preview = $LineToolPreview
onready var line_tool_area = $LineToolArea
onready var line_tool_area_shape = $LineToolArea/LineToolAreaShape

const tiledata_script = preload("res://map/tiledata/tile_metadata.gd")
var tiledata

enum Tools {
	SELECT,
	BRUSH,
	LINE,
	FILL,
	ERASE
	}

var line_start:Vector2
var tool_selected:int = -1
var tile_selected:int = 0
var tooling := false
var tool_pos:Vector2

var game
var nk
var nkr

func initialize(args:Dictionary)->void:
	if args["create"]:
		var new_mapid = game.user_id + String(OS.get_unix_time()) + String(randi()%999999)
		var new_mapdata = {	"name": "Untitled map",
							"creator_id": game.user_id,
							"map_id": new_mapid,
							"cell_ids": {}
							}
		map.mapdata_load(new_mapdata)
	else:
		var parse_result = JSON.parse(args["mapdata"])
		if parse_result.error != OK:
			game.show_error(-1,"Map data corrupt. Cant load! Parse error:\n%s\nat line: %s"%[parse_result.error_string,parse_result.error_line])
			return#game.game_state_change_to(game.GameStates.EDITORMENU)
		map.mapdata_load(parse_result.result)

func _ready() -> void:
	game = get_node("/root/Game")
	nk = game.get_nakama_rest_client()
	nkr = game.get_nakama_rt_client()
	
	lst_tiles.connect("item_selected",self,"_on_LstTiles_item_selected")
	lst_tiles.connect("nothing_selected",self,"_on_LstTiles_nothing_selected")
	lst_tools.connect("item_selected",self,"_on_LstTools_item_selected")
	
	tiledata = tiledata_script.new()
	map.editor_set_editing_mode()
	map_camera.make_current()
	map_camera.zoomable = false
	
	#populate tools list
	lst_tools.add_item("Select")
	lst_tools.set_item_metadata(lst_tools.get_item_count()-1,Tools.SELECT)
	lst_tools.add_item("Brush")
	lst_tools.set_item_metadata(lst_tools.get_item_count()-1,Tools.BRUSH)
	lst_tools.add_item("Line")
	lst_tools.set_item_metadata(lst_tools.get_item_count()-1,Tools.LINE)
	lst_tools.add_item("Fill")
	lst_tools.set_item_metadata(lst_tools.get_item_count()-1,Tools.FILL)
	
	for id in tiledata.tiles.keys():
		lst_tiles.add_item(tiledata.tiles[id]["name"],load(tiledata.tiles[id]["stexpath"]))
		lst_tiles.set_item_metadata(lst_tiles.get_item_count()-1,id)
	lst_tiles.add_item("nothing/erase")
	lst_tiles.set_item_metadata(lst_tiles.get_item_count()-1,0)
	lst_tiles.select(lst_tiles.get_item_count()-1)

func _process(delta: float) -> void:
	if tooling:
		_apply_tool()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			tooling = event.pressed
			if tool_selected == Tools.LINE:
				if event.pressed:
					line_start = event.global_position
					line_tool_preview.clear_points()
					line_tool_preview.add_point(line_start)
					line_tool_preview.add_point(line_start)
					line_tool_preview.visible = true
				else:
					_line_complete(event.global_position)
					line_tool_preview.visible = false
	
	if event is InputEventMouseMotion:
		tool_pos = event.global_position
#		if tool_selected == Tools.LINE:
#			var line = tool_pos-line_start
#			var line_length = sqrt(line.length_squared())
#			var selected:Array
#			for step in range(0,line_length):
#				selected.append(line_start+(line*(step/line_length))+map_camera.position)
#			map.editor_make_selected(selected)
#		else:
#			map.editor_make_selected([event.global_position+ map_camera.position])

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("editor_unselect"):
		lst_tiles.unselect_all()
		tile_selected = -1

func _apply_tool()->void:
	match tool_selected:
		Tools.SELECT:
			tile_selected = -1
			lst_tiles.unselect_all()
			continue
		
		Tools.BRUSH:
			if tile_selected == -1:
				return
			map.editor_set_tile(tile_selected,tool_pos + map_camera.position)
		
		Tools.LINE:
			line_tool_preview.set_point_position(0,line_start + map_camera.position)
			line_tool_preview.set_point_position(1,tool_pos + map_camera.position)
			line_tool_area_shape.shape.a = line_start + map_camera.position
			line_tool_area_shape.shape.b = tool_pos + map_camera.position

func _line_complete(end_pos:Vector2)->void:
	if tile_selected == -1:
		return
	print(line_tool_area.get_overlapping_areas())

func _on_LstTools_item_selected(idx:int)->void:
	tool_selected = lst_tools.get_item_metadata(idx)

func _on_LstTiles_item_selected(idx:int)->void:
	tile_selected = lst_tiles.get_item_metadata(idx)

func _on_LstTiles_nothing_selected()->void:
	tile_selected = -1