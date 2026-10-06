class_name Scenery
extends Node3D
## Décor autour de l'île : ciel (skybox), lumière du soleil, étalonnage des
## couleurs, océan, nuages qui dérivent et murs invisibles en bordure.
## (Le cycle jour / nuit et la météo qui les animent sont dans SkyCycle.)

const WATER_Y := IslandGenerator.SEA + 0.75

var env: Environment
var sky_mat: PanoramaSkyMaterial
var sun: DirectionalLight3D
var _ocean: MeshInstance3D
var _ocean_mat: ShaderMaterial
var _clouds: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_setup_environment()
	_setup_ocean()
	_setup_clouds()
	_setup_bounds()


func _process(delta: float) -> void:
	for cl in _clouds.get_children():
		var n := cl as Node3D
		n.position.x += delta * 1.2
		if n.position.x > VoxelWorld.SX + 100.0:
			n.position.x = -100.0


## Couleurs de l'eau selon l'île (le ciel est réglé par SkyCycle).
func apply_look(isl: Dictionary) -> void:
	var sh: Color = isl["water_shallow"]
	var dp: Color = isl["water_deep"]
	_ocean_mat.set_shader_parameter("shallow_color", Color(sh.r, sh.g, sh.b, 0.55))
	_ocean_mat.set_shader_parameter("deep_color", Color(dp.r, dp.g, dp.b, 0.93))


## Dedans, on cache le décor (et le ciel) pour ne voir que la pièce.
func set_outside_visible(v: bool) -> void:
	_ocean.visible = v
	_clouds.visible = v
	env.background_mode = Environment.BG_SKY if v else Environment.BG_COLOR
	env.background_color = Color("2b2420")
	env.fog_enabled = v


func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	# Ciel : skybox de Kenney (CC0), choisie selon l'île.
	var sky_res := Sky.new()
	sky_mat = PanoramaSkyMaterial.new()
	sky_mat.filter = true
	sky_res.sky_material = sky_mat
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.ambient_light_color = Color("e8e2d6")
	env.ambient_light_sky_contribution = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.8
	# Plafond : avec le MSAA, quelques sous-échantillons aberrants au bord des
	# blocs lointains devenaient de grosses taches blanches une fois étalés
	# par le glow.
	env.glow_hdr_luminance_cap = 2.0
	env.fog_enabled = true
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.06
	we.environment = env
	we.compositor = _make_color_grading()
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


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
	_ocean = mi


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
