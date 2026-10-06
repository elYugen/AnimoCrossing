class_name Main
extends Node3D
## Scène principale : met en place l'environnement et les systèmes du jeu,
## charge les îles, gère le menu, la boucle et les entrées du joueur.
##
## Les systèmes vivent dans leurs propres scripts :
##   npc/      Residents (présence), ResidentAI (routine), ResidentTalk (discussions),
##             Moments (petites scènes : banc, feu, coucous, découvertes),
##             ResidentJobs (« Va nettoyer », « Va planter »)
##   story/    StoryDirector (histoire, pensées, découvertes), Expeditions (barque,
##             coque, phare : découvrir les autres îles), Mystery (la plage)
##   world/    DayCycle (nuits, arrivées), Houses, Construction, Wildlife, Gathering
##   world/    Scenery (ciel, lumière, océan, nuages), IslandLife (la vitalité se voit),
##             WeatherFX (flaques, traces dans la neige, cerf des brumes)
##   tools/    ToolAim (cible, fantôme), ToolActions (pouvoirs de l'outil)

var world: VoxelWorld
var player: Player
var rig: CameraRig
var hud: HUD
var title: TitleMenu
var props: Props
var worksites: Worksites
var sky: SkyCycle
var ambience: Ambience
var nav := Navigator.new()
var camp_props: CampProps
## Intérieur de maison où se trouve le joueur (null : dehors).
var interior: Interior

# Systèmes
var residents: Residents
var npc_ai: ResidentAI
var talk: ResidentTalk
var moments: Moments
var jobs: ResidentJobs
var story: StoryDirector
var days: DayCycle
var houses: Houses
var construction: Construction
var wildlife: Wildlife
var gathering: Gathering
var life: IslandLife
var expeditions: Expeditions
var mystery: Mystery
var weather_fx: WeatherFX
var aim: ToolAim
var tools: ToolActions

## Pouvoir sélectionné (0 casser, 1 poser, 2 fleurir, 3 planter).
var power := 0
var block := Blocks.GRASS
## Construction ou meuble sélectionné pour « Poser » ("" : on pose des blocs).
var structure := ""
## Tests : une nouvelle partie démarre directement, sans création ni intro.
var skip_intro := false
var loading := false
var cinematic := false
var busy := false  # séquence scénarisée en cours (coffre, nuit...)
var in_title := true
var spawn_point := Vector3.ZERO
var rng := RandomNumberGenerator.new()

var scenery: Scenery
var _prompt: Label3D
var _faded := {}  # objets rendus transparents devant la caméra
var _last_deny := ""
var _last_deny_at := 0


