tool
extends Node

var NakamaRealtimeClient = preload("res://addons/nakama-client/NakamaRealtimeClient.gd")
var NakamaPromise = preload("res://addons/nakama-client/NakamaPromise.gd")

var nkr
var match_id := ""

export (String) var host = "192.168.0.234"
export (int) var port = 7350
export (String) var server_key = "defaultkey"
export (bool) var use_ssl = false
export (bool) var ssl_validate = false
export (bool) var debugging = false

var authenticated := false
var session_token := ''
var session_expires := 0

var client : HTTPRequest = HTTPRequest.new()
var queue := []
var current_request
var current_promise
var errored_promises := []

signal completed (response, request)

func _ready() -> void:
	add_child(client)
	client.connect("request_completed", self, "_on_HTTPRequest_completed")

func _queue_request(request: Dictionary):
	var promise = NakamaPromise.new(request)
	if current_request:
		queue.append([request, promise])
	else:
		_request(request, promise)
	return promise

func _request(request: Dictionary, promise):
	current_request = request
	current_promise = promise
	
	var url = ('https://' if use_ssl else 'http://') + host + ':' + str(port) + '/' + request['path']
	if request.has('query_string') && request['query_string'].size() > 0:
		var query_string = PoolStringArray()
		for k in request['query_string'].keys():
			if typeof(request['query_string'][k]) == TYPE_ARRAY:
				for z in request['query_string'][k].keys():
					query_string.append(k + '=' + str(request['query_string'][k][z]).percent_encode())
			elif typeof(request['query_string'][k]) == TYPE_BOOL:
				query_string.append(k + '=' + ('true' if request['query_string'][k] else 'false'))
			else:
				query_string.append(k + '=' + str(request['query_string'][k]).percent_encode())
		url += '?' + query_string.join('&')
	
	var headers = [
		'Content-Type: application/json',
		'Accept: application/json',
	]
	
	if authenticated && not request['name'].begins_with('authenticate_'):
		headers.append('Authorization: Bearer ' + session_token)
	else:
		headers.append('Authorization: Basic ' + Marshalls.utf8_to_base64(server_key + ':'))
	
	var data = ''
	if request.has('data'):
		data = JSON.print(request['data'])
	
	if debugging:
		print ("NAKAMA REQUEST: " + url)
		print (headers)
		print (data)
	
	var error = client.request(url, headers, ssl_validate, request['method'], data)
	if error != OK:
		promise.error = error
		
		# Defer completing the promise until the next frame.
		errored_promises.append(promise)
		
		_start_next_request()

func _process(delta: float) -> void:
	# Make sure all promises get completed, even ones that errored.
	if errored_promises.size() > 0:
		var promise = errored_promises.pop_front()
		promise.complete({})

func _start_next_request():
	if queue.size() > 0:
		var queue_next = queue.pop_front()
		_request(queue_next[0], queue_next[1])
	else:
		current_request = null
		current_promise = null

func _on_HTTPRequest_completed(result, response_code, headers, body : PoolByteArray):
	var request = current_request
	var promise = current_promise
	
	var response = {
		result = result,
		http_code = response_code,
		headers = headers,
		body = body.get_string_from_utf8(),
		data = {},
	}
	
	if result == HTTPRequest.RESULT_SUCCESS:
		var parse_result = JSON.parse(response['body'])
		if parse_result.error == OK:
			response['data'] = parse_result.result
		
			# If the user successfully authenticated, then store the session token.
			if request['name'].begins_with('authenticate_'):
				authenticated = false
				session_token = ''
				session_expires = 0
				if response_code == 200 && response['data'].has('token'):
					authenticated = true
					_set_session(response['data']['token'])
	
	if debugging:
		print ("NAKAMA RESPONSE:")
		print (response)
	
	# Queue up the next request right away.
	_start_next_request()
	
	# Emit all the signals in order of most specific to least specific.
	promise.complete(response)
	emit_signal(request['name'] + '_completed', response, request)
	emit_signal('completed', response, request)

func _set_session(_session_token):
	authenticated = true
	session_token = _session_token
	session_expires = 0
	
	var parts = session_token.split('.')
	if parts.size() != 3:
		# Something is up with this token! Bail.
		return

	# Godot's base64 utility requires padding on the base64, but the value
	# we get from the JWT token has it stripped. So, add it back first.
	var base64_text = parts[1]
	while base64_text.length() % 4 != 0:
		base64_text += '='
		
	var parse_result = JSON.parse(Marshalls.base64_to_utf8(base64_text))
	if parse_result.error != OK:
		return
	
	var data = parse_result.result
	if data.has('exp'):
		session_expires = int(data['exp'])

