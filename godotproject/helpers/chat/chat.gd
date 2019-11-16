extends Control
"""
Chat widget

Needs to be initialized with match id

recieve_message to display game messages
usertext messages are displayed automatically
"""


onready var txt_message = $TxtMessage
onready var chat = $Chatlog

enum MessageTypes {
	USERTEXT,
	EVENT_PRESENCE,
	EVENT_GAME,
	DEBUG,
	ERROR
	}

var initialized := false
var match_id

var game
var nk
var nkr

func initialize(match_id:String)->void:
	if initialized:
		return
	self.match_id = match_id
	initialized = true

func _ready() -> void:
	game = get_node("/root/Game")
	nk = game.get_nakama_rest_client()
	nkr = game.get_nakama_rt_client()
	
	txt_message.connect("text_entered",self,"_on_TxtMessage_text_entered")


func send_usertext(text:String)->void:
	var data_jstr = JSON.print({"message_type":MessageTypes.USERTEXT, "content":text})
	var promise = nkr.send({"match_data_send":{"op_code":2001,"match_id":match_id,"data":data_jstr}})
	#yield(promise,"completed")
	if game.check_promise(promise):
		_chatlog_add(MessageTypes.USERTEXT,text,"You")
	else:
		_chatlog_add(MessageTypes.ERROR,"Could not send message:\n%s"%text)

func recieve_message(message_type:int,content:String,username:String = "")->void:
	#TODO filter bbcode from usertext messages
	_chatlog_add(message_type,content,username)

func recieve_error(content:String)->void:
	_chatlog_add(MessageTypes.ERROR,content)


func _chatlog_add(message_type:int,content:String,username:String = "")->void:
	var time = OS.get_time()
	var new_text := "\n%s:%s:%s - "%[time["hour"],time["minute"],time["second"]] #prefix
	match message_type:
		MessageTypes.USERTEXT:
			new_text += "[b]%s[/b]:\n%s"%[username,content]
		MessageTypes.EVENT_PRESENCE:
			new_text += "[b]%s[/b] [i]%s[/i]"%[username,content]
		MessageTypes.EVENT_GAME:
			if username == "":
				new_text += "[u]%s[/u]"%content
			else:
				new_text += "[b]%s[/b] [u]%s[/u]"%[username,content]
		MessageTypes.DEBUG:
			if !game.debugging:
				return
			new_text += content
		MessageTypes.ERROR:
			new_text += "[color=red][b]ERROR:\n%s[/b][/color]"%content
		_:
			recieve_error("Recieved message with unknown message type")
	chat.bbcode_text += new_text

func _on_TxtMessage_text_entered(text:String)->void:
	txt_message.text = ""
	send_usertext(text)