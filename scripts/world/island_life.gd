class_name IslandLife
extends Node3D
## La vitalité se voit et s'entend : plus l'île est accueillante, plus elle
## vit, sans chiffre ni objectif à atteindre.
##   palier 0 (< 20 %)  île silencieuse : vent et vagues seulement
##   palier 1 (20 %)    quelques oiseaux chantent, lucioles la nuit
##   palier 2 (40 %)    papillons sur les fleurs (Wildlife), plus de chants
##   palier 3 (60 %)    des vols d'oiseaux traversent le ciel
##   palier 4-5 (80 %+) l'île chante du matin au soir, les grillons la nuit
## Les habitants en parlent aussi (ResidentTalk), se retrouvent plus souvent
## (Moments, ResidentAI), et les fleurs sauvages repoussent plus vite (DayCycle).
## Le point d'eau de la Prairie suit la même renaissance : eau terne, puis
## claire, puis nénuphars, libellules et grenouilles.

## Couleur de l'eau du point d'eau selon le palier.
const POND_COLORS := [Color(0.36, 0.4, 0.28, 0.88), Color(0.32, 0.5, 0.44, 0.78), Color(0.33, 0.66, 0.78, 0.6)]

## Intensité des chants d'oiseaux et des grillons selon le palier.
const SONG := [0.0, 0.3, 0.5, 0.7, 0.9, 1.0]
## Ce qui change quand l'île passe un palier (annoncé une fois).
const NEWS := [
	"",
	"Des oiseaux chantent au loin, les fleurs reviennent.",
	"Des papillons dansent au-dessus des fleurs.",
	"Des oiseaux traversent le ciel. L'île est pleine de vie.",
	"On entend la vie partout. Les habitants sont heureux ici.",
	"Rien ne manque... mais il reste toujours des choses à découvrir.",
]

var main: Main
## Palier de vie de l'île courante (Vitality.tier_index).
var tier := 0
var _timer := 0.0
var _flock_wait := 20.0
var _fireflies: CPUParticles3D
var _pond: Node3D  # surface de l'eau, nénuphars, libellules
var _pond_water: MeshInstance3D
var _pond_tier := -1
var _pond_free := -1  # cases d'eau libre (sans vase) au dernier décor


func _ready() -> void:
	_fireflies = _make_fireflies()
	add_child(_fireflies)


func refresh() -> void:
	tier = Vitality.tier_index(Vitality.percent(Game.current_island))
	_update_pond()


## Le point d'eau (Prairie) : sa surface change avec la vie de l'île.
func _update_pond() -> void:
	var p := IslandGenerator.pond
	if Game.current_island != "prairie" or p == Vector3.ZERO:
		if _pond:
			_pond.queue_free()
			_pond = null
		return
	if _pond == null:
		_pond = Node3D.new()
		add_child(_pond)
		_pond.global_position = p
		_pond_water = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.0
		cyl.bottom_radius = 1.0
		cyl.height = 0.02
		cyl.radial_segments = 28
		_pond_water.mesh = cyl
		_pond_water.scale = Vector3(5.6, 1, 4.4)
		_pond_water.position.y = 0.04
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.2
		mat.metallic_specular = 0.6
		_pond_water.material_override = mat
		_pond_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pond.add_child(_pond_water)
		_pond_tier = -1
	var level := clampi(tier, 0, 2)
	# Cases d'eau libre : les nénuphars ne poussent pas sur la vase.
	var free_cells: Array[Vector2i] = []
	for dz in range(-4, 5):
		for dx in range(-5, 6):
			var x := floori(p.x) + dx
			var z := floori(p.z) + dz
			if Vector2(dx / 5.0, dz / 4.0).length() <= 1.0 and main.world.top_solid_y(x, z) < IslandGenerator.SEA 					and main.world.get_block(x, IslandGenerator.SEA, z) == Blocks.AIR:
				free_cells.append(Vector2i(dx, dz))
	if level == _pond_tier and free_cells.size() == _pond_free:
		return
	var first := _pond_tier < 0
	var changed := level != _pond_tier
	_pond_tier = level
	_pond_free = free_cells.size()
	var mat2 := _pond_water.material_override as StandardMaterial3D
	if first:
		mat2.albedo_color = POND_COLORS[level]
	elif changed:
		create_tween().tween_property(mat2, "albedo_color", POND_COLORS[level], 4.0)
	# Nénuphars (île qui reprend des couleurs) et libellules (île pleine de vie).
	for c in _pond.get_children():
		if c != _pond_water:
			c.queue_free()
	if level >= 2 and not free_cells.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var cells := free_cells.duplicate()
		for i in mini(5, cells.size()):
			var cell: Vector2i = cells.pop_at(rng.randi() % cells.size())
			var lily := Props.make_model("lily", rng.randf_range(0.8, 1.1))
			var cx := floorf(p.x) + cell.x + 0.5 - p.x
			var cz := floorf(p.z) + cell.y + 0.5 - p.z
			lily.position = Vector3(cx, 0.06, cz)
			lily.rotation.y = rng.randf() * TAU
			_pond.add_child(lily)
	if tier >= 3:
		_pond.add_child(_dragonflies())


