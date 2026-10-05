class_name Animal
extends Node3D
## Animal sauvage (Cube Pets de Kenney) : il se promène autour de son coin,
## broute, et réagit quand on s'approche pour le saluer (E).

const SCALE := 0.55

var species := "bunny"
var world: VoxelWorld
var home := Vector3.ZERO

var _ap: AnimationPlayer
var _target := Vector3.ZERO
var _walking := false
var _timer := 1.0
var _facing := 0.0
var _speed := 1.2
var _react := 0.0


func setup(sp: String, w: VoxelWorld, pos: Vector3) -> void:
	species = sp
	world = w
	position = pos
	home = pos
	_facing = randf() * TAU
	_timer = randf_range(0.5, 3.0)
	_speed = randf_range(0.9, 1.5)


func _ready() -> void:
	var sc := Props.scene("pets/animal-" + species)
	if sc == null:
		return
	var m := sc.instantiate() as Node3D
	m.scale = Vector3.ONE * SCALE
	add_child(m)
	_ap = m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap:
		for n in ["idle", "walk", "eat"]:
			if _ap.has_animation(n):
				_ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		_play("idle")
	rotation.y = _facing


func _play(anim: String) -> void:
	if _ap and _ap.has_animation(anim) and _ap.current_animation != anim:
		_ap.play(anim, 0.2)


## Salué par le joueur : petite danse.
func react(from: Vector3) -> void:
	var d := from - position
	_facing = atan2(d.x, d.z)
	_walking = false
	_react = 2.0
	_play("dance" if randf() < 0.5 else "gesture-positive")


func _process(delta: float) -> void:
	_timer -= delta
	if _react > 0.0:
		_react -= delta
	elif _walking:
		_walk(delta)
	elif _timer <= 0.0:
		_pick()
	position.y = lerpf(position.y, _ground(position.x, position.z, position.y + 1.4), minf(1.0, delta * 10.0))
	rotation.y = lerp_angle(rotation.y, _facing, minf(1.0, delta * 6.0))


func _pick() -> void:
	if randf() < 0.35:
		_play("eat")
		_timer = randf_range(2.0, 4.0)
		return
	for i in 6:
		var a := randf() * TAU
		var t := home + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 5.0)
		var gy := _ground(t.x, t.z, position.y + 3.0)
		if gy < IslandGenerator.SEA + 1.0 or absf(gy - position.y) > 2.5:
			continue
		_target = Vector3(t.x, gy, t.z)
		_walking = true
		_timer = 7.0
		_play("walk")
		return
	_timer = randf_range(1.0, 2.0)


func _walk(delta: float) -> void:
	var to := _target - position
	to.y = 0.0
	if to.length() < 0.2 or _timer <= 0.0:
		_walking = false
		_timer = randf_range(1.5, 4.0)
		_play("idle")
		return
	var dir := to.normalized()
	_facing = atan2(dir.x, dir.z)
	var probe := position + dir * 0.5
	var gy := _ground(probe.x, probe.z, position.y + 1.4)
	if gy < IslandGenerator.SEA + 1.0 or gy - position.y > 1.1:
		_walking = false
		_timer = randf_range(0.5, 1.5)
		_play("idle")
		return
	position.x += dir.x * _speed * delta
	position.z += dir.z * _speed * delta


func _ground(x: float, z: float, from_y: float) -> float:
	var xi := floori(x)
	var zi := floori(z)
	var y := mini(floori(from_y), VoxelWorld.SY - 1)
	while y >= 0:
		if world.is_opaque(xi, y, zi):
			return float(y + 1)
		y -= 1
	return position.y
