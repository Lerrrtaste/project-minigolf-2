extends Control

"""
Lobby

Tabs:
Settings:
	change game preferences in gamedata
maps:
	select map rotation if enabled in settings
Opponents:
	all players in the room

gamedata
setting_access:int (open or password)
setting_turntimer:int (seconds for each turn)
setting_voteskip:bool (vote or host only map skip)
setting_mapselection:int (random, select at lobby,vote after each map)
settubg_mapcount:int (if not select at at lobby, how many rounds)
"""

onready var lst_opponents = $TabContainer/Opponents/LstOpponents
onready var chat = $Chat
onready var btn_ready = $BtnReady
onready var lbl_ready = $BtnReady/LblReady
onready var timer = $Timer

const GAME_START_DELAY = 5

var m #(containes self, matchid and maybe presences)
var opponents:Dictionary # {userid : {"presence":presence, "ready":bool}
var gamesettings:Dictionary
var countdown:int

var game
var nk
var nkr


func initialize(args:Dictionary)->void:
	m = args["match"]
	chat.initialize(m["match_id"])
	if m.has("presences"):
		for i in m["presences"]:
#			for j in opponents.keys(): #not working 
#				if i["user_id"] == j:
#					game.show_error(-1,"Your user_id is already joined!")
#					game.game_state_change_to(game.GameStates.MATCHLIST)
			presence_join(i)

func _ready() -> void:
	game = get_node("/root/Game")
	nk = game.get_nakama_rest_client()
	nkr = game.get_nakama_rt_client()
	
	nkr.connect("match_data",self,"_on_Nkr_match_data")
	nkr.connect("match_presence",self,"_on_Nkr_match_presence")
	nkr.connect("disconnected",self,"_on_Nkr_disconnected")
	btn_ready.connect("toggled",self,"_on_BtnReady_toggled")
	timer.connect("timeout",self,"_on_Timer_timeout")


func presence_join(presence:Dictionary)->void:
	if opponents.has(presence["user_id"]):
		game.show_error(-1,"Joining presence was already joined:\n%s"%presence)
		return
	
	opponents[presence["user_id"]] = { "presence":presence, "ready": false}
	lst_opponents.add_item(presence["username"])
	lst_opponents.set_item_metadata(lst_opponents.get_item_count()-1,presence["user_id"])
	chat.recieve_message(chat.MessageTypes.EVENT_PRESENCE,"joined",presence["username"])

func presence_leave(presence:Dictionary)->void:
	if !opponents.has(presence["user_id"]):
		game.show_error(-1,"Leaving presence was not joined:\n%s"%presence)
		return
	
	opponents.erase(presence)
	for i in lst_opponents.get_item_count():
		if lst_opponents.get_item_metadata(i) == presence["user_id"]:
			lst_opponents.remove_item(i)
			break
	chat.recieve_message(chat.MessageTypes.EVENT_PRESENCE,"left",presence["username"])

func presence_ready(presence:Dictionary,ready:bool)->void:
	if !opponents.has(presence["user_id"]):
		game.show_error(-1,"Not joined presence sending ready state:\n%s"%presence)
		return
	
	opponents[presence["user_id"]]["ready"] = ready
	for i in lst_opponents.get_item_count():
		if lst_opponents.get_item_metadata(i) == presence["user_id"]:
			lst_opponents.set_item_text(i, "%s%s"%[("READY | " if ready else ""),presence["username"]])
	chat.recieve_message(chat.MessageTypes.EVENT_GAME,"is ready" if ready else "is not ready anymore :(",presence["username"])
	
	for i in opponents.keys():
		if opponents[i]["ready"] == false:
			if !timer.is_stopped():
				chat.recieve_message(chat.MessageTypes.EVENT_GAME,"Aborting game start")
				timer.stop()
			break
		countdown = GAME_START_DELAY
		timer.start(1)
		chat.recieve_message(chat.MessageTypes.EVENT_GAME,"Starting game in...")


func _on_Timer_timeout()->void: #TODO start game here
	if countdown == 0:
		pass #start game
		return
	countdown -= 1
	chat.recieve_message(chat.MessageTypes.EVENT_GAME,"%s"%(countdown+1))
	timer.start(1)

func _on_BtnReady_toggled(val:bool)->void:
	lbl_ready.text = "Ready!" if val else "Ready?"
	var promise = nkr.send({"match_data_send":{"op_code":1001,"match_id":m["match_id"],"data":JSON.print({"ready":val})}})
	if game.check_promise(promise):
		presence_ready(m["self"],val)

func _on_Nkr_match_data(data:Dictionary)->void:
	var match_data:Dictionary
	if data.has("data"):
		var parse_result = JSON.parse(data["data"])
		if parse_result.error != OK:
			game.show_error(-1,"Error parsing json %s"%parse_result.error_string)
			return
		match_data = parse_result.result
	match data["op_code"]:
		2001: #chat message
			if !match_data.has_all(["message_type","content"]):
				chat.recieve_error("Recieved incomplete message")
				return
			chat.recieve_message(match_data["message_type"],match_data["content"],data["presence"]["username"])
		1001: #user ready
			presence_ready(data["presence"],match_data["ready"])
		1002: #gamedata update
			pass

func _on_Nkr_match_presence(data:Dictionary)->void:
#	if !data.has("match_presence_event"):
#		game.show_error(-1,"Recieved empty match_presence_event??")
#		return

	if data.has("joins"):
		for i in data["joins"]:
			presence_join(i)
	
	if data.has("leaves"):
		for i in data["leaves"]:
			presence_leave(i)

func _on_Nkr_disconnected(data:Dictionary)->void:
	print("Diconnected: ",data)
	game.game_state_change_to(game.GameStates.MATCHLIST)