func _dragonflies() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 6
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.position.y = 0.8
	var m := QuadMesh.new()
	m.size = Vector2(0.18, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color("3aa3d8")
	m.material = mat
	p.mesh = m
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(4.0, 0.4, 3.0)
	p.gravity = Vector3.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.4
	p.tangential_accel_min = -2.0
	p.tangential_accel_max = 2.0
	return p


## Le joueur revient au point d'eau devenu clair : il le remarque (une fois).
func _check_pond_visit() -> void:
	var p := IslandGenerator.pond
	if _pond_tier < 2 or p == Vector3.ZERO or Game.has_flag("pond_clear") or not Game.has_flag("water"):
		return
	if main.busy or main.hud.dialog_open():
		return
	var pp := main.player.global_position
	if Vector2(p.x - pp.x, p.z - pp.z).length() < 6.0:
		Game.set_flag("pond_clear")
		main.story.think("eau_claire")


func _process(delta: float) -> void:
	if main == null or main.in_title:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 2.0
		refresh()
		_update_sounds()
		_check_pond_visit()
	_update_fireflies()
	_flock_wait -= delta
	if _flock_wait <= 0.0:
		_flock_wait = randf_range(30.0, 70.0) if tier >= 4 else randf_range(60.0, 120.0)
		if tier >= 3 and _fair_day() and main.interior == null:
			_spawn_flock()


func _fair_day() -> bool:
	return not main.sky.is_night() and not Game.weather in ["rain", "storm", "fog"]


func _update_sounds() -> void:
	var amb := main.ambience
	var level: float = SONG[tier]
	var day := not main.sky.is_night()
	var bad := Game.weather in ["rain", "storm"]
	var target_birds := level * (1.0 if day and not bad else 0.0) * (0.4 if Game.weather in ["fog", "snow"] else 1.0)
	var target_crickets := level * (1.0 if not day and not bad and Game.weather != "snow" else 0.0)
	if main.interior != null:
		target_birds *= 0.2
		target_crickets *= 0.2
	# Grenouilles : près du point d'eau, la nuit ou sous la pluie, si l'île vit.
	var target_frogs := 0.0
	var pond := IslandGenerator.pond
	if tier >= 2 and pond != Vector3.ZERO and Game.current_island == "prairie" and main.interior == null:
		var d := Vector2(pond.x, pond.z).distance_to(Vector2(main.player.global_position.x, main.player.global_position.z))
		if (not day or Game.weather == "rain") and d < 30.0:
			target_frogs = clampf(1.0 - d / 30.0, 0.0, 1.0) * (0.6 + 0.1 * tier)
	# Rumeur du village : quand plusieurs habitants sont tout près.
	var near := 0
	for r in main.residents.all():
		if r.visible and r.global_position.distance_to(main.player.global_position) < 18.0:
			near += 1
	var target_village := clampf((near - 1) / 4.0, 0.0, 1.0) if day and main.interior == null else 0.0
	var tw := amb.create_tween().set_parallel(true)
	tw.tween_property(amb, "birds", target_birds, 2.0)
	tw.tween_property(amb, "crickets", target_crickets, 2.0)
	tw.tween_property(amb, "frogs", target_frogs, 2.0)
	tw.tween_property(amb, "village", target_village, 2.0)


# --- Lucioles ----------------------------------------------------------------

func _make_fireflies() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 40
	p.lifetime = 4.0
	p.local_coords = false
	var m := QuadMesh.new()
	m.size = Vector2(0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(2.6, 2.4, 0.9)  # assez lumineux pour briller (glow)
	m.material = mat
	p.mesh = m
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(10, 1.2, 10)
	p.gravity = Vector3.ZERO
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.tangential_accel_min = -0.6
	p.tangential_accel_max = 0.6
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 0.6, 0), Color(1, 1, 0.6, 1), Color(1, 1, 0.6, 1), Color(1, 1, 0.6, 0)])
	p.color_ramp = fade
	return p


