class_name Creature
extends Node3D
## Créature amie : se promène tranquillement sur l'île, sautille, et
## discute avec le joueur.

enum State { IDLE, WALK, TALK }

var data: Dictionary
var world: VoxelWorld
var home := Vector3.ZERO
var state := State.IDLE

var _pivot: Node3D
var _model: MeshInstance3D
var _label: Label3D
var _target := Vector3.ZERO
var _timer := 1.0
var _anim := 0.0
var _facing := 0.0
var _speed := 1.3
var _celebrate := 0.0


func setup(d: Dictionary, w: VoxelWorld, pos: Vector3) -> void:
	data = d
	world = w
	position = pos
	home = pos
	_facing = randf() * TAU
	_anim = randf() * 10.0
	_speed = randf_range(1.0, 1.6)


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_model = VoxelModel.build(data["look"])
	_pivot.add_child(_model)
	var h: float = _model.get_meta("height", 1.0)
	_label = Label3D.new()
	_label.text = data["name"]
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 30
	_label.outline_size = 10
	_label.fixed_size = true
	_label.font = UIStyle.font()
	_label.modulate = Color("5a4636")
	_label.outline_modulate = Color(1, 1, 1, 0.95)
	_label.pixel_size = 0.0011
	_label.position = Vector3(0, h + 0.45, 0)
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)
	rotation.y = _facing


func set_label_visible(v: bool, prompt := false) -> void:
	_label.visible = v
	_label.text = data["name"] + ("\n[E] Parler" if prompt else "")


func celebrate() -> void:
	_celebrate = 1.6


func talk_to(player_pos: Vector3) -> void:
	state = State.TALK
	_timer = 5.0
	var d := player_pos - position
	_facing = atan2(d.x, d.z)


func _process(delta: float) -> void:
	_anim += delta
	_timer -= delta
	match state:
		State.IDLE:
			if _timer <= 0.0:
				_pick_target()
		State.TALK:
			if _timer <= 0.0:
				state = State.IDLE
				_timer = randf_range(1.0, 3.0)
		State.WALK:
			_walk(delta)

	# Garde la créature posée sur le sol.
	var gy := _ground_at(position.x, position.z, position.y + 1.4)
	if gy > -100.0:
		position.y = lerpf(position.y, gy, minf(1.0, delta * 10.0))
	rotation.y = lerp_angle(rotation.y, _facing, minf(1.0, delta * 7.0))

	# Animation : sautillement en marchant, respiration à l'arrêt.
	if _celebrate > 0.0:
		_celebrate -= delta
		_pivot.position.y = absf(sin(_anim * 10.0)) * 0.35
		_pivot.rotation.y = _anim * 8.0
	elif state == State.WALK:
		var hop := absf(sin(_anim * 9.0 * _speed))
		_pivot.position.y = hop * 0.13
		_pivot.scale = Vector3(1.0 + (1.0 - hop) * 0.06, 1.0 - (1.0 - hop) * 0.08, 1.0)
		_pivot.rotation.y = 0.0
	else:
		_pivot.position.y = lerpf(_pivot.position.y, 0.0, minf(1.0, delta * 10.0))
		var b := sin(_anim * 2.4) * 0.03
		_pivot.scale = Vector3(1.0 - b * 0.5, 1.0 + b, 1.0 - b * 0.5)
		_pivot.rotation.y = 0.0


func _pick_target() -> void:
	for attempt in 6:
		var a := randf() * TAU
		var r := randf_range(2.0, 6.0)
		var t := home + Vector3(cos(a) * r, 0, sin(a) * r)
		var gy := _ground_at(t.x, t.z, position.y + 3.0)
		if gy < IslandGenerator.SEA + 1.0 or absf(gy - position.y) > 3.0:
			continue
		_target = Vector3(t.x, gy, t.z)
		state = State.WALK
		_timer = 8.0
		return
	_timer = randf_range(1.0, 2.5)


func _walk(delta: float) -> void:
	var to := _target - position
	to.y = 0.0
	if to.length() < 0.15 or _timer <= 0.0:
		state = State.IDLE
		_timer = randf_range(1.5, 4.5)
		return
	var dir := to.normalized()
	_facing = atan2(dir.x, dir.z)
	var next := position + dir * _speed * delta
	var probe := position + dir * 0.45
	var gy := _ground_at(probe.x, probe.z, position.y + 1.4)
	# Bloqué par une marche trop haute, un trou ou l'eau.
	if gy < -100.0 or gy - position.y > 1.1 or position.y - gy > 2.5 or gy < IslandGenerator.SEA + 1.0:
		state = State.IDLE
		_timer = randf_range(0.5, 1.5)
		return
	position.x = next.x
	position.z = next.z


## Hauteur du sol (dessus du bloc solide) sous (x, z) en partant de from_y.
func _ground_at(x: float, z: float, from_y: float) -> float:
	var xi := floori(x)
	var zi := floori(z)
	var y := mini(floori(from_y), VoxelWorld.SY - 1)
	while y >= 0:
		if world.is_opaque(xi, y, zi):
			if world.is_opaque(xi, y + 1, zi):
				return -1000.0
			return float(y + 1)
		y -= 1
	return -1000.0
