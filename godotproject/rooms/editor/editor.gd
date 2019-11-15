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
onready var map = $MapContainer
onready var lst_tiles = $MapCam/LstTiles
onready var lst_tools = $MapCam/LstTools
onready var line_tool_preview = $LineToolPreview
onready var line_tool_area = $LineToolArea
onready var line_tool_area_shape = $LineToolArea/LineToolAreaShape
onready var pop_save_dialgue = $MapCam/PopSaveDialogue
onready var pop_leave = $MapCam/PopLeave
onready var btn_menu = $MapCam/BtnMenu
onready var btn_save = $MapCam/PopSaveDialogue/VBoxContainer/BtnSave
onready var btn_save_leave = $MapCam/PopSaveDialogue/VBoxContainer/BtnSaveLeave
onready var btn_leave = $MapCam/PopSaveDialogue/VBoxContainer/BtnLeave
onready var btn_cancel = $MapCam/PopSaveDialogue/VBoxContainer/BtnCancel

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
		randomize()
		var new_mapid = game.user["user"]["id"] + String(OS.get_unix_time()) + String(randi()%999999)
		var new_mapdata = {	"name": "Untitled map",
							"creator_id": game.user["user"]["id"],
							"map_id": new_mapid,
							"cells": {},
							"game_version": game.GAME_VERSION
							}
		map.mapdata_load(new_mapdata)
	else:
		map.mapdata_load(args["mapdata"])

func _ready() -> void:
	game = get_node("/root/Game")
	nk = game.get_nakama_rest_client()
	nkr = game.get_nakama_rt_client()
	
	lst_tiles.connect("item_selected",self,"_on_LstTiles_item_selected")
	lst_tiles.connect("nothing_selected",self,"_on_LstTiles_nothing_selected")
	lst_tools.connect("item_selected",self,"_on_LstTools_item_selected")
	btn_menu.connect("pressed",self,"_on_BtnMenu_pressed")
	btn_cancel.connect("pressed",self,"_on_BtnCancel_pressed")
	btn_save.connect("pressed",self,"_on_BtnSave_pressed")
	btn_save_leave.connect("pressed",self,"_on_BtnSaveLeave_pressed")
	btn_leave.connect("pressed",self,"_on_BtnLeave_pressed")
	pop_leave.connect("confirmed",self,"_on_PopLeave_confirmed")
	
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

func _save()->bool:
	var export_mapdata:String = map.mapdata_export()
	if export_mapdata == "": #mapdata couldnt be exported, map displayed the error
		return 
	var save_obj = {"collection" : "maps",
					"key" : map.mapdata["map_id"],
					"value" : export_mapdata
					}
	var promise = nk.write_storage_objects([save_obj])
	yield(promise,"completed")
	return game.check_promise(promise)

func _on_BtnMenu_pressed()->void:
	pop_save_dialgue.popup_centered()

func _on_BtnSave_pressed()->void:
	_save()
	pop_save_dialgue.hide()

func _on_BtnSaveLeave_pressed()->void:
	if _save():
		game.game_state_change_to(game.GameStates.EDITORMENU)

func _on_BtnLeave_pressed()->void:
	pop_leave.popup_centered()

func _on_PopLeave_confirmed()->void:
	game.game_state_change_to(game.GameStates.EDITORMENU)

func _on_BtnCancel_pressed()->void:
	pop_save_dialgue.hide()

func _on_LstTools_item_selected(idx:int)->void:
	tool_selected = lst_tools.get_item_metadata(idx)

func _on_LstTiles_item_selected(idx:int)->void:
	tile_selected = lst_tiles.get_item_metadata(idx)

func _on_LstTiles_nothing_selected()->void:
	tile_selected = -1