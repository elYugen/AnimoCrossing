extends Node3D
## Scène principale : environnement, île voxel, joueur, créatures, pouvoirs.

const REACH := 6.5
const ADMIN_REACH := 24.0
const WATER_Y := IslandGenerator.SEA + 0.75

var world: VoxelWorld
var player: Player
var rig: CameraRig
var hud: HUD
var title: TitleMenu
var creatures_root: Node3D

var _env: Environment
var _sky_mat: PanoramaSkyMaterial
var _sun: DirectionalLight3D
var _ocean_mat: ShaderMaterial
var _clouds: Node3D
var _highlight: MeshInstance3D
var _highlight_mat: StandardMaterial3D
var _outline: MeshInstance3D

var power := 0
var block := Blocks.GRASS
## Construction sélectionnée pour « Poser » ("" : on pose des blocs).
var structure := ""
var animals_root: Node3D
var worksites: Worksites
var sky: SkyCycle
var nav := Navigator.new()
var ambience: Ambience
var _assign_timer := 0.0
var _ai_timer := 0.0
var _beach_spots: Array[Vector3] = []
var _hint_timer := 3.0
var _faded := {}  # objets rendus transparents devant la caméra
## Intérieur de maison où se trouve le joueur (null : dehors).
var interior: Interior
var _outside_pos := Vector3.ZERO
var _place_rot := 0.0
var _ghost: Node3D
var _ghost_kind := ""
var _ghost_ok := false
var _ghost_pos := Vector3.ZERO
var target := {}
## Tests : une nouvelle partie démarre directement, sans création ni intro.
var skip_intro := false
var _loading := false
var _cinematic := false
var props: Props
var pickups_root: Node3D
var camp_props: CampProps
var _prompt: Label3D
var _busy := false  # séquence scénarisée en cours (coffre, nuit...)
var _morning := false  # arrivées de la nuit : pas de célébration immédiate
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()
var _spawn := Vector3.ZERO
var _in_title := true


func _ready() -> void:
	_rng.randomize()
	_setup_environment()
	world = VoxelWorld.new()
	world.name = "World"
	add_child(world)
	_setup_ocean()
	_setup_clouds()
	# Ambiance sonore permanente (vagues, vent, pluie) et cycle jour / nuit.
	ambience = Ambience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	ambience.fade_to(0.12, 0.08, 0.0, 0.1)
	sky = SkyCycle.new()
	sky.name = "Sky"
	sky.env = _env
	sky.sky_mat = _sky_mat
	sky.sun = _sun
	sky.ambience = ambience
	add_child(sky)
	_setup_bounds()
	creatures_root = Node3D.new()
	creatures_root.name = "Creatures"
	add_child(creatures_root)
	animals_root = Node3D.new()
	animals_root.name = "Animals"
	add_child(animals_root)
	props = Props.new()
	props.name = "Props"
	props.world = world
	props.on_change = func(id: int, v: int): nav.mark_prop(id, v)
	add_child(props)
	worksites = Worksites.new()
	worksites.name = "Worksites"
	worksites.props = props
	worksites.world = world
	worksites.finished.connect(_on_site_finished)
	add_child(worksites)
	pickups_root = Node3D.new()
	pickups_root.name = "Pickups"
	add_child(pickups_root)
	_prompt = _make_label3d("", 30, UIStyle.TEXT, 10)
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
	add_child(rig)
	player.rig = rig
	_setup_highlight()

	hud = HUD.new()
	hud.setup(self)
	add_child(hud)
	hud.travel_requested.connect(travel_to)
	hud.power_selected.connect(select_power)
	hud.block_selected.connect(select_block)
	hud.admin_changed.connect(_on_admin_changed)
	hud.step_changed.connect(_on_step_changed)
	hud.sleep_requested.connect(sleep)
	Game.stats_changed.connect(_announce_recipes)
	Game.action_done.connect(func(kind: String):
		if kind == "craft":
			Game.set_flag("did_craft")
		elif kind == "build":
			Game.set_flag("did_build"))
	Game.resident_arrived.connect(_on_resident_arrived)
	hud.structure_selected.connect(select_structure)

	_load_island(Game.current_island)
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


func _enter_title_camera() -> void:
	_in_title = true
	rig.shoulder = 0.0
	rig.distance = 34.0
	rig.pitch = -0.62
	rig.snap()


func _start_game(new_game: bool) -> void:
	if _loading:
		return
	if new_game and not skip_intro:
		_open_creator()
		return
	_loading = true
	await hud.fade(true, 0.4)
	if new_game:
		Game.reset_game()
		_load_island("prairie")
	title.visible = false
	_in_title = false
	hud.visible = true
	hud.close_panel()
	hud.refresh_all()
	power = 0
	if hud.power_unlocked(0):
		select_power(0)
	_gameplay_camera(0.0)
	rig.snap()
	await get_tree().process_frame
	await hud.fade(false, 0.5)
	_loading = false


func _gameplay_camera(yaw: float) -> void:
	rig.shoulder = 0.55
	rig.distance = 6.0
	rig.pitch = -0.3
	rig.yaw = yaw


# --- Nouvelle partie : création du personnage puis naufrage ----------------

func _open_creator() -> void:
	title.visible = false
	var cc := CharacterCreator.new()
	add_child(cc)
	cc.cancelled.connect(func():
		cc.queue_free()
		title.show_menu())
	cc.confirmed.connect(func(n: String, skin: String, head: String):
		_new_game_story(cc, n, skin, head))


func _new_game_story(cc: CharacterCreator, player_name: String, skin: String, head: String) -> void:
	if _loading:
		return
	_loading = true
	var story := StoryOverlay.new()
	story.speaker = player_name
	add_child(story)
	await story.black(0.8)
	cc.queue_free()
	Game.reset_game()
	# Le naufragé se réveille à l'aube, par beau temps.
	Game.time = 6.6
	Game.weather = "clear"
	Game.weather_left = 5.0
	Game.player_name = player_name
	Game.player_skin = skin
	Game.player_head = head
	player.set_skin(skin, head)
	Audio.stop_music(1.2)
	_load_island("prairie", false)
	hud.close_panel()
	hud.refresh_all()
	hud.visible = false
	_in_title = false
	_cinematic = true
	title.visible = false
	power = 0
	Game.save_game()
	var intro := ShipwreckIntro.new()
	await intro.run(self, story)
	_cinematic = false
	_loading = false
	hud.visible = true
	hud.refresh_all()
	hud.fade_in_root(1.0)
	Game.save_game()
	_think("reveil")


func return_to_title() -> void:
	if _loading:
		return
	_loading = true
	await hud.fade(true, 0.4)
	hud.close_panel()
	player.set_flying(false)
	hud.visible = false
	title.show_menu()
	_enter_title_camera()
	await hud.fade(false, 0.5)
	_loading = false


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


func respawn_creatures() -> void:
	_spawn_creatures()


# --- Mise en place -------------------------------------------------------

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	# Ciel : skybox de Kenney (CC0), choisie selon l'île.
	var sky := Sky.new()
	_sky_mat = PanoramaSkyMaterial.new()
	_sky_mat.filter = true
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.75
	_env.ambient_light_color = Color("e8e2d6")
	_env.ambient_light_sky_contribution = 0.3
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 0.92
	_env.tonemap_white = 6.0
	_env.ssao_enabled = true
	_env.ssao_radius = 1.4
	_env.ssao_intensity = 1.6
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.8
	_env.fog_enabled = true
	_env.fog_density = 0.0025
	_env.fog_sky_affect = 0.0
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.08
	_env.adjustment_contrast = 1.06
	we.environment = _env
	we.compositor = _make_color_grading()
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, 38, 0)
	_sun.light_energy = 1.0
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_max_distance = 80.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(_sun)


## Étalonnage « cozy » (addon Color Grading de Rytelier) : ombres
## légèrement bleutées, tons moyens et hautes lumières chaleureux.
## Réglages : (teinte, intensité de teinte, vibrance, luminosité).
func _make_color_grading() -> Compositor:
	var cg := ColorGrading.new()
	cg.shadows = Vector4(0.68, 0.10, 1.0, 1.0)
	cg.midtones = Vector4(0.11, 0.05, 1.08, 1.0)
	cg.highlights = Vector4(0.14, 0.07, 1.0, 1.03)
	cg.vibrance_post = Vector3(1.0, 1.08, 1.0)
	var comp := Compositor.new()
	comp.compositor_effects = [cg]
	return comp


func _setup_ocean() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Ocean"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1200, 1200)
	pm.subdivide_width = 300
	pm.subdivide_depth = 300
	mi.mesh = pm
	_ocean_mat = ShaderMaterial.new()
	_ocean_mat.shader = load("res://shaders/ocean.gdshader")
	mi.material_override = _ocean_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(VoxelWorld.SX * 0.5, WATER_Y, VoxelWorld.SZ * 0.5)
	add_child(mi)


