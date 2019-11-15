extends Control

onready var btn_create = $BtnCreate

var game
var nk
var nkr

func _ready() -> void:
	game = get_node("/root/Game")
	nk = game.get_nakama_rest_client()
	nkr = game.get_nakama_rt_client()
	btn_create.connect("pressed",self,"_on_BtnCreate_pressed")

func _on_BtnCreate_pressed()->void:
	game.game_state_change_to(game.GameStates.EDITOR,{"create":true})