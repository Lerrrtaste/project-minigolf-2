extends Node

#general
var room:Node
var nk
var nkr
var error_queue:Array

const NakamaRestClient = preload("res://addons/nakama-client/NakamaRestClient.gd")

#user/nakama
var username:String
var user_id:String

#server settings
const HOST:String = "192.168.0.234"
const PORT:int = 7350
const KEY:String = "defaultkey"

#game state
enum GameStates {
	INVALID = -1,
	LOGIN = 10,
	MATCHLIST = 30,
	LOBBY = 40,
	PLAYING = 50,
	EDITORMENU = 60,
	EDITOR = 70
	}

const GameStateScenesPath = {
	GameStates.LOGIN : "res://rooms/login/Login.tscn",
	GameStates.MATCHLIST : "res://rooms/matchlist/Matchlist.tscn",
	GameStates.LOBBY : "res://rooms/lobby/Lobby.tscn",
	GameStates.EDITORMENU : "res://rooms/editormenu/EditorMenu.tscn",
	GameStates.EDITOR : "res://rooms/editor/Editor.tscn"
}

var game_state = GameStates.INVALID

#debugging
var debugging := true


func _ready() -> void:
	#start nakama rest
	nk = NakamaRestClient.new()
	nk.host = HOST
	nk.port = PORT
	nk.server_key = KEY
	nk.use_ssl = false
	nk.ssl_validate = false
	nk.debugging = debugging
	add_child(nk)
	
	#open login screen
	game_state_change_to(GameStates.LOGIN,{})

func _process(delta: float) -> void:
	if nkr != null:
		nkr.poll()
	if !$ErrorPopup.visible && error_queue.size() > 0:
		_work_error_queue()

func check_promise(promise:Object)->bool:
	if promise.error != OK:
		show_error(promise.error,"",promise)
		return false
	if promise.response == null:
		show_error(-1,"Promise had no response yet!",promise)
		return false
#	if promise.response.keys().has("error"):
#		show_error(-1,"Promise response had an unknown error",promise)
#		return false
	if promise.response.keys().has("data"):
		if promise.response["data"].keys().has("error"):
			show_error(promise.response["data"]["code"],promise.response["data"]["message"],promise)
			return false
	return true

func show_error(code:int = -1, message:String = "", promise:Object = null)->void:
	###use template:
	#if promise.response["data"].has("error"):
	#	game.show_error(promise.response["data"]["code"],promise.response["data"]["message"],promise)
	###
	error_queue.append([code,message,promise])

func game_state_change_to(new_state:int,args:Dictionary = {})->void:
	if debugging: print("Changing state to GameState: %s%s"%[get_game_state_name(new_state)," with args: "+String(args)])
	if GameStateScenesPath.keys().has(new_state):
		if room != null:
			room.queue_free()
		room = load(GameStateScenesPath[new_state]).instance()
		if room.has_method("initialize"):
			room.initialize(args)
		add_child(room)
	game_state = new_state
	_game_state_changed(args)

func _work_error_queue()->void:
	var error = error_queue.pop_front()
	var code = error[0]
	var message = error[1]
	var promise = error[2]
	
	var inst = $ErrorPopup
	inst.window_title = "Error code: %s"%(code if code != -1 else "generic (-1)")
	inst.dialog_text = "There was an error (%s)."%code
	if message != "":
		inst.dialog_text = inst.dialog_text + "\nError message:\n" + message
	if promise != null && debugging:
		inst.dialog_text = inst.dialog_text + "\nPromise object response body:\n" + promise.response["body"]
	inst.popup_centered()

func _game_state_changed(args:Dictionary)->void:
	match game_state:
		GameStates.LOGIN:
			pass

func get_nakama_rest_client()->Object:
	return nk

func get_nakama_rt_client()->Object:
	if nkr == null:
		nkr = nk.create_realtime_client(true)
	return nkr

static func get_game_state_name(state:int)->String:
	match state:
		-1: return "Inavlid"
		10: return "Login"
		20: return "LoginGuest"
		30: return "Matchlist"
		40: return "Lobby"
		50: return "Playing"
		_: return "Unkown Game State: %s"%state