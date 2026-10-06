extends Node
## État global du jeu : inventaire, habitants, statistiques par île,
## modifications du monde, progression et sauvegarde.

signal resident_arrived(id: String)
signal stats_changed
signal action_done(kind: String)
signal inventory_changed
## Un objet ou un bloc obtenu pour la toute première fois ("item:<id>" ou
## "block:<id>") : le HUD affiche sa fiche de découverte.
signal first_obtained(key: String)

const SAVE_PATH := "user://evergrove_save.json"
const SAVE_VERSION := 7  # v7 : îles agrandies (384 x 384)

var current_island := "prairie"
var tutorial_step := 0
## Objets : ressources ramassées et composants fabriqués (voir Items).
var inventory := {}
## Constructions fabriquées, prêtes à être posées (type d'objet Props -> quantité).
var structures := {}
## Espèces animales déjà apparues.
var species_seen := {}
## Collections du carnet : {"flowers": {id: true}, "trees": {...},
## "furniture": {...}, "islands": {...}}.
var collections := {}
## Blocs possédés (id en texte -> quantité) : on ne pose que ce qu'on a cassé ou fabriqué.
var blocks := {}
## Recettes déjà annoncées au joueur.
var recipes_seen := {}
## Découvertes de l'histoire : "water", "camp", "chest".
var flags := {}
## Jour en cours (on passe au lendemain en dormant).
var day := 1
## Heure de la journée (0-24) et météo en cours (voir SkyCycle).
var time := 8.0
var weather := "clear"
var weather_left := 4.0  # heures avant le prochain changement de temps
## Quantités générées par île (déchets, vase) : cibles de la vitalité.
var island_totals := {}
## Objets 3D ajoutés / retirés par le joueur, par île (voir Props).
var props_added := {}
var props_removed := {}
## Chantiers en cours, par île (voir Worksites).
var sites := {}
## Ressources ramassées (île -> {"x,z": {"d": jour, "k": type}}), qui repoussent.
var picked := {}
## Qui habite où : clé de la maison (objet Props) -> id d'habitant ou "player".
var homes := {}
## Intérieurs personnalisés : clé de la maison -> [{"f": meuble, "x", "z", "r"}].
var interiors := {}
var residents := {}  # id -> {"island": String}
var stats := {}  # island_id -> {stat: int}
var edits := {}  # island_id -> {"x,y,z": block_id}
var talked := {}  # habitants à qui on a parlé cette session
## Constructions récentes que les habitants n'ont pas encore remarquées :
## île -> [{"key", "kind", "day"}] (voir Moments).
var novelties := {}
var player_skin := "a"  # tenue : modèle Kenney du joueur (a..r)
var player_head := "a"  # tête / coiffure : modèle Kenney (a..r)
var player_name := ""
var mouse_sensitivity := 0.0028
var music_volume := 0.6
## Mode admin : tout est débloqué, fabrication gratuite, vol libre (touche V).
var admin := false
var sfx_volume := 0.8

var _autosave_timer := 0.0


func _ready() -> void:
	_setup_inputs()
	_import_old_save()
	load_game()


## Le jeu s'appelait Animo : sa sauvegarde est dans un autre dossier
## (app_userdata/Animo). On la récupère une fois.
func _import_old_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		return
	var old := OS.get_user_data_dir().get_base_dir().path_join("Animo").path_join("animo_save.json")
	if FileAccess.file_exists(old):
		DirAccess.copy_absolute(old, ProjectSettings.globalize_path(SAVE_PATH))


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
	_add_logical("map", [KEY_M])
	_add_logical("inventory", [KEY_I, KEY_TAB])
	# Poser : la molette choisit l'objet, F change de catégorie, R tourne.
	_add_logical("place_category", [KEY_F])
	_add_logical("rotate", [KEY_R])
	_add_logical("assign", [KEY_G])
	_add_logical("ui_back", [KEY_ESCAPE])
	_add_logical("fly", [KEY_V])
	_add_logical("admin_toggle", [KEY_F1])
	_add_physical("fly_down", [KEY_CTRL])
	_add_physical("free_cursor", [KEY_ALT])


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


# --- Inventaire & découvertes -------------------------------------------

func add_item(kind: String, amount := 1) -> void:
	inventory[kind] = item_count(kind) + amount
	inventory_changed.emit()
	if amount > 0 and not admin and collect("items", kind):
		first_obtained.emit("item:" + kind)


