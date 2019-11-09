extends Reference

var error : int = OK
var completed : bool = false

var request : Dictionary
var response : Dictionary

signal completed (response, request)

func _init(_request: Dictionary):
	request = _request

func complete(_response: Dictionary,error_reason = error) -> void:
	response = _response
	response['error'] = error_reason
	completed = true
	emit_signal("completed", response, request)