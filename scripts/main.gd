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
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _ocean_mat: ShaderMaterial
var _clouds: Node3D
var _highlight: MeshInstance3D
var _highlight_mat: StandardMaterial3D
var _outline: MeshInstance3D

var power := 0
var block := Blocks.GRASS
var target := {}
var _rotating := false
var _rotate_anchor := Vector2.ZERO
var _loading := false
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
	_setup_bounds()
	creatures_root = Node3D.new()
	creatures_root.name = "Creatures"
	add_child(creatures_root)

	player = Player.new()
	player.name = "Player"
	player.world = world
	add_child(player)
	rig = CameraRig.new()
	rig.name = "CameraRig"
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
	Game.friend_unlocked.connect(_on_friend_unlocked)

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
	rig.distance = 34.0
	rig.pitch = -0.62
	rig.snap()


func _start_game(new_game: bool) -> void:
	if _loading:
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
	rig.distance = 10.0
	rig.pitch = -0.72
	rig.yaw = 0.0
	rig.snap()
	await get_tree().process_frame
	await hud.fade(false, 0.5)
	_loading = false


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
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sun_angle_max = 20.0
	_sky_mat.sky_curve = 0.12
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
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, 38, 0)
	_sun.light_energy = 1.0
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_max_distance = 80.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(_sun)


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

func _load_island(id: String) -> void:
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
	Audio.play_music(id)
	player.teleport(_spawn)
	rig.yaw = 0.0
	rig.snap()
	_spawn_creatures()


func _apply_look(isl: Dictionary) -> void:
	var top: Color = isl["sky_top"]
	var hor: Color = isl["sky_horizon"]
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = hor
	_sky_mat.ground_horizon_color = hor
	_sky_mat.ground_bottom_color = (isl["water_deep"] as Color).darkened(0.2)
	_sun.light_color = isl["sun"]
	_env.fog_light_color = isl["fog"]
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
	if Game.current_island == "prairie":
		var gp := Vector3(IslandGenerator.SPAWN.x + 6.5, 0, IslandGenerator.SPAWN.y - 3.5)
		gp.y = world.top_solid_y(floori(gp.x), floori(gp.z)) + 1.0
		var guide := _make_creature(CreatureDB.GUIDE, gp)
		guide.home = gp
	for id in Game.friends:
		var info: Dictionary = Game.friends[id]
		if info.get("island", "") == Game.current_island:
			_make_creature(CreatureDB.get_creature(id), _find_spot(_spawn, 18.0))


func _make_creature(d: Dictionary, pos: Vector3) -> Creature:
	var c := Creature.new()
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


func _on_friend_unlocked(id: String) -> void:
	var c := CreatureDB.get_creature(id)
	var info: Dictionary = Game.friends.get(id, {})
	if info.get("island", "") == Game.current_island:
		var pos := _find_spot(player.global_position, 4.0)
		var cr := _make_creature(c, pos)
		cr.celebrate()
		_burst(pos + Vector3(0, 0.6, 0), Color("ffd84a"), 24)
		_burst(pos + Vector3(0, 0.6, 0), Color("f7a3c8"), 16)
	if c["island"] != "":
		Audio.play("jingle_friend", -4.0, 0.0)
		hud.show_friend_popup(id)
		hud.toast("%s s'installe sur l'île !" % c["name"], UIStyle.GREEN_DARK)
		# Nouvelle île débloquée ?
		for isl in IslandDB.ISLANDS:
			if int(isl["friends_needed"]) == Game.friend_count() and int(isl["friends_needed"]) > 0:
				hud.toast("Nouvelle île débloquée : %s ! (Carte : M)" % isl["name"], UIStyle.BLUE.darkened(0.2))
				get_tree().create_timer(2.5).timeout.connect(func(): Audio.play("jingle_island", -4.0, 0.0))


# --- Boucle --------------------------------------------------------------

func _process(delta: float) -> void:
	_cooldown -= delta
	for cl in _clouds.get_children():
		var n := cl as Node3D
		n.position.x += delta * 1.2
		if n.position.x > VoxelWorld.SX + 100.0:
			n.position.x = -100.0
	if _in_title:
		rig.yaw += delta * 0.07
		player.input_enabled = false
		rig.input_enabled = false
		_highlight.visible = false
		_outline.visible = false
		world.focus = player.global_position
		world.set_view(Vector3(0, -1000, 0), Vector3.ZERO)
		return
	var blocking := hud.is_blocking() or _loading
	player.input_enabled = not blocking
	rig.input_enabled = not blocking
	world.set_view(player.global_position, rig.camera.global_position)
	world.focus = player.global_position
	_update_creature_labels()
	if blocking:
		_highlight.visible = false
		_outline.visible = false
		return
	_update_target()


func _update_target() -> void:
	target = {}
	var mp := get_viewport().get_mouse_position()
	var cam := rig.camera
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	var hit := world.raycast(from, dir, 80.0, _is_cut)
	if hit["hit"]:
		var center := Vector3(hit["pos"]) + Vector3(0.5, 0.5, 0.5)
		if center.distance_to(player.global_position + Vector3(0, 0.7, 0)) <= (ADMIN_REACH if Game.admin else REACH):
			target = hit
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