func _setup_clouds() -> void:
	_clouds = Node3D.new()
	_clouds.name = "Clouds"
	add_child(_clouds)
	var mat := MeshBuilder.vertex_color_material()
	mat.roughness = 1.0
	for i in 50:
		var mb := MeshBuilder.new()
		var n := _rng.randi_range(3, 6)
		for k in n:
			var s := Vector3(_rng.randf_range(3, 6), _rng.randf_range(1.2, 2.2), _rng.randf_range(3, 5))
			mb.add_box(Vector3(k * 2.4 - n, _rng.randf_range(0, 1.2), _rng.randf_range(-1.5, 1.5)), s, Color(1, 1, 1))
		var mi := MeshInstance3D.new()
		mi.mesh = mb.commit(mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(_rng.randf_range(-80, VoxelWorld.SX + 80), _rng.randf_range(44, 56), _rng.randf_range(-80, VoxelWorld.SZ + 80))
		_clouds.add_child(mi)


func _setup_bounds() -> void:
	# Murs invisibles autour de l'île pour ne pas tomber dans le vide.
	var body := StaticBody3D.new()
	body.name = "Bounds"
	add_child(body)
	var sx := float(VoxelWorld.SX)
	var sz := float(VoxelWorld.SZ)
	for data in [
		[Vector3(-0.5, 40, sz * 0.5), Vector3(1, 120, sz + 2)],
		[Vector3(sx + 0.5, 40, sz * 0.5), Vector3(1, 120, sz + 2)],
		[Vector3(sx * 0.5, 40, -0.5), Vector3(sx + 2, 120, 1)],
		[Vector3(sx * 0.5, 40, sz + 0.5), Vector3(sx + 2, 120, 1)],
		[Vector3(sx * 0.5, -0.5, sz * 0.5), Vector3(sx + 2, 1, sz + 2)],
	]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = data[1]
		cs.shape = box
		cs.position = data[0]
		body.add_child(cs)


func _setup_highlight() -> void:
	_highlight = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	_highlight.mesh = bm
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.albedo_color = Color(1, 1, 1, 0.3)
	_highlight.material_override = _highlight_mat
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_highlight.visible = false
	add_child(_highlight)

	var mb := MeshBuilder.new()
	var t := 0.035
	for a in [-0.5, 0.5]:
		for b in [-0.5, 0.5]:
			mb.add_box(Vector3(0, a, b), Vector3(1 + t, t, t), Color.WHITE, false)
			mb.add_box(Vector3(a, 0, b), Vector3(t, 1 + t, t), Color.WHITE, false)
			mb.add_box(Vector3(a, b, 0), Vector3(t, t, 1 + t), Color.WHITE, false)
	var omat := StandardMaterial3D.new()
	omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	omat.vertex_color_use_as_albedo = true
	_outline = MeshInstance3D.new()
	_outline.mesh = mb.commit(omat)
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline.visible = false
	add_child(_outline)


# --- Îles ----------------------------------------------------------------

func _load_island(id: String, music := true) -> void:
	Game.current_island = id
	Game.talked.clear()
	var isl := IslandDB.get_island(id)
	world.island_id = id
	_spawn = IslandGenerator.generate(world, isl)
	var edits: Dictionary = Game.edits.get(id, {})
	for key in edits:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 3:
			world.set_raw(int(parts[0]), int(parts[1]), int(parts[2]), int(edits[key]))
	world.build_all(_spawn)
	_spawn.y = world.top_solid_y(floori(_spawn.x), floori(_spawn.z)) + 1.1
	_apply_look(isl)
	if music:
		Audio.play_music(id)
	player.teleport(_spawn)
	rig.yaw = 0.0
	rig.snap()
	props.spawn_island(id, IslandGenerator.props)
	nav.build(world, props)
	worksites.load_island(id)
	_spawn_creatures()
	_spawn_animals(false)
	_spawn_pickups()
	_spawn_camp()


func _apply_look(isl: Dictionary) -> void:
	sky.set_island(isl)
	var sh: Color = isl["water_shallow"]
	var dp: Color = isl["water_deep"]
	_ocean_mat.set_shader_parameter("shallow_color", Color(sh.r, sh.g, sh.b, 0.55))
	_ocean_mat.set_shader_parameter("deep_color", Color(dp.r, dp.g, dp.b, 0.93))


func travel_to(id: String) -> void:
	if _loading:
		return
	_loading = true
	_highlight.visible = false
	_outline.visible = false
	await hud.fade(true, 0.4)
	_load_island(id)
	hud.refresh_all()
	await get_tree().process_frame
	await hud.fade(false, 0.6)
	_loading = false
	hud.toast("Bienvenue sur l'%s !" % IslandDB.get_island(id)["name"], UIStyle.GREEN_DARK)
	Game.save_game()


func reset_game() -> void:
	Game.reset_game()
	power = 0
	await travel_to("prairie")
	hud.refresh_all()


# --- Créatures -----------------------------------------------------------

func _spawn_creatures() -> void:
	for c in creatures_root.get_children():
		c.queue_free()
	for id in Game.residents:
		var info: Dictionary = Game.residents[id]
		if info.get("island", "") == Game.current_island:
			var door := _home_door(id)
			var cr := _make_creature(ResidentDB.get_resident(id), door if door != Vector3.INF else _find_spot(_spawn, 18.0))
			cr.voice = 0.85 + float(hash(id) % 50) / 100.0
	_find_beach_spots()


func _make_creature(d: Dictionary, pos: Vector3) -> Creature:
	var c := Creature.new()
	c.nav = nav
	c.setup(d, world, pos)
	creatures_root.add_child(c)
	return c


func _find_spot(center: Vector3, radius: float) -> Vector3:
	for i in 40:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(2.0, radius)
		var x := floori(center.x + cos(a) * r)
		var z := floori(center.z + sin(a) * r)
		var y := world.top_solid_y(x, z)
		if y <= IslandGenerator.SEA:
			continue
		var b := world.get_block(x, y, z)
		if b in [Blocks.LEAVES, Blocks.PINE_LEAVES, Blocks.PALM_LEAVES, Blocks.AUTUMN_LEAVES, Blocks.WOOL, Blocks.WOOD, Blocks.PALM_WOOD]:
			continue
		return Vector3(x + 0.5, y + 1.0, z + 0.5)
	return center


func _on_resident_arrived(id: String) -> void:
	_check_new_islands()
	if _morning:
		return  # présenté par la scène du matin (_welcome)
	var c := ResidentDB.get_resident(id)
	var info: Dictionary = Game.residents.get(id, {})
	if info.get("island", "") == Game.current_island:
		var pos := _find_spot(player.global_position, 4.0)
		var cr := _make_creature(c, pos)
		cr.celebrate()
		_burst(pos + Vector3(0, 0.6, 0), Color("ffd84a"), 24)


func _check_new_islands() -> void:
	for isl in IslandDB.ISLANDS:
		if int(isl["residents_needed"]) == Game.resident_count() and int(isl["residents_needed"]) > 0:
			hud.toast("Nouvelle île débloquée : %s ! (Carte : M)" % isl["name"], UIStyle.BLUE.darkened(0.2))
			get_tree().create_timer(2.5).timeout.connect(func(): Audio.play("jingle_island", -4.0, 0.0))


# --- Nuit et arrivées -----------------------------------------------------

## On dort jusqu'au lendemain : chaque île assez accueillante attire un
## nouvel habitant, tiré au sort selon son environnement.
func sleep() -> void:
	if _loading or _busy or _cinematic or _in_title:
		return
	_busy = true
	_cinematic = true
	hud.close_panel()
	_prompt.visible = false
	await _think("dormir")
	var story := StoryOverlay.new()
	add_child(story)
	story._set_lid(0.0)
	story._skip_hint.visible = false
	await story.black(1.4)
	Game.day += 1
	sky.morning()
	_regrow()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var arrivals := {}
	for isl in IslandDB.ISLANDS:
		var iid: String = isl["id"]
		if iid != Game.current_island and Game.get_stat(iid, "place") + Game.get_stat(iid, "break") == 0:
			continue  # île jamais visitée
		var c := Vitality.pick_arrival(iid, rng)
		if not c.is_empty():
			arrivals[iid] = c
	story.show_title("Jour %d" % Game.day, "Le lendemain matin...", 1.4)
	await get_tree().create_timer(3.6).timeout
	_morning = true
	for iid in arrivals:
		Game.add_resident(arrivals[iid]["id"], iid)
	_morning = false
	Game.save_game()
	await story.clear_bars(1.6)
	story.queue_free()
	_cinematic = false
	_spawn_animals(true)
	for iid in arrivals:
		if iid != Game.current_island:
			hud.toast("%s s'est installé sur l'%s !" % [arrivals[iid]["name"], IslandDB.get_island(iid)["name"]], UIStyle.GREEN_DARK)
	if arrivals.has(Game.current_island) and interior == null:
		await _welcome(arrivals[Game.current_island])
	elif arrivals.has(Game.current_island):
		hud.toast("%s s'est installé sur l'île !" % arrivals[Game.current_island]["name"], UIStyle.GREEN_DARK)
		_spawn_creatures()
	elif Vitality.next_threshold(Game.current_island) >= 0:
		await _think("matin_vide")
	_busy = false


## Le nouvel habitant arrive près du joueur, regarde autour de lui... et reste.
func _welcome(c: Dictionary) -> void:
	var pp := player.global_position
	var fwd := -rig.camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var pos := _find_spot(pp + fwd * 5.0, 2.5)
	var cr := _make_creature(c, pos)
	cr.talk_to(pp)
	player.face_towards(pos)
	_burst(pos + Vector3(0, 0.6, 0), Color("ffd84a"), 18)
	Audio.play("jingle_friend", -4.0, 0.0)
	await get_tree().create_timer(1.0).timeout
	var first := not Game.has_flag("first_arrival")
	var lines := await Dialogues.texts(Dialogues.ARRIVALS, "premiere" if first else "arrivee")
	hud.show_dialog(c["name"], lines)
	while hud.dialog_open():
		await get_tree().process_frame
	hud.show_resident_popup(c["id"])
	hud.toast("%s s'installe sur l'île !" % c["name"], UIStyle.GREEN_DARK)
	if first:
		Game.set_flag("first_arrival")
		get_tree().create_timer(3.5).timeout.connect(func():
			hud.toast("Plus l'île est accueillante, plus elle attire d'habitants !", UIStyle.BLUE.darkened(0.2)))
	Game.notify_action("arrival")
	# Une maison libre ? Il s'y installe ; sinon, il faudra lui en bâtir une.
	for id in props.items:
		if Props.is_house(props.kind_of(id)) and not Game.homes.has(props.key_of(id)):
			Game.set_home(props.key_of(id), c["id"])
			hud.toast("%s s'installe dans une maison libre." % c["name"], UIStyle.GREEN_DARK)
			return
	if not Game.has_flag("hint_house"):
		Game.set_flag("hint_house")
		get_tree().create_timer(4.0).timeout.connect(func(): _think("maison_habitant"))


# --- Boucle --------------------------------------------------------------

func _process(delta: float) -> void:
	_cooldown -= delta
	for cl in _clouds.get_children():
		var n := cl as Node3D
		n.position.x += delta * 1.2
		if n.position.x > VoxelWorld.SX + 100.0:
			n.position.x = -100.0
	_update_mouse_mode()
	if _in_title:
		rig.yaw += delta * 0.07
		player.input_enabled = false
		rig.input_enabled = false
		_highlight.visible = false
		_outline.visible = false
		world.focus = player.global_position
		world.set_view(Vector3(0, -1000, 0), Vector3.ZERO)
		return
	var blocking := hud.is_blocking() or _loading or _cinematic
	player.input_enabled = not blocking
	rig.input_enabled = not blocking
	world.set_view(player.global_position, rig.camera.global_position)
	world.focus = player.global_position
	_update_creature_labels()
	nav.budget = Navigator.STEPS_PER_FRAME
	_update_worksites(delta)
	_npc_ai(delta)
	_update_occluders()
	_hints(delta)
	_update_story()
	var aiming := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	hud.set_crosshair(aiming and not blocking, UIStyle.POWER_COLORS[power] if hud.power_unlocked(power) else Color.WHITE)
	if blocking:
		_highlight.visible = false
		_outline.visible = false
		return
	_update_target()
	_update_ghost()


## Souris capturée en jeu (caméra libre) ; libérée dans les menus,
## dialogues, cinématiques, ou en maintenant Alt.
func _update_mouse_mode() -> void:
	var capture := not _in_title and not _cinematic and not _loading and not hud.is_blocking() \
		and not hud.wants_cursor() and not Input.is_action_pressed("free_cursor") \
		and DisplayServer.window_is_focused()
	var want := Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func _make_label3d(text: String, size: int, col: Color, outline: int) -> Label3D:
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


# --- Histoire : exploration, point d'eau, campement, coffre ---------------

func _spawn_camp() -> void:
	if camp_props:
		camp_props.queue_free()
		camp_props = null
	if IslandGenerator.camp.is_empty():
		return
	camp_props = CampProps.new()
	camp_props.world = world
	camp_props.name = "Camp"
	add_child(camp_props)


## Objets à ramasser : un peu partout, et quelques-uns sur le chemin
## entre la plage du naufrage et le campement.
func _spawn_pickups() -> void:
	for c in pickups_root.get_children():
		c.queue_free()
	var isl := IslandDB.get_island(Game.current_island)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(isl["seed"]) + 5
	var counts := {"branch": 70, "stone": 60, "fruit": 40, "plant": 55}
	for k in counts:
		var placed := 0
		for attempt in 3000:
			if placed >= int(counts[k]):
				break
			var x := rng.randi_range(8, VoxelWorld.SX - 9)
			var z := rng.randi_range(8, VoxelWorld.SZ - 9)
			if _add_pickup(k, x, z, k == "fruit"):
				placed += 1
	var b: Dictionary = IslandGenerator.beach
	if b.is_empty():
		return
	var from: Vector3 = b["pos"]
	var to := Vector3(IslandGenerator.SPAWN.x, 0, IslandGenerator.SPAWN.y)
	var side := (to - from).cross(Vector3.UP).normalized()
	for k in HUD.TUTO[0]["goals"]:
		var need: int = int(HUD.TUTO[0]["goals"][k]) + 1
		for attempt in 60:
			if need <= 0:
				break
			var p := from.lerp(to, rng.randf_range(0.12, 0.8)) + side * rng.randf_range(-7.0, 7.0)
			if _add_pickup(k, floori(p.x), floori(p.z), false):
				need -= 1


func _add_pickup(kind: String, x: int, z: int, near_tree: bool) -> bool:
	var y := world.top_solid_y(x, z)
	if y <= IslandGenerator.SEA:
		return false
	if not world.get_block(x, y, z) in [Blocks.GRASS, Blocks.SAND, Blocks.DIRT, Blocks.SNOW, Blocks.MOSS]:
		return false
	var p := Vector3(x + 0.5, y + 1.0, z + 0.5)
	if near_tree and not props.any_near(p, 3.0, true):
		return false
	if props.any_near(p, 0.9):
		return false
	# Déjà ramassé et pas encore repoussé : la place reste vide.
	var key := "%d,%d" % [x, z]
	if (Game.picked.get(Game.current_island, {}) as Dictionary).has(key):
		return true
	var pk := Pickup.new()
	pk.kind = kind
	pk.set_meta("key", key)
	pk.position = Vector3(x + 0.5, y + 1.0, z + 0.5)
	pickups_root.add_child(pk)
	return true


func _update_story() -> void:
	if _cinematic:
		return
	var pp := player.global_position
	var it := _nearest_interactable()
	_prompt.visible = not it.is_empty() and not hud.is_blocking() and not _busy
	if _prompt.visible:
		_prompt.text = it["prompt"]
		_prompt.global_position = (it["at"] as Vector3) + Vector3(0, 1.4, 0)
	# Ramassage automatique.
	for n in pickups_root.get_children():
		var pk := n as Pickup
		if pk == null or pk.collected:
			continue
		var d := pk.global_position - pp
		if Vector2(d.x, d.z).length() < Pickup.RADIUS and absf(d.y) < 1.6:
			pk.collect(pp)
			Game.add_item(pk.kind)
			if pk.has_meta("key"):
				(Game.picked.get_or_add(Game.current_island, {}) as Dictionary)[pk.get_meta("key")] = {"d": Game.day, "k": pk.kind}
			Audio.play("select", -6.0, 0.12, 1.5)
	if hud.dialog_open() or _busy:
		return
	# Découvertes.
	var pond := IslandGenerator.pond
	if pond != Vector3.ZERO and not Game.has_flag("water") and Vector2(pond.x - pp.x, pond.z - pp.z).length() < 5.5:
		Game.set_flag("water")
		player.face_towards(pond)
		_think("eau")
	var camp: Dictionary = IslandGenerator.camp
	if not camp.is_empty() and not Game.has_flag("camp"):
		var c: Vector3 = camp["center"]
		if Vector2(c.x - pp.x, c.z - pp.z).length() < 8.0:
			Game.set_flag("camp")
			player.face_towards(c)
			_think("campement")



## Pensées du personnage (fichier story.dialogue), affichées en bas de l'écran.
## Attend la fin du dialogue.
func _think(cue: String) -> void:
	while hud.dialog_open():
		await get_tree().process_frame
	var lines := await Dialogues.texts(Dialogues.STORY, cue)
	if lines.is_empty():
		return
	hud.show_dialog(Game.player_name if Game.player_name != "" else "Moi", lines)
	while hud.dialog_open():
		await get_tree().process_frame


func _on_step_changed(step: int) -> void:
	if step == 1 and not Game.has_flag("camp"):
		_think("provisions")


## Objet du décor le plus proche avec lequel on peut interagir.
func _nearest_interactable() -> Dictionary:
	var pp := player.global_position
	var cands := []
	if interior:
		cands.append({"pos": interior.to_global(interior.door_inside), "prompt": "[E] Sortir", "action": exit_house})
		cands.append({"pos": interior.to_global(interior.bed), "prompt": "[E] Dormir", "action": sleep})
	else:
		if camp_props and camp_props.chest:
			cands.append({"node": camp_props.chest, "prompt": "[E] Examiner" if camp_props.opened else "[E] Fouiller", "action": _open_chest})
			cands.append({"node": camp_props.tools, "prompt": "[E] Examiner", "action": func(): _think("rouille")})
			cands.append({"node": camp_props.tent, "prompt": "[E] Dormir", "action": sleep})
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
				cands.append({"pos": props.door_position(id), "prompt": ("%s\n" % who if who != "" else "") + "[E] Entrer   [G] Habitant", "action": func(): enter_house(hid), "house": hid})
			elif kind == "tent" and props.key_of(id).begins_with("p:"):
				cands.append({"node": props.items[id]["node"], "prompt": "[E] Dormir", "action": sleep})
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


func _open_chest() -> void:
	if camp_props.opened:
		_think("rouille")
		return
	_busy = true
	player.face_towards(camp_props.chest.global_position)
	await _think("coffre")
	player.play_action("open")
	camp_props.open()
	Audio.play("open", -2.0, 0.0, 0.8)
	await get_tree().create_timer(0.8).timeout
	Audio.play("jingle_rare", -4.0, 0.0)
	_burst(camp_props.chest.global_position + Vector3(0, 0.7, 0), Color("ffd84a"), 24)
	hud.show_item_popup("Outil de destruction/construction universel obtenu !", "Il peut détruire et construire presque n'importe quoi.")
	Game.set_flag("camp")
	Game.set_flag("chest")
	hud.jump_to_step(3)
	Game.save_game()
	await get_tree().create_timer(2.6).timeout
	await _think("outil")
	_busy = false


func _update_target() -> void:
	target = {}
	var mp := get_viewport().get_mouse_position()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mp = get_viewport().get_visible_rect().size * 0.5
	var cam := rig.camera
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if interior:
		_update_target_inside(from, dir)
		return
	var reach := ADMIN_REACH if Game.admin else REACH
	var chest_pos := player.global_position + Vector3(0, 0.7, 0)
	var hit := world.raycast(from, dir, 80.0, _is_cut)
	var voxel_d := INF
	if hit["hit"]:
		var center := Vector3(hit["pos"]) + Vector3(0.5, 0.5, 0.5)
		voxel_d = from.distance_to(center) - 0.5
		if center.distance_to(chest_pos) <= reach:
			target = hit
	# Objets 3D (arbres, feux...) visés au viseur, s'ils sont devant les voxels.
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 80.0, Props.LAYER)
	var ph := get_world_3d().direct_space_state.intersect_ray(q)
	if not ph.is_empty():
		var id := props.id_from_collider(ph["collider"])
		var hp: Vector3 = ph["position"]
		if id > 0 and from.distance_to(hp) < voxel_d and hp.distance_to(chest_pos) <= reach + 1.0:
			target = {"hit": true, "prop": id, "point": hp, "pos": Vector3i(hp.floor()), "block": Blocks.AIR}
	_update_highlight()