func is_session_expired():
	if not session_token:
		return true
	return OS.get_system_time_secs() > session_expires

# If create_status = True, it'll show the user as connected.
func create_realtime_client(create_status : bool = false):
	if not authenticated:
		return null
	
	var url = ('wss://' if use_ssl else 'ws://') + host + ':' + str(port) + '/ws?lang=en&status=' + ('true' if create_status else 'false') + '&token=' + session_token.percent_encode()
	var rtclient = NakamaRealtimeClient.new()
	rtclient.debugging = debugging
	rtclient.connect_to_url(url)
	nkr = rtclient
	return rtclient

#
# AUTOMATICALLY GENERATED:
#

signal authenticate_device_completed (response, request)

# Authenticate a user with a device id against the server.
func authenticate_device(id: String, create: bool = false, username: String = ''):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/authenticate/device',
		data = {},
		query_string = {},
		name = 'authenticate_device',
	}
	
	request['data']['id'] = id
	request['query_string']['create'] = create
	if username != '':
		request['query_string']['username'] = username
	
	return _queue_request(request)

signal authenticate_email_completed (response, request)

# Authenticate a user with an email+password against the server.
func authenticate_email(email: String, password: String, create: bool = false, username: String = ''):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/authenticate/email',
		data = {},
		query_string = {},
		name = 'authenticate_email',
	}
	
	request['data']['email'] = email
	request['data']['password'] = password
	request['query_string']['create'] = create
	if username != '':
		request['query_string']['username'] = username
	
	return _queue_request(request)

signal authenticate_facebook_completed (response, request)

# Authenticate a user with a Facebook OAuth token against the server.
func authenticate_facebook(token: String, create: bool = false, username: String = '', import: bool = false):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/authenticate/facebook',
		data = {},
		query_string = {},
		name = 'authenticate_facebook',
	}
	
	request['data']['token'] = token
	request['query_string']['create'] = create
	if username != '':
		request['query_string']['username'] = username
	if import != false:
		request['data']['import'] = import
	
	return _queue_request(request)

signal authenticate_google_completed (response, request)

# Authenticate a user with Google against the server.
func authenticate_google(token: String, create: bool = false, username: String = ''):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/authenticate/google',
		data = {},
		query_string = {},
		name = 'authenticate_google',
	}
	
	request['data']['token'] = token
	request['query_string']['create'] = create
	if username != '':
		request['query_string']['username'] = username
	
	return _queue_request(request)

signal authenticate_gamecenter_completed (response, request)

# Authenticate a user with Apple's GameCenter against the server.
func authenticate_gamecenter(player_id: String, bundle_id: String, timestamp_seconds: int, salt: String, signature: String, public_key_url: String, create: bool = false, username: String = ''):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/authenticate/gamecenter',
		data = {},
		query_string = {},
		name = 'authenticate_gamecenter',
	}
	
	request['data']['player_id'] = player_id
	request['data']['bundle_id'] = bundle_id
	request['data']['timestamp_seconds'] = timestamp_seconds
	request['data']['salt'] = salt
	request['data']['signature'] = signature
	request['data']['public_key_url'] = public_key_url
	request['query_string']['create'] = create
	if username != '':
		request['query_string']['username'] = username
	
	return _queue_request(request)

signal authenticate_steam_completed (response, request)

# Authenticate a user with Steam against the server.
func authenticate_steam(token: String, create: bool = false, username: String = ''):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/authenticate/steam',
		data = {},
		query_string = {},
		name = 'authenticate_steam',
	}
	
	request['data']['token'] = token
	request['query_string']['create'] = create
	if username != '':
		request['query_string']['username'] = username
	
	return _queue_request(request)

signal authenticate_custom_completed (response, request)

# Authenticate a user with a custom id against the server.
func authenticate_custom(id: String, create: bool = false, username: String = ''):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/authenticate/custom',
		data = {},
		query_string = {},
		name = 'authenticate_custom',
	}
	
	request['data']['id'] = id
	request['query_string']['create'] = create
	if username != '':
		request['query_string']['username'] = username
	
	return _queue_request(request)

signal link_device_completed (response, request)

