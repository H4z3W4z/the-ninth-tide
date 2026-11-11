extends SceneTree
## Lobby tests: ProfileStore (names, ids, files, legacy adoption, offline profiles), the lobby
## hosting the game with each player's own save and Switch player, and SaveSync against a
## live tools/web/serve.py (skipped if python3 is missing). Run after an import:
##   godot --headless --path . --script tests/lobby_test.gd

const ROOT := "user://test_profiles"
var failures: Array = []
var checks := 0
## Each section adds its name as its last line: a script error that aborts one shows up as
## a missing section, never as a silent pass.
var finished: Array = []

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_wipe(ROOT)
	_store_tests()
	_wipe(ROOT)
	await _lobby_tests()
	_wipe(ROOT)
	await _sync_tests()
	_wipe(ROOT)
	for sec in ["store", "lobby", "sync"]:
		check(sec in finished, "section %s ran to the end" % sec)
	if failures.is_empty():
		print("PASS: lobby_test (%d checks)" % checks)
	else:
		print("FAIL (%d): %s" % [failures.size(), "; ".join(failures)])
	quit(0 if failures.is_empty() else 1)

func _wipe(dir: String) -> void:
	var abs := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs):
		return
	for sub in DirAccess.get_directories_at(abs):
		_wipe(dir.path_join(sub))
	for f in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(f))
	DirAccess.remove_absolute(abs)

# ---------------------------------------------------------------------------
func _store_tests() -> void:
	var s := ProfileStore.new(ROOT)
	s.legacy_save = ROOT + "_legacy/ninth_tide_progress.json"
	check(s.list().is_empty(), "store starts empty")
	check(s.legacy_files().is_empty(), "no legacy save")
	check(ProfileStore.clean_name("  Ada \t  Lovelace\n") == "Ada Lovelace", "clean_name collapses whitespace")
	check(ProfileStore.clean_name("x".repeat(40)).length() == ProfileStore.NAME_MAX, "clean_name caps length")
	check(s.name_problem("   ") != "", "blank name refused")
	var a := s.create("Ada")
	check(a.id == "ada" and a.name == "Ada", "create: id from name")
	check(s.name_problem("ADA") != "", "names unique, case-insensitive")
	check(s.create("ada").is_empty(), "duplicate create refused")
	check(s.make_id("Ada!") == "ada-2", "make_id avoids taken ids")
	check(s.make_id("???") == "player", "make_id fallback")
	check(not ProfileStore.valid_id("../x") and not ProfileStore.valid_id("A") and ProfileStore.valid_id("a-1"), "valid_id")
	var b := s.create("Grace Hopper")
	check(b.id == "grace-hopper", "slug id")
	s.touch("grace-hopper", 200)
	s.touch("ada", 100)
	check(s.list().map(func(p): return p.id) == ["grace-hopper", "ada"], "most recent first")
	# Files
	s.write_files("ada", {"progress": "{\"a\":1}", "settings": "{}", "bogus": "x"})
	check(s.read_files("ada") == {"progress": "{\"a\":1}", "settings": "{}"}, "write/read files, unknown keys ignored")
	check(s.save_path("ada") == ROOT + "/ada/ninth_tide_progress.json", "save_path")
	check(FileAccess.file_exists(s.file_path("ada", "settings")) and s.file_path("ada", "settings").ends_with(".settings.json"), "settings file beside the save")
	s.write_files("ada", {"progress": "{}"})
	check(s.read_files("ada").keys() == ["progress"], "write_files drops files the server lacks")
	# Persistence
	var s2 := ProfileStore.new(ROOT)
	check(s2.list().size() == 2 and s2.find("ada").name == "Ada", "index persists")
	# Offline-created profiles survive the server's list until uploaded
	var c := s2.create("Offline Olga", "", 0, true)
	s2.replace_all([{"id": "ada", "name": "Ada", "updated": 5}])
	check(s2.list().map(func(p): return p.id) == ["ada", "offline-olga"], "replace_all keeps offline-only profiles")
	s2.touch("offline-olga", 9)
	s2.replace_all([{"id": "ada", "name": "Ada", "updated": 5}])
	check(s2.find("offline-olga").is_empty(), "uploaded profile follows the server")
	check(s2.find("grace-hopper").is_empty(), "removed elsewhere -> gone here")
	s2.replace_all([{"id": "BAD", "name": "x"}, {"id": "ok", "name": "  "}, {"id": "fine", "name": "Fine"}])
	check(s2.list().map(func(p): return p.id) == ["fine"], "replace_all drops malformed entries")
	# Remove
	s2.write_files("fine", {"progress": "{}"})
	s2.remove("fine")
	check(s2.list().is_empty() and not FileAccess.file_exists(s2.file_path("fine", "progress")), "remove deletes files")
	# Legacy adoption: the pre-lobby save moves to a profile once.
	s2.legacy_save = ROOT + "_legacy/ninth_tide_progress.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "_legacy"))
	var lf := FileAccess.open(s2.legacy_save, FileAccess.WRITE)
	lf.store_string("{\"old\":1}")
	lf.close()
	var lf2 := FileAccess.open(ROOT + "_legacy/ninth_tide_progress.settings.json", FileAccess.WRITE)
	lf2.store_string("{}")
	lf2.close()
	s2.create("Old Hand")
	check(s2.adopt_legacy("old-hand") and s2.read_files("old-hand") == {"progress": "{\"old\":1}", "settings": "{}"}, "legacy save adopted")
	check(s2.legacy_files().is_empty() and not s2.adopt_legacy("old-hand"), "legacy adopted only once")
	_wipe(ROOT + "_legacy")
	finished.append("store")

