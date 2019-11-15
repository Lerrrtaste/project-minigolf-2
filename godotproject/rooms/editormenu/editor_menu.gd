extends Control

"""
Editor menu
shows all maps created by user and allows to edit/delete them or create a new map


When loading a map the game state changes to Editor and the following arguments are to be passed:
create:bool
mapdata:Dictionary -> When create false the mapdata of the map to be loaded needs to be retrieved from the nakama container
"""

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