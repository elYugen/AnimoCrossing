class_name Player
extends CharacterBody3D
## Le joueur : un personnage voxel Kenney (Blocky Characters, CC0)
## capable de façonner l'île grâce à ses pouvoirs.

const SPEED := 5.2
const ACCEL := 14.0
const GRAVITY := 24.0
const JUMP := 8.4
const MODEL_HEIGHT := 1.35
const SKINS := "abcdefghijklmnopqr"
const SKIN_PATH := "res://assets/characters/kenney/character-%s.glb"

var rig: CameraRig
var world: VoxelWorld
var input_enabled := true
var respawn_point := Vector3.ZERO
var distance_walked := 0.0

var _pivot: Node3D
var _model: Node3D
var _anim_player: AnimationPlayer
var _facing := 0.0
var _action_timer := 0.0
var _step_timer := 0.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.25
	col.shape = cap
	col.position.y = 0.625
	add_child(col)
	_pivot = Node3D.new()
	add_child(_pivot)
	set_skin(Game.player_skin)
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)


func set_skin(letter: String) -> void:
	if _model:
		_model.queue_free()
		_model = null
		_anim_player = null
	var path := SKIN_PATH % letter
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Modèle joueur introuvable : %s" % path)
		return
	_model = scene.instantiate() as Node3D
	_pivot.add_child(_model)
	# Normalise la taille du modèle.
	var aabb := _compute_aabb(_model)
	if aabb.size.y > 0.01:
		var s := MODEL_HEIGHT / aabb.size.y
		_model.scale = Vector3.ONE * s
		_model.position.y = -aabb.position.y * s
	_anim_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player:
		for loop_name in ["idle", "walk", "sprint"]:
			if _anim_player.has_animation(loop_name):
				_anim_player.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		_play("idle")


static func _compute_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var box := _relative_xf(root, mi) * mi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


static func _relative_xf(root: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _play(anim: String, blend := 0.15) -> void:
	if _anim_player and _anim_player.has_animation(anim) and _anim_player.current_animation != anim:
		_anim_player.play(anim, blend)


## Animation ponctuelle lors de l'utilisation d'un pouvoir.
func play_action(kind: String) -> void:
	var anim := "interact-right"
	match kind:
		"break":
			anim = "attack-melee-right"
		"bloom", "tree":
			anim = "pick-up"
		"talk":
			anim = "emote-yes"
	if _anim_player and _anim_player.has_animation(anim):
		_anim_player.play(anim, 0.08)
		_action_timer = minf(_anim_player.get_animation(anim).length, 0.7)


func face_towards(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.1:
		_facing = atan2(d.x, d.z)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw := rig.yaw if rig else 0.0
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	var sprint := input_enabled and Input.is_key_pressed(KEY_SHIFT)
	var target_v := dir * SPEED * (1.5 if sprint else 1.0)
	velocity.x = move_toward(velocity.x, target_v.x, ACCEL * SPEED * delta)
	velocity.z = move_toward(velocity.z, target_v.z, ACCEL * SPEED * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif input_enabled and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP

	var pre := global_position
	move_and_slide()

	# Saut automatique sur les marches d'un bloc.
	if world and is_on_floor() and is_on_wall() and dir.length() > 0.1 and velocity.y <= 0.0:
		var ahead := global_position + dir.normalized() * 0.55
		var fx := floori(ahead.x)
		var fz := floori(ahead.z)
		var fy := floori(global_position.y + 0.1)
		if world.is_opaque(fx, fy, fz) and not world.is_opaque(fx, fy + 1, fz) and not world.is_opaque(fx, fy + 2, fz):
			velocity.y = JUMP * 0.92

	distance_walked += Vector2(global_position.x - pre.x, global_position.z - pre.z).length()

	if dir.length() > 0.1:
		_facing = atan2(dir.x, dir.z)
	_pivot.rotation.y = lerp_angle(_pivot.rotation.y, _facing, minf(1.0, delta * 12.0))

	# Bruits de pas selon le sol.
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5 and world:
		_step_timer -= delta * hspeed / SPEED
		if _step_timer <= 0.0:
			_step_timer = 0.36
			var below := world.get_block(floori(global_position.x), floori(global_position.y - 0.2), floori(global_position.z))
			Audio.play(_step_sound(below), -14.0, 0.12)
	else:
		_step_timer = 0.0

	# Animations
	_action_timer -= delta
	if _action_timer <= 0.0:
		var speed := Vector2(velocity.x, velocity.z).length()
		if speed > SPEED * 1.2:
			_play("sprint")
		elif speed > 0.5:
			_play("walk")
		else:
			_play("idle")

	if global_position.y < -8.0:
		teleport(respawn_point)


static func _step_sound(b: int) -> String:
	if b in [Blocks.SNOW, Blocks.ICE]:
		return "step_snow"
	if b in [Blocks.WOOD, Blocks.PLANK, Blocks.PALM_WOOD]:
		return "step_wood"
	if b in [Blocks.STONE, Blocks.BRICK, Blocks.BASALT, Blocks.MOSS, Blocks.CLAY]:
		return "step_stone"
	return "step_grass"


func teleport(p: Vector3) -> void:
	global_position = p
	respawn_point = p
	velocity = Vector3.ZERO


static func next_skin(letter: String, step: int) -> String:
	var i := SKINS.find(letter)
	i = posmod(i + step, SKINS.length())
	return SKINS[i]
