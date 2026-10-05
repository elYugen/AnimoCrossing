class_name Thumbs
extends Node
## Miniatures 3D des constructions (affichées en petit dans l'inventaire) :
## chaque modèle est rendu une fois dans un SubViewport, puis figé.

const SIZE := 128

static var _inst: Thumbs
static var _cache := {}


## Texture de la miniature d'un type d'objet Props.
static func of(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	if _inst == null:
		_inst = Thumbs.new()
		_inst.name = "Thumbs"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_inst.add_child(vp)
	var size: Vector3
	var center: Vector3
	if kind.begins_with("f_"):
		# Meuble (Furniture Kit) : modèle centré.
		var fname := kind.trim_prefix("f_")
		vp.add_child(Interior.make_furn_model(fname))
		size = Interior.furn_aabb(fname).size * Interior.SCALE
		center = Vector3(0, size.y * 0.5, 0)
	else:
		var model := Props.make_model(kind, 1.0)
		vp.add_child(model)
		var ab := Props.local_aabb(kind)
		var s := float(Props.KINDS[kind]["scale"])
		size = ab.size * s
		center = (ab.position + ab.size * 0.5) * s
	var r := maxf(size.length() * 0.5, 0.3)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var dir := Vector3(1.0, 0.8, 1.3).normalized()
	cam.look_at_from_position(center + dir * r / sin(deg_to_rad(15.0)) * 1.05, center)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	vp.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff4e6")
	e.ambient_light_energy = 0.7
	env.environment = e
	vp.add_child(env)
	var tex := vp.get_texture()
	_cache[kind] = tex
	# Après quelques images, on fige le rendu pour ne plus le recalculer.
	(Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout.connect(func():
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	return tex
