extends Reference

var NakamaPromise = preload("res://addons/nakama-client/NakamaPromise.gd")

var socket : WebSocketClient = WebSocketClient.new()
var ready := false

var callbacks = {}
var max_cid = 0

var close_code : int = 0
var close_reason : String = ''

var debugging := false

signal connected ()
signal disconnected (data)
signal error (data)
signal notification (data)
signal match_data (data)
signal match_presence (data)
signal matchmaker_matched (data)
signal status_presence (data)
signal stream_data (data)
signal channel_message (data)
signal channel_presence (data)

func _init() -> void:
	socket.connect("connection_established", self, "_on_connection_established")
	socket.connect("connection_closed", self, "_on_connection_closed")
	socket.connect("connection_error", self, "_on_connection_error")
	socket.connect("data_received", self, "_on_data_received")
	socket.connect("server_close_request", self, "_on_server_close_request")

func connect_to_url(url : String) -> int:
	return socket.connect_to_url(url)

func disconnect_from_host(code : int = 1000, reason : String = ''):
	ready = false
	socket.disconnect_from_host(code, reason)

func send(data : Dictionary, callback_object = null, callback_method : String = ''):
	var promise = NakamaPromise.new(data)
	
	if not ready:
		promise.complete({}, ERR_UNCONFIGURED)
		return promise
	
	if debugging:
		print ("\nNAKAMA REALTIME SENT:")
		print (JSON.print(data))
	
	# Register a callback for this message.
	max_cid += 1
	var cid = max_cid
	callbacks[cid] = promise
	data['cid'] = str(cid)
	
	if data.has('match_data_send'):
		data['match_data_send']['data'] = Marshalls.utf8_to_base64(data['match_data_send']['data'])
		data['match_data_send']['op_code'] = str(data['match_data_send']['op_code'])
	
	var serialized_data = JSON.print(data)

	var error = socket.get_peer(1).put_packet(serialized_data.to_utf8())
	if error != OK:
		promise.complete({}, error)
	
	return promise

func _on_connection_established(protocol : String):
	ready = true
	socket.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	emit_signal("connected")

func _on_connection_error():
	ready = false
	emit_signal("error", {})

func _on_connection_closed(was_clean_close : bool = false):
	ready = false
	var data = {
		was_clean_close = was_clean_close,
		code = close_code,
		reason = close_reason,
	}
	emit_signal("disconnected", data)

func _on_server_close_request(code : int, reason : String):
	close_code = code
	close_reason = reason

func _json_or_null(s : String):
	var json_result : JSONParseResult = JSON.parse(s)
	if json_result.error == OK:
		return json_result.result
	return null

func _on_data_received():
	while socket.get_peer(1).get_available_packet_count() > 0:
		var packet : PoolByteArray = socket.get_peer(1).get_packet()
		
		var json_result : JSONParseResult = JSON.parse(packet.get_string_from_utf8())
		if json_result.error == OK:
			var data = json_result.result
			
			if data.has('cid'):
				# The 'cid' is a respose value that can be passed when sending a payload.
				# It's for targetted responses to a specific message.
				var cid = int(data['cid'])
				if callbacks.has(cid):
					var promise = callbacks[cid];
					callbacks.erase(cid)
					data.erase('cid')
					promise.complete(data)
				else:
					print("Unknown callback for: " + str(data['cid']))
			elif data.has('notifications'):
				for n in data['notifications']['notifications']:
					if n.has('content'):
						n['content'] = _json_or_null(n['content'])
					emit_signal('notification', n)
			elif data.has('match_data'):
				if data['match_data'].has('data') and data['match_data']['data']:
					data['match_data']['data'] = Marshalls.base64_to_utf8(data['match_data']['data'])
				data['match_data']['op_code'] = int(data['match_data']['op_code'])
				emit_signal('match_data', data['match_data'])
			elif data.has('match_presence_event'):
				emit_signal('match_presence', data['match_presence_event'])
			elif data.has('matchmaker_matched'):
				emit_signal('matchmaker_matched', data['matchmaker_matched'])
			elif data.has('status_presence_event'):
				emit_signal('status_presence', data['status_presence_event'])
			elif data.has('stream_data'):
				emit_signal('stream_data', data['stream_data'])
			elif data.has('channel_message'):
				data['channel_message']['content'] = _json_or_null(data['channel_message']['content'])
				emit_signal('channel_message', data['channel_message'])
			elif data.has('channel_presence_event'):
				emit_signal('channel_presence', data['channel_presence_event'])
			else:
				if debugging:
					print("Unrecognized message: " + str(data))
			
			if debugging:
				print ("NAKAMA REALTIME RECEIVED:")
				print (data)
		else:
			if debugging:
				print("JSON parse error: " + packet.get_string_from_utf8())

func poll():
	if socket.get_connection_status() > NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
		socket.poll()
