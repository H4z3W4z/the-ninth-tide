class_name SaveSync
extends Node
## Keeps profiles and their saves on the home server (tools/web/serve.py on Beast), so a
## player's progress follows them to any device on the network.
##
## The game never waits on the network: it reads and writes its files in user:// as always.
## Before a profile plays, pull() copies the server's files down; while it plays, this node
## notices changed files every PUSH_EVERY seconds and uploads them. Last write wins.
##
## Active only in a web build served by serve.py (or when a test sets base_url); elsewhere
## every call reports offline and the lobby uses this device's profiles alone.

signal pushed(id: String, ok: bool)

const API := "/api/profiles"
const PUSH_EVERY := 3.0
const TIMEOUT := 8.0

var base_url := ""
var online := false
var store: ProfileStore

var _playing := ""          # profile whose files are being watched
var _last_sent := ""        # JSON of the files at the last successful push
var _since := 0.0
var _busy := false

func _init(profile_store: ProfileStore = null, url := "") -> void:
	store = profile_store
	base_url = url

func _ready() -> void:
	if base_url == "" and OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("location.origin", true)
		if origin is String and origin.begins_with("http"):
			base_url = origin

func enabled() -> bool:
	return base_url != ""

## {code, data}: code 0 when the server could not be reached.
func call_api(method: int, path: String, body: Variant = null) -> Dictionary:
	if not enabled():
		return {"code": 0, "data": null}
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var payload := "" if body == null else JSON.stringify(body)
	if http.request(base_url + path, headers, method, payload) != OK:
		http.queue_free()
		return {"code": 0, "data": null}
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1] if res[0] == HTTPRequest.RESULT_SUCCESS else 0
	var data = null
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	if text != "":
		data = JSON.parse_string(text)
	return {"code": code, "data": data}

## Fetches the server's profile list into the store. True when the server answered.
func refresh() -> bool:
	var r := await call_api(HTTPClient.METHOD_GET, API)
	online = r.code == 200 and r.data is Dictionary and r.data.get("profiles") is Array
	if online:
		store.replace_all(r.data.profiles)
	return online

## Creates the profile on the server (it picks the id) and in the store. {} on failure;
## {"error": text} when the server refused the name.
func create(name: String) -> Dictionary:
	var r := await call_api(HTTPClient.METHOD_POST, API, {"name": ProfileStore.clean_name(name)})
	if r.code == 201 and r.data is Dictionary:
		online = true
		return store.create(str(r.data.name), str(r.data.id), int(r.data.get("updated", 0)))
	if r.code in [400, 409] and r.data is Dictionary:
		return {"error": str(r.data.get("error", "That name can't be used."))}
	online = r.code != 0
	if not online:
		return store.create(name, "", 0, true)   # uploads with its first save
	return {}

func remove(id: String) -> bool:
	var r := await call_api(HTTPClient.METHOD_DELETE, API + "/" + id)
	online = r.code != 0
	if r.code in [204, 404]:
		store.remove(id)
		return true
	return false

## Copies the server's save for `id` onto this device. True when the device now holds it.
func pull(id: String) -> bool:
	var r := await call_api(HTTPClient.METHOD_GET, API + "/" + id + "/save")
	online = r.code != 0
	if r.code != 200 or not (r.data is Dictionary) or not (r.data.get("files") is Dictionary):
		return false
	store.write_files(id, r.data.files)
	_last_sent = JSON.stringify(store.read_files(id))
	return true

## Uploads `id`'s files now if they changed since the last push.
func push(id: String) -> bool:
	var files := store.read_files(id)
	var text := JSON.stringify(files)
	if text == _last_sent or files.is_empty():
		return true
	# The name rides along so a profile made offline is created on its first upload.
	var r := await call_api(HTTPClient.METHOD_PUT, API + "/" + id + "/save",
		{"files": files, "name": str(store.find(id).get("name", id))})
	online = r.code != 0
	var ok: bool = r.code == 200
	if ok:
		_last_sent = text
		if r.data is Dictionary:
			store.touch(id, int(r.data.get("updated", 0)))
	pushed.emit(id, ok)
	return ok

## Starts watching `id`'s files (call after pull()).
func watch(id: String) -> void:
	_playing = id
	_since = 0.0

## Stops watching after one last push.
func stop() -> void:
	if _playing != "" and enabled():
		var id := _playing
		_playing = ""
		while _busy:
			await get_tree().process_frame
		await push(id)
	_playing = ""

func _process(dt: float) -> void:
	if _playing == "" or not enabled() or _busy:
		return
	_since += dt
	if _since < PUSH_EVERY:
		return
	_since = 0.0
	_busy = true
	await push(_playing)
	_busy = false