## À l'intérieur : on vise le sol (pour poser) ou un meuble (pour le reprendre).
func _update_target_inside(from: Vector3, dir: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 30.0, Interior.LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit["position"] as Vector3).distance_to(player.global_position) < 9.0:
		var col: Object = hit["collider"]
		if col is Node and (col as Node).has_meta("furn"):
			target = {"hit": true, "furn": int((col as Node).get_meta("furn")), "point": hit["position"], "pos": Vector3i.ZERO, "block": Blocks.AIR}
		elif col is Node and (col as Node).has_meta("floor"):
			target = {"hit": true, "floor": interior.to_local(hit["position"]), "point": hit["position"], "pos": Vector3i.ZERO, "block": Blocks.AIR}
	_update_highlight()


## Même test que le shader voxel : bloc d'arbre effacé car entre la caméra et le joueur.
func _is_cut(p: Vector3i) -> bool:
	if not world.get_blockv(p) in VoxelWorld.SEE_THROUGH:
		return false
	var c := Vector3(p) + Vector3(0.5, 0.5, 0.5)
	var pp := player.global_position
	if c.y + 0.5 <= pp.y - 0.2:
		return false
	var cam := rig.camera.global_position
	var to_player := pp + Vector3(0, 0.7, 0) - cam
	var dp := to_player.length()
	if dp < 0.01:
		return false
	var dir := to_player / dp
	var rel := c - cam
	var t := rel.dot(dir)
	if t <= 0.0 or t >= dp - 0.6:
		return false
	var perp := (rel - dir * t).length()
	var r := 2.2 * clampf(t / dp + 0.35, 0.0, 1.0)
	return perp < r * 0.8