## Rotation caméra : clic droit ou clic molette maintenu (souris capturée).
func _input(event: InputEvent) -> void:
	if _in_title:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed and not _rotating and not hud.is_blocking() and not _loading:
				_rotating = true
				_rotate_anchor = mb.position
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
			elif not mb.pressed and _rotating:
				_rotating = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				Input.warp_mouse(_rotate_anchor)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _rotating:
		var mm := event as InputEventMouseMotion
		rig.rotate_by(mm.relative.x, mm.relative.y)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _loading or _in_title:
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
	if event.is_action_pressed("gacha"):
		hud.toggle_panel("gacha")
		return
	if event.is_action_pressed("map"):
		hud.toggle_panel("map")
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


func select_block(id: int) -> void:
	block = id
	hud.set_block(id)
	if power != 1 and hud.power_unlocked(1):
		select_power(1)


func _cycle_block(step: int) -> void:
	var list := Game.available_blocks()
	var i := list.find(block)
	block = list[posmod(i + step, list.size())]
	hud.set_block(block)


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
	if best == null:
		return
	best.talk_to(player.global_position)
	player.face_towards(best.global_position)
	player.play_action("talk")
	var id: String = best.data["id"]
	var lines: Array = []
	if id == "guide":
		if Game.tutorial_step < HUD.TUTO_DONE:
			lines = ["Hou hou ! Suis mes conseils dans le panneau à gauche, tu t'en sors très bien !"]
		else:
			lines = [[
				"Chaque créature a ses goûts : regarde le panneau « Amis à attirer » en haut à droite.",
				"Les capsules de la Machine Gacha contiennent des amis venus d'ailleurs !",
				"Avec assez d'amis, tu pourras voyager vers d'autres îles grâce à la Carte.",
				"Hou hou ! Quelle belle île tu as façonnée.",
			].pick_random()]
	else:
		lines = [(best.data["lines"] as Array).pick_random()]
		if not Game.talked.has(id):
			Game.talked[id] = true
			Game.add_stars(5)
			lines.append("(%s a l'air ravi de te voir ! +5 ★)" % best.data["name"])
	hud.show_dialog(best.data["name"], lines)
	Audio.play("talk", -4.0, 0.2, 1.3 if id != "guide" else 0.9)
	Game.notify_action("talk")


# --- Pouvoirs ------------------------------------------------------------

func _use_power() -> void:
	if target.is_empty() or _cooldown > 0.0:
		return
	if not hud.power_unlocked(power):
		_deny("Ce pouvoir n'est pas encore débloqué !")
		return
	_cooldown = 0.16
	var ok := false
	match power:
		0:
			ok = _do_break()
		1:
			ok = _do_place()
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
	Game.add_stars(1)
	Game.add_stat("break")
	Game.notify_action("break")
	return true


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
	world.set_block(p, block)
	world.flush()
	_burst(Vector3(p) + Vector3(0.5, 0.5, 0.5), Blocks.main_color(block), 8)
	Audio.play("place_wood" if material_sound(block) == "wood" else "place", -2.0)
	Game.add_stars(1)
	Game.add_stat("place")
	Game.add_stat("place_%d" % block)
	Game.notify_action("place")
	return true


func _do_bloom() -> bool:
	var c: Vector3i = target["pos"]
	if Blocks.is_deco(int(target["block"])):
		c.y -= 1
	var biome: String = IslandDB.get_island(Game.current_island)["biome"]
	var flowers: Array = IslandGenerator.FLOWER_SETS[biome]
	var chance := 1.0 if Game.tutorial_step == 4 else 0.75
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
	if count > 0:
		Game.add_stars(count)
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
	if Vector2(bc.x - player.global_position.x, bc.z - player.global_position.z).length() < 0.9 and absf(bc.y - player.global_position.y) < 3.0:
		_deny("Recule un peu pour laisser pousser l'arbre !")
		return false
	if Blocks.is_deco(world.get_blockv(base)):
		world.set_block(base, Blocks.AIR)
	var biome: String = IslandDB.get_island(Game.current_island)["biome"]
	var style := IslandGenerator.tree_style(biome, _rng)
	if not IslandGenerator.grow_tree(world, base.x, base.y, base.z, style, _rng, true):
		world.flush()
		_deny("Pas assez de place pour un arbre.")
		return false
	world.flush()
	_burst(bc + Vector3(0, 3.5, 0), Color("6cbf4a"), 22)
	Audio.play("tree", -4.0)
	Audio.play("place_wood", -4.0, 0.1, 0.8)
	_burst(bc + Vector3(0, 0.5, 0), Color("c99d6c"), 10)
	Game.add_stars(5)
	Game.add_stat("tree")
	Game.notify_action("tree")
	return true


func _deny(msg: String) -> void:
	hud.toast(msg, UIStyle.TEXT_SOFT)
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
