extends Control

"""
Editor menu
shows all maps created by user and allows to edit/delete them or create a new map


When loading a map the game state changes to Editor and the following arguments are to be passed:
create:bool
mapdata:Dictionary -> When create false the mapdata of the map to be loaded needs to be retrieved from the nakama container
"""

onready var btn_create = $VBoxSelectedMap/BtnCreate
onready var lst_maps = $LstMaps
onready var txt_map_name = $VBoxSelectedMap/GridMapMetadata/TxtMapName
onready var txt_map_creation = $VBoxSelectedMap/GridMapMetadata/TxtMapCreation
onready var txt_map_edited = $VBoxSelectedMap/GridMapMetadata/TxtMapEdited
onready var check_map_public = $VBoxSelectedMap/GridMapMetadata/CheckMapPublic
onready var txt_map_version = $VBoxSelectedMap/GridMapMetadata/TxtMapVersion
onready var grid_map_metadata = $VBoxSelectedMap/GridMapMetadata
onready var pop_deletion = $PopDeletion

var game
var nk
var nkr

var activated_idx:int

func _ready() -> void:
	game = get_node("/root/Game")
	nk = game.get_nakama_rest_client()
	nkr = game.get_nakama_rt_client()
	btn_create.connect("pressed",self,"_on_BtnCreate_pressed")
	lst_maps.connect("item_activated",self,"_on_LstMaps_item_activated")
	pop_deletion.connect("confirmed",self,"_on_PopDeletion_confirmed")
	update_map_list()

func update_map_list()->void:
	lst_maps.clear()
	grid_map_metadata.visible = false
	var promise = nk.list_storage_objects("maps", game.user["user"]["id"],99)
	yield(promise,"completed")
	game.check_promise(promise)
	
	if !promise.response["data"].has("objects"):
		return
	
	for o in promise.response["data"]["objects"]:
		var parse_result = JSON.parse(o["value"])
		if parse_result.error != OK:
			game.show_error(-1,"Map data corrupt. Cant load! Parse error:\n%s\nat line: %s"%[parse_result.error_string,parse_result.error_line])
			continue
		o["mapdata"] = parse_result.result
		var list_title = "%s"%o["mapdata"]["name"]
		lst_maps.add_item(list_title)
		lst_maps.set_item_metadata(lst_maps.get_item_count()-1,o)

func _on_LstMaps_item_activated(idx:int)->void:
	activated_idx = idx
	var o = lst_maps.get_item_metadata(idx)
	txt_map_name.text = o["mapdata"]["name"]
	txt_map_creation.text = o["create_time"]
	txt_map_edited.text = o["update_time"]
	check_map_public.pressed = o["permission_read"] == 2
	txt_map_version.text = String(o["mapdata"]["game_version"])
	grid_map_metadata.visible = true

func _on_BtnCreate_pressed()->void:
	game.game_state_change_to(game.GameStates.EDITOR,{"create":true})

func _on_BtnEdit_pressed() -> void:
	var o = lst_maps.get_item_metadata(activated_idx)
	game.game_state_change_to(game.GameStates.EDITOR,{"create":false,"mapdata":o["mapdata"]})

func _on_BtnSaveChanges_pressed() -> void:
	var o = lst_maps.get_item_metadata(activated_idx)
	o["mapdata"]["name"] = txt_map_name.text
	var permission_read = 2 if check_map_public.pressed else 1
	var mapdata_jstr = JSON.print(o["mapdata"] )
	var save_obj = {"collection" : "maps",
					"key" : o["key"],
					"value" : mapdata_jstr,
					"permission_read" : permission_read
					}
	var promise = nk.write_storage_objects([save_obj])
	yield(promise,"completed")
	game.check_promise(promise)
	update_map_list()

func _on_BtnDelete_pressed()->void:
	var o = lst_maps.get_item_metadata(activated_idx)
	pop_deletion.dialog_text = "Do you want to irreversably delete your map: %s?"%o["mapdata"]["name"]
	pop_deletion.popup_centered()

func _on_PopDeletion_confirmed() -> void:
	var o = lst_maps.get_item_metadata(activated_idx)
	var promise = nk.delete_storage_objects([{"collection" : "maps", "key" : o["key"]}])
	yield(promise,"completed")
	game.check_promise(promise)
	update_map_list()