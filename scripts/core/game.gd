extends Node
## État global du jeu : monnaie, amis, statistiques par île, modifications
## du monde, gacha, tutoriel et sauvegarde.

signal stars_changed(value: int)
signal friend_unlocked(id: String)
signal stats_changed
signal action_done(kind: String)

const SAVE_PATH := "user://animo_save.json"
const SAVE_VERSION := 3  # v3 : îles 256x256, anciens édits invalides
const PULL_COST := 100
const TEN_PULL_COST := 900
const DUPLICATE_REFUND := 25
const FRIEND_REWARD := 50
const LEGENDARY_PITY := 30

var stars := 0
var current_island := "prairie"
var tutorial_step := 0
var friends := {}  # id -> {"island": String}
var stats := {}  # island_id -> {stat: int}
var edits := {}  # island_id -> {"x,y,z": block_id}
var pity := 0
var total_pulls := 0
var talked := {}  # amis à qui on a parlé cette session
var player_skin := "a"  # modèle Kenney du joueur (a..r)
var music_volume := 0.6
## Mode admin : tout est débloqué, gacha gratuit, vol libre (touche V).
var admin := false
var sfx_volume := 0.8

var _autosave_timer := 0.0


func _ready() -> void:
	_setup_inputs()
	load_game()


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer > 30.0:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# --- Entrées -------------------------------------------------------------

func _setup_inputs() -> void:
	# Touches physiques : WASD en QWERTY == ZQSD en AZERTY.
	_add_physical("move_forward", [KEY_W])
	_add_physical("move_back", [KEY_S])
	_add_physical("move_left", [KEY_A])
	_add_physical("move_right", [KEY_D])
	# Caméra au clavier : flèches.
	_add_physical("cam_left", [KEY_LEFT])
	_add_physical("cam_right", [KEY_RIGHT])
	_add_physical("cam_up", [KEY_UP])
	_add_physical("cam_down", [KEY_DOWN])
	_add_physical("jump", [KEY_SPACE])
	_add_physical("power_1", [KEY_1, KEY_KP_1])
	_add_physical("power_2", [KEY_2, KEY_KP_2])
	_add_physical("power_3", [KEY_3, KEY_KP_3])
	_add_physical("power_4", [KEY_4, KEY_KP_4])
	_add_logical("interact", [KEY_E])
	_add_logical("carnet", [KEY_C])
	_add_logical("gacha", [KEY_G])
	_add_logical("map", [KEY_M])
	_add_logical("block_next", [KEY_R])
	_add_logical("block_prev", [KEY_F])
	_add_logical("ui_back", [KEY_ESCAPE])
	_add_logical("fly", [KEY_V])
	_add_logical("admin_toggle", [KEY_F1])
	_add_physical("fly_down", [KEY_CTRL])