# Add a device ID to the social profiles on the current user's account.
func link_device(id: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/link/device',
		data = {},
		name = 'link_device',
	}
	
	request['data']['id'] = id
	
	return _queue_request(request)

signal link_email_completed (response, request)

# Add an email+password to the social profiles on the current user's account.
func link_email(email: String, password: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/link/email',
		data = {},
		name = 'link_email',
	}
	
	request['data']['email'] = email
	request['data']['password'] = password
	
	return _queue_request(request)

signal link_facebook_completed (response, request)

# Add Facebook to the social profiles on the current user's account.
func link_facebook(token: String, import: bool = false):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/link/facebook',
		data = {},
		name = 'link_facebook',
	}
	
	request['data']['token'] = token
	if import != false:
		request['data']['import'] = import
	
	return _queue_request(request)

signal link_google_completed (response, request)

# Add Google to the social profiles on the current user's account.
func link_google(token: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/link/google',
		data = {},
		name = 'link_google',
	}
	
	request['data']['token'] = token
	
	return _queue_request(request)

signal link_gamecenter_completed (response, request)

# Add Apple's GameCenter to the social profiles on the current user's account.
func link_gamecenter(player_id: String, bundle_id: String, timestamp_seconds: int, salt: String, signature: String, public_key_url: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/link/gamecenter',
		data = {},
		name = 'link_gamecenter',
	}
	
	request['data']['player_id'] = player_id
	request['data']['bundle_id'] = bundle_id
	request['data']['timestamp_seconds'] = timestamp_seconds
	request['data']['salt'] = salt
	request['data']['signature'] = signature
	request['data']['public_key_url'] = public_key_url
	
	return _queue_request(request)

signal link_steam_completed (response, request)

# Add Steam to the social profiles on the current user's account.
func link_steam(token: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/link/steam',
		data = {},
		name = 'link_steam',
	}
	
	request['data']['token'] = token
	
	return _queue_request(request)

signal link_custom_completed (response, request)

# Add a custom ID to the social profiles on the current user's account.
func link_custom(id: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/link/custom',
		data = {},
		name = 'link_custom',
	}
	
	request['data']['id'] = id
	
	return _queue_request(request)

signal unlink_device_completed (response, request)

# Remove the device ID from the social profiles on the current user's account.
func unlink_device(id: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/unlink/device',
		data = {},
		name = 'unlink_device',
	}
	
	request['data']['id'] = id
	
	return _queue_request(request)

signal unlink_email_completed (response, request)

# Remove the email+password from the social profiles on the current user's account.
func unlink_email(email: String, password: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/unlink/email',
		data = {},
		name = 'unlink_email',
	}
	
	request['data']['email'] = email
	request['data']['password'] = password
	
	return _queue_request(request)

signal unlink_facebook_completed (response, request)

# Remove Facebook from the social profiles on the current user's account.
func unlink_facebook(token: String, import: bool = false):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/unlink/facebook',
		data = {},
		name = 'unlink_facebook',
	}
	
	request['data']['token'] = token
	if import != false:
		request['data']['import'] = import
	
	return _queue_request(request)

signal unlink_google_completed (response, request)

# Remove Google from the social profiles on the current user's account.
func unlink_google(token: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/unlink/google',
		data = {},
		name = 'unlink_google',
	}
	
	request['data']['token'] = token
	
	return _queue_request(request)

signal unlink_gamecenter_completed (response, request)

# Remove Apple's GameCenter from the social profiles on the current user's account.
func unlink_gamecenter(player_id: String, bundle_id: String, timestamp_seconds: int, salt: String, signature: String, public_key_url: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/unlink/gamecenter',
		data = {},
		name = 'unlink_gamecenter',
	}
	
	request['data']['player_id'] = player_id
	request['data']['bundle_id'] = bundle_id
	request['data']['timestamp_seconds'] = timestamp_seconds
	request['data']['salt'] = salt
	request['data']['signature'] = signature
	request['data']['public_key_url'] = public_key_url
	
	return _queue_request(request)

signal unlink_steam_completed (response, request)

# Remove Steam from the social profiles on the current user's account.
func unlink_steam(token: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/unlink/steam',
		data = {},
		name = 'unlink_steam',
	}
	
	request['data']['token'] = token
	
	return _queue_request(request)

signal unlink_custom_completed (response, request)

