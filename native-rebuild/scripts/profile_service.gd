class_name WmcProfileService
extends Node

signal status_changed(text: String)
signal profile_loaded(profile: Dictionary)
signal profile_error(text: String)
const SERVICE_URL := "https://siwvtpijqgtshaknzoyb.supabase.co"
const PUBLIC_KEY := "sb_publishable_YZDH8wjnu0_NoZZN1FXkhQ_c3Gvyqoa"
const CALLBACK_PORT := 18674
const CALLBACK := "http://127.0.0.1:18674/callback"
var token := ""
var user_id := ""
var _verifier := ""
var _operation := ""
var _listener := TCPServer.new()
var _connection: StreamPeerTCP
var _incoming := ""
var _started_at := 0
var _http: HTTPRequest

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20
	add_child(_http)
	_http.request_completed.connect(_on_response)

func sign_in() -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		status_changed.emit("Please wait for the current request")
		return
	_listener.stop()
	if _listener.listen(CALLBACK_PORT, "127.0.0.1") != OK:
		status_changed.emit("Could not open the sign-in callback")
		return
	_verifier = _url64(Crypto.new().generate_random_bytes(32))
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(_verifier.to_utf8_buffer())
	var challenge := _url64(hash.finish())
	_started_at = Time.get_ticks_msec()
	_incoming = ""
	_connection = null
	var address := SERVICE_URL + "/auth/v1/authorize?provider=google&redirect_to=" + CALLBACK.uri_encode() + "&code_challenge=" + challenge.uri_encode() + "&code_challenge_method=s256"
	if OS.shell_open(address) != OK:
		_listener.stop()
		_verifier = ""
		status_changed.emit("Could not open the browser")
	else:
		status_changed.emit("Complete sign-in in your browser")

func _url64(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")

func _process(_delta: float) -> void:
	if not _listener.is_listening():
		return
	if Time.get_ticks_msec() - _started_at > 180000:
		_listener.stop()
		_verifier = ""
		status_changed.emit("Sign-in timed out")
		return
	if not _connection and _listener.is_connection_available():
		_connection = _listener.take_connection()
	if not _connection:
		return
	_connection.poll()
	var count := _connection.get_available_bytes()
	if count > 0:
		_incoming += _connection.get_utf8_string(count)
	if _incoming.length() > 8192:
		_connection.disconnect_from_host()
		_connection = null
		_incoming = ""
		return
	if not _incoming.contains("\r\n\r\n"):
		if _connection.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_connection = null
			_incoming = ""
		return
	var fields := _incoming.get_slice("\r\n", 0).split(" ")
	var code := ""
	if fields.size() >= 2 and fields[0] == "GET" and fields[1].begins_with("/callback?"):
		for field in fields[1].get_slice("?", 1).split("&"):
			if field.get_slice("=", 0) == "code":
				code = field.get_slice("=", 1).uri_decode()
	var body := "Sign-in received. Return to WMC." if not code.is_empty() else "Invalid callback."
	var status := "200 OK" if not code.is_empty() else "400 Bad Request"
	_connection.put_data(("HTTP/1.1 %s\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [status, body.to_utf8_buffer().size(), body]).to_utf8_buffer())
	_connection.disconnect_from_host()
	_connection = null
	_incoming = ""
	if code.is_empty():
		return
	_listener.stop()
	_operation = "token"
	var payload := JSON.stringify({"auth_code": code, "code_verifier": _verifier})
	_verifier = ""
	_send("/auth/v1/token?grant_type=pkce", HTTPClient.METHOD_POST, payload, false)

func _send(path: String, method: HTTPClient.Method, payload: String, authorized: bool) -> void:
	var headers := PackedStringArray(["apikey: " + PUBLIC_KEY, "Content-Type: application/json"])
	if authorized:
		headers.append("Authorization: Bearer " + token)
	if _operation == "save":
		headers.append("Prefer: resolution=merge-duplicates,return=representation")
	if _http.request(SERVICE_URL + path, headers, method, payload) != OK:
		_operation = ""
		profile_error.emit("Could not contact profile service")

func _on_response(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var operation := _operation
	_operation = ""
	var data = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
		var message := "Profile request failed. Please try again."
		if data is Dictionary and data.get("code", "") == "23505":
			message = "That username is already taken."
		profile_error.emit(message)
		return
	if operation == "token" and data is Dictionary and data.has("access_token"):
		token = str(data.access_token)
		var user: Dictionary = data.get("user", {})
		user_id = str(user.get("id", ""))
		if user_id.is_empty():
			sign_out()
			profile_error.emit("Sign-in response missing user")
			return
		_operation = "load"
		_send("/rest/v1/rider_profiles?select=username,display_name,rider_number,plate_color&id=eq." + user_id.uri_encode(), HTTPClient.METHOD_GET, "", true)
	elif operation in ["load", "save"] and data is Array:
		profile_loaded.emit(data[0] if not data.is_empty() and data[0] is Dictionary else {})
	else:
		profile_error.emit("Unexpected profile service response")

func save_profile(display_name: String, username: String, number: int, color: String) -> void:
	if token.is_empty() or user_id.is_empty():
		profile_error.emit("Sign in first")
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		profile_error.emit("Please wait for the current request")
		return
	var name := " ".join(display_name.strip_edges().split(" ", false))
	var handle := username.strip_edges().to_lower()
	var name_regex := RegEx.create_from_string("^\\S+\\s+\\S+(?:\\s+.*\\S)?$")
	var handle_regex := RegEx.create_from_string("^[a-z0-9_]{3,20}$")
	if name.length() > 15 or name_regex.search(name) == null:
		profile_error.emit("Use at least two names, up to 15 characters")
		return
	if handle_regex.search(handle) == null:
		profile_error.emit("Username must be 3–20 letters, numbers or underscores")
		return
	if number < 10 or number > 99 or color not in ["blue", "red", "yellow", "orange", "green", "cyan", "purple", "pink", "white", "black", "silver"]:
		profile_error.emit("Choose a two-digit number and plate color")
		return
	_operation = "save"
	var payload := JSON.stringify({"id": user_id, "display_name": name, "username": handle, "rider_number": number, "plate_color": color})
	_send("/rest/v1/rider_profiles?on_conflict=id&select=username,display_name,rider_number,plate_color", HTTPClient.METHOD_POST, payload, true)

func sign_out() -> void:
	_listener.stop()
	_verifier = ""
	_http.cancel_request()
	token = ""
	user_id = ""
	_operation = ""
	status_changed.emit("Signed out")
