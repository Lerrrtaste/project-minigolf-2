extends Control

"""
Editor menu
shows all maps created by user and allows to edit/delete them or create a new map


When loading a map the game state changes to Editor and the following arguments are to be passed:
create:bool
mapdata:Dictionary -> When create false the mapdata of the map to be loaded needs to be retrieved from the nakama container
"""

onready var btn_create = $BtnCreate
onready var lst_maps = $LstMaps

var game
var nk
var nkr

func _ready() -> void:
	game = get_node("/root/Game")
	nk = game.get_nakama_rest_client()
	nkr = game.get_nakama_rt_client()
	btn_create.connect("pressed",self,"_on_BtnCreate_pressed")
	lst_maps.connect("item_activated",self,"_on_LstMaps_item_activated")
	
	#load maps
	var promise = nk.list_storage_objects("maps", game.user["user"]["id"])
	yield(promise,"completed")
	game.check_promise(promise)
	
	if !promise.response["data"].has("objects"):
		return
	
	for o in promise.response["data"]["objects"]:
		var parse_result = JSON.parse(o["value"])
		if parse_result.error != OK:
			game.show_error(-1,"Map data corrupt. Cant load! Parse error:\n%s\nat line: %s"%[parse_result.error_string,parse_result.error_line])
			continue
		var mapdata = parse_result.result
		var list_title = "%s (Public: %s Created: %s Modified: %s)"%[mapdata["name"],o["permission_read"] == 2, o["create_time"],o["update_time"]]
		lst_maps.add_item(list_title)
		lst_maps.set_item_metadata(lst_maps.get_item_count()-1,mapdata)

func _on_LstMaps_item_activated(idx:int)->void:
	var mapdata = lst_maps.get_item_metadata(idx)
	game.game_state_change_to(game.GameStates.EDITOR,{"create":false,"mapdata":mapdata})

func _on_BtnCreate_pressed()->void:
	game.game_state_change_to(game.GameStates.EDITOR,{"create":true})