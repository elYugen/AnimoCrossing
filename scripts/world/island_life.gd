class_name IslandLife
extends Node3D
## La vitalité se voit et s'entend : plus l'île est accueillante, plus elle
## vit, sans chiffre ni objectif à atteindre.
##   palier 0 (< 20 %)  île silencieuse : vent et vagues seulement
##   palier 1 (20 %)    quelques oiseaux chantent, lucioles la nuit
##   palier 2 (40 %)    papillons sur les fleurs (Wildlife), plus de chants
##   palier 3 (60 %)    des vols d'oiseaux traversent le ciel
##   palier 4-5 (80 %+) l'île chante du matin au soir, les grillons la nuit
## Les habitants en parlent aussi (ResidentTalk), se retrouvent plus souvent
## (Moments, ResidentAI), et les fleurs sauvages repoussent plus vite (DayCycle).

## Intensité des chants d'oiseaux et des grillons selon le palier.
const SONG := [0.0, 0.3, 0.5, 0.7, 0.9, 1.0]
## Ce qui change quand l'île passe un palier (annoncé une fois).
const NEWS := [
	"",
	"Des oiseaux chantent au loin, les fleurs reviennent.",
	"Des papillons dansent au-dessus des fleurs.",
	"Des oiseaux traversent le ciel. L'île est pleine de vie.",
	"On entend la vie partout. Les habitants sont heureux ici.",
	"Rien ne manque... mais il reste toujours des choses à découvrir.",
]

var main: Main
## Palier de vie de l'île courante (Vitality.tier_index).
var tier := 0
var _timer := 0.0
var _flock_wait := 20.0
var _fireflies: CPUParticles3D


func _ready() -> void:
	_fireflies = _make_fireflies()
	add_child(_fireflies)


func refresh() -> void:
	tier = Vitality.tier_index(Vitality.percent(Game.current_island))


func _process(delta: float) -> void:
	if main == null or main.in_title:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 2.0
		refresh()
		_update_sounds()
	_update_fireflies()
	_flock_wait -= delta
	if _flock_wait <= 0.0:
		_flock_wait = randf_range(30.0, 70.0) if tier >= 4 else randf_range(60.0, 120.0)
		if tier >= 3 and _fair_day() and main.interior == null:
			_spawn_flock()


func _fair_day() -> bool:
	return not main.sky.is_night() and not Game.weather in ["rain", "storm", "fog"]


func _update_sounds() -> void:
	var amb := main.ambience
	var level: float = SONG[tier]
	var day := not main.sky.is_night()
	var bad := Game.weather in ["rain", "storm"]
	var target_birds := level * (1.0 if day and not bad else 0.0) * (0.4 if Game.weather in ["fog", "snow"] else 1.0)
	var target_crickets := level * (1.0 if not day and not bad and Game.weather != "snow" else 0.0)
	if main.interior != null:
		target_birds *= 0.2
		target_crickets *= 0.2
	var tw := amb.create_tween().set_parallel(true)
	tw.tween_property(amb, "birds", target_birds, 2.0)
	tw.tween_property(amb, "crickets", target_crickets, 2.0)


# --- Lucioles ----------------------------------------------------------------

func _make_fireflies() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 40
	p.lifetime = 4.0
	p.local_coords = false
	var m := QuadMesh.new()
	m.size = Vector2(0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(2.6, 2.4, 0.9)  # assez lumineux pour briller (glow)
	m.material = mat
	p.mesh = m
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(10, 1.2, 10)
	p.gravity = Vector3.ZERO
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.tangential_accel_min = -0.6
	p.tangential_accel_max = 0.6
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 0.6, 0), Color(1, 1, 0.6, 1), Color(1, 1, 0.6, 1), Color(1, 1, 0.6, 0)])
	p.color_ramp = fade
	return p


## La nuit (et par temps sec), des lucioles autour du joueur ; d'autant plus
## nombreuses que l'île est vivante.
func _update_fireflies() -> void:
	var want := tier >= 1 and main.sky.is_night() and not Game.weather in ["rain", "storm", "snow"] and main.interior == null
	if want:
		_fireflies.global_position = main.player.global_position + Vector3(0, 0.8, 0)
		var n := 16 + tier * 12
		if _fireflies.amount != n:
			_fireflies.amount = n  # (changer le nombre relance l'émission)
	if _fireflies.emitting != want:
		_fireflies.emitting = want


# --- Vols d'oiseaux ----------------------------------------------------------

## Un petit vol d'oiseaux traverse le ciel au-dessus du joueur.
func _spawn_flock() -> void:
	var flock := Node3D.new()
	add_child(flock)
	var center := main.player.global_position
	var dir := Vector3(cos(randf() * TAU), 0, sin(randf() * TAU))
	var start := center - dir * 90.0 + Vector3(0, randf_range(26.0, 36.0), 0)
	flock.global_position = start
	flock.look_at(start + dir, Vector3.UP)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3d3a44")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var count := randi_range(3, 7)
	for i in count:
		var bird := _make_bird(mat)
		# En V : chaque oiseau un peu derrière et sur le côté du précédent.
		var side := 1.0 if i % 2 == 0 else -1.0
		var rank := float((i + 1) / 2)
		bird.position = Vector3(side * rank * 1.6, randf_range(-0.4, 0.4), rank * 1.8)
		flock.add_child(bird)
	var tw := flock.create_tween()
	tw.tween_property(flock, "global_position", start + dir * 180.0, 180.0 / 9.0)
	tw.tween_callback(flock.queue_free)


func _make_bird(mat: Material) -> Node3D:
	var bird := Node3D.new()
	for s in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.7, 0.22)
		wing.mesh = q
		wing.material_override = mat
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing.position.x = s * 0.35
		wing.rotation.x = -PI * 0.5
		var pivot := Node3D.new()
		pivot.add_child(wing)
		bird.add_child(pivot)
		# Battements d'ailes.
		var tw := pivot.create_tween().set_loops()
		var up: float = s * 0.6
		tw.tween_property(pivot, "rotation:z", up, 0.22).set_trans(Tween.TRANS_SINE).set_delay(randf() * 0.2)
		tw.tween_property(pivot, "rotation:z", -up * 0.5, 0.22).set_trans(Tween.TRANS_SINE)
	return bird