# ---------------------------------------------------------------------------
func _lobby_tests() -> void:
	var lobby = load("res://game/lobby/lobby.tscn").instantiate()
	lobby.store = ProfileStore.new(ROOT)
	lobby.store.legacy_save = ROOT + "_legacy/none.json"
	root.add_child(lobby)
	await process_frame
	await process_frame
	check(lobby.state == "pick", "lobby opens on the picker (got %s)" % lobby.state)
	check(not lobby.sync.enabled(), "no server outside the web build")
	check(lobby.action_at(lobby.new_rect().get_center()) == "new", "empty lobby offers a new player")
	await lobby.act("new")
	check(lobby.state == "naming" and lobby.name_edit.visible, "New opens the name entry")
	lobby.name_edit.text = "  "
	await lobby.act("begin")
	check(lobby.state == "naming" and lobby.notice != "", "blank name refused with a notice")
	lobby.name_edit.text = "Ada"
	await lobby.act("begin")
	check(lobby.state == "playing" and lobby.game != null, "Begin starts the game")
	var g = lobby.game
	check(g.save_path == ROOT + "/ada/ninth_tide_progress.json", "game uses the player's save (%s)" % g.save_path)
	check(g.player_name == "Ada" and not g.migrate_slice_save, "game knows its player")
	# Play a little: begin the game, which saves.
	g.dispatch("begin")
	check(FileAccess.file_exists(g.save_path), "the player's save is written")
	var ada_save := FileAccess.get_file_as_string(g.save_path)
	# The menu offers Switch player.
	g.dispatch("menu")
	check(g._core_action_at(g._menu_rect(4).get_center()) == "switch_player", "menu has Switch player")
	g.dispatch("switch_player")
	for i in 5:
		await process_frame
	check(lobby.state == "pick" and lobby.game == null, "Switch player returns to the lobby")
	check(not is_instance_valid(g) or g.is_queued_for_deletion(), "the old game is freed")
	# A second player starts fresh, and Ada's save is untouched.
	await lobby.act("new")
	lobby.name_edit.text = "Grace"
	await lobby.act("begin")
	var g2 = lobby.game
	check(g2.save_path.contains("/grace/") and not g2.sim.state.started, "a new player starts at the title")
	g2.dispatch("menu")
	g2.dispatch("switch_player")
	for i in 5:
		await process_frame
	check(FileAccess.get_file_as_string(lobby.store.save_path("ada")) == ada_save, "players' saves stay apart")
	# Back into Ada: her progress loads.
	await lobby.start("ada")
	check(lobby.game.sim.state.started, "Ada resumes her watch")
	# Remove needs two clicks.
	lobby.game.dispatch("menu")
	lobby.game.dispatch("switch_player")
	for i in 5:
		await process_frame
	var i_grace: int = lobby.shown_profiles().map(func(p): return p.id).find("grace")
	await lobby.act(lobby.action_at(lobby.remove_rect(i_grace).get_center()))
	check(not lobby.store.find("grace").is_empty(), "first Remove click only arms")
	await lobby.act("remove:grace")
	check(lobby.store.find("grace").is_empty(), "second click removes")
	lobby.queue_free()
	await process_frame
	finished.append("lobby")

