class_name ProfileStore
extends RefCounted
## Player profiles on this device: an index of {id, name, updated} and, per profile, the
## game's save files under user://profiles/<id>/. Node-free and synchronous, so the lobby,
## the server sync and the tests all share one source of truth.
##
## A profile's files are exactly the ones game.gd writes for its save_path (progress,
## settings, previous save, checkpoint); FILES maps a short key to each file's suffix.

const ROOT := "user://profiles"
const INDEX := "user://profiles/index.json"
const SAVE_NAME := "ninth_tide_progress"
const FILES := {
	"progress": ".json",
	"settings": ".settings.json",
	"prev": ".prev.json",
	"checkpoint": ".pre_ending.json",   # game.gd CHECKPOINT_SUFFIX
}
const NAME_MAX := 24
const LEGACY_SAVE := "user://ninth_tide_progress.json"

var root := ROOT
## The pre-lobby save this store may adopt (tests point it elsewhere).
var legacy_save := LEGACY_SAVE
var _profiles: Array = []   # [{id, name, updated}], most recently played first

func _init(root_dir := ROOT) -> void:
	root = root_dir
	_load()

func _index_path() -> String:
	return root.path_join("index.json")

func _load() -> void:
	_profiles = []
	if not FileAccess.file_exists(_index_path()):
		return
	var j = JSON.parse_string(FileAccess.get_file_as_string(_index_path()))
	if j is Dictionary and j.get("profiles") is Array:
		for p in j.profiles:
			if p is Dictionary and valid_id(str(p.get("id", ""))) and str(p.get("name", "")) != "":
				var e := {"id": str(p.id), "name": clean_name(str(p.name)), "updated": int(p.get("updated", 0))}
				if p.get("local", false):
					e.local = true
				_profiles.append(e)
	_sort()

func _store() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var f := FileAccess.open(_index_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"profiles": _profiles}))

func _sort() -> void:
	_profiles.sort_custom(func(a, b): return a.updated > b.updated if a.updated != b.updated else a.name.nocasecmp_to(b.name) < 0)

## Profiles, most recently played first. Copies: edit through the methods.
func list() -> Array:
	return _profiles.duplicate(true)

func find(id: String) -> Dictionary:
	for p in _profiles:
		if p.id == id:
			return p.duplicate()
	return {}

## Trims, collapses inner whitespace, drops control characters, caps at NAME_MAX.
static func clean_name(s: String) -> String:
	var out := ""
	for ch in s.strip_edges():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			out += ch
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.substr(0, NAME_MAX).strip_edges()

static func valid_id(id: String) -> bool:
	var re := RegEx.create_from_string("^[a-z0-9][a-z0-9-]{0,39}$")
	return re.search(id) != null

## Why `name` can't be a new profile's name, or "" if it can.
func name_problem(name: String) -> String:
	var n := clean_name(name)
	if n == "":
		return "Write a name first."
	for p in _profiles:
		if p.name.nocasecmp_to(n) == 0:
			return "%s already keeps a watch here." % p.name
	return ""

## A url-safe id from the name, unique on this device ("mike", "mike-2", ...).
func make_id(name: String) -> String:
	var slug := ""
	for ch in clean_name(name).to_lower():
		var c := ch.unicode_at(0)
		if (c >= 97 and c <= 122) or (c >= 48 and c <= 57):
			slug += ch
		elif slug != "" and not slug.ends_with("-"):
			slug += "-"
	slug = slug.trim_suffix("-").substr(0, 32)
	if slug == "":
		slug = "player"
	var id := slug
	var n := 2
	while not find(id).is_empty():
		id = "%s-%d" % [slug, n]
		n += 1
	return id

## Adds a profile (id from make_id unless the server already chose one). Returns it, or {}
## if the name is not usable. `local` marks one made while the server was unreachable: it
## survives replace_all() until its first successful upload (touch()).
func create(name: String, id := "", updated := 0, local := false) -> Dictionary:
	if name_problem(name) != "":
		return {}
	if id == "":
		id = make_id(name)
	if not valid_id(id) or not find(id).is_empty():
		return {}
	var p := {"id": id, "name": clean_name(name), "updated": updated}
	if local:
		p.local = true
	_profiles.append(p)
	_sort()
	_store()
	return p.duplicate()

## Replaces the list with the server's view of who exists, keeping local files and any
## profile made offline that the server has not seen yet.
func replace_all(profiles: Array) -> void:
	var pending := _profiles.filter(func(p): return p.get("local", false))
	_profiles = []
	for p in profiles:
		if p is Dictionary and valid_id(str(p.get("id", ""))) and clean_name(str(p.get("name", ""))) != "":
			_profiles.append({"id": str(p.id), "name": clean_name(str(p.name)), "updated": int(p.get("updated", 0))})
	for p in pending:
		if find(p.id).is_empty():
			_profiles.append(p)
	_sort()
	_store()

## Records a play (or a server upload) at `when`; the profile is no longer offline-only.
func touch(id: String, when: int) -> void:
	for p in _profiles:
		if p.id == id:
			p.updated = when
			p.erase("local")
	_sort()
	_store()

## Forgets the profile and deletes its save files.
func remove(id: String) -> void:
	_profiles = _profiles.filter(func(p): return p.id != id)
	_store()
	for key in FILES:
		var path := file_path(id, key)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.path_join(id)))

func dir_of(id: String) -> String:
	return root.path_join(id)

## The save_path to hand game.gd for this profile.
func save_path(id: String) -> String:
	return dir_of(id).path_join(SAVE_NAME + FILES.progress)

func file_path(id: String, key: String) -> String:
	return dir_of(id).path_join(SAVE_NAME + FILES[key])

## {key: text} for each save file that exists.
func read_files(id: String) -> Dictionary:
	var out := {}
	for key in FILES:
		var path := file_path(id, key)
		if FileAccess.file_exists(path):
			out[key] = FileAccess.get_file_as_string(path)
	return out

## Writes the given files (unknown keys ignored); keys absent from `files` are deleted, so
## the device ends up holding exactly the server's copy.
func write_files(id: String, files: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_of(id)))
	for key in FILES:
		var path := file_path(id, key)
		if files.has(key) and files[key] is String:
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_string(files[key])
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## The pre-lobby single save, if this device has one and no profile has taken it yet.
func legacy_files() -> Dictionary:
	var base := legacy_save.get_basename()
	var out := {}
	for key in FILES:
		var path: String = base + FILES[key]
		if FileAccess.file_exists(path):
			out[key] = FileAccess.get_file_as_string(path)
	return out if out.has("progress") else {}

## Hands the legacy save to `id` and removes the old files, so it is adopted only once.
func adopt_legacy(id: String) -> bool:
	var files := legacy_files()
	if files.is_empty():
		return false
	write_files(id, files)
	var base := legacy_save.get_basename()
	for key in FILES:
		var path: String = base + FILES[key]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return true
