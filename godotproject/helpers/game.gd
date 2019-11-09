extends Node

#general
var room:Node
var nk
var nkr

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
	PLAYING = 50
	}

const GameStateScenesPath = {
	GameStates.LOGIN : "res://rooms/login/Login.tscn"
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

func check_promise(promise:Object)->bool:
	if promise.response["data"].has("error"):
		show_error(promise.response["data"]["code"],promise.response["data"]["message"],promise)
		return false
	return true

func show_error(code:int = -1, message:String = "", promise:Object = null)->void:
	###use template:
	#if promise.response["data"].has("error"):
	#	game.show_error(promise.response["data"]["code"],promise.response["data"]["message"],promise)
	###
	var inst = $ErrorPopup
	inst.window_title = "Error code: %s"%(code if code != -1 else "generic (-1)")
	inst.dialog_text = "There was an error (%s)."%code
	if message != "":
		inst.dialog_text = inst.dialog_text + "\nError message:\n" + message
	if promise != null && debugging:
		inst.dialog_text = inst.dialog_text + "\nPromise object response body:\n" + promise.response["body"]
	inst.popup_centered()

func game_state_change_to(new_state:int,args:Dictionary)->void:
	if debugging: print("Changing state to GameState: ",get_game_state_name(new_state))
	if GameStateScenesPath.keys().has(new_state):
		if room != null:
			room.queue_free()
		room = load(GameStateScenesPath[new_state]).instance()
		if room.has_method("initialize"):
			room.initialize(args)
		add_child(room)
	game_state = new_state
	_game_state_changed()

func _game_state_changed()->void:
	match game_state:
		GameStates.LOGIN:
			pass

func get_nakama_rest_client()->Object:
	return nk

func get_nakama_rt_client()->Object:
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