# ---------------------------------------------------------------------------
func _sync_tests() -> void:
	var py := "python3"
	if OS.execute(py, ["-c", "pass"]) != 0:
		print("SKIP: sync tests (no python3)")
		finished.append("sync")
		return
	var data := ProjectSettings.globalize_path("user://test_serve_data")
	var port := 18000 + (Time.get_ticks_msec() % 1000)
	OS.set_environment("NT_PORT", str(port))
	OS.set_environment("NT_DATA_DIR", data)
	OS.set_environment("NT_WEB_ROOT", ProjectSettings.globalize_path("user://"))
	OS.set_environment("NT_TLS_CERT", "/nonexistent")
	var pid := OS.create_process(py, [ProjectSettings.globalize_path("res://tools/web/serve.py")])
	check(pid > 0, "server starts")
	var store := ProfileStore.new(ROOT)
	var sync := SaveSync.new(store, "http://127.0.0.1:%d" % port)
	root.add_child(sync)
	var up := false
	for i in 50:
		if await sync.refresh():
			up = true
			break
		await create_timer(0.1).timeout
	check(up, "sync reaches the server")
	if up:
		var p: Dictionary = await sync.create("Ada")
		check(p.get("id", "") == "ada" and store.find("ada").name == "Ada", "create goes through the server")
		var dup: Dictionary = await sync.create("ada")
		check(dup.has("error"), "server refuses a duplicate name")
		store.write_files("ada", {"progress": "{\"room\":\"R05\"}", "settings": "{}"})
		check(await sync.push("ada"), "push uploads")
		check(store.find("ada").updated > 0, "push records the server time")
		# Another device: empty store, pulls Ada's watch.
		var other := ProfileStore.new(ROOT + "_other")
		var sync2 := SaveSync.new(other, sync.base_url)
		root.add_child(sync2)
		check(await sync2.refresh() and not other.find("ada").is_empty(), "second device sees Ada")
		check(await sync2.pull("ada") and other.read_files("ada").get("progress", "") == "{\"room\":\"R05\"}", "second device pulls her save")
		# The watcher pushes changes on its own.
		other.write_files("ada", {"progress": "{\"room\":\"R07\"}", "settings": "{}"})
		sync2.watch("ada")
		await create_timer(SaveSync.PUSH_EVERY + 1.5).timeout
		check(await sync.pull("ada") and store.read_files("ada").progress == "{\"room\":\"R07\"}", "watch pushes changes")
		await sync2.stop()
		# Offline-made profile uploads with its first save.
		var olga := other.create("Olga", "", 0, true)
		other.write_files("olga", {"progress": "{}"})
		check(await sync2.push("olga"), "offline profile uploads")
		check(await sync.refresh() and not store.find("olga").is_empty(), "and appears for everyone")
		check(await sync.remove("olga") and store.find("olga").is_empty(), "remove through the server")
		sync2.queue_free()
		_wipe(ROOT + "_other")
	OS.kill(pid)
	sync.queue_free()
	_wipe("user://test_serve_data")
	# No server at all: calls fail fast and say offline.
	var dead_store := ProfileStore.new(ROOT)
	dead_store.legacy_save = ROOT + "_legacy/none.json"
	var dead := SaveSync.new(dead_store, "http://127.0.0.1:9")
	root.add_child(dead)
	check(not await dead.refresh() and not dead.online, "unreachable server reads as offline")
	var made: Dictionary = await dead.create("Nell")
	check(made.get("local", false), "offline create makes a local profile")
	dead.queue_free()
	finished.append("sync")