func _ready() -> void:
	rng.randomize()
	Presence.main = self  # statut Discord
	scenery = Scenery.new()
	scenery.name = "Scenery"
	add_child(scenery)
	world = VoxelWorld.new()
	world.name = "World"
	add_child(world)
	# Ambiance sonore permanente (vagues, vent, pluie) et cycle jour / nuit.
	ambience = Ambience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	ambience.fade_to(0.12, 0.08, 0.0, 0.1)
	sky = SkyCycle.new()
	sky.name = "Sky"
	sky.env = scenery.env
	sky.sky_mat = scenery.sky_mat
	sky.sun = scenery.sun
	sky.ambience = ambience
	add_child(sky)
	props = Props.new()
	props.name = "Props"
	props.world = world
	props.on_change = func(id: int, v: int): nav.mark_prop(id, v)
	add_child(props)
	worksites = Worksites.new()
	worksites.name = "Worksites"
	worksites.props = props
	worksites.world = world
	add_child(worksites)
	_prompt = make_label3d("", 30, UIStyle.TEXT, 10)
	_prompt.visible = false
	add_child(_prompt)

	player = Player.new()
	player.name = "Player"
	player.world = world
	add_child(player)
	rig = CameraRig.new()
	rig.name = "CameraRig"
	sky.follow = rig
	rig.target = player
	rig.world = world
	rig.props = props
	add_child(rig)
	player.rig = rig

	hud = HUD.new()
	hud.setup(self)
	add_child(hud)

	residents = Residents.new()
	_add_system(residents, "Residents")
	npc_ai = ResidentAI.new()
	_add_system(npc_ai, "ResidentAI")
	talk = ResidentTalk.new()
	_add_system(talk, "ResidentTalk")
	moments = Moments.new()
	_add_system(moments, "Moments")
	jobs = ResidentJobs.new()
	_add_system(jobs, "ResidentJobs")
	story = StoryDirector.new()
	_add_system(story, "Story")
	days = DayCycle.new()
	_add_system(days, "DayCycle")
	houses = Houses.new()
	_add_system(houses, "Houses")
	construction = Construction.new()
	_add_system(construction, "Construction")
	wildlife = Wildlife.new()
	_add_system(wildlife, "Animals")
	gathering = Gathering.new()
	_add_system(gathering, "Pickups")
	life = IslandLife.new()
	_add_system(life, "IslandLife")
	expeditions = Expeditions.new()
	_add_system(expeditions, "Expeditions")
	mystery = Mystery.new()
	_add_system(mystery, "Mystery")
	weather_fx = WeatherFX.new()
	_add_system(weather_fx, "WeatherFX")
	aim = ToolAim.new()
	_add_system(aim, "Aim")
	tools = ToolActions.new()
	_add_system(tools, "Tools")

	worksites.finished.connect(construction.on_site_finished)
	hud.travel_requested.connect(travel_to)
	hud.power_selected.connect(select_power)
	hud.block_selected.connect(select_block)
	hud.structure_selected.connect(select_structure)
	hud.admin_changed.connect(_on_admin_changed)
	hud.step_changed.connect(story.on_step_changed)
	hud.sleep_requested.connect(days.sleep)
	Game.stats_changed.connect(_announce_recipes)
	Game.action_done.connect(func(kind: String):
		if kind == "craft":
			Game.set_flag("did_craft")
		elif kind == "build":
			Game.set_flag("did_build"))

	load_island(Game.current_island)
	hud.refresh_all()
	hud.set_block(block)

	# Menu de démarrage, l'île tourne en fond.
	title = TitleMenu.new()
	title.setup(self)
	add_child(title)
	title.play_requested.connect(_start_game)
	_enter_title_camera()
	hud.visible = false
	hud.fade(false, 0.8)


func _add_system(node: Node, node_name: String) -> void:
	node.name = node_name
	node.set("main", self)
	add_child(node)


# --- Menu et parties ---------------------------------------------------------

func _enter_title_camera() -> void:
	in_title = true
	rig.shoulder = 0.0
	rig.distance = 34.0
	rig.pitch = -0.62
	rig.snap()


func _start_game(new_game: bool) -> void:
	if loading:
		return
	if new_game and not skip_intro:
		story.open_creator()
		return
	loading = true
	await hud.fade(true, 0.4)
	if new_game:
		Game.reset_game()
		load_island("prairie")
	title.visible = false
	in_title = false
	hud.visible = true
	hud.close_panel()
	hud.refresh_all()
	power = 0
	if hud.power_unlocked(0):
		select_power(0)
	gameplay_camera(0.0)
	rig.snap()
	await get_tree().process_frame
	await hud.fade(false, 0.5)
	loading = false


func gameplay_camera(yaw: float) -> void:
	rig.shoulder = 0.55
	rig.distance = 6.0
	rig.pitch = -0.3
	rig.yaw = yaw


func return_to_title() -> void:
	if loading:
		return
	loading = true
	await hud.fade(true, 0.4)
	hud.close_panel()
	player.set_flying(false)
	hud.visible = false
	title.show_menu()
	_enter_title_camera()
	await hud.fade(false, 0.5)
	loading = false


func toggle_fly() -> void:
	if not Game.admin:
		return
	player.set_flying(not player.flying)
	hud.refresh_admin()
	hud.toast("Vol activé : Espace pour monter, Ctrl pour descendre" if player.flying else "Atterrissage !", Color("d4542a"))


