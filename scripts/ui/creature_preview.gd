class_name CreaturePreview
extends SubViewportContainer
## Aperçu 3D tournant d'une créature (carnet, gacha).

var _viewport: SubViewport
var _holder: Node3D
var _silhouette := false
var spin_speed := 0.8


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.75, 2.6)
	cam.fov = 38
	_viewport.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.55, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	light.light_energy = 0.8
	_viewport.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff4e6")
	e.ambient_light_energy = 0.45
	env.environment = e
	_viewport.add_child(env)
	_holder = Node3D.new()
	_viewport.add_child(_holder)


func set_creature(look: Dictionary, silhouette := false) -> void:
	for c in _holder.get_children():
		c.queue_free()
	_silhouette = silhouette
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6e5f52")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if look.has("skin"):
		# Habitant humain : même modèle que le joueur.
		var h := Player.build_model(look["skin"], look.get("head", ""))
		_holder.add_child(h)
		h.scale *= 0.85
		var ap := h.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("idle"):
			ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			ap.play("idle")
		if silhouette:
			for mi in h.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = mat
	else:
		var m := VoxelModel.build(look)
		if silhouette:
			m.material_override = mat
		_holder.add_child(m)
	_holder.rotation.y = 0.5


func clear() -> void:
	for c in _holder.get_children():
		c.queue_free()


func _process(delta: float) -> void:
	_holder.rotation.y += delta * spin_speed