# Remove the custom ID from the social profiles on the current user's account.
func unlink_custom(id: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/account/unlink/custom',
		data = {},
		name = 'unlink_custom',
	}
	
	request['data']['id'] = id
	
	return _queue_request(request)

signal get_account_completed (response, request)

# Fetch the current user's account.
func get_account():
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/account',
		name = 'get_account',
	}
	
	return _queue_request(request)

signal update_account_completed (response, request)

# Update fields in the current user's account.
func update_account(data: Dictionary):
	var request = {
		method = HTTPClient.METHOD_PUT,
		path = 'v2/account',
		data = {},
		name = 'update_account',
	}
	
	request['data'] = data
	
	return _queue_request(request)

signal get_users_completed (response, request)

# Fetch zero or more users by ID and/or username.
func get_users(ids: Array = [], usernames: Array = [], facebook_ids: Array = []):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/user',
		query_string = {},
		name = 'get_users',
	}
	
	if ids != []:
		request['query_string']['ids'] = ids
	if usernames != []:
		request['query_string']['usernames'] = usernames
	if facebook_ids != []:
		request['query_string']['facebook_ids'] = facebook_ids
	
	return _queue_request(request)

signal import_facebook_friends_completed (response, request)

# Import Facebook friends and add them to a user's account.
func import_facebook_friends(token: String, reset: bool):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/friend/facebook',
		data = {},
		query_string = {},
		name = 'import_facebook_friends',
	}
	
	request['data']['token'] = token
	request['query_string']['reset'] = reset
	
	return _queue_request(request)

signal write_storage_objects_completed (response, request)

# Write objects into the storage engine.
func write_storage_objects(objects: Array):
	var request = {
		method = HTTPClient.METHOD_PUT,
		path = 'v2/storage',
		data = {},
		name = 'write_storage_objects',
	}
	
	request['data']['objects'] = objects
	
	return _queue_request(request)

signal read_storage_objects_completed (response, request)

# Get storage objects.
func read_storage_objects(object_ids: Array):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/storage',
		data = {},
		name = 'read_storage_objects',
	}
	
	request['data']['object_ids'] = object_ids
	
	return _queue_request(request)

signal list_storage_objects_completed (response, request)

# List publicly readable storage objects in a given collection.
func list_storage_objects(collection: String, user_id: String = "null", limit: int = 100, cursor: String = ''):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/storage/' + collection,
		query_string = {},
		name = 'list_storage_objects',
	}
	if user_id != "null":
		request['query_string']['user_id'] = user_id
	if limit != 100:
		request['query_string']['limit'] = limit
	if cursor != '':
		request['query_string']['cursor'] = cursor
	
	return _queue_request(request)

signal delete_storage_objects_completed (response, request)

# Delete one or more objects by ID or username.
func delete_storage_objects(object_ids: Array):
	var request = {
		method = HTTPClient.METHOD_PUT,
		path = 'v2/storage/delete',
		data = {},
		name = 'delete_storage_objects',
	}
	
	request['data']['object_ids'] = object_ids
	
	return _queue_request(request)

signal add_friends_completed (response, request)

# Add friends by ID or username to a user's account.
func add_friends(ids: Array = [], usernames: Array = []):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/friend',
		query_string = {},
		name = 'add_friends',
	}
	
	if ids != []:
		request['query_string']['ids'] = ids
	if usernames != []:
		request['query_string']['usernames'] = usernames
	
	return _queue_request(request)

signal list_friends_completed (response, request)

# List all friends for the current user.
func list_friends():
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/friend',
		name = 'list_friends',
	}
	
	return _queue_request(request)

signal delete_friends_completed (response, request)

# Delete one or more users by ID or username.
func delete_friends(ids: Array = [], usernames: Array = []):
	var request = {
		method = HTTPClient.METHOD_DELETE,
		path = 'v2/friend',
		query_string = {},
		name = 'delete_friends',
	}
	
	if ids != []:
		request['query_string']['ids'] = ids
	if usernames != []:
		request['query_string']['usernames'] = usernames
	
	return _queue_request(request)

signal block_friends_completed (response, request)

# Block one or more users by ID or username.
func block_friends(ids: Array = [], usernames: Array = []):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/friend/block',
		query_string = {},
		name = 'block_friends',
	}
	
	if ids != []:
		request['query_string']['ids'] = ids
	if usernames != []:
		request['query_string']['usernames'] = usernames
	
	return _queue_request(request)

signal list_groups_completed (response, request)