func item_count(kind: String) -> int:
	return int(inventory.get(kind, 0))


func block_count(id: int) -> int:
	return int(blocks.get(str(id), 0))


func add_block(id: int, amount := 1) -> void:
	blocks[str(id)] = maxi(0, block_count(id) + amount)
	inventory_changed.emit()
	if amount > 0 and not admin and collect("blocks", str(id)):
		first_obtained.emit("block:%d" % id)


func structure_count(kind: String) -> int:
	return int(structures.get(kind, 0))


func add_structure(kind: String, amount := 1) -> void:
	structures[kind] = maxi(0, structure_count(kind) + amount)
	inventory_changed.emit()


func has_flag(f: String) -> bool:
	return bool(flags.get(f, false))


func set_flag(f: String) -> void:
	if has_flag(f):
		return
	flags[f] = true
	action_done.emit("flag_" + f)


# --- Statistiques & habitants ---------------------------------------------

func get_stat(island_id: String, stat: String) -> int:
	var s: Dictionary = stats.get(island_id, {})
	return int(s.get(stat, 0))


func add_stat(stat: String, amount: int = 1) -> void:
	var s: Dictionary = stats.get_or_add(current_island, {})
	s[stat] = int(s.get(stat, 0)) + amount
	stats_changed.emit()


func notify_action(kind: String) -> void:
	action_done.emit(kind)


## Ajoute une entrée à une collection du carnet. Renvoie true si elle est nouvelle.
func collect(category: String, id: String) -> bool:
	var c: Dictionary = collections.get_or_add(category, {})
	if c.has(id):
		return false
	c[id] = true
	return true


func has_collected(category: String, id: String) -> bool:
	return (collections.get(category, {}) as Dictionary).has(id)


func add_resident(id: String, island_id: String) -> void:
	if residents.has(id):
		return
	residents[id] = {"island": island_id, "since": day, "pts": 0}
	resident_arrived.emit(id)
	save_game()


## Maison d'un habitant ("" : sans maison).
func home_of(owner: String) -> String:
	for k in homes:
		if homes[k] == owner:
			return k
	return ""


## Attribue une maison (un seul occupant par maison, une maison par occupant).
func set_home(house_key: String, owner: String) -> void:
	for k in homes.keys():
		if homes[k] == owner and owner != "":
			homes.erase(k)
	if owner == "":
		homes.erase(house_key)
	else:
		homes[house_key] = owner
	save_game()


func resident_count() -> int:
	return residents.size()


## Les îles se découvrent par l'histoire (barque, coque, phare : Expeditions).
func is_island_unlocked(island_id: String) -> bool:
	return admin or island_id == "prairie" or has_flag("unlock_" + island_id)


func available_blocks() -> Array[int]:
	var out: Array[int] = []
	for entry in Blocks.BUILD_PALETTE:
		var id := int(entry["id"])
		if admin or block_count(id) > 0:
			out.append(id)
	return out


# --- Sauvegarde ----------------------------------------------------------

