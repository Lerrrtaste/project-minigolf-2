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
setting_passphrase:string (open or password)
setting_turntimer:int (seconds for each turn)
setting_voteskip:int (vote amount or -1 for hostskip only)
setting_mapmode:int (random, select at lobby,vote after each map)
settubg_rounds:int (if not select at at lobbymapmode, how many rounds)
setting_maps:Dictionary {map_ids:int[], added by : presence}
"""

onready var lst_opponents = $TabContainer/Opponents/LstOpponents
onready var chat = $Chat
onready var btn_ready = $BtnReady
onready var lbl_ready = $BtnReady/LblReady
onready var timer = $Timer
onready var txt_settings_passphrase = $TabContainer/Settings/SettingsContainer/TxtSettingsPassphrase
onready var spin_settigs_turntimer = $TabContainer/Settings/SettingsContainer/SpinSettingsTurntimer
onready var check_settings_voteskip = $TabContainer/Settings/SettingsContainer/CheckSettingsVoteskip
onready var spin_settings_voteskip_required = $TabContainer/Settings/SettingsContainer/SpinSettingsVoteskipRequired
onready var check_settings_mapmode = $TabContainer/Settings/SettingsContainer/CheckSettingsMapMode
onready var spin_settings_rounds = $TabContainer/Settings/SettingsContainer/SpinSettingsRounds
onready var btn_settings_save = $TabContainer/Settings/SettingsContainer/BtnSettingsSave
onready var lbl_settings_voteskip_required = $TabContainer/Settings/SettingsContainer/LblSettingsVoteskipRequired
onready var lbl_settings_rounds = $TabContainer/Settings/SettingsContainer/LblSettingsRounds
onready var btn_exit = $Chat/BtnExit
onready var maps_tab = $TabContainer/Maps
onready var tab_container = $TabContainer
onready var lst_maps_user = $TabContainer/Maps/MapsContainer/MapsBrowse/LstMapsUser
onready var lst_maps_selected = $TabContainer/Maps/MapsContainer/MapsSelectedContainer/LstMapsSelected

const GAME_START_DELAY = 5

enum Settings {
	PASSPHRASE, #string
	TURNTIMER, #int 
	VOTESKIP, #int
	MAPMODE, #int
	ROUNDS, #int
	MAPS #Dictionary {map_ids:int[], added by : presence}
	}


var map_modes = {
	0:"random",
	1:"random from featured",
	2:"selected maps",
	3:"vote from featured after each round"
	}

var default_settings = {Settings.PASSPHRASE: "",
						Settings.TURNTIMER: 30,
						Settings.VOTESKIP: -1,
						Settings.MAPMODE: 2,
						Settings.ROUNDS: 5,
						Settings.MAPS: []
						}
var m #(containes self, matchid and maybe presences)
var opponents:Dictionary # {userid : {"presence":presence, "ready":bool}
var match_settings:Dictionary
var countdown:int
var host_mode := false
var host_presence:Dictionary

var game
var nk
var nkr

func initialize(args:Dictionary)->void:
	m = args["match"]
	if args["host"]:
		_is_host()
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
	btn_exit.connect("pressed",self,"_on_BtnExit_pressed")
	btn_settings_save.connect("pressed",self,"_on_BtnSettingsSave_pressed")
	check_settings_voteskip.connect("toggled",self,"_on_CheckSettingsVoteskip_toggled")
	check_settings_mapmode.connect("item_selected",self,"_on_CheckSettingsMapMode_item_selected")
	lst_maps_user.connect("item_activated",self,"_on_LstMapsUser_item_activated")
	lst_maps_selected.connect("item_activated",self,"_on_LstMapsSelected_item_activated")
	
	for i in map_modes:
		check_settings_mapmode.add_item(map_modes[i],i)
	
	maps_update()


#maps
func maps_update()->void:
	#TODO list featured
	#own public maps
	lst_maps_user.clear()
	var promise = nk.list_storage_objects("maps",game.user["user"]["id"],100)
	yield(promise,"completed")
	game.check_promise(promise)
	
	if !promise.response["data"].has("objects"):
		return
	
	for i in promise.response["data"]["objects"]:
		if i["permission_read"] != 2:
			continue
		var parse_result = JSON.parse(i["value"])
		if parse_result.error != OK:
			game.show_error(-1,"Map data corrupt. Cant load! Parse error:\n%s\nat line: %s"%[parse_result.error_string,parse_result.error_line])
			continue
		var mapdata = parse_result.result
		var list_title = "%s by %s"%[mapdata["name"],game.user["user"]["username"]]
		lst_maps_user.add_item(list_title)
		lst_maps_user.set_item_metadata(lst_maps_user.get_item_count()-1,i)

func _map_select(map_id:String,map_owner_uid:String)->void:
	for i in lst_maps_selected.get_item_count():
		if lst_maps_selected.get_item_metadata(i) == map_id:
			game.show_error(-1,"Map was already selected! ID:%s"%map_id)
			return #map already selected
	
	var promise = nk.read_storage_objects([{"collection":"maps","key":map_id,"user_id":map_owner_uid}])
	yield(promise,"completed")
	if !game.check_promise(promise):
		return
	var obj = promise.response["data"]["objects"][0]
	var parse_result = JSON.parse(obj["value"])
	if parse_result.error != OK:
		game.show_error(-1,"Map data corrupt. Cant load! Parse error:\n%s\nat line: %s"%[parse_result.error_string,parse_result.error_line])
		return
	obj["mapdata"] = parse_result.result
	var list_title = "%s by %s"%[obj["mapdata"]["name"],game.user["user"]["username"]]
	lst_maps_selected.add_item(list_title)
	#game.show_error(-1,"ADDDDDDDING: %s"%obj)
	lst_maps_selected.set_item_metadata(lst_maps_selected.get_item_count()-1,obj["mapdata"]["map_id"])

func _map_deselect(map_id:String)->void:
	for i in lst_maps_selected.get_item_count():
		if lst_maps_selected.get_item_metadata(i) == map_id:
			lst_maps_selected.remove_item(i)
			return
	game.show_error(-1,"Trying to deselect not selected map! ID:%s"%map_id)

func map_request(add:Array,remove:Array)->void:
	var data = JSON.print({"add":add, "remove":remove})
	var match_data = {"op_code":1003,"match_id":m["match_id"],"data":data}
	if host_mode:
		match_data["presence"] = m["self"]
		_on_Nkr_match_data(match_data)
	else:
		nkr.send({"match_data_send":match_data})



#presence
func presence_join(presence:Dictionary)->void:
	if opponents.has(presence["user_id"]):
		game.show_error(-1,"Joining presence was already joined:\n%s"%presence)
		return
	
	opponents[presence["user_id"]] = { "presence":presence, "ready": false}
	lst_opponents.add_item(presence["username"] )
	lst_opponents.set_item_metadata(lst_opponents.get_item_count()-1,presence["user_id"])
	chat.recieve_message(chat.MessageTypes.EVENT_PRESENCE,"joined",presence["username"])
	if host_mode:
		setting_share()
	if presence != m["self"]: # if someone else joined share current ready state again
		_on_BtnReady_toggled(btn_ready.pressed)

func presence_leave(presence:Dictionary)->void:
	if !opponents.has(presence["user_id"]):
		game.show_error(-1,"Leaving presence was not joined:\n%s"%presence)
		return
	
	if presence["user_id"] == host_presence["user_id"]:
		game.show_error(-1,"Match closed early, host has left")
		_on_BtnExit_pressed()
	
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
	
	var changed = opponents[presence["user_id"]]["ready"] != ready
	
	opponents[presence["user_id"]]["ready"] = ready
	for i in lst_opponents.get_item_count():
		if lst_opponents.get_item_metadata(i) == presence["user_id"]:
			var prefix = "READY | " if ready else ""
			var suffix = ""
			if host_presence.has("user_id"):
				if presence["user_id"] == host_presence["user_id"]:
					suffix = " (HOST)" 
			lst_opponents.set_item_text(i,"%s%s%s"%[prefix,presence["username"],suffix])
	
	if changed:
		chat.recieve_message(chat.MessageTypes.EVENT_GAME,"is ready" if ready else "is not ready anymore :(",presence["username"])
	
	#loop returns if not all ready 
	for i in opponents.keys():
		if opponents[i]["ready"] == false:
			if !timer.is_stopped():
				chat.recieve_message(chat.MessageTypes.EVENT_GAME,"Aborting game start")
				timer.stop()
			return
	countdown = GAME_START_DELAY
	timer.start(1)
	chat.recieve_message(chat.MessageTypes.EVENT_GAME,"Starting game in...")


#settings
func setting_set(setting:int,val,silent:bool=false)->void:
	if match_settings.has(setting):
		if match_settings[setting] == val:
			return
	match_settings[setting] = val
	var setting_name:String
	var val_name:String
	match setting:
		Settings.MAPS:
			for i in val:
				lst_maps_selected.clear()
				_map_select(i["map_id"],i["map_owner_uid"])
		Settings.VOTESKIP:
			setting_name = "Voteskip"
			val_name = "off" if val == -1 else String(val)
			check_settings_voteskip.pressed = val != -1
			spin_settings_voteskip_required.value = val
		Settings.MAPMODE:
			setting_name = "MapMode"
			val_name = map_modes[int(val)]
			check_settings_mapmode.selected = val
			tab_container.set_tab_disabled(1,val != 2)
			if tab_container.current_tab == 1 && val != 2: #change to differenct tab if on maps which gets disabled
				tab_container.current_tab = 0
			_on_CheckSettingsMapMode_item_selected(val)
		Settings.PASSPHRASE:
			setting_name = "Passphrase"
			val_name = "*******"
			if host_mode:
				txt_settings_passphrase.text = val
		Settings.TURNTIMER:
			setting_name = "Turntimer"
			val_name = "%ss"%val
			spin_settigs_turntimer.value = val
		Settings.ROUNDS:
			setting_name = "Rounds"
			val_name = String(val)
			spin_settings_rounds.value = val
	if !silent:
		chat.recieve_message(chat.MessageTypes.EVENT_GAME,"%s set to %s"%[setting_name,val_name])

func setting_map_change(add:Array,remove:Array, presence:Dictionary)->void:
	chat.recieve_message(chat.MessageTypes.EVENT_PRESENCE,"added %s and removed %s maps from the selection"%[add.size(),remove.size()],presence["username"])
	if host_mode:
		for i in add:
			if !match_settings[Settings.MAPS].has(i):
				match_settings[Settings.MAPS].append(i)
				_map_select(i["map_id"],i["map_owner_uid"])
		for i in remove:
			match_settings[Settings.MAPS].erase(i)
			_map_deselect(i)
		setting_share()

func setting_share()->void:
	if !host_mode:
		game.show_error(-1,"Trying to share match_settings while not in hostmode!")
		return
	var data = JSON.print({"match_settings":match_settings, "host":m["self"]})
	var promise = nkr.send({"match_data_send" : {"op_code":1002,"match_id":m["match_id"],"data":data}})
	game.check_promise(promise)
	chat.recieve_message(chat.MessageTypes.EVENT_GAME,"Settings have been updated")

func setting_save()->void:
	if !host_mode:
		game.show_error(-1,"Trying to save settings while not in host mode")
		return
	
	setting_set(Settings.PASSPHRASE,txt_settings_passphrase.text)
	setting_set(Settings.TURNTIMER,spin_settigs_turntimer.value)
	setting_set(Settings.VOTESKIP,spin_settings_voteskip_required.value if check_settings_voteskip.pressed else -1)
	setting_set(Settings.MAPMODE,check_settings_mapmode.selected)
	setting_set(Settings.ROUNDS,spin_settings_rounds.value)
	setting_share()


#host
func _is_host()->void:
	host_mode = true
	host_presence = m["self"]
	chat.recieve_message(chat.MessageTypes.EVENT_GAME,"You are the game host!")
	txt_settings_passphrase.editable = true
	spin_settigs_turntimer.editable = true
	check_settings_voteskip.disabled = false
	spin_settings_voteskip_required.editable = true
	check_settings_mapmode.disabled = false
	spin_settings_rounds.editable = true
	btn_settings_save.disabled = false
	
	for i in default_settings.keys():
		setting_set(i,default_settings[i],true)

func _set_host(host_presence:Dictionary)->void:
	self.host_presence = host_presence
	chat.recieve_message(chat.MessageTypes.EVENT_PRESENCE,"is the game host!",host_presence["username"])
	presence_ready(host_presence,opponents[host_presence["user_id"]]["ready"]) # TO UPDATE USERNAME (ADD " (HOST)")


#events
func _on_LstMapsUser_item_activated(idx:int)->void:
	var obj = lst_maps_user.get_item_metadata(idx)
	map_request([{"map_id":obj["key"], "map_owner_uid":obj["user_id"]}],[])

func _on_LstMapsSelected_item_activated(idx:int)->void:
	map_request([],[lst_maps_selected.get_item_metadata(idx)])

func _on_CheckSettingsVoteskip_toggled(val:bool)->void:
	lbl_settings_voteskip_required.visible = val
	spin_settings_voteskip_required.visible = val

func _on_CheckSettingsMapMode_item_selected(id:int)->void:
	lbl_settings_rounds.visible = id != 2
	spin_settings_rounds.visible = id != 2

func _on_BtnSettingsSave_pressed()->void:
	setting_save()

func _on_BtnExit_pressed()->void:
	nkr.send({"match_leave":{"match_id":m["match_id"]}})
	game.game_state_change_to(game.GameStates.MATCHLIST)

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
		1002: #match_settings update
			if !host_presence.has_all(["user_id","username","session_id"]):
				_set_host(match_data["host"])
			for i in match_data["match_settings"].keys():
				setting_set(int(i),match_data["match_settings"][i])
		1003: #map_id change:
			setting_map_change(match_data["add"],match_data["remove"],data["presence"])

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