func _update_highlight() -> void:
	if target.is_empty() or not hud.power_unlocked(power):
		_highlight.visible = false
		_outline.visible = false
		return
	if target.has("floor"):
		_highlight.visible = false
		_outline.visible = false
		return
	if target.has("prop") or target.has("furn"):
		# Objet 3D : on entoure toute sa boîte englobante (seul « Casser » s'applique).
		var ab := props.bounds(int(target["prop"])) if target.has("prop") else interior.furn_bounds(int(target["furn"]))
		var c0: Color = UIStyle.POWER_COLORS[0] if power == 0 else UIStyle.TEXT_SOFT
		_highlight.visible = true
		_highlight.position = ab.get_center()
		_highlight.scale = ab.size + Vector3.ONE * 0.1
		_highlight_mat.albedo_color = Color(c0.r, c0.g, c0.b, 0.18 + sin(Time.get_ticks_msec() * 0.006) * 0.05)
		_outline.visible = false
		return
	var p: Vector3i = target["pos"]
	var col: Color = UIStyle.POWER_COLORS[power]
	var pos := Vector3(p) + Vector3(0.5, 0.5, 0.5)
	var size := Vector3.ONE * 1.02
	var show_outline := true
	match power:
		1:
			if not Blocks.is_deco(int(target["block"])):
				pos += Vector3(target["normal"] as Vector3i)
			col = Blocks.main_color(block)
		2:
			if Blocks.is_deco(int(target["block"])):
				pos.y -= 1.0
			pos.y += 0.52
			size = Vector3(5.0, 0.06, 5.0)
			show_outline = false
		3:
			if Blocks.is_deco(int(target["block"])):
				pos.y -= 1.0
			pos.y += 1.0
			size = Vector3(0.5, 1.0, 0.5)
			show_outline = false
	_highlight.visible = true
	_highlight.position = pos
	_highlight.scale = size
	var pulse := 0.3 + sin(Time.get_ticks_msec() * 0.006) * 0.08
	_highlight_mat.albedo_color = Color(col.r, col.g, col.b, pulse + (0.15 if power == 1 else 0.0))
	_outline.visible = show_outline
	_outline.position = pos
	_outline.scale = Vector3.ONE * 1.02


func _update_creature_labels() -> void:
	var best: Creature = null
	var best_d := 2.6
	for n in creatures_root.get_children():
		var c := n as Creature
		if c == null or c.is_queued_for_deletion():
			continue
		var d := c.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = c
	for n in creatures_root.get_children():
		var c := n as Creature
		if c == null:
			continue
		var d := c.global_position.distance_to(player.global_position)
		c.set_label_visible(d < 7.0, c == best)


# --- Entrées -------------------------------------------------------------

## Caméra libre : la souris (capturée) oriente la caméra.
func _input(event: InputEvent) -> void:
	if _in_title or _cinematic:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		rig.look(-mm.relative.x * Game.mouse_sensitivity, -mm.relative.y * Game.mouse_sensitivity)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _loading or _in_title or _cinematic:
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
		var it := _nearest_interactable()
		if it.has("house"):
			choose_resident(int(it["house"]))
		return
	if hud.is_blocking():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					rig.zoom(-1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					rig.zoom(1.0)
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_use_power()

	for i in 4:
		if event.is_action_pressed("power_%d" % (i + 1)):
			select_power(i)
	if event.is_action_pressed("rotate"):
		_place_rot = wrapf(_place_rot + PI * 0.5, 0.0, TAU)
		Audio.play("click", -10.0)
	if event.is_action_pressed("block_next"):
		_cycle_block(1)
	elif event.is_action_pressed("block_prev"):
		_cycle_block(-1)
	if event.is_action_pressed("interact"):
		_interact()


func select_power(i: int) -> void:
	if not hud.power_unlocked(i):
		_deny("Ce pouvoir n'est pas encore débloqué !")
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


func _cycle_block(step: int) -> void:
	var list := hud.placeables()
	if list.is_empty():
		return
	var cur: Variant = structure if structure != "" else block
	var i := list.find(cur)
	var next: Variant = list[posmod(i + step, list.size())]
	if next is String:
		select_structure(next)
	else:
		select_block(next)


func _interact() -> void:
	var best: Creature = null
	var best_d := 2.6
	for n in creatures_root.get_children():
		var c := n as Creature
		if c == null:
			continue
		var d := c.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = c
	var it := _nearest_interactable()
	var animal: Animal = null
	var animal_d := 2.2
	for n in animals_root.get_children():
		var a := n as Animal
		if a and a.global_position.distance_to(player.global_position) < animal_d:
			animal_d = a.global_position.distance_to(player.global_position)
			animal = a
	if animal and (it.is_empty() or animal_d < float(it["dist"])) and (best == null or animal_d < best_d):
		animal.react(player.global_position)
		player.face_towards(animal.global_position)
		player.play_action("talk")
		Audio.play("talk", -6.0, 0.2, 1.8)
		return
	if not it.is_empty() and (best == null or float(it["dist"]) < best_d):
		_prompt.visible = false
		(it["action"] as Callable).call()
		return
	if best == null:
		return
	best.talk_to(player.global_position)
	player.face_towards(best.global_position)
	player.play_action("talk")
	await _talk_resident(best)


# --- Amitié : parler, offrir, rendre service ---------------------------------

## Une réplique d'un habitant (fichier residents.dialogue), avec remplacements.
func _rline(cue: String, repl := {}) -> String:
	var t := await Dialogues.texts(Dialogues.RESIDENTS, cue)
	var line: String = t[0] if not t.is_empty() else "..."
	for k in repl:
		line = line.replace("{%s}" % k, str(repl[k]))
	return line


func _talk_resident(c: Creature) -> void:
	var id: String = c.data["id"]
	var d := Friendship.data(id)
	if d.is_empty():
		return
	var lines: Array = []
	var first_today := int(d.get("talk_day", -1)) != Game.day
	# 1) Ce qui a changé pour lui : un déménagement, de nouveaux meubles.
	var react: String = await _furniture_reaction(id)
	if d.get("moved", false):
		d["moved"] = false
		lines.append(await _rline("demenage") + " " + Friendship.moved_reason(id))
	elif react != "":
		lines.append(react)
	else:
		# 2) Sinon, une réplique selon le moment, la météo, son ancienneté...
		var cue := ""
		if sky.is_wet():
			cue = "pluie"
		elif Game.time >= 20.0 or Game.time < 6.0:
			cue = "nuit"
		elif Game.time < 10.0 and first_today:
			cue = "matin"
		elif Friendship.days_here(id) < 3 and _rng.randf() < 0.6:
			cue = "nouveau"
		elif Friendship.days_here(id) >= 10 and Friendship.hearts(id) >= 3 and _rng.randf() < 0.5:
			cue = "installe"
		elif Game.home_of(id) == "" and _rng.randf() < 0.5:
			cue = "sans_maison"
		elif Vitality.percent(Game.current_island) >= 45 and _rng.randf() < 0.4:
			cue = "belle_ile"
		if cue != "":
			lines.append(await _rline(cue))
		elif Friendship.hearts(id) >= 1 or _rng.randf() < 0.5:
			lines.append((c.data["lines"] as Array).pick_random())
		else:
			lines.append(await _rline("nouveau"))
	# 3) Une fois par jour : l'amitié grandit, et les cœurs débloquent des choses.
	if first_today:
		d["talk_day"] = Game.day
		Friendship.add(id, 3)
		var h := Friendship.hearts(id)
		if h >= 5 and not d.get("best_friend", false):
			d["best_friend"] = true
			lines.append(await _rline("ami"))
			get_tree().create_timer(0.5).timeout.connect(func():
				hud.show_item_popup("%s est devenu un véritable ami" % c.data["name"], "♥ 5/5", false))
		elif h >= 4 and not d.get("unique_given", false):
			d["unique_given"] = true
			var f: String = Friendship.UNIQUE[Friendship.habitat(id)]
			Game.add_structure("f_" + f)
			lines.append(await _rline("meuble_unique"))
			lines.append("(Tu reçois : %s)" % Interior.label_of(f))
		elif h >= 3 and not d.has("request") and int(d.get("request_day", -1)) != Game.day:
			var item: String = Friendship.REQUESTS.pick_random()
			var n := _rng.randi_range(2, 4)
			d["request"] = {"item": item, "n": n}
			d["request_day"] = Game.day
			lines.append(await _rline("demande", {"n": n, "item": Items.name_of(item, n).to_lower()}))
		elif h >= 2 and _rng.randf() < 0.35:
			var gift: String = (Items.RAW + ["beam", "peg", "rope"]).pick_random()
			Game.add_item(gift, 2)
			lines.append(await _rline("donne"))
			lines.append("(Tu reçois : 2 %s)" % Items.name_of(gift, 2).to_lower())
	Game.talked[id] = true
	Game.save_game()
	var who := "%s   %s" % [c.data["name"], Friendship.hearts_text(id)]
	hud.show_dialog(who, lines, func(): _offer_menu(c))
	Audio.play("talk", -4.0, 0.2, c.voice)
	Game.notify_action("talk")


## Après la discussion : offrir quelque chose (ou partir).
func _offer_menu(c: Creature) -> void:
	var opts := [{"id": "", "label": "Au revoir"}]
	for k in Items.ALL:
		if Game.item_count(k) > 0:
			opts.append({"id": k, "label": "Offrir : %s (%d)" % [Items.name_of(k), Game.item_count(k)]})
	if opts.size() == 1:
		return
	hud.show_choice("Offrir quelque chose à %s ?" % c.data["name"], opts, func(item: String):
		if item != "":
			_give(c, item))


func _give(c: Creature, item: String) -> void:
	var id: String = c.data["id"]
	var d := Friendship.data(id)
	var lines: Array = []
	var req: Dictionary = d.get("request", {})
	if not req.is_empty() and req["item"] == item and Game.item_count(item) >= int(req["n"]):
		# Il avait demandé ça : on lui rend service.
		Game.add_item(item, -int(req["n"]))
		d.erase("request")
		Friendship.add(id, 8)
		var rewards := Friendship.LIKES[Friendship.habitat(id)]["furniture"] as Array
		var f: String = rewards.pick_random()
		Game.add_structure("f_" + f)
		lines.append(await _rline("demande_ok"))
		lines.append("(Tu reçois : %s)" % Interior.label_of(f))
	elif int(d.get("gift_day", -1)) == Game.day:
		lines.append(await _rline("deja_cadeau"))
	else:
		Game.add_item(item, -1)
		d["gift_day"] = Game.day
		var liked := Friendship.likes_item(id, item)
		Friendship.add(id, 6 if liked else 3)
		lines.append(await _rline("cadeau_aime" if liked else "cadeau"))
	c.celebrate()
	Game.save_game()
	hud.show_dialog("%s   %s" % [c.data["name"], Friendship.hearts_text(id)], lines)


## L'habitant remarque les meubles ajoutés chez lui depuis sa dernière visite.
func _furniture_reaction(id: String) -> String:
	var key := Game.home_of(id)
	if key == "" or not Game.interiors.has(key):
		return ""
	var d := Friendship.data(id)
	var seen: Array = d.get("seen_furn", [])
	var fresh := ""
	var names: Array = []
	for e in Game.interiors[key]:
		names.append(e["f"])
		if not e["f"] in seen and fresh == "":
			fresh = e["f"]
	d["seen_furn"] = names
	if fresh == "":
		return ""
	var liked := Friendship.likes_furniture(id, fresh)
	Friendship.add(id, 4 if liked else 2)
	return await _rline("meuble_aime" if liked else "meuble", {"f": Interior.with_article(fresh)})


# --- Pouvoirs ------------------------------------------------------------

func _use_power() -> void:
	if target.is_empty() or _cooldown > 0.0:
		return
	if interior:
		_use_power_inside()
		return
	if not hud.power_unlocked(power):
		_deny("Ce pouvoir n'est pas encore débloqué !")
		return
	_cooldown = 0.16
	var ok := false
	if target.has("prop"):
		if power == 0:
			ok = _do_cut_prop()
		else:
			_deny("Vise le sol pour utiliser ce pouvoir.")
		if ok:
			player.face_towards(target["point"])
			player.play_action("break")
		return
	match power:
		0:
			ok = _do_break()
		1:
			ok = _do_place_structure() if structure != "" else _do_place()
		2:
			ok = _do_bloom()
		3:
			ok = _do_tree()
	if ok:
		player.face_towards(Vector3(target["pos"] as Vector3i) + Vector3(0.5, 0, 0.5))
		player.play_action(["break", "place", "bloom", "tree"][power])


func _do_break() -> bool:
	var p: Vector3i = target["pos"]
	var b: int = target["block"]
	if p.y <= 0:
		_deny("Ce bloc est trop profond pour être cassé.")
		return false
	world.set_block(p, Blocks.AIR)
	var above := p + Vector3i.UP
	if Blocks.is_deco(world.get_blockv(above)):
		world.set_block(above, Blocks.AIR)
	world.flush()
	_burst(Vector3(p) + Vector3(0.5, 0.5, 0.5), Blocks.main_color(b), 14)
	Audio.play("break_" + material_sound(b), -2.0, 0.1, 1.25 if Blocks.is_deco(b) else 1.0)
	if b == Blocks.DEBRIS:
		if p.y <= IslandGenerator.SEA + 3:
			Game.add_stat("clean_shore")
		Game.add_stat("clean_waste")
		Game.notify_action("clean_waste")
	elif b == Blocks.SLUDGE:
		Game.add_stat("clean_water")
		Game.notify_action("clean_water")
	# Les objets posés au-dessus ne doivent pas flotter.
	props.resnap_near(Vector3(p) + Vector3(0.5, 0, 0.5), 4.0)
	nav.refresh_area(Vector3(p), 1.5)
	# On récupère ce qu'on casse (une fleur donne une plante).
	var drop := Blocks.drop_of(b)
	if drop >= 0:
		Game.add_block(drop)
	elif b in Blocks.FLOWERS:
		Game.add_item("plant")
	_count_altitude(p.y)
	Game.add_stat("break")
	Game.notify_action("break")
	hud.set_block(block)
	return true


func _announce_recipes() -> void:
	if _in_title:
		return
	_check_zones()
	for r in Crafting.newly_unlocked():
		hud.show_item_popup("Nouvelle recette : %s" % r["name"], "À fabriquer à la table d'artisan.", false)
		Audio.play("jingle_common", -6.0, 0.0)


# --- Intérieurs : meubler -------------------------------------------------

func _use_power_inside() -> void:
	_cooldown = 0.2
	if power == 0 and target.has("furn"):
		var name := interior.take_furniture(int(target["furn"]))
		if name != "":
			Game.add_structure("f_" + name)
			Audio.play("place_wood", -4.0, 0.1, 1.2)
			player.play_action("break")
			hud.set_block(block)
			Game.save_game()
	elif power == 1 and structure.begins_with("f_") and _ghost_ok and _ghost and _ghost.visible:
		var name := structure.trim_prefix("f_")
		var lp := interior.to_local(_ghost_pos)
		interior.add_furniture(name, lp.x, lp.z, _place_rot)
		if not Game.admin:
			Game.add_structure(structure, -1)
		Audio.play("place_wood", -3.0, 0.05, 0.9)
		player.play_action("place")
		Game.notify_action("place")
		hud.set_structure(structure)
		if Game.structure_count(structure) <= 0 and not Game.admin:
			select_block(block)
		Game.save_game()
	else:
		_deny("")


func _update_ghost_inside() -> void:
	var show := power == 1 and structure.begins_with("f_") and target.has("floor") and (Game.admin or Game.structure_count(structure) > 0)
	if not show:
		if _ghost:
			_ghost.visible = false
		return
	if _ghost == null or _ghost_kind != structure:
		if _ghost:
			_ghost.queue_free()
		_ghost = Interior.make_furn_model(structure.trim_prefix("f_"))
		_ghost_kind = structure
		add_child(_ghost)
	var lp: Vector3 = target["floor"]
	var x := snappedf(lp.x, 0.5)
	var z := snappedf(lp.z, 0.5)
	_ghost_pos = interior.to_global(Vector3(x, 0, z))
	_ghost.visible = true
	_ghost.global_position = _ghost_pos
	_ghost.rotation.y = _place_rot
	_ghost_ok = interior.fits(structure.trim_prefix("f_"), x, z, _place_rot)
	_tint_ghost()


func _tint_ghost() -> void:
	var tint := Color(0.4, 1.0, 0.5, 0.35) if _ghost_ok else Color(1.0, 0.35, 0.3, 0.45)
	for m in _ghost.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).material_overlay as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			(m as MeshInstance3D).material_overlay = mat
		mat.albedo_color = tint