func _on_admin_changed(enabled: bool) -> void:
	if not enabled and player.flying:
		player.set_flying(false)
	hud.set_block(block)


func respawn_residents() -> void:
	residents.spawn_all()


func reset_game() -> void:
	Game.reset_game()
	power = 0
	await travel_to("prairie")
	hud.refresh_all()


# --- Mise en place -------------------------------------------------------

## Dedans, on cache l'île (et son ciel) pour ne voir que la pièce.
func set_outside_visible(v: bool) -> void:
	for n in [world, props, worksites, residents, wildlife, gathering, camp_props]:
		if n:
			n.visible = v
	scenery.set_outside_visible(v)


# --- Îles ----------------------------------------------------------------

func load_island(id: String, music := true) -> void:
	Game.current_island = id
	Game.collect("islands", id)
	Game.talked.clear()
	var isl := IslandDB.get_island(id)
	world.island_id = id
	spawn_point = IslandGenerator.generate(world, isl)
	var edits: Dictionary = Game.edits.get(id, {})
	for key in edits:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 3:
			world.set_raw(int(parts[0]), int(parts[1]), int(parts[2]), int(edits[key]))
	world.build_all(spawn_point)
	spawn_point.y = world.top_solid_y(floori(spawn_point.x), floori(spawn_point.z)) + 1.1
	sky.set_island(isl)
	scenery.apply_look(isl)
	if music:
		Audio.play_music(id)
	player.teleport(spawn_point)
	rig.yaw = 0.0
	rig.snap()
	props.spawn_island(id, IslandGenerator.props)
	nav.build(world, props)
	worksites.load_island(id)
	life.refresh()
	weather_fx.clear()
	residents.spawn_all()
	wildlife.spawn(false)
	gathering.spawn()
	story.spawn_camp()
	expeditions.update_beacon()


func travel_to(id: String) -> void:
	if loading:
		return
	loading = true
	aim.hide_marks()
	await hud.fade(true, 0.4)
	load_island(id)
	hud.refresh_all()
	await get_tree().process_frame
	await hud.fade(false, 0.6)
	loading = false
	hud.toast("Bienvenue sur l'%s !" % IslandDB.get_island(id)["name"], UIStyle.GREEN_DARK)
	Game.save_game()


# --- Boucle --------------------------------------------------------------

func _process(delta: float) -> void:
	tools.cooldown -= delta
	_update_mouse_mode()
	if in_title:
		rig.yaw += delta * 0.07
		player.input_enabled = false
		rig.input_enabled = false
		aim.hide_marks()
		world.focus = player.global_position
		world.set_view(Vector3(0, -1000, 0), Vector3.ZERO)
		return
	var blocking := hud.is_blocking() or loading or cinematic
	player.input_enabled = not blocking
	rig.input_enabled = not blocking
	world.set_view(player.global_position, rig.camera.global_position)
	world.focus = player.global_position
	residents.update_labels(player.global_position)
	nav.budget = Navigator.STEPS_PER_FRAME
	npc_ai.assign_workers(delta)
	construction.advance_work(delta)
	npc_ai.tick(delta)
	moments.tick(delta)
	_update_occluders()
	story.hints(delta)
	_update_world_interaction()
	var aiming := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	hud.set_crosshair(aiming and not blocking, UIStyle.POWER_COLORS[power] if hud.power_unlocked(power) else Color.WHITE)
	if blocking:
		aim.hide_marks()
		return
	aim.update_target()
	aim.update_ghost()
	# Clic gauche maintenu : on pose des blocs en continu.
	if is_placing() and structure == "" and aiming and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		tools.use_power()


## Souris capturée en jeu (caméra libre) ; libérée dans les menus,
## dialogues, cinématiques, ou en maintenant Alt.
func _update_mouse_mode() -> void:
	var capture := not in_title and not cinematic and not loading and not hud.is_blocking() \
		and not hud.wants_cursor() and not Input.is_action_pressed("free_cursor") \
		and DisplayServer.window_is_focused()
	var want := Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want


