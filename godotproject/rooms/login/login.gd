extends Control

onready var login_email = $TabContainer/Login/TxtEmail
onready var login_password = $TabContainer/Login/TxtPassword
onready var login_btn = $TabContainer/Login/BtnLogin
onready var loginguest_username = $TabContainer/LoginGuest/TxtGuestUsername
onready var loginguest_btn = $TabContainer/LoginGuest/BtnLoginGuest
onready var register_username = $TabContainer/Register/TxtRegisterUsername
onready var register_email = $TabContainer/Register/TxtRegisterEmail
onready var register_password = $TabContainer/Register/TxtRegisterPassword
onready var register_password_repeat = $TabContainer/Register/TxtRegisterPasswordRepeat
onready var register_btn = $TabContainer/Register/BtnRegister
onready var dbg_login = $DbgLogin

var game
var nk

func _ready() -> void:
	game = get_node("/root/Game")
	nk = game.get_nakama_rest_client()
	login_btn.connect("pressed",self,"_on_LoginBtn_pressed")
	loginguest_btn.connect("pressed",self,"_on_LoginguestBtn_pressed")
	register_btn.connect("pressed",self,"_on_RegisterBtn_pressed")
	dbg_login.connect("pressed",self,"_on_DbgLogin_pressed")
	if game.debugging:
		dbg_login.visible = true
		dbg_login.disabled = false

func _on_LoginBtn_pressed()->void:
	var promise = nk.authenticate_email(login_email.text, login_password.text)
	yield(promise,"completed")
	if game.check_promise(promise) && game.nk.authenticated:
		game.game_state_change_to(game.GameStates.MATCHLIST,{})

func _on_LoginguestBtn_pressed()->void:
	var promise = nk.authenticate_custom(loginguest_username.text+String(OS.get_ticks_usec()), true, "Guest_"+loginguest_username.text)
	yield(promise,"completed")
	if game.check_promise(promise) && game.nk.authenticated:
		game.game_state_change_to(game.GameStates.MATCHLIST,{})
	#TODO check if duplicate username, then add random number at the end

func _on_RegisterBtn_pressed()->void:
	if register_password.text != register_password_repeat.text:
		game.show_error(-1,"Passwords don't match")
	var promise = nk.authenticate_email(register_email.text,register_password.text,true,register_username.text)
	yield(promise,"completed")
	if game.check_promise(promise) && game.nk.authenticated:
		game.game_state_change_to(game.GameStates.MATCHLIST,{})

func _on_DbgLogin_pressed()->void:
	var promise = nk.authenticate_custom("DEBUGUSER_"+String(OS.get_unix_time()),true,"DEBUGUSER_"+String(OS.get_unix_time()))
	yield(promise,"completed")
	if game.check_promise(promise) && game.nk.authenticated:
		game.game_state_change_to(game.GameStates.MATCHLIST,{})