# List groups based on given filters.
func list_groups(name: String, limit: int = 100, cursor: String = ''):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/group',
		query_string = {},
		name = 'list_groups',
	}
	
	request['query_string']['name'] = name
	if limit != 100:
		request['query_string']['limit'] = limit
	if cursor != '':
		request['query_string']['cursor'] = cursor
	
	return _queue_request(request)

signal join_group_completed (response, request)

# Immediately join an open group, or request to join a closed one.
func join_group(group_id: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/group/' + group_id + '/join',
		name = 'join_group',
	}
	
	return _queue_request(request)

signal list_user_groups_completed (response, request)

# List groups the current user belongs to.
func list_user_groups(user_id: String):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/user/' + user_id + '/group',
		name = 'list_user_groups',
	}
	
	return _queue_request(request)

signal list_group_users_completed (response, request)

# List all users that are part of a group.
func list_group_users(group_id: String):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/group/' + group_id + '/user',
		name = 'list_group_users',
	}
	
	return _queue_request(request)

signal create_group_completed (response, request)

# Create a new group with the current user as the owner.
func create_group(data: Dictionary):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/group',
		data = {},
		name = 'create_group',
	}
	
	request['data'] = data
	
	return _queue_request(request)

signal update_group_completed (response, request)

# Update fields in a given group.
func update_group(group_id: String, data: Dictionary):
	var request = {
		method = HTTPClient.METHOD_PUT,
		path = 'v2/group/' + group_id,
		data = {},
		name = 'update_group',
	}
	
	request['data'] = data
	
	return _queue_request(request)

signal leave_group_completed (response, request)

# Leave a group the user is a member of.
func leave_group(group_id: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/group/' + group_id + '/leave',
		name = 'leave_group',
	}
	
	return _queue_request(request)

signal add_group_users_completed (response, request)

# Add users to a group.
func add_group_users(group_id: String, user_ids: Array):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/group/' + group_id + '/add',
		query_string = {},
		name = 'add_group_users',
	}
	
	request['query_string']['user_ids'] = user_ids
	
	return _queue_request(request)

signal promote_group_users_completed (response, request)

# Promote a set of users in a group to the next role up.
func promote_group_users(group_id: String, user_ids: Array):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/group/' + group_id + '/promote',
		query_string = {},
		name = 'promote_group_users',
	}
	
	request['query_string']['user_ids'] = user_ids
	
	return _queue_request(request)

signal kick_group_users_completed (response, request)

# Kick a set of users from a group.
func kick_group_users(group_id: String, user_ids: Array):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/group/' + group_id + '/kick',
		query_string = {},
		name = 'kick_group_users',
	}
	
	request['query_string']['user_ids'] = user_ids
	
	return _queue_request(request)

signal delete_group_completed (response, request)

# Delete a group by ID.
func delete_group(group_id: String):
	var request = {
		method = HTTPClient.METHOD_DELETE,
		path = 'v2/group/' + group_id,
		name = 'delete_group',
	}
	
	return _queue_request(request)

signal list_notifications_completed (response, request)

# Fetch list of notifications.
func list_notifications(limit: int = 100, cursor: String = ''):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/notification',
		data = {},
		query_string = {},
		name = 'list_notifications',
	}
	
	if limit != 100:
		request['query_string']['limit'] = limit
	if cursor != '':
		request['data']['cursor'] = cursor
	
	return _queue_request(request)

signal delete_notifications_completed (response, request)

# Delete one or more notifications for the current user.
func delete_notifications(ids: Array):
	var request = {
		method = HTTPClient.METHOD_DELETE,
		path = 'v2/notification',
		query_string = {},
		name = 'delete_notifications',
	}
	
	request['query_string']['ids'] = ids
	
	return _queue_request(request)

signal list_channel_messages_completed (response, request)

# List a channel's message history.
func list_channel_messages(channel_id: String, limit: int = 100, cursor: String = ''):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/channel/' + channel_id,
		query_string = {},
		name = 'list_channel_messages',
	}
	
	if limit != 100:
		request['query_string']['limit'] = limit
	if cursor != '':
		request['query_string']['cursor'] = cursor
	
	return _queue_request(request)

signal write_leaderboard_record_completed (response, request)

# Write a record to a leaderboard.
func write_leaderboard_record(leaderboard_id: String, record: Dictionary):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/leaderboard/' + leaderboard_id,
		data = {},
		name = 'write_leaderboard_record',
	}
	
	request['data']['record'] = record
	
	return _queue_request(request)

