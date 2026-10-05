class_name CameraRig
extends Node3D
## Caméra orbitale à la troisième personne : clic droit / clic molette
## maintenu ou flèches pour tourner, molette pour zoomer.

var target: Node3D
var world: VoxelWorld
var camera: Camera3D
var yaw := 0.0
var pitch := -0.72
var distance := 10.0
var _dist_cur := 10.0
var input_enabled := true


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.1
	camera.far = 900.0
	add_child(camera)
	camera.current = true


func rotate_by(dx: float, dy: float) -> void:
	yaw -= dx * 0.008
	pitch = clampf(pitch - dy * 0.006, -1.45, -0.05)


func zoom(amount: float) -> void:
	distance = clampf(distance + amount, 3.0, 28.0)


func snap() -> void:
	if target:
		global_position = target.global_position + Vector3(0, 0.8, 0)
	_dist_cur = distance
	_update_camera()


func _process(delta: float) -> void:
	var kx := Input.get_axis("cam_left", "cam_right")
	var ky := Input.get_axis("cam_up", "cam_down")
	if input_enabled and (kx != 0.0 or ky != 0.0):
		rotate_by(kx * 260.0 * delta, ky * 160.0 * delta)
	if target:
		var goal := target.global_position + Vector3(0, 0.8, 0)
		global_position = global_position.lerp(goal, minf(1.0, delta * 9.0))
	var want := distance
	if world:
		# Rapproche la caméra seulement si elle se retrouve dans le terrain.
		var dir := _offset_dir()
		while want > 3.0:
			var p := global_position + dir * want
			if not world.is_opaque(floori(p.x), floori(p.y), floori(p.z)):
				break
			want -= 0.5
	_dist_cur = lerpf(_dist_cur, want, minf(1.0, delta * (14.0 if want < _dist_cur else 4.0)))
	_update_camera()


func _offset_dir() -> Vector3:
	return (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3(0, 0, 1)).normalized()


func _update_camera() -> void:
	camera.global_position = global_position + _offset_dir() * _dist_cur
	camera.look_at(global_position, Vector3.UP)