# --- Constructions : aperçu fantôme et pose --------------------------------

func _update_ghost() -> void:
	if interior:
		_update_ghost_inside()
		return
	var show := power == 1 and structure != "" and not structure.begins_with("f_") and not target.is_empty() \
		and not target.has("prop") and (Game.admin or Game.structure_count(structure) > 0)
	if not show:
		if _ghost:
			_ghost.visible = false
		return
	if _ghost == null or _ghost_kind != structure:
		if _ghost:
			_ghost.queue_free()
		_ghost = Props.make_model(structure, 1.0)
		_ghost_kind = structure
		add_child(_ghost)
	var p: Vector3i = target["pos"]
	if Blocks.is_deco(int(target["block"])):
		p.y -= 1
	_ghost_pos = Vector3(p.x + 0.5, p.y + 1, p.z + 0.5)
	_ghost.visible = true
	_ghost.position = _ghost_pos
	_ghost.rotation.y = _place_rot
	_ghost_ok = _structure_fits(structure, _ghost_pos, _place_rot)
	var tint := Color(0.4, 1.0, 0.5, 0.35) if _ghost_ok else Color(1.0, 0.35, 0.3, 0.45)
	for m in _ghost.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).material_overlay as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			(m as MeshInstance3D).material_overlay = mat
		mat.albedo_color = tint
	_highlight.visible = false
	_outline.visible = false


## La construction tient-elle ici ? Sol assez plat, hors de l'eau, sans
## chevaucher d'autre objet ni le joueur.
func _structure_fits(kind: String, pos: Vector3, rot: float) -> bool:
	var ab := Props.local_aabb(kind)
	var s := float(Props.KINDS[kind]["scale"])
	var half := Vector2(ab.size.x, ab.size.z) * s * 0.5
	var basis := Basis(Vector3.UP, rot)
	var base_y := floori(pos.y) - 1
	for fx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for fz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var q := pos + basis * Vector3(fx * half.x * 0.9, 0, fz * half.y * 0.9)
			var top := world.top_solid_y(floori(q.x), floori(q.z))
			if top <= IslandGenerator.SEA or absi(top - base_y) > 1:
				return false
	var radius := maxf(half.x, half.y)
	for id in props.items:
		var q: Vector3 = props.items[id]["pos"]
		var r2 := maxf(0.6, minf(2.5, Props.local_aabb(props.kind_of(id)).size.x * float(Props.KINDS[props.kind_of(id)]["scale"]) * 0.4))
		if Vector2(q.x - pos.x, q.z - pos.z).length() < radius * 0.8 + r2 and absf(q.y - pos.y) < 4.0:
			return false
	for site in worksites.all():
		var c := worksites.center_of(site)
		if Vector2(c.x - pos.x, c.z - pos.z).length() < radius * 0.8 + worksites.radius_of(site):
			return false
	var pp := player.global_position
	if Vector2(pp.x - pos.x, pp.z - pos.z).length() < radius * 0.7 + 0.4:
		return false
	return true


func _do_place_structure() -> bool:
	if not Game.admin and Game.structure_count(structure) <= 0:
		_deny("")
		return false
	if not _ghost_ok or _ghost == null or not _ghost.visible:
		_deny("")
		return false
	var kind := structure
	# On dégage la petite végétation sous l'emprise.
	var ab := Props.local_aabb(kind)
	var s := float(Props.KINDS[kind]["scale"])
	var half := Vector2(ab.size.x, ab.size.z) * s * 0.5
	var changed := false
	for dx in range(-ceili(half.x), ceili(half.x) + 1):
		for dz in range(-ceili(half.y), ceili(half.y) + 1):
			var q := Vector3i(floori(_ghost_pos.x) + dx, floori(_ghost_pos.y), floori(_ghost_pos.z) + dz)
			if Blocks.is_deco(world.get_blockv(q)):
				world.set_block(q, Blocks.AIR)
				changed = true
	if changed:
		world.flush()
	if not Game.admin:
		Game.add_structure(kind, -1)
	if Props.is_site(kind):
		# Grosse construction : on pose le plan, les habitants viendront bâtir.
		worksites.add_build(kind, _ghost_pos, _place_rot)
		Audio.play("place", -4.0, 0.05, 0.7)
		Game.notify_action("place")
		if Vitality.residents(Game.current_island) == 0:
			_think("chantier_seul")
		Game.save_game()
	else:
		props.add_persistent(kind, _ghost_pos, _place_rot, 1.0, true)
		_burst(_ghost_pos + Vector3(0, 1.0, 0), Color("ffd84a"), 16)
		Audio.play("place_wood", -2.0, 0.05, 0.8)
		_count_altitude(floori(_ghost_pos.y))
		Game.add_stat("build")
		Game.add_stat("build_" + kind)
		Game.notify_action("place")
		Game.notify_action("build")
	hud.set_structure(structure)
	if Game.structure_count(kind) <= 0 and not Game.admin:
		select_block(block)
	return true