## La nuit (et par temps sec), des lucioles autour du joueur ; d'autant plus
## nombreuses que l'île est vivante.
func _update_fireflies() -> void:
	var want := tier >= 1 and main.sky.is_night() and not Game.weather in ["rain", "storm", "snow"] and main.interior == null
	if want:
		_fireflies.global_position = main.player.global_position + Vector3(0, 0.8, 0)
		var n := 16 + tier * 12
		if _fireflies.amount != n:
			_fireflies.amount = n  # (changer le nombre relance l'émission)
	if _fireflies.emitting != want:
		_fireflies.emitting = want


# --- Vols d'oiseaux ----------------------------------------------------------

## Un petit vol d'oiseaux traverse le ciel au-dessus du joueur.
func _spawn_flock() -> void:
	var flock := Node3D.new()
	add_child(flock)
	var center := main.player.global_position
	var dir := Vector3(cos(randf() * TAU), 0, sin(randf() * TAU))
	var start := center - dir * 90.0 + Vector3(0, randf_range(26.0, 36.0), 0)
	flock.global_position = start
	flock.look_at(start + dir, Vector3.UP)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3d3a44")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var count := randi_range(3, 7)
	for i in count:
		var bird := _make_bird(mat)
		# En V : chaque oiseau un peu derrière et sur le côté du précédent.
		var side := 1.0 if i % 2 == 0 else -1.0
		var rank := float((i + 1) / 2)
		bird.position = Vector3(side * rank * 1.6, randf_range(-0.4, 0.4), rank * 1.8)
		flock.add_child(bird)
	var tw := flock.create_tween()
	tw.tween_property(flock, "global_position", start + dir * 180.0, 180.0 / 9.0)
	tw.tween_callback(flock.queue_free)


func _make_bird(mat: Material) -> Node3D:
	var bird := Node3D.new()
	for s in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.7, 0.22)
		wing.mesh = q
		wing.material_override = mat
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing.position.x = s * 0.35
		wing.rotation.x = -PI * 0.5
		var pivot := Node3D.new()
		pivot.add_child(wing)
		bird.add_child(pivot)
		# Battements d'ailes.
		var tw := pivot.create_tween().set_loops()
		var up: float = s * 0.6
		tw.tween_property(pivot, "rotation:z", up, 0.22).set_trans(Tween.TRANS_SINE).set_delay(randf() * 0.2)
		tw.tween_property(pivot, "rotation:z", -up * 0.5, 0.22).set_trans(Tween.TRANS_SINE)
	return bird
