class_name ShipwreckIntro
extends RefCounted
## Introduction d'une nouvelle partie, en quatre actes (Échap la passe) :
##   1. La tempête : écran noir, pluie, vent, tonnerre et éclairs ; quelques
##      pensées, puis le choc... et le silence.
##   2. Le réveil : à l'aube, les yeux s'ouvrent sur la plage ; la caméra est
##      au ras du sable, à côté du personnage allongé.
##   3. Debout : il se relève, se tient la tête, regarde les débris.
##   4. L'île : la caméra s'élève par-dessus son épaule et la dévoile
##      (« Une île inconnue »), puis à lui de jouer.

var main: Node
var story: StoryOverlay
var cam: Camera3D
var _pos := Vector3.ZERO  # position actuelle de la caméra
var _look := Vector3.ZERO  # point regardé
var _up := Vector3.UP
var _from := []  # [pos, look, up] au début du déplacement
var _to := []
var _arc := 0.0


func run(m: Node, overlay: StoryOverlay) -> void:
	main = m
	story = overlay
	var player: Player = main.player
	var rig: CameraRig = main.rig
	var b: Dictionary = IslandGenerator.beach
	var pos: Vector3 = b.get("pos", player.global_position)
	var out: Vector3 = b.get("out", Vector3(0, 0, 1))
	var inland := -out
	var side := out.cross(Vector3.UP).normalized()

	# Le joueur est déjà sur la plage : l'île se construit autour pendant le noir.
	player.teleport(pos + Vector3(0, 0.05, 0))
	player.set_lying(out)
	rig.cinematic = true
	cam = rig.camera

	# --- Acte 1 : la tempête (écran noir).
	var amb := Ambience.new()
	main.add_child(amb)
	amb.fade_to(0.0, 0.0, 0.0, 0.01)
	await _wait(0.8)
	amb.rain = 0.0
	amb.create_tween().tween_property(amb, "rain", 1.0, 2.5)
	amb.fade_to(1.0, 0.9, 1.0, 2.5)
	await _wait(1.6)
	_storm_flash(amb, 1.0)
	await _wait(1.0)
	var storm := await Dialogues.fetch(Dialogues.INTRO, "tempete")
	# Éclairs pendant que les pensées défilent.
	var storm_on := [true]
	_storm_loop(amb, storm_on)
	await story.play_lines(storm)
	storm_on[0] = false
	_speed_up_if_skipped()
	# Le choc : un grand craquement, puis plus rien.
	_storm_flash(amb, 1.0)
	Audio.play("break_wood", 0.0, 0.0, 0.55)
	await _wait(0.25)
	amb.fade_to(0.0, 0.0, 0.0, 0.4)
	amb.create_tween().tween_property(amb, "rain", 0.0, 0.4)
	await _wait(3.0)
	# Le silence, puis les vagues reviennent, calmes. Quelques oiseaux.
	amb.fade_to(0.7, 0.15, 0.0, 4.0)
	amb.create_tween().tween_property(amb, "birds", 0.25, 6.0)
	await _wait(2.0)
	var wake := await Dialogues.fetch(Dialogues.INTRO, "naufrage")
	await story.play_lines(wake)
	_speed_up_if_skipped()

	# --- Acte 2 : le réveil. Caméra au ras du sable, à côté du visage.
	var head := pos + out * 0.55 + Vector3.UP * 0.25
	_place(head + side * 1.1 + inland * 0.4 + Vector3.UP * 0.25, head + inland * 0.6 + Vector3.UP * 0.15)
	var drift := _tween_to(head + side * 1.6 + inland * 0.9 + Vector3.UP * 0.6, head + inland * 0.3, 6.0)
	await story.open_eyes()
	_speed_up_if_skipped()
	var get_up := await Dialogues.fetch(Dialogues.INTRO, "reveil_plage")
	await story.play_lines(get_up)
	if drift.is_running():
		await drift.finished

	# --- Acte 3 : il se relève et regarde autour de lui.
	var stand_cam := pos + out * 3.4 + side * 1.4 + Vector3.UP * 1.3
	var stand_look := pos + Vector3.UP * 0.9 + inland * 1.2
	var move := _tween_to(stand_cam, stand_look, 2.0)
	await player.stand_up(1.5)
	if move.is_running():
		await move.finished
	await _wait(0.2)
	player.play_anim("emote-no")  # il se tient la tête, encore sonné
	await _wait(1.0)
	await player.turn_to(atan2(side.x - out.x * 0.3, side.z - out.z * 0.3), 0.8)
	await _wait(0.5)
	await player.turn_to(atan2(-side.x - out.x * 0.3, -side.z - out.z * 0.3), 1.0)
	await _wait(0.4)
	var look := await Dialogues.fetch(Dialogues.INTRO, "debout")
	await story.play_lines(look)
	await player.turn_to(atan2(inland.x, inland.z), 0.7)

	# --- Acte 4 : la caméra s'élève par-dessus son épaule et dévoile l'île.
	var peak := IslandGenerator.PRAIRIE_PEAK
	var mountain := Vector3(peak.x, 24.0, peak.y)
	var over := pos + out * 2.2 + side * 0.8 + Vector3.UP * 2.0
	await _move(over, pos + inland * 12.0 + Vector3.UP * 2.0, 2.4)
	var crane := pos + out * 6.0 + Vector3.UP * 16.0
	var vista := pos + inland * 60.0 + Vector3.UP * 4.0
	var reveal := _tween_to(crane, vista.lerp(mountain, 0.35), 9.0, Vector3.UP, 3.0)
	main.get_tree().create_timer(2.2).timeout.connect(func():
		if not story.skipped:
			Audio.play("jingle_island", -6.0, 0.0))
	main.get_tree().create_timer(2.8).timeout.connect(func():
		if not story.skipped:
			story.show_title("Une île inconnue", "Quelque part au milieu de l'océan...", 3.2))
	if reveal.is_running():
		await reveal.finished

	# --- Retour derrière le joueur : à lui de jouer.
	main.gameplay_camera(atan2(out.x, out.z))
	rig.snap()
	var gt := rig.gameplay_transform()
	await _move(gt.origin, gt.origin - gt.basis.z * 10.0, 2.4)
	rig.snap()
	rig.cinematic = false
	Engine.time_scale = 1.0
	story.clear_bars(1.0)
	main.get_tree().create_timer(1.2).timeout.connect(story.queue_free)
	amb.fade_out_and_free(10.0)
	Audio.play_music("prairie")