# --- Chantiers : les habitants construisent et démolissent ----------------

## Une ruine se démolit en entier (tous ses murs et piliers).
func _demolish_group(id: int) -> Array:
	var key := props.key_of(id)
	if not key.begins_with("g:r:") and not key.begins_with("g:p:"):
		return [id]
	var c: Vector3 = props.items[id]["pos"]
	var out := []
	for other in props.items:
		var k := props.key_of(other)
		if not (k.begins_with("g:r:") or k.begins_with("g:p:")) or worksites.is_targeted(k):
			continue
		var q: Vector3 = props.items[other]["pos"]
		if Vector2(q.x - c.x, q.z - c.z).length() < 6.5:
			out.append(other)
	return out


func _update_worksites(delta: float) -> void:
	var sites := worksites.all()
	if sites.is_empty():
		return
	# Affectation des habitants libres (deux fois par seconde), de jour seulement.
	var work_hours := not sky.is_night() and Game.weather != "storm"
	_assign_timer -= delta
	if _assign_timer <= 0.0 and work_hours:
		_assign_timer = 0.5
		var workers := {}
		for n in creatures_root.get_children():
			var c := n as Creature
			if c and c.site_id != "":
				if worksites.get_site(c.site_id).is_empty():
					c.release()
				else:
					workers[c.site_id] = int(workers.get(c.site_id, 0)) + 1
		for n in creatures_root.get_children():
			var c := n as Creature
			if c == null or c.site_id != "" or not c.is_free():
				continue
			var best := {}
			var best_d := INF
			for site in sites:
				if int(workers.get(site["id"], 0)) >= Worksites.MAX_WORKERS:
					continue
				var d := c.global_position.distance_to(worksites.center_of(site))
				if d < best_d:
					best_d = d
					best = site
			if best.is_empty():
				continue
			var i := int(workers.get(best["id"], 0))
			workers[best["id"]] = i + 1
			c.assign(best["id"], worksites.slot(best, i), worksites.center_of(best))
	# Le travail avance avec chaque habitant à l'ouvrage.
	var busy := {}
	for n in creatures_root.get_children():
		var c := n as Creature
		if c and c.is_working():
			busy[c.site_id] = true
			worksites.work(c.site_id, delta)
	for site in worksites.all():
		worksites.set_busy(site["id"], busy.has(site["id"]))


func _on_site_finished(site: Dictionary) -> void:
	for n in creatures_root.get_children():
		var c := n as Creature
		if c and c.site_id == site["id"]:
			c.release()
	var pos := worksites.center_of(site)
	if site["type"] == "build":
		var kind: String = site["kind"]
		_burst(pos + Vector3(0, 2.0, 0), Color("ffd84a"), 30)
		Audio.play("jingle_common", -6.0, 0.0)
		_count_altitude(floori(pos.y))
		Game.add_stat("build")
		Game.add_stat("build_" + kind)
		Game.notify_action("build")
		hud.toast("%s : construction terminée !" % Crafting.structure_name(kind), UIStyle.GREEN_DARK)
		if Props.is_house(kind):
			for id in props.items:
				if props.kind_of(id) == kind and (props.items[id]["pos"] as Vector3).distance_to(pos) < 0.5:
					_auto_home(props.key_of(id), pos)
	else:
		for key in site["targets"]:
			for id in props.items.keys():
				if props.key_of(id) != key:
					continue
				var kind := props.kind_of(id)
				_burst(props.bounds(id).get_center(), Color("c9b99f"), 16)
				if key.begins_with("p:") and Props.is_structure(kind):
					Game.add_structure(kind)  # la maison démontée peut être reposée ailleurs
				if Game.homes.has(key):
					Game.homes.erase(key)
					Game.interiors.erase(key)
				var loot: Dictionary = (Props.KINDS[kind] as Dictionary).get("demolish", {})
				for item in loot:
					Game.add_item(item, int(loot[item]))
				props.remove(id)
		props.resnap_near(pos, 8.0)
		Audio.play("break_stone", -2.0, 0.05, 0.8)
		Game.add_stat("demolish")
		hud.set_block(block)
	Game.save_game()


# --- Repousse : l'île vit d'un jour à l'autre -------------------------------

## Jours avant qu'une ressource ramassée repousse.
const REGROW_DAYS := {"branch": 1, "plant": 1, "fruit": 2, "stone": 3}


## Chaque matin : les ressources repoussent peu à peu, des fleurs sauvages
## apparaissent près des autres, et les jeunes arbres grandissent.
func _regrow() -> void:
	for isl in Game.picked:
		var picked: Dictionary = Game.picked[isl]
		for key in picked.keys():
			var e: Dictionary = picked[key]
			if Game.day - int(e["d"]) >= int(REGROW_DAYS.get(e["k"], 2)) and _rng.randf() < 0.7:
				picked.erase(key)
	_spawn_pickups()
	# Fleurs sauvages : quelques-unes repoussent à côté des fleurs existantes.
	var biome: String = IslandDB.get_island(Game.current_island)["biome"]
	var flowers: Array = IslandGenerator.FLOWER_SETS[biome]
	if not flowers.is_empty():
		var grown := 0
		for attempt in 400:
			if grown >= 14:
				break
			var x := _rng.randi_range(8, VoxelWorld.SX - 9)
			var z := _rng.randi_range(8, VoxelWorld.SZ - 9)
			var y := world.top_solid_y(x, z)
			if y <= IslandGenerator.SEA or world.get_block(x, y, z) != Blocks.GRASS or world.get_block(x, y + 1, z) != Blocks.AIR:
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2)]:
				if world.get_block(x + d.x, y + 1, z + d.y) in Blocks.FLOWERS:
					near = true
			if near and not props.any_near(Vector3(x + 0.5, y + 1, z + 0.5), 0.8):
				world.set_block(Vector3i(x, y + 1, z), flowers.pick_random())
				grown += 1
		world.flush()
	props.update_growth()


# --- Pensées qui guident (pas de tutoriel) ---------------------------------

func _hints(delta: float) -> void:
	_hint_timer -= delta
	if _hint_timer > 0.0:
		return
	_hint_timer = 2.0
	if _cinematic or _busy or _loading or hud.dialog_open() or hud.is_blocking() or not Game.has_flag("chest"):
		return
	var raw := 0
	for k in Items.RAW:
		raw += Game.item_count(k)
	var hint := ""
	if interior and not Game.has_flag("hint_meubler") and Game.interiors.get(interior.house_key, []).size() < 4:
		hint = "meubler"
	elif interior:
		return
	elif sky.is_night() and Game.resident_count() == 0 and not Game.has_flag("hint_nuit"):
		hint = "nuit"
	elif sky.is_wet() and not Game.has_flag("hint_pluie"):
		hint = "pluie"
	elif raw >= 8 and not Game.has_flag("did_craft") and not Game.has_flag("hint_fabriquer"):
		hint = "fabriquer"
	elif Game.has_flag("did_craft") and not Game.has_flag("did_build") and not Game.has_flag("hint_construire"):
		hint = "construire"
	elif Game.has_flag("did_build") and not Game.has_flag("hint_belle_allure"):
		hint = "belle_allure"
	elif Vitality.percent(Game.current_island) >= Vitality.ARRIVALS[0] and Game.resident_count() == 0 and not Game.has_flag("hint_quelqu_un"):
		hint = "quelqu_un"
	if hint != "":
		Game.set_flag("hint_" + hint)
		_think(hint)


## Un arbre (ou une maison) entre la caméra et le joueur devient transparent :
## seulement celui qui gêne, pas toute la forêt.
func _update_occluders() -> void:
	var now := {}
	if interior == null and not _in_title:
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


# --- Habitants : routines et maisons ----------------------------------

## Porte de la maison d'un habitant (Vector3.INF : sans maison).
func _home_door(owner: String) -> Vector3:
	var key := Game.home_of(owner)
	if key == "":
		return Vector3.INF
	for id in props.items:
		if props.key_of(id) == key:
			return props.door_position(id)
	return Vector3.INF


func _find_beach_spots() -> void:
	_beach_spots.clear()
	for i in 400:
		var x := _rng.randi_range(8, VoxelWorld.SX - 9)
		var z := _rng.randi_range(8, VoxelWorld.SZ - 9)
		var y := world.top_solid_y(x, z)
		if y == IslandGenerator.SEA + 1 and world.get_block(x, y, z) == Blocks.SAND:
			_beach_spots.append(Vector3(x + 0.5, y + 1, z + 0.5))
		if _beach_spots.size() >= 25:
			break


## Lieux d'intérêt de l'île : [{"pos", "tag"}] (feu, banc, place, jardin, atelier...).
func _places() -> Array:
	var tags := {"campfire": "fire", "campfire_old": "fire", "bench": "bench", "fountain": "plaza",
		"stall": "plaza", "lantern": "plaza", "garden": "garden", "planter": "garden", "workbench": "work", "cart": "work"}
	var out := []
	for id in props.items:
		var k := props.kind_of(id)
		if tags.has(k):
			out.append({"pos": props.items[id]["pos"], "tag": tags[k]})
	return out


## Lieu préféré selon l'environnement de l'habitant.
const FAVORITE := {"forest": ["nature"], "garden": ["garden", "nature"], "marine": ["beach"], "mountain": ["nature", "mountain"], "village": ["plaza", "work", "bench"]}


