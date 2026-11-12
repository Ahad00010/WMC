extends Node

# Native system-browser OAuth with PKCE. Tokens are held only in memory.
signal status_changed(message: String)
signal profile_loaded(profile: Dictionary)
const URL := "https://siwvtpijqgtshaknzoyb.supabase.co"
const KEY := "sb_publishable_YZDH8wjnu0_NoZZN1FXkhQ_c3Gvyqoa"
const PORT := 18674
const REDIRECT := "http://127.0.0.1:18674/callback"
var listener := TCPServer.new()
var peer: StreamPeerTCP
var input := ""
var verifier := ""
var access_token := ""
var pending_at := 0
var request: HTTPRequest

func _ready() -> void:
 request = HTTPRequest.new()
 request.timeout = 20.0
 add_child(request)
 request.request_completed.connect(_response)

func _base64url(bytes: PackedByteArray) -> String:
 return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")

func sign_in() -> void:
 if request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
  status_changed.emit("Please wait for the current request")
  return
 listener.stop()
 var err := listener.listen(PORT, "127.0.0.1")
 if err != OK:
  status_changed.emit("Cannot open local sign-in callback; close other prototype instances")
  return
 verifier = _base64url(Crypto.new().generate_random_bytes(32))
 var hash := HashingContext.new()
 hash.start(HashingContext.HASH_SHA256)
 hash.update(verifier.to_utf8_buffer())
 var challenge := _base64url(hash.finish())
 pending_at = Time.get_ticks_msec()
 peer = null
 input = ""
 var url := URL + "/auth/v1/authorize?provider=google&redirect_to=" + REDIRECT.uri_encode() + "&code_challenge=" + challenge.uri_encode() + "&code_challenge_method=s256"
 if OS.shell_open(url) != OK:
  listener.stop()
  verifier = ""
  status_changed.emit("Could not open your browser")
 else:
  status_changed.emit("Complete sign-in in your browser")

func _process(_delta: float) -> void:
 if not listener.is_listening():
  return
 if Time.get_ticks_msec() - pending_at > 180000:
  listener.stop()
  verifier = ""
  status_changed.emit("Sign-in timed out; try again")
  return
 if peer == null and listener.is_connection_available():
  peer = listener.take_connection()
 if peer == null:
  return
 peer.poll()
 var count := peer.get_available_bytes()
 if count > 0:
  input += peer.get_utf8_string(count)
  if input.length() > 8192:
   peer.disconnect_from_host()
   peer = null
   input = ""
   return
 if not input.contains("\r\n\r\n"):
  if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
   peer = null
   input = ""
  return
 var first := input.get_slice("\r\n", 0).split(" ")
 var code := ""
 if first.size() >= 2 and first[0] == "GET" and first[1].begins_with("/callback?"):
  for field in first[1].get_slice("?", 1).split("&"):
   if field.get_slice("=", 0) == "code":
    code = field.get_slice("=", 1).uri_decode()
 if code.is_empty():
  peer.put_data("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_utf8_buffer())
  peer.disconnect_from_host()
  peer = null
  input = ""
  return
 var body := "Sign-in received. You can return to WMC."
 peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n%s" % [body.to_utf8_buffer().size(), body]).to_utf8_buffer())
 peer.disconnect_from_host()
 peer = null
 listener.stop()
 input = ""
 status_changed.emit("Finishing sign-in…")
 var payload := JSON.stringify({"auth_code": code, "code_verifier": verifier})
 verifier = ""
 var err := request.request(URL + "/auth/v1/token?grant_type=pkce", ["apikey: " + KEY, "Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
 if err != OK:
  status_changed.emit("Could not contact sign-in service")

func _response(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
 if result != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
  access_token = ""
  status_changed.emit("Sign-in or profile request failed; try again")
  return
 var data = JSON.parse_string(body.get_string_from_utf8())
 if data is Dictionary and data.has("access_token"):
  access_token = str(data.access_token)
  var user = data.get("user", {})
  if not user is Dictionary or not user.has("id"):
   access_token = ""
   status_changed.emit("Sign-in response missing user")
   return
  var id: String = str(user.id)
  var path := "/rest/v1/rider_profiles?select=username,display_name,rider_number,plate_color&id=eq." + id.uri_encode()
  var err := request.request(URL + path, ["apikey: " + KEY, "Authorization: Bearer " + access_token], HTTPClient.METHOD_GET)
  if err != OK:
   access_token = ""
   status_changed.emit("Could not load your rider profile")
 elif data is Array:
  if data.size() == 0:
   status_changed.emit("No rider profile yet — create one in the web game")
  elif data[0] is Dictionary:
   profile_loaded.emit(data[0])
 else:
  access_token = ""
  status_changed.emit("Unexpected sign-in response")

func sign_out() -> void:
 listener.stop()
 verifier = ""
 request.cancel_request()
 access_token = ""
 status_changed.emit("Signed out on this device")