signal list_leaderboard_records_completed (response, request)

# List leaderboard records.
func list_leaderboard_records(leaderboard_id: String, owner_ids: Array = [], cursor: String = ''):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/leaderboard/' + leaderboard_id,
		query_string = {},
		name = 'list_leaderboard_records',
	}
	
	if owner_ids != []:
		request['query_string']['owner_ids'] = owner_ids
	if cursor != '':
		request['query_string']['cursor'] = cursor
	
	return _queue_request(request)

signal list_leaderboard_records_around_owner_completed (response, request)

# List leaderboard records that belong to a user.
func list_leaderboard_records_around_owner(leaderboard_id: String, owner_id: String, limit: int):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/leaderboard/' + leaderboard_id + '/owner/' + owner_id,
		query_string = {},
		name = 'list_leaderboard_records_around_owner',
	}
	
	request['query_string']['limit'] = limit
	
	return _queue_request(request)

signal delete_leaderboard_record_completed (response, request)

# Delete a leaderboard record.
func delete_leaderboard_record(leaderboard_id: String):
	var request = {
		method = HTTPClient.METHOD_DELETE,
		path = 'v2/leaderboard/' + leaderboard_id,
		name = 'delete_leaderboard_record',
	}
	
	return _queue_request(request)

signal list_tournaments_completed (response, request)

# List current or upcoming tournaments.
func list_tournaments(category_start: int, category_end: int, start_time: int, end_type: int = -1, limit: int = 100, cursor: String = ''):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/tournament',
		data = {},
		query_string = {},
		name = 'list_tournaments',
	}
	
	request['query_string']['category_start'] = category_start
	request['query_string']['category_end'] = category_end
	request['query_string']['start_time'] = start_time
	if end_type != -1:
		request['data']['end_type'] = end_type
	if limit != 100:
		request['query_string']['limit'] = limit
	if cursor != '':
		request['query_string']['cursor'] = cursor
	
	return _queue_request(request)

signal join_tournament_completed (response, request)

# Attempt to join an open and running tournament.
func join_tournament(tournament_id: String):
	var request = {
		method = HTTPClient.METHOD_POST,
		path = 'v2/tournament/' + tournament_id + '/join',
		name = 'join_tournament',
	}
	
	return _queue_request(request)

signal list_tournament_records_completed (response, request)

# List tournament records.
func list_tournament_records(tournament_id: String, owner_ids: Array = [], limit: int = 100, cursor: String = ''):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/tournament/' + tournament_id,
		query_string = {},
		name = 'list_tournament_records',
	}
	
	if owner_ids != []:
		request['query_string']['owner_ids'] = owner_ids
	if limit != 100:
		request['query_string']['limit'] = limit
	if cursor != '':
		request['query_string']['cursor'] = cursor
	
	return _queue_request(request)

signal list_tournament_records_around_owner_completed (response, request)

# List tournament records for a given owner.
func list_tournament_records_around_owner(tournament_id: String, owner_id: String, limit: int):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/tournament/' + tournament_id + '/owner/' + owner_id,
		query_string = {},
		name = 'list_tournament_records_around_owner',
	}
	
	request['query_string']['limit'] = limit
	
	return _queue_request(request)

signal write_tournament_record_completed (response, request)

# Write a record to a tournament.
func write_tournament_record(tournament_id: String, score: int, subscore: int, metadata: Dictionary):
	var request = {
		method = HTTPClient.METHOD_PUT,
		path = 'v2/tournament/' + tournament_id,
		data = {},
		name = 'write_tournament_record',
	}
	
	request['data']['score'] = score
	request['data']['subscore'] = subscore
	request['data']['metadata'] = metadata
	
	return _queue_request(request)

signal list_matches_completed (response, request)

# Fetch list of running matches.
func list_matches(limit: int, authoritative: bool=false, label: String ="", min_size: int=-1, max_size: int=-1, query: String=""):
	var request = {
		method = HTTPClient.METHOD_GET,
		path = 'v2/match',
		query_string = {},
		name = 'list_matches',
	}
	
	request['query_string']['limit'] = limit
#	request['query_string']['authoritative'] = authoritative
#	request['query_string']['label'] = label
#	request['query_string']['min_size'] = min_size
#	request['query_string']['max_size'] = max_size
#	request['query_string']['query'] = query
	
	return _queue_request(request)