func _npc_ai(delta: float) -> void:
	_ai_timer -= delta
	if _ai_timer > 0.0:
		return
	_ai_timer = 1.0
	var hour := Game.time
	var night := sky.is_night()
	var wet := sky.is_wet()
	var places := _places()
	var crs := []
	for n in creatures_root.get_children():
		if n is Creature:
			crs.append(n)
	for c: Creature in crs:
		var id: String = c.data["id"]
		var door := _home_door(id)
		# Nuit ou pluie : chacun rentre chez soi (ou se réchauffe près d'un feu).
		if night or (wet and door != Vector3.INF):
			if c.site_id != "":
				c.release()
			if c.state == Creature.State.HOME or (c.state == Creature.State.GO and c.activity == "home"):
				continue
			if door != Vector3.INF:
				c.go(door, "home", 0.0)
				continue
			var fire := _nearest_place(places, c.global_position, ["fire"])
			if not fire.is_empty() and c.is_free():
				var a := _rng.randf() * TAU
				c.go(fire["pos"] + Vector3(cos(a), 0, sin(a)) * 1.8, "sit", 30.0, fire["pos"])
			continue
		# Le matin, on sort de chez soi.
		if c.state == Creature.State.HOME:
			if door != Vector3.INF and _rng.randf() < 0.35:
				c.leave_home(door)
			elif door == Vector3.INF:
				c.leave_home(c.global_position)
			continue
		if not c.is_free() or c.idle_time < _rng.randf_range(5.0, 12.0):
			continue
		# Journée : discuter avec un voisin, aller à son lieu préféré, à la place...
		var r := _rng.randf()
		if r < 0.25:
			var other: Creature = null
			for o: Creature in crs:
				if o != c and o.is_free() and o.global_position.distance_to(c.global_position) < 25.0:
					other = o
					break
			if other:
				var mid := (c.global_position + other.global_position) * 0.5
				var off := (c.global_position - other.global_position).normalized() * 0.8
				c.go(mid + off, "chat", 5.0, mid)
				other.go(mid - off, "chat", 5.0, mid)
				get_tree().create_timer(2.5).timeout.connect(func():
					if is_instance_valid(other):
						other.chatter())
				continue
		var hab: String = c.data.get("habitat", "village")
		var wanted: Array = FAVORITE.get(hab, ["plaza"])
		if hour >= 12.0 and hour < 14.0 or hour >= 18.0:
			wanted = ["plaza", "fire", "bench"]  # midi et soirée : on se retrouve
		var spot := _activity_spot(places, c, wanted)
		if spot.is_empty():
			continue
		c.go(spot["pos"], spot["act"], _rng.randf_range(8.0, 20.0), spot.get("face", Vector3.INF))


func _nearest_place(places: Array, from: Vector3, tags: Array) -> Dictionary:
	var best := {}
	var best_d := INF
	for p in places:
		if not p["tag"] in tags:
			continue
		var d := from.distance_to(p["pos"])
		if d < best_d:
			best_d = d
			best = p
	return best


## Endroit où faire une activité : lieux posés par le joueur, nature, plage, hauteurs.
func _activity_spot(places: Array, c: Creature, tags: Array) -> Dictionary:
	for tag in tags:
		match tag:
			"beach":
				if not _beach_spots.is_empty():
					var b: Vector3 = _beach_spots.pick_random()
					return {"pos": b, "act": "idle", "face": b + Vector3(0, 0, 5)}
			"nature":
				var trees := []
				for id in props.items:
					if Props.is_tree(props.kind_of(id)) and (props.items[id]["pos"] as Vector3).distance_to(c.global_position) < 40.0:
						trees.append(props.items[id]["pos"])
				if not trees.is_empty():
					var t: Vector3 = trees.pick_random()
					return {"pos": t + Vector3(1.6, 0, 1.2), "act": "pickup" if _rng.randf() < 0.5 else "idle", "face": t}
			"mountain":
				pass
			_:
				var cands := []
				for p in places:
					if p["tag"] == tag:
						cands.append(p)
				if not cands.is_empty():
					var p: Dictionary = cands.pick_random()
					var a := _rng.randf() * TAU
					var act := {"bench": "sit", "fire": "sit", "garden": "pickup", "work": "pickup", "plaza": "idle"}.get(tag, "idle") as String
					var dist := 0.9 if tag == "bench" else 2.0
					return {"pos": (p["pos"] as Vector3) + Vector3(cos(a), 0, sin(a)) * dist, "act": act, "face": p["pos"]}
	# Sinon une petite balade.
	var a2 := _rng.randf() * TAU
	return {"pos": c.global_position + Vector3(cos(a2), 0, sin(a2)) * _rng.randf_range(4.0, 10.0), "act": "idle"}


## Une maison terminée accueille un habitant sans logement (celui dont
## l'environnement préféré est le plus proche).
func _auto_home(house_key: String, pos: Vector3) -> void:
	var best := ""
	var best_score := -INF
	for id in Game.residents:
		if (Game.residents[id] as Dictionary).get("island", "") != Game.current_island or Game.home_of(id) != "":
			continue
		var hab: String = ResidentDB.get_resident(id).get("habitat", "")
		var score := 0.0
		match hab:
			"marine":
				for b in _beach_spots:
					score = maxf(score, 40.0 - b.distance_to(pos))
			"forest":
				score = 10.0 if props.any_near(pos, 12.0, true) else 0.0
			_:
				score = 5.0
		score += _rng.randf()
		if score > best_score:
			best_score = score
			best = id
	if best != "":
		Game.set_home(house_key, best)
		hud.toast("%s s'installe dans cette maison !" % ResidentDB.get_resident(best)["name"], UIStyle.GREEN_DARK)


## Choix de l'occupant d'une maison (touche G devant la porte).
func choose_resident(house_id: int) -> void:
	var key := props.key_of(house_id)
	var options := [{"id": "", "label": "Personne"}, {"id": "player", "label": "Moi (%s)" % (Game.player_name if Game.player_name != "" else "joueur")}]
	for id in Game.residents:
		if (Game.residents[id] as Dictionary).get("island", "") != Game.current_island:
			continue
		var cur := Game.home_of(id)
		var where := "" if cur == "" else (" — habite déjà ailleurs" if cur != key else " — habite ici")
		options.append({"id": id, "label": ResidentDB.get_resident(id)["name"] + where})
	hud.show_choice("Qui habite ici ?", options, func(owner: String):
		var before := Game.home_of(owner) if owner != "" else ""
		Game.set_home(key, owner)
		if owner != "" and owner != "player":
			var d := Friendship.data(owner)
			d["seen_furn"] = []
			for e in Game.interiors.get(key, []):
				(d["seen_furn"] as Array).append(e["f"])
			if before != "" and before != key:
				d["moved"] = true
				hud.toast("%s a déménagé !" % ResidentDB.get_resident(owner)["name"], UIStyle.GREEN_DARK)
			else:
				hud.toast("%s s'installe ici !" % ResidentDB.get_resident(owner)["name"], UIStyle.GREEN_DARK))


# --- Maisons : intérieurs instanciés ------------------------------------

func enter_house(id: int) -> void:
	if _loading or interior:
		return
	_loading = true
	var kind := props.kind_of(id)
	var key := props.key_of(id)
	_outside_pos = props.door_position(id)
	await hud.fade(true, 0.35)
	interior = Interior.new()
	interior.setup(kind, key)
	add_child(interior)
	structure = ""
	hud.set_block(block)
	# L'habitant est chez lui ? On le retrouve à l'intérieur.
	var owner: String = Game.homes.get(key, "")
	for n in creatures_root.get_children():
		var c := n as Creature
		if c and c.data["id"] == owner and c.state == Creature.State.HOME:
			# Il profite de ses meubles : canapé, table, cuisine, lit...
			var spot := interior.occupant_spot(Game.time)
			var guest := Creature.new()
			guest.setup(c.data, world, interior.to_local(spot["pos"]))
			interior.add_child(guest)
			guest.state = Creature.State.ACT
			guest.activity = spot["act"]
			guest._timer = 1.0e9
			var fd: Vector3 = spot["face"] - spot["pos"]
			guest._facing = atan2(fd.x, fd.z)
	if owner != "":
		hud.toast("Chez moi" if owner == "player" else "Chez %s" % ResidentDB.get_resident(owner).get("name", ""), UIStyle.TEXT_SOFT)
	_set_outside_visible(false)
	sky.indoor = true
	player.teleport(interior.to_global(interior.spawn))
	player.face_towards(interior.to_global(interior.spawn) - Vector3(0, 0, 3))
	rig.world = null
	rig.yaw = 0.0
	rig.pitch = -0.85
	rig.distance = 8.0
	rig.snap()
	Audio.play("open", -4.0)
	await get_tree().process_frame
	await hud.fade(false, 0.35)
	_loading = false


func exit_house() -> void:
	if _loading or interior == null:
		return
	_loading = true
	await hud.fade(true, 0.35)
	interior.queue_free()
	interior = null
	structure = ""
	hud.set_block(block)
	_set_outside_visible(true)
	sky.indoor = false
	player.teleport(_outside_pos + Vector3(0, 0.2, 0))
	rig.world = world
	rig.distance = 6.0
	rig.pitch = -0.3
	rig.snap()
	Audio.play("close", -4.0)
	await get_tree().process_frame
	await hud.fade(false, 0.35)
	_loading = false


## Dedans, on cache l'île (et son ciel) pour ne voir que la pièce.
func _set_outside_visible(v: bool) -> void:
	for n in [world, props, worksites, creatures_root, animals_root, pickups_root, _clouds, camp_props, get_node_or_null("Ocean")]:
		if n:
			n.visible = v
	_env.background_mode = Environment.BG_SKY if v else Environment.BG_COLOR
	_env.background_color = Color("2b2420")
	_env.fog_enabled = v


# --- Animaux sauvages ----------------------------------------------------

## Fait apparaître les animaux selon l'environnement. `announce` : bannière
## pour chaque nouvelle espèce (le matin).
func _spawn_animals(announce: bool) -> void:
	for c in animals_root.get_children():
		c.queue_free()
	var pop := Fauna.population(Game.current_island)
	var fresh := []
	for sp in pop:
		for i in int(pop[sp]):
			var pos := _animal_spot(Fauna.SPECIES[sp]["habitat"])
			if pos == Vector3.INF:
				continue
			var a := Animal.new()
			a.setup(sp, world, pos)
			animals_root.add_child(a)
		if not Game.species_seen.has(sp):
			Game.species_seen[sp] = true
			fresh.append(sp)
	if announce:
		for sp in fresh:
			hud.show_item_popup("Un %s est apparu !" % Fauna.name_of(sp).to_lower(), "L'environnement lui plaît.", false)
			Audio.play("jingle_common", -6.0, 0.0)


