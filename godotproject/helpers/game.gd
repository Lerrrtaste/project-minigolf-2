extends Node

enum GameStates {
	INVALID = -1,
	LOGIN = 10,
	LOGINGUEST = 20,
	MATCHLIST = 30,
	LOBBY = 40,
	PLAYING = 50
	}

const GameStateScenesPath = {
	GameStates.LOGIN : "res://rooms/login/Login.tscn"
}

var game_state = GameStates.INVALID
var debugging := true

func _ready() -> void:
	pass

func game_state_change(new_state:int,args:Dictionary)->void:
	if debugging: print("Changing state to GameState: ",get_game_state_name(new_state))

func get_game_state_name(state:int)->String:
	match state:
		-1: return "Inavlid"
		10: return "Login"
		20: return "LoginGuest"
		30: return "Matchlist"
		40: return "Lobby"
		50: return "Playing"
		_: return "Unkown Game State: %s"%state