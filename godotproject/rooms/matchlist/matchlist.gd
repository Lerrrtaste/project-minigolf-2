extends Control

onready var lst_matches = $LstMatches
onready var btn_join_selected = $BtnJoinSelected
onready var btn_join_id = $BtnJoinId
onready var btn_refresh = $BtnRefresh
onready var btn_editor = $BtnEditor
onready var btn_create = $BtnCreate
onready var txt_filter = $TxtFilter
onready var txt_id = $BtnJoinId/TxtId

var nk
var nkr
var game
var matches:Array

func _ready() -> void:
	game = get_node("/root/Game")
	nk = game.get_nakama_rest_client()
	nkr = game.get_nakama_rt_client()
	btn_join_selected.connect("pressed",self,"_on_BtnJoinSelected_pressed")
	btn_join_id.connect("pressed",self,"_on_BtnJoinId_pressed")
	btn_refresh.connect("pressed",self,"_on_BtnRefresh_pressed")
	btn_editor.connect("pressed",self,"_on_BtnEditor_pressed")
	btn_create.connect("pressed",self,"_on_BtnCreate_pressed")
	txt_filter.connect("text_entered",self,"_on_TxtFilter_text_entered")
	lst_matches.connect("item_selected",self,"_on_LstMatches_item_selected")
	lst_matches.connect("nothing_selected",self,"_on_LstMatches_nothing_selected")

func _matchlist_update()->void:
	_disable_buttons(true)
	lst_matches.clear()
	for m in matches:
		var label = "no label"#m["label"]
		if txt_filter.text == "" || (label.find(txt_filter.text) != -1):
			var size = m["size"]
			var match_id = m["match_id"]
			var item_title = "%s | Players: %s"%[label,size]+((" | %s"%match_id) if game.debugging else "")
			lst_matches.add_item(item_title)
			lst_matches.set_item_metadata(lst_matches.get_item_count()-1,match_id)
	_disable_buttons(true)

func _disable_buttons(val:bool)->void:
	btn_create.disabled = val
	btn_editor.disabled = val
	btn_join_id.disabled = val
	btn_join_selected.disabled = val
	btn_refresh.disabled = val
	txt_filter.editable = val

func _finished(match_dict:Dictionary,host:bool = false)->void:
	game.game_state_change_to(game.GameStates.LOBBY,{"match":match_dict,"host":host})

func _on_BtnJoinSelected_pressed()->void:
	if !lst_matches.is_anything_selected():
		game.show_error(-1,"Nothing selected!")
		return
	_disable_buttons(true)
	var idx = lst_matches.get_selected_items()[0]
	var match_id = lst_matches.get_item_metadata(idx)
	var promise = nkr.send({"match_join":{"match_id":match_id}})
	yield(promise,"completed")
	if !game.check_promise(promise):
		_disable_buttons(false)
		return
	_finished(promise.response["match"])

func _on_BtnJoinId_pressed()->void:
	if !txt_id.visible:
		txt_id.visible = true
		btn_join_id.text = "Join this match ->"
		return
	if txt_id.text == "":
		game.show_error(-1,"No match id entered!")
		return
	_disable_buttons(true)
	var promise = nkr.send({"match_join":{"match_id":txt_id.text}})
	yield(promise,"completed")
	if !game.check_promise(promise):
		_disable_buttons(false)
		return
	else:
		if !promise.response.keys().has("match"):
			game.show_error(-1,"No match with this id found!")
		_disable_buttons(false)
		return
	_finished(promise.response["match"])

func _on_BtnRefresh_pressed()->void:
	_disable_buttons(true)
	var promise = nk.list_matches(100,false,"",0,0,"")
	yield(promise,"completed")
	if !game.check_promise(promise):
		return
	if !promise.response["data"].has("matches"):
		game.show_error(-1,"No matches available!")
	else:
		matches.clear()
		for m in promise.response["data"]["matches"]:
			matches.append(m)
		_matchlist_update()
	_disable_buttons(false)

func _on_BtnEditor_pressed()->void:
	game.game_state_change_to(game.GameStates.EDITORMENU)

func _on_BtnCreate_pressed()->void:
	_disable_buttons(true)
	print(nkr)
	var promise = nkr.send({"match_create":{}})
	yield(promise,"completed")
	if(!game.check_promise(promise)):
		_disable_buttons(false)
		return
	_finished(promise.response["match"],true)

func _on_LstMatches_item_selected(idx:int)->void:
	btn_join_selected.disabled = false

func _on_TxtFilter_text_entered(new_text:String)->void:
	_matchlist_update()