extends Control

onready var txt_message = $TxtMessage

var game
var nk
var nkr

func _ready() -> void:
	game = get_node("/root/Game")
	nk = game.get_nakama_rest_client()
	nkr = game.get_nakama_rt_client()
	txt_message.connect("text_entered",self,"_on_TxtMessage_text_entered")

func _send_chat_message(msgtxt:String)->void:
	pass#TODO CONTINUE: var promise = nkr.send({"match_data_send":{"op_code": #(Need match id)

func _on_TxtMessage_text_entered(text:String)->void:
	txt_message.text = ""
	_send_chat_message(text)