func record_edit(island_id: String, pos: Vector3i, id: int) -> void:
	var e: Dictionary = edits.get_or_add(island_id, {})
	e["%d,%d,%d" % [pos.x, pos.y, pos.z]] = id
	stats_changed.emit()  # la vitalité dépend de l'état de l'île


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"current_island": current_island,
		"tutorial_step": tutorial_step,
		"inventory": inventory,
		"structures": structures,
		"species_seen": species_seen,
		"collections": collections,
		"blocks": blocks,
		"recipes_seen": recipes_seen,
		"flags": flags,
		"day": day,
		"time": time,
		"weather": weather,
		"weather_left": weather_left,
		"island_totals": island_totals,
		"props_added": props_added,
		"props_removed": props_removed,
		"sites": sites,
		"novelties": novelties,
		"homes": homes,
		"picked": picked,
		"interiors": interiors,
		"residents": residents,
		"stats": stats,
		"edits": edits,
		"player_skin": player_skin,
		"player_head": player_head,
		"player_name": player_name,
		"mouse_sensitivity": mouse_sensitivity,
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
	current_island = str(parsed.get("current_island", "prairie"))
	tutorial_step = int(parsed.get("tutorial_step", 0))
	inventory = parsed.get("inventory", {})
	structures = parsed.get("structures", {})
	species_seen = parsed.get("species_seen", {})
	collections = parsed.get("collections", {})
	blocks = parsed.get("blocks", {})
	recipes_seen = parsed.get("recipes_seen", {})
	flags = parsed.get("flags", {})
	day = int(parsed.get("day", 1))
	time = float(parsed.get("time", 8.0))
	weather = str(parsed.get("weather", "clear"))
	weather_left = float(parsed.get("weather_left", 4.0))
	island_totals = parsed.get("island_totals", {})
	props_added = parsed.get("props_added", {})
	props_removed = parsed.get("props_removed", {})
	sites = parsed.get("sites", {})
	novelties = parsed.get("novelties", {})
	homes = parsed.get("homes", {})
	picked = parsed.get("picked", {})
	interiors = parsed.get("interiors", {})
	residents = parsed.get("residents", parsed.get("friends", {}))
	# Les anciens « amis » (animaux, gacha) n'existent plus.
	for id in residents.keys():
		if ResidentDB.get_resident(id).is_empty():
			residents.erase(id)
	stats = parsed.get("stats", {})
	edits = parsed.get("edits", {})
	player_skin = str(parsed.get("player_skin", "a"))
	player_head = str(parsed.get("player_head", player_skin))
	player_name = str(parsed.get("player_name", ""))
	mouse_sensitivity = float(parsed.get("mouse_sensitivity", 0.0028))
	music_volume = float(parsed.get("music_volume", 0.6))
	sfx_volume = float(parsed.get("sfx_volume", 0.8))
	admin = bool(parsed.get("admin", false))
	# Anciennes sauvegardes : les îles débloquées par le nombre d'habitants
	# le restent.
	for isl in IslandDB.ISLANDS:
		var need := int(isl["residents_needed"])
		if need > 0 and resident_count() >= need:
			flags["unlock_" + str(isl["id"])] = true
	var version := int(parsed.get("version", 1))
	if version < 4:
		# Les îles ont changé : on garde la progression mais
		# les constructions de l'ancienne version ne sont plus valides.
		edits = {}
		# v4 : nouvelle introduction (exploration + campement) avant les pouvoirs.
		if tutorial_step >= 9:
			flags = {"water": true, "camp": true, "chest": true}
	if version < 6:
		# v6 : nouvelle suite de missions ; une ancienne partie avancée la saute.
		tutorial_step = 99 if tutorial_step >= 7 else mini(tutorial_step, 3)
	if version < 7:
		# v7 : les îles ont été agrandies et redessinées. On garde les
		# habitants, l'inventaire, les amitiés et les découvertes ; ce qui
		# était posé sur l'ancien terrain n'a plus sa place : les constructions
		# et les meubles reviennent dans l'inventaire.
		for isl in props_added:
			for e in props_added[isl]:
				var k := str(e.get("kind", ""))
				if Props.is_structure(k):
					structures[k] = int(structures.get(k, 0)) + 1
		for key in interiors:
			for e in interiors[key]:
				var fk := "f_" + str(e.get("f", ""))
				structures[fk] = int(structures.get(fk, 0)) + 1
		edits = {}
		props_added = {}
		props_removed = {}
		sites = {}
		homes = {}
		interiors = {}
		picked = {}
		novelties = {}
		stats = {}
		island_totals = {}


## Fait venir tous les habitants possibles sur l'île actuelle (mode admin).
func admin_all_residents() -> void:
	for c in ResidentDB.ALL:
		if not residents.has(c["id"]) and ResidentDB.can_live_on(c, current_island):
			residents[c["id"]] = {"island": current_island}
			resident_arrived.emit(c["id"])
	save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func reset_game() -> void:
	admin = false
	current_island = "prairie"
	tutorial_step = 0
	inventory = {}
	structures = {}
	species_seen = {}
	collections = {}
	blocks = {}
	recipes_seen = {}
	flags = {}
	day = 1
	time = 8.0
	weather = "clear"
	weather_left = 4.0
	island_totals = {}
	props_added = {}
	props_removed = {}
	sites = {}
	novelties = {}
	homes = {}
	interiors = {}
	picked = {}
	residents = {}
	stats = {}
	edits = {}
	talked = {}
	player_name = ""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