func _add_physical(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_logical(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = k
		InputMap.action_add_event(action, ev)


# --- Monnaie & stats -----------------------------------------------------

func add_stars(amount: int) -> void:
	stars = max(0, stars + amount)
	stars_changed.emit(stars)


func get_stat(island_id: String, stat: String) -> int:
	var s: Dictionary = stats.get(island_id, {})
	return int(s.get(stat, 0))


func add_stat(stat: String, amount: int = 1) -> void:
	var s: Dictionary = stats.get_or_add(current_island, {})
	s[stat] = int(s.get(stat, 0)) + amount
	stats_changed.emit()
	check_unlocks()


func notify_action(kind: String) -> void:
	action_done.emit(kind)


func check_unlocks() -> void:
	for c in CreatureDB.island_creatures(current_island):
		if friends.has(c["id"]):
			continue
		if get_stat(current_island, c["stat"]) >= int(c["amount"]):
			unlock_friend(c["id"], current_island)


func unlock_friend(id: String, island_id: String) -> void:
	if friends.has(id):
		return
	friends[id] = {"island": island_id}
	add_stars(FRIEND_REWARD)
	friend_unlocked.emit(id)
	save_game()


func friend_count() -> int:
	return friends.size()


func is_island_unlocked(island_id: String) -> bool:
	if admin:
		return true
	var isl := IslandDB.get_island(island_id)
	return friend_count() >= int(isl["friends_needed"])


func available_blocks() -> Array[int]:
	var out: Array[int] = []
	for entry in Blocks.BUILD_PALETTE:
		if admin or is_island_unlocked(entry["island"]):
			out.append(int(entry["id"]))
	return out


# --- Gacha ---------------------------------------------------------------

func _roll_rarity() -> int:
	var r := randf()
	if r < 0.05:
		return CreatureDB.LEGENDARY
	if r < 0.30:
		return CreatureDB.RARE
	return CreatureDB.COMMON


func _single_pull(min_rarity: int = CreatureDB.COMMON) -> Dictionary:
	pity += 1
	total_pulls += 1
	var rarity: int = max(_roll_rarity(), min_rarity)
	if pity >= LEGENDARY_PITY:
		rarity = CreatureDB.LEGENDARY
	if rarity == CreatureDB.LEGENDARY:
		pity = 0
	var pool := CreatureDB.gacha_pool(rarity)
	var c: Dictionary = pool.pick_random()
	var id: String = c["id"]
	var is_new := not friends.has(id)
	if is_new:
		friends[id] = {"island": current_island}
		friend_unlocked.emit(id)
	else:
		add_stars(DUPLICATE_REFUND)
	return {"id": id, "new": is_new, "rarity": rarity}


## Renvoie la liste des résultats, ou [] si pas assez d'étoiles.
func gacha_pull(count: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var cost := PULL_COST if count == 1 else TEN_PULL_COST
	if admin:
		cost = 0
	if stars < cost:
		return results
	add_stars(-cost)
	for i in count:
		# Le dernier tirage d'un x10 garantit au moins un Rare.
		var min_r := CreatureDB.COMMON
		if count == 10 and i == count - 1:
			var has_rare := false
			for r in results:
				if int(r["rarity"]) >= CreatureDB.RARE:
					has_rare = true
			if not has_rare:
				min_r = CreatureDB.RARE
		results.append(_single_pull(min_r))
	save_game()
	return results


# --- Sauvegarde ----------------------------------------------------------

func record_edit(island_id: String, pos: Vector3i, id: int) -> void:
	var e: Dictionary = edits.get_or_add(island_id, {})
	e["%d,%d,%d" % [pos.x, pos.y, pos.z]] = id


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"stars": stars,
		"current_island": current_island,
		"tutorial_step": tutorial_step,
		"friends": friends,
		"stats": stats,
		"edits": edits,
		"pity": pity,
		"total_pulls": total_pulls,
		"player_skin": player_skin,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"admin": admin,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	stars = int(parsed.get("stars", 0))
	current_island = str(parsed.get("current_island", "prairie"))
	tutorial_step = int(parsed.get("tutorial_step", 0))
	friends = parsed.get("friends", {})
	stats = parsed.get("stats", {})
	edits = parsed.get("edits", {})
	pity = int(parsed.get("pity", 0))
	total_pulls = int(parsed.get("total_pulls", 0))
	player_skin = str(parsed.get("player_skin", "a"))
	music_volume = float(parsed.get("music_volume", 0.6))
	sfx_volume = float(parsed.get("sfx_volume", 0.8))
	admin = bool(parsed.get("admin", false))
	if int(parsed.get("version", 1)) < SAVE_VERSION:
		# Les îles ont changé de taille : on garde la progression mais
		# les constructions de l'ancienne version ne sont plus valides.
		edits = {}


## Donne tous les amis (mode admin). Les amis d'île vont sur leur île,
## ceux du gacha sur l'île actuelle.
func admin_unlock_all_friends() -> void:
	for c in CreatureDB.ALL:
		if not friends.has(c["id"]):
			var home: String = c["island"] if c["island"] != "" else current_island
			friends[c["id"]] = {"island": home}
			friend_unlocked.emit(c["id"])
	save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func reset_game() -> void:
	admin = false
	stars = 0
	current_island = "prairie"
	tutorial_step = 0
	friends = {}
	stats = {}
	edits = {}
	pity = 0
	total_pulls = 0
	talked = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
