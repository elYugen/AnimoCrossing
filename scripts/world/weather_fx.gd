class_name WeatherFX
extends Node3D
## La météo change le monde, pas seulement le ciel :
##   pluie   : des flaques se forment autour du joueur (puis sèchent)
##   orage   : les animaux vont se cacher
##   neige   : on laisse des traces de pas (sur la neige, ou quand il neige)
##   brouillard : rencontre rare, au fond des bois... (le cerf des brumes)
## (Pluie, neige, éclairs et tonnerre eux-mêmes : SkyCycle ; les habitants :
## ResidentAI.)

const MAX_PUDDLES := 28
const MAX_PRINTS := 70

var main: Main
var _puddles: Array[MeshInstance3D] = []
var _puddle_timer := 0.0
var _puddle_mat: StandardMaterial3D
var _prints: Array[MeshInstance3D] = []
var _print_mat: StandardMaterial3D
var _print_mesh: QuadMesh
var _left := false
var _deer: SpiritDeer


func _ready() -> void:
	_puddle_mat = StandardMaterial3D.new()
	_puddle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puddle_mat.albedo_color = Color(0.4, 0.52, 0.66, 0.5)
	_puddle_mat.metallic_specular = 0.6
	_puddle_mat.roughness = 0.15
	_print_mat = StandardMaterial3D.new()
	_print_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_print_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_print_mat.albedo_color = Color(0.55, 0.62, 0.75, 0.45)
	_print_mesh = QuadMesh.new()
	_print_mesh.size = Vector2(0.16, 0.26)
	_print_mesh.orientation = PlaneMesh.FACE_Y
	main.player.stepped.connect(_on_step)


func clear() -> void:
	for p in _puddles:
		p.queue_free()
	_puddles.clear()
	for p in _prints:
		p.queue_free()
	_prints.clear()
	if _deer:
		_deer.queue_free()
		_deer = null


func _process(delta: float) -> void:
	if main.in_title:
		return
	var outside := main.interior == null
	var wet := main.sky.is_wet()
	# Pendant l'orage, les animaux se cachent.
	main.wildlife.visible = outside and Game.weather != "storm"
	_puddle_timer -= delta
	if _puddle_timer <= 0.0:
		_puddle_timer = 1.2
		if wet and outside:
			_add_puddle()
		elif not wet:
			_dry_one()
	_update_deer(delta)


# --- Flaques ------------------------------------------------------------------

func _add_puddle() -> void:
	if _puddles.size() >= MAX_PUDDLES:
		return
	var world := main.world
	var pp := main.player.global_position
	for attempt in 8:
		var a := randf() * TAU
		var r := randf_range(2.0, 16.0)
		var x := floori(pp.x + cos(a) * r)
		var z := floori(pp.z + sin(a) * r)
		var y := world.top_solid_y(x, z)
		if y <= IslandGenerator.SEA or not world.get_block(x, y, z) in [Blocks.GRASS, Blocks.DIRT, Blocks.SAND, Blocks.MOSS]:
			continue
		if Blocks.is_deco(world.get_block(x, y + 1, z)) or main.props.any_near(Vector3(x + 0.5, y + 1, z + 0.5), 1.0):
			continue
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = randf_range(0.35, 0.8)
		cyl.bottom_radius = cyl.top_radius
		cyl.height = 0.02
		cyl.radial_segments = 14
		mi.mesh = cyl
		mi.material_override = _puddle_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = Vector3(x + randf_range(0.3, 0.7), y + 1.012, z + randf_range(0.3, 0.7))
		mi.scale = Vector3(0.05, 1, 0.05)
		mi.create_tween().tween_property(mi, "scale", Vector3(randf_range(0.9, 1.4), 1, randf_range(0.9, 1.4)), 6.0)
		_puddles.append(mi)
		return


## Après la pluie, les flaques sèchent une à une.
func _dry_one() -> void:
	if _puddles.is_empty():
		return
	var mi: MeshInstance3D = _puddles.pop_front()
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.02, 1, 0.02), 8.0)
	tw.tween_callback(mi.queue_free)


# --- Traces de pas -------------------------------------------------------------

func _on_step(pos: Vector3, block: int, facing: float) -> void:
	if main.interior != null or not (block == Blocks.SNOW or Game.weather == "snow"):
		return
	if block in [Blocks.WOOD, Blocks.PLANK, Blocks.STONE, Blocks.BRICK] and Game.weather != "snow":
		return
	_left = not _left
	var mi := MeshInstance3D.new()
	mi.mesh = _print_mesh
	mi.material_override = _print_mat.duplicate()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var side := Vector3(cos(facing), 0, -sin(facing)) * (0.12 if _left else -0.12)
	mi.global_position = Vector3(pos.x, floorf(pos.y) + 0.015, pos.z) + side
	mi.rotation.y = facing
	_prints.append(mi)
	var tw := mi.create_tween()
	tw.tween_interval(14.0)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 8.0)
	tw.tween_callback(func():
		_prints.erase(mi)
		mi.queue_free())
	while _prints.size() > MAX_PRINTS:
		var old: MeshInstance3D = _prints.pop_front()
		old.queue_free()


# --- Le cerf des brumes ----------------------------------------------------------

## Un matin de brouillard, au fond des bois : un craquement, une silhouette
## qui disparaît et réapparaît plus loin... puis le cerf, qui regarde et
## s'efface. Une fois par jour de brouillard au plus.
func _update_deer(_delta: float) -> void:
	var fog := Game.weather == "fog" and not main.sky.is_night() and main.interior == null and not main.cinematic
	if _deer and is_instance_valid(_deer):
		if not fog:
			_deer.vanish()
			_deer = null
		return
	_deer = null
	if not fog or Game.has_flag("fogdeer_day_%d" % Game.day) or main.busy:
		return
	var pp := main.player.global_position
	if not main.props.any_near(pp, 9.0, true):
		return  # il faut être dans les bois
	var spot := _deer_spot(pp, 17.0)
	if spot == Vector3.INF:
		return
	Game.set_flag("fogdeer_day_%d" % Game.day)
	_deer = SpiritDeer.new()
	_deer.fx = self
	add_child(_deer)
	_deer.appear(spot, pp)


## Un endroit au sol, près des arbres, à `dist` du joueur, devant lui.
func _deer_spot(from: Vector3, dist: float) -> Vector3:
	var fwd := -main.rig.camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	for attempt in 12:
		var dir := fwd.rotated(Vector3.UP, randf_range(-0.7, 0.7))
		var p := from + dir * randf_range(dist - 2.0, dist + 3.0)
		var y := main.world.top_solid_y(floori(p.x), floori(p.z))
		if y <= IslandGenerator.SEA:
			continue
		p.y = y + 1.0
		if main.props.any_near(p, 7.0, true) and not main.props.any_near(p, 1.0):
			return p
	return Vector3.INF


## Le cerf a été vu jusqu'au bout. La première fois, on ne sait pas trop ce
## qu'on a vu ; la deuxième, il entre dans le carnet.
func deer_seen() -> void:
	if Game.species_seen.has("spirit_deer"):
		return
	if not Game.has_flag("deer_glimpse"):
		Game.set_flag("deer_glimpse")
		Game.save_game()
		main.story.think("cerf_apercu")
		return
	Game.species_seen["spirit_deer"] = true
	Game.save_game()
	main.hud.show_item_popup("Nouvelle découverte : le cerf des brumes", "Il ne se montre que dans le brouillard... (noté dans ton carnet)", false)
	main.memories.record("deer")
	Audio.play("jingle_rare", -6.0, 0.0)
