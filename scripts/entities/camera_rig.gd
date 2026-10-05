class_name CameraRig
extends Node3D
## Caméra 3D classique à la troisième personne : la souris oriente librement
## la caméra (curseur capturé), légèrement décalée au-dessus de l'épaule,
## molette pour zoomer. Elle se rapproche si le terrain la gêne.
## En mode `cinematic`, la caméra n'est plus pilotée par le rig.

const PIVOT_HEIGHT := 1.35
const MIN_DIST := 2.0
const MAX_DIST := 14.0
const PITCH_MIN := -1.35
const PITCH_MAX := 0.6

var target: Node3D
var world: VoxelWorld
var camera: Camera3D
var yaw := 0.0
var pitch := -0.32
var distance := 6.0
## Décalage latéral (vers la droite) : le personnage est un peu à gauche de l'écran.
var shoulder := 0.55
var input_enabled := true
var cinematic := false
var _dist_cur := 6.0
var _shoulder_cur := 0.55


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.1
	camera.far = 900.0
	add_child(camera)
	camera.current = true


## Tourne la caméra (radians).
func look(d_yaw: float, d_pitch: float) -> void:
	yaw += d_yaw
	pitch = clampf(pitch + d_pitch, PITCH_MIN, PITCH_MAX)


func zoom(amount: float) -> void:
	distance = clampf(distance + amount, MIN_DIST, MAX_DIST)


func snap() -> void:
	if target:
		global_position = target.global_position + Vector3(0, PIVOT_HEIGHT, 0)
	_dist_cur = distance
	_shoulder_cur = shoulder
	_update_camera()


func _process(delta: float) -> void:
	if cinematic:
		return
	var kx := Input.get_axis("cam_left", "cam_right")
	var ky := Input.get_axis("cam_up", "cam_down")
	if input_enabled and (kx != 0.0 or ky != 0.0):
		look(-kx * 2.2 * delta, -ky * 1.4 * delta)
	if target:
		var goal := target.global_position + Vector3(0, PIVOT_HEIGHT, 0)
		global_position = global_position.lerp(goal, minf(1.0, delta * 12.0))
	_shoulder_cur = lerpf(_shoulder_cur, shoulder, minf(1.0, delta * 6.0))
	var want := _clear_distance(distance)
	# Se rapproche vite (collision), s'éloigne en douceur.
	_dist_cur = lerpf(_dist_cur, want, minf(1.0, delta * (16.0 if want < _dist_cur else 4.0)))
	_update_camera()


## Distance maximale sans traverser le terrain (les arbres sont ignorés :
## ils sont effacés par le shader quand ils cachent le joueur).
func _clear_distance(want: float) -> float:
	if world == null:
		return want
	var origin := _arm_origin()
	var dir := _offset_dir()
	var t := 0.3
	while t < want:
		var p := origin + dir * t
		var x := floori(p.x)
		var y := floori(p.y)
		var z := floori(p.z)
		if world.is_opaque(x, y, z) and not world.get_block(x, y, z) in VoxelWorld.SEE_THROUGH:
			return maxf(0.6, t - 0.35)
		t += 0.25
	return want


func _offset_dir() -> Vector3:
	return (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3(0, 0, 1)).normalized()


func _arm_origin() -> Vector3:
	var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	return global_position + right * _shoulder_cur


## Transform que la caméra aurait en jeu (utile pour finir une cinématique).
func gameplay_transform() -> Transform3D:
	var goal := global_position
	if target:
		goal = target.global_position + Vector3(0, PIVOT_HEIGHT, 0)
	var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var dir := _offset_dir()
	var pos := goal + right * shoulder + dir * distance
	return Transform3D(Basis.looking_at(-dir, Vector3.UP), pos)


func _update_camera() -> void:
	var dir := _offset_dir()
	camera.global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), _arm_origin() + dir * _dist_cur)