func _animal_spot(habitat: String) -> Vector3:
	for attempt in 60:
		var c := Vector3.ZERO
		match habitat:
			"forest":
				var trees := []
				for id in props.items:
					if Props.is_tree(props.kind_of(id)):
						trees.append(props.items[id]["pos"])
				if trees.is_empty():
					return Vector3.INF
				c = (trees.pick_random() as Vector3) + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
			"village":
				var built := []
				for id in props.items:
					if props.key_of(id).begins_with("p:"):
						built.append(props.items[id]["pos"])
				var base: Vector3 = built.pick_random() if not built.is_empty() else _spawn
				c = base + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
			_:
				c = Vector3(_rng.randf_range(10, VoxelWorld.SX - 10), 0, _rng.randf_range(10, VoxelWorld.SZ - 10))
		var x := floori(c.x)
		var z := floori(c.z)
		var y := world.top_solid_y(x, z)
		if y <= IslandGenerator.SEA:
			continue
		var b := world.get_block(x, y, z)
		match habitat:
			"marine":
				if b != Blocks.SAND or y > IslandGenerator.SEA + 2:
					continue
			"mountain":
				if y < IslandGenerator.SEA + 12:
					continue
			"garden":
				if b != Blocks.GRASS or not Blocks.is_deco(world.get_block(x, y + 1, z)):
					continue
		if not b in [Blocks.GRASS, Blocks.SAND, Blocks.DIRT, Blocks.SNOW, Blocks.MOSS, Blocks.STONE]:
			continue
		return Vector3(x + 0.5, y + 1.0, z + 0.5)
	return Vector3.INF


# --- Nouvelles zones -----------------------------------------------------

## La montagne de l'Île Prairie est bloquée par un éboulement qui se dégage
## quand l'île devient assez accueillante.
func _check_zones() -> void:
	if Game.current_island != "prairie" or Game.has_flag("zone_mountain"):
		return
	if Vitality.percent("prairie") < IslandGenerator.MOUNTAIN_UNLOCK:
		return
	Game.set_flag("zone_mountain")
	for id in props.items.keys():
		if props.key_of(id).begins_with("g:z:"):
			_burst(props.bounds(id).get_center(), Color("a7adb5"), 10)
			props.remove(id)
	Audio.play("break_stone", 0.0, 0.0, 0.7)
	hud.show_item_popup("La montagne est accessible !", "L'éboulement s'est dégagé.", false)
	Game.save_game()


## Aménager les hauteurs développe l'habitat « montagne ».
func _count_altitude(y: int) -> void:
	if y >= IslandGenerator.SEA + 12:
		Game.add_stat("mountain")


func _do_place() -> bool:
	var p: Vector3i = target["pos"]
	if not Blocks.is_deco(int(target["block"])):
		p += target["normal"] as Vector3i
	if not VoxelWorld.in_bounds(p.x, p.y, p.z) or p.y >= VoxelWorld.SY - 1:
		return false
	var cur := world.get_blockv(p)
	if cur != Blocks.AIR and not Blocks.is_deco(cur):
		return false
	if _overlaps_entity(p):
		_deny("Pas de place ici !")
		return false
	# On ne pose que les blocs qu'on possède (cassés ou fabriqués).
	if not Game.admin and Game.block_count(block) <= 0:
		_deny("")
		return false
	if props.any_near(Vector3(p) + Vector3(0.5, 0, 0.5), 0.6):
		_deny("Pas de place ici !")
		return false
	world.set_block(p, block)
	world.flush()
	props.resnap_near(Vector3(p) + Vector3(0.5, 0, 0.5), 3.0)
	nav.refresh_area(Vector3(p), 1.5)
	_burst(Vector3(p) + Vector3(0.5, 0.5, 0.5), Blocks.main_color(block), 8)
	Audio.play("place_wood" if material_sound(block) == "wood" else "place", -2.0)
	if not Game.admin:
		Game.add_block(block, -1)
	_count_altitude(p.y)
	Game.add_stat("place")
	Game.add_stat("place_%d" % block)
	Game.notify_action("place")
	hud.set_block(block)
	return true


func _do_bloom() -> bool:
	var c: Vector3i = target["pos"]
	if Blocks.is_deco(int(target["block"])):
		c.y -= 1
	var biome: String = IslandDB.get_island(Game.current_island)["biome"]
	var flowers: Array = IslandGenerator.FLOWER_SETS[biome]
	var chance := 1.0 if Game.tutorial_step == 5 else 0.75
	var count := 0
	var converted := 0
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if dx * dx + dz * dz > 5:
				continue
			var x := c.x + dx
			var z := c.z + dz
			var y := -1
			for yy in range(c.y + 2, c.y - 3, -1):
				if world.is_opaque(x, yy, z) and not world.is_opaque(x, yy + 1, z):
					y = yy
					break
			if y < 0 or y + 1 >= VoxelWorld.SY:
				continue
			var g := world.get_block(x, y, z)
			if g == Blocks.DIRT or g == Blocks.SNOW:
				world.set_block(Vector3i(x, y, z), Blocks.GRASS)
				g = Blocks.GRASS
				converted += 1
			if g == Blocks.GRASS or g == Blocks.SAND or g == Blocks.MOSS:
				var above := world.get_block(x, y + 1, z)
				if (above == Blocks.AIR or above == Blocks.TALL_GRASS) and _rng.randf() < chance:
					var f: int = flowers.pick_random()
					world.set_block(Vector3i(x, y + 1, z), f)
					count += 1
					_burst(Vector3(x + 0.5, y + 1.3, z + 0.5), Blocks.main_color(f), 4)
	if count == 0 and converted == 0:
		_deny("Il n'y a rien à faire fleurir ici.")
		return false
	world.flush()
	_burst(Vector3(c) + Vector3(0.5, 1.5, 0.5), Color("ffffff"), 10)
	Audio.play("bloom", -3.0, 0.15)
	_count_altitude(c.y)
	if count > 0:
		Game.add_stat("bloom", count)
	Game.notify_action("bloom")
	return true


func _do_tree() -> bool:
	var g: Vector3i = target["pos"]
	var gb: int = target["block"]
	if Blocks.is_deco(gb):
		g.y -= 1
		gb = world.get_blockv(g)
	if not gb in [Blocks.GRASS, Blocks.DIRT, Blocks.SAND, Blocks.SNOW, Blocks.MOSS]:
		_deny("Les arbres poussent sur l'herbe, la terre, le sable ou la neige.")
		return false
	var base := g + Vector3i.UP
	var bc := Vector3(base) + Vector3(0.5, 0, 0.5)
	if Vector2(bc.x - player.global_position.x, bc.z - player.global_position.z).length() < 1.2 and absf(bc.y - player.global_position.y) < 3.0:
		_deny("Recule un peu pour laisser pousser l'arbre !")
		return false
	if props.any_near(bc, 2.0) or world.is_opaque(base.x, base.y, base.z) or world.is_opaque(base.x, base.y + 1, base.z):
		_deny("Pas assez de place pour un arbre.")
		return false
	if Blocks.is_deco(world.get_blockv(base)):
		world.set_block(base, Blocks.AIR)
		world.flush()
	var biome: String = IslandDB.get_island(Game.current_island)["biome"]
	var kinds: Array = Props.TREES[biome]
	props.add_persistent(kinds[_rng.randi() % kinds.size()], bc, _rng.randf() * TAU, _rng.randf_range(0.9, 1.15), true, {"planted": Game.day})
	_burst(bc + Vector3(0, 3.5, 0), Color("6cbf4a"), 22)
	Audio.play("tree", -4.0)
	Audio.play("place_wood", -4.0, 0.1, 0.8)
	_burst(bc + Vector3(0, 0.5, 0), Color("c99d6c"), 10)
	_count_altitude(g.y)
	Game.add_stat("tree")
	Game.notify_action("tree")
	return true


## Couper un arbre ou retirer un feu / un potager posé.
func _do_cut_prop() -> bool:
	var id: int = target["prop"]
	var kind := props.kind_of(id)
	var def: Dictionary = Props.KINDS.get(kind, {})
	var mine := props.key_of(id).begins_with("p:")
	if worksites.is_targeted(props.key_of(id)):
		_deny("")
		return false
	# Grosses choses (maison, ruines) : ce sont les habitants qui démolissent.
	if (Props.is_site(kind) and mine) or def.has("demolish"):
		var group := _demolish_group(id)
		worksites.add_demolish(group)
		Audio.play("break_stone", -6.0, 0.05, 0.8)
		if Vitality.residents(Game.current_island) == 0:
			_think("chantier_seul")
		Game.save_game()
		return true
	if Props.is_structure(kind) and mine:
		# Une construction posée par le joueur retourne dans l'inventaire.
		var ab0 := props.bounds(id)
		props.remove(id)
		Game.add_structure(kind)
		_burst(ab0.get_center(), Color("c99d6c"), 14)
		Audio.play("place_wood", -2.0, 0.1, 1.2)
		hud.set_block(block)
		return true
	if not def.get("cut", false):
		_deny("Mieux vaut laisser ça où c'est.")
		return false
	var ab := props.bounds(id)
	props.remove(id)
	if Props.is_tree(kind):
		_burst(ab.get_center() + Vector3(0, ab.size.y * 0.2, 0), Color("6cbf4a"), 24)
		_burst(ab.position + Vector3(ab.size.x * 0.5, 0.5, ab.size.z * 0.5), Color("c99d6c"), 12)
		Audio.play("break_wood", -2.0, 0.1, 0.8)
		Game.add_item("branch", 2 if ab.size.y > 3.0 else 1)
		Game.add_stat("cut_tree")
	else:
		_burst(ab.get_center(), Color("c99d6c"), 12)
		Audio.play("break_wood", -2.0, 0.1, 1.1)
	Game.add_stat("break")
	Game.notify_action("break")
	return true


## Action impossible : pas de texte à l'écran, juste un petit son.
func _deny(_msg: String) -> void:
	Audio.play("error", -6.0)


static func material_sound(b: int) -> String:
	if b in [Blocks.WOOD, Blocks.PLANK, Blocks.PALM_WOOD]:
		return "wood"
	if b in [Blocks.STONE, Blocks.BRICK, Blocks.BASALT, Blocks.MOSS, Blocks.ICE, Blocks.CLAY]:
		return "stone"
	return "soft"


func _overlaps_entity(p: Vector3i) -> bool:
	var cell := AABB(Vector3(p), Vector3.ONE)
	var pp := player.global_position
	if cell.intersects(AABB(pp - Vector3(0.3, 0, 0.3), Vector3(0.6, 1.3, 0.6))):
		return true
	for n in creatures_root.get_children():
		var c := n as Node3D
		if cell.intersects(AABB(c.global_position - Vector3(0.3, 0, 0.3), Vector3(0.6, 0.9, 0.6))):
			return true
	return false


func _burst(pos: Vector3, col: Color, amount: int) -> void:
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