## Invite « [E] ... » au-dessus de l'objet proche, ramassage, découvertes.
func _update_world_interaction() -> void:
	if cinematic:
		return
	var pp := player.global_position
	var it := nearest_interactable()
	_prompt.visible = not it.is_empty() and not hud.is_blocking() and not busy
	if _prompt.visible:
		_prompt.text = it["prompt"]
		_prompt.global_position = (it["at"] as Vector3) + Vector3(0, 1.4, 0)
	gathering.collect_near(pp)
	if hud.dialog_open() or busy:
		return
	story.check_discoveries(pp)


func hide_prompt() -> void:
	_prompt.visible = false


## Objet du décor le plus proche avec lequel on peut interagir.
func nearest_interactable() -> Dictionary:
	var pp := player.global_position
	var cands := []
	if interior:
		cands.append({"pos": interior.to_global(interior.door_inside), "prompt": "[E] Sortir", "action": houses.exit})
		cands.append({"pos": interior.to_global(interior.bed), "prompt": "[E] Dormir", "action": days.sleep})
	else:
		if camp_props and camp_props.chest:
			cands.append({"node": camp_props.chest, "prompt": "[E] Examiner" if camp_props.opened else "[E] Fouiller", "action": story.open_chest})
			cands.append({"node": camp_props.tools, "prompt": "[E] Examiner", "action": mystery.examine_tools})
			cands.append({"node": camp_props.tent, "prompt": "[E] Dormir", "action": days.sleep})
		for id in props.items:
			var kind := props.kind_of(id)
			var q: Vector3 = props.items[id]["pos"]
			if Vector2(q.x - pp.x, q.z - pp.z).length() > 9.0:
				continue
			var def: Dictionary = Props.KINDS[kind]
			if def.get("craft", false) and Game.has_flag("chest"):
				cands.append({"node": props.items[id]["node"], "prompt": "[E] Fabriquer", "action": func(): hud.open_crafting(true)})
			elif Props.is_house(kind):
				var hid: int = id
				var owner: String = Game.homes.get(props.key_of(id), "")
				var who: String = "" if owner == "" else ("Chez moi" if owner == "player" else "Chez " + ResidentDB.get_resident(owner).get("name", "?"))
				cands.append({"pos": props.door_position(id), "prompt": ("%s\n" % who if who != "" else "") + "[E] Entrer   [G] Habitant", "action": func(): houses.enter(hid), "house": hid})
			elif kind == "tent" and props.key_of(id).begins_with("p:"):
				cands.append({"node": props.items[id]["node"], "prompt": "[E] Dormir", "action": days.sleep})
		cands.append_array(expeditions.interactables())
		cands.append_array(mystery.interactables())
		# Chantiers : choisir qui y travaille (au bord de l'emprise, côté joueur).
		for site in worksites.all():
			var c := worksites.center_of(site)
			var to_p := Vector3(pp.x - c.x, 0, pp.z - c.z)
			var edge := c + (to_p.normalized() if to_p.length() > 0.01 else Vector3.FORWARD) * (worksites.radius_of(site) + 0.6)
			edge.y = pp.y
			var sid: String = site["id"]
			cands.append({"pos": edge, "prompt": "%s\n[E] Choisir les ouvriers" % construction.site_label(site), "action": func(): construction.open_crew_menu(sid)})
	var best := {}
	var best_d := 2.4
	for it in cands:
		var pos: Vector3 = it["pos"] if it.has("pos") else (it["node"] as Node3D).global_position
		var d := Vector2(pos.x - pp.x, pos.z - pp.z).length()
		if d < best_d and absf(pos.y - pp.y) < 3.0:
			best_d = d
			best = it
			best["dist"] = d
			best["at"] = pos
	return best