## Un éclair, et le tonnerre qui suit.
func _storm_flash(amb: Ambience, strength: float) -> void:
	story.lightning(0.55 * strength)
	main.get_tree().create_timer(randf_range(0.2, 0.6)).timeout.connect(func():
		if is_instance_valid(amb):
			amb.thunder(strength))


## Éclairs réguliers tant que `on[0]` est vrai.
func _storm_loop(amb: Ambience, on: Array) -> void:
	while on[0] and not story.skipped:
		await main.get_tree().create_timer(randf_range(2.0, 3.5)).timeout
		if on[0] and not story.skipped:
			_storm_flash(amb, randf_range(0.5, 0.9))


func _speed_up_if_skipped() -> void:
	if story.skipped:
		Engine.time_scale = 6.0


func _wait(t: float) -> void:
	if story.skipped:
		return
	await main.get_tree().create_timer(t).timeout


func _place(p: Vector3, look: Vector3, up := Vector3.UP) -> void:
	_pos = p
	_look = look
	_up = up
	_apply()


func _apply() -> void:
	var fwd := (_look - _pos).normalized()
	var up := _up
	if absf(fwd.dot(up.normalized())) > 0.999:
		up = Vector3.FORWARD
	cam.global_transform = Transform3D(Basis.looking_at(fwd, up), _pos)


## Déplacement fluide de la caméra (position, point regardé, verticale).
## `arc` soulève la trajectoire au milieu (mouvement de grue).
func _move(to_pos: Vector3, to_look: Vector3, duration: float, to_up := Vector3.UP, arc := 0.0) -> void:
	await _tween_to(to_pos, to_look, duration, to_up, arc).finished


func _tween_to(to_pos: Vector3, to_look: Vector3, duration: float, to_up := Vector3.UP, arc := 0.0) -> Tween:
	_speed_up_if_skipped()
	_from = [_pos, _look, _up]
	_to = [to_pos, to_look, to_up]
	_arc = arc
	var tw := main.create_tween()
	tw.tween_method(_step, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


func _step(t: float) -> void:
	_pos = (_from[0] as Vector3).lerp(_to[0], t) + Vector3.UP * sin(PI * t) * _arc
	_look = (_from[1] as Vector3).lerp(_to[1], t)
	_up = (_from[2] as Vector3).lerp(_to[2], t).normalized()
	_apply()
