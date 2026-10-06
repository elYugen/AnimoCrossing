class_name SpiritDeer
extends Node3D
## Le cerf des brumes (WeatherFX) : une silhouette pâle et translucide.
## Quand on s'approche, il s'efface et réapparaît plus loin (deux fois),
## puis il reste à nous regarder... et s'enfuit dans le brouillard.

const SCALE := 0.8
## Distance à laquelle il s'efface (puis, la dernière fois, s'enfuit).
const SHY := 11.0
const LAST_SHY := 7.0

var fx: WeatherFX
var _stage := 0  # 0, 1 : il se dérobe ; 2 : il regarde ; 3 : parti
var _busy := false
var _watch := 0.0
var _ap: AnimationPlayer
var _mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	var sc := Props.scene("pets/animal-deer")
	if sc == null:
		return
	var m := sc.instantiate() as Node3D
	m.scale = Vector3.ONE * SCALE
	add_child(m)
	# Pâle, bleuté, un peu transparent et lumineux.
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.82, 0.9, 1.0, 0.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.55, 0.7, 0.9)
		mat.emission_energy_multiplier = 0.6
		(n as MeshInstance3D).material_override = mat
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mats.append(mat)
	_ap = m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play("idle")


func _play(anim: String) -> void:
	if _ap and _ap.has_animation(anim):
		_ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		_ap.play(anim, 0.2)


func _alpha(a: float, dur: float) -> Tween:
	var tw := create_tween().set_parallel(true)
	for mat in _mats:
		tw.tween_property(mat, "albedo_color:a", a, dur)
	return tw


## Apparaît à `pos`, tourné vers le joueur, avec un craquement de branche.
func appear(pos: Vector3, look_at_pos: Vector3) -> void:
	global_position = pos
	_face(look_at_pos)
	_alpha(0.55, 1.2)
	Audio.play("break_wood", -14.0, 0.15, 0.7)


func _face(p: Vector3) -> void:
	var d := p - global_position
	rotation.y = atan2(d.x, d.z)


func _process(delta: float) -> void:
	if _busy or fx == null:
		return
	var pp := fx.main.player.global_position
	var d := pp.distance_to(global_position)
	if _stage < 2:
		if d < SHY:
			_slip_away(pp)
		return
	if _stage == 2:
		_face(pp)
		if d < 15.0:
			_watch += delta
		if d < LAST_SHY or _watch > 5.0:
			_flee(pp)


## Il s'efface, puis réapparaît plus loin dans les bois.
func _slip_away(pp: Vector3) -> void:
	_busy = true
	await _alpha(0.0, 0.6).finished
	var away := global_position - pp
	away.y = 0.0
	var spot := fx._deer_spot(pp + away.normalized() * 6.0, 16.0)
	if spot == Vector3.INF:
		spot = global_position + away.normalized() * 10.0
	_stage += 1
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	appear(spot, pp)
	_busy = false


## La dernière fois : il regarde encore un instant, puis s'enfuit en s'effaçant.
func _flee(pp: Vector3) -> void:
	_busy = true
	_stage = 3
	var away := global_position - pp
	away.y = 0.0
	_face(global_position + away)
	_play("walk")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", global_position + away.normalized() * 8.0, 2.0)
	for mat in _mats:
		tw.tween_property(mat, "albedo_color:a", 0.0, 2.0)
	await tw.finished
	fx.deer_seen()
	queue_free()


## Le brouillard se lève : il disparaît sans qu'on l'ait vraiment vu.
func vanish() -> void:
	_busy = true
	var tw := _alpha(0.0, 1.5)
	tw.chain().tween_callback(queue_free)
