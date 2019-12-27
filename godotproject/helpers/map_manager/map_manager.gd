extends Node

var maps:Dictionary #{mapid: mapref}

var game
var nk
var nkr

func _ready()->void:
	game = get_node("/root/Game")
	nk = game.get_nakama_rest_client()
	nkr = game.get_nakama_rt_client()

func _load_map(mid:String, user_id:String)->bool:
	var promise = nk.list_storage_objects("maps", game.user["user"]["id"],99)
	yield(promise,"completed")
	if(!game.check_promise(promise)):
		return false
	
	return true