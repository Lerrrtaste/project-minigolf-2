extends Control

onready var map_camera = $MapCam
onready var map = $Map
onready var lst_tiles = $MapCam/LstTiles

const tiledata_script = preload("res://map/tiledata/map_tiles.gd")

var tiledata
var tile_selected:int = -1

func _ready() -> void:
	lst_tiles.connect("item_selected",self,"_on_LstTiles_item_selected")
	lst_tiles.connect("nothing_selected",self,"_on_LstTiles_nothing_selected")
	tiledata = tiledata_script.new()
	map.editor_set_editing_mode()
	map_camera.make_current()
	map_camera.zoomable = false
	
	for id in tiledata.tiles.keys():
		lst_tiles.add_item(tiledata.tiles[id]["name"],load(tiledata.tiles[id]["stexpath"]))
		lst_tiles.set_item_metadata(lst_tiles.get_item_count()-1,id)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == BUTTON_LEFT:
				if tile_selected == -1:
					return
				map.editor_set_tile(tile_selected,event.global_position + map_camera.position)

func _on_LstTiles_item_selected(idx:int)->void:
	tile_selected = lst_tiles.get_item_metadata(idx)

func _on_LstTiles_nothing_selected()->void:
	tile_selected = -1