## Un arbre (ou une maison) entre la caméra et le joueur devient transparent :
## seulement celui qui gêne, pas toute la forêt.
func _update_occluders() -> void:
	var now := {}
	if interior == null and not in_title:
		var from := rig.camera.global_position
		var to := player.global_position + Vector3(0, 0.9, 0)
		var exclude: Array[RID] = []
		for i in 3:
			var q := PhysicsRayQueryParameters3D.create(from, to, Props.LAYER, exclude)
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			if hit.is_empty():
				break
			var id := props.id_from_collider(hit["collider"])
			if id > 0:
				var kind := props.kind_of(id)
				if Props.is_tree(kind) or Props.is_structure(kind) or kind in ["tent", "workbench"]:
					now[id] = true
			exclude.append(hit["rid"])
	for id in _faded.keys():
		if not now.has(id):
			_set_prop_alpha(id, 0.0)
			_faded.erase(id)
	for id in now:
		if not _faded.has(id):
			_set_prop_alpha(id, 0.7)
			_faded[id] = true


func _set_prop_alpha(id: int, t: float) -> void:
	if not props.items.has(id):
		return
	for m in (props.items[id]["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var tw := mi.create_tween()
		tw.tween_property(mi, "transparency", t, 0.2)


func _announce_recipes() -> void:
	if in_title:
		return
	construction.check_zones()
	for r in Crafting.newly_unlocked():
		hud.show_item_popup("Nouvelle recette : %s" % r["name"], "À fabriquer à la table d'artisan.", false)
		Audio.play("jingle_common", -6.0, 0.0)


# --- Entrées -------------------------------------------------------------

## Caméra libre : la souris (capturée) oriente la caméra.
func _input(event: InputEvent) -> void:
	if in_title or cinematic:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		rig.look(-mm.relative.x * Game.mouse_sensitivity, -mm.relative.y * Game.mouse_sensitivity)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if loading or in_title or cinematic:
		return
	if event.is_action_pressed("admin_toggle"):
		hud.toggle_admin()
		return
	if event.is_action_pressed("fly") and not hud.is_blocking():
		if Game.admin:
			toggle_fly()
		return
	if event.is_action_pressed("ui_back"):
		hud.back()
		return
	if hud.dialog_open():
		if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			hud.advance_dialog()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("carnet"):
		hud.toggle_panel("carnet")
		return
	if event.is_action_pressed("map"):
		hud.toggle_panel("map")
		return
	if event.is_action_pressed("inventory"):
		hud.toggle_panel("craft")
		return
	if event.is_action_pressed("assign") and interior == null:
		var it := nearest_interactable()
		if it.has("house"):
			houses.choose_resident(int(it["house"]))
		return
	if hud.is_blocking():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# En mode Poser, la molette choisit l'objet (Ctrl + molette : zoom).
		var choosing := is_placing() and not mb.ctrl_pressed
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					if choosing:
						_cycle_block(-1)
					else:
						rig.zoom(-1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					if choosing:
						_cycle_block(1)
					else:
						rig.zoom(1.0)
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					tools.use_power()
			MOUSE_BUTTON_RIGHT:
				# Clic droit : retirer (casser) sans changer de pouvoir.
				if mb.pressed and hud.power_unlocked(0):
					tools.use_power(0)

	for i in 4:
		if event.is_action_pressed("power_%d" % (i + 1)):
			select_power(i)
	if event.is_action_pressed("rotate"):
		aim.rotate_placement()
		Audio.play("click", -10.0)
	if event.is_action_pressed("place_category"):
		_cycle_category()
	if event.is_action_pressed("interact"):
		interact()


func select_power(i: int) -> void:
	if not hud.power_unlocked(i):
		deny("Ce pouvoir n'est pas encore débloqué.")
		return
	if power != i:
		Audio.play("select", -8.0)
	power = i
	hud.set_power(i)


func select_structure(kind: String) -> void:
	structure = kind
	hud.set_structure(kind)
	if power != 1 and hud.power_unlocked(1):
		select_power(1)


func select_block(id: int) -> void:
	structure = ""
	block = id
	hud.set_block(id)
	if power != 1 and hud.power_unlocked(1):
		select_power(1)


## Le pouvoir Poser est actif (et débloqué).
func is_placing() -> bool:
	return power == 1 and hud.power_unlocked(1)


## Catégorie de ce qui est sélectionné : 0 blocs, 1 constructions, 2 meubles.
func place_category() -> int:
	if structure.begins_with("f_"):
		return 2
	return 1 if structure != "" else 0


func _select_placeable(v: Variant) -> void:
	if v is String:
		select_structure(v)
	else:
		select_block(v)
	Audio.play("click", -12.0)


## Molette : objet suivant / précédent dans la catégorie courante.
func _cycle_block(step: int) -> void:
	var list := hud.placeables_in(place_category())
	if list.is_empty():
		_cycle_category()
		return
	var cur: Variant = structure if structure != "" else block
	var i := list.find(cur)
	_select_placeable(list[posmod(i + step, list.size())])


## F : catégorie suivante (seulement celles où il y a quelque chose à poser).
func _cycle_category() -> void:
	var cur := place_category()
	for k in range(1, 4):
		var cat := (cur + k) % 3
		var list := hud.placeables_in(cat)
		if not list.is_empty():
			_select_placeable(list[0])
			return
	deny("Rien d'autre à poser : fabrique des constructions à la table d'artisan.")


## Touche E : saluer un animal, utiliser un objet du décor, ou parler à
## l'habitant le plus proche (le plus près l'emporte).
func interact() -> void:
	var pp := player.global_position
	var best := residents.nearest(pp, 2.6)
	var best_d := best.global_position.distance_to(pp) if best else INF
	var it := nearest_interactable()
	var animal := wildlife.nearest(pp, 2.2)
	if animal:
		var animal_d := animal.global_position.distance_to(pp)
		if (it.is_empty() or animal_d < float(it["dist"])) and animal_d < best_d:
			animal.react(pp)
			player.face_towards(animal.global_position)
			player.play_action("talk")
			Audio.play("talk", -6.0, 0.2, 1.8)
			return
	if not it.is_empty() and float(it["dist"]) < best_d:
		hide_prompt()
		(it["action"] as Callable).call()
		return
	if best == null:
		return
	best.talk_to(pp)
	player.face_towards(best.global_position)
	player.play_action("talk")
	await talk.talk(best)


# --- Retours visuels ----------------------------------------------------------

## Nouvelle entrée dans une collection du carnet : un petit mot discret.
func collect(category: String, id: String) -> void:
	if Game.collect(category, id):
		hud.show_gain("carnet:" + category, "%s : %s" % [CarnetPanel.CATEGORY_NAMES[category], CarnetPanel.entry_name(category, id)], 1, UIStyle.BLUE)


## Action impossible : un petit son, et la raison sous le viseur.
func deny(reason := "") -> void:
	# (clic maintenu : pas le même refus en boucle)
	var now := Time.get_ticks_msec()
	if reason == _last_deny and now - _last_deny_at < 900:
		return
	_last_deny = reason
	_last_deny_at = now
	Audio.play("error", -6.0)
	if reason != "":
		hud.flash_reason(reason)


## Le joueur récupère quelque chose : « +1 Terre » dans le fil des gains (les
## gains identiques se cumulent) et, si `at` est donné, un texte qui s'envole
## de l'endroit où on l'a récupéré. `key` regroupe les gains (par défaut : label).
func gain(label: String, n: int, col: Color, at := Vector3.INF, key := "") -> void:
	hud.show_gain(key if key != "" else label, label, n, col)
	if at == Vector3.INF:
		return
	var l := make_label3d("+%d %s" % [n, label], 46, col.darkened(0.45), 16)
	l.outline_modulate = Color.WHITE
	l.render_priority = 10
	add_child(l)
	l.global_position = at + Vector3(0, 0.6, 0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.3, 0), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.7)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.4).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


func make_label3d(text: String, size: int, col: Color, outline: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UIStyle.font()
	l.font_size = size
	l.outline_size = outline
	l.modulate = col
	l.outline_modulate = Color(1, 1, 1, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.no_depth_test = true
	return l


func burst(pos: Vector3, col: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.8
	p.explosiveness = 1.0
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.13
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	m.material = mat
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -13, 0)
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)
