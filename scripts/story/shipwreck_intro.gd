class_name ShipwreckIntro
extends RefCounted
## Introduction d'une nouvelle partie : écran noir et pensées sur fond de
## vagues, de vent et de bois qui craque, puis réveil sur la plage et
## caméra qui dévoile l'île. Échap accélère la cinématique.


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

	# --- Écran noir : les sons arrivent petit à petit, puis les pensées.
	var amb := Ambience.new()
	main.add_child(amb)
	amb.fade_to(0.0, 0.0, 0.0, 0.01)
	await _wait(1.0)
	amb.fade_to(0.9, 0.0, 0.0, 3.5)
	await _wait(1.8)
	amb.fade_to(0.9, 0.55, 0.0, 2.5)
	await _wait(1.6)
	amb.fade_to(0.9, 0.55, 0.8, 1.0)
	await _wait(1.2)
	var lines := await Dialogues.fetch(Dialogues.INTRO, "naufrage")
	await story.play_lines(lines)
	_speed_up_if_skipped()
	amb.fade_to(0.8, 0.35, 0.0, 3.0)

	# --- Réveil : vue plongeante sur le visage, les yeux s'ouvrent.
	var body := pos + out * 0.6 + Vector3.UP * 0.2
	_place(body + Vector3.UP * 2.6 + inland * 0.2, body, out)
	var open := _tween_to(body + Vector3.UP * 3.6 + side * 0.9, body, 5.0, out)
	await story.open_eyes()
	_speed_up_if_skipped()
	if open.is_running():
		await open.finished

	# --- Il se relève.
	var stand_cam := pos + out * 3.2 + side * 1.1 + Vector3.UP * 1.2
	var stand_look := pos + Vector3.UP * 0.9 + inland * 1.5
	var move := _tween_to(stand_cam, stand_look, 1.8)
	await player.stand_up(1.4)
	if move.is_running():
		await move.finished
	await _wait(0.3)
	player.play_anim("emote-no")
	await _wait(0.9)
	await player.turn_to(atan2(inland.x + side.x * 0.8, inland.z + side.z * 0.8), 0.7)
	await _wait(0.4)
	await player.turn_to(atan2(inland.x - side.x * 0.8, inland.z - side.z * 0.8), 0.9)
	await _wait(0.3)
	await player.turn_to(atan2(inland.x, inland.z), 0.6)

	# --- La caméra s'élève au-dessus des vagues et dévoile l'île.
	var peak := IslandGenerator.PRAIRIE_PEAK
	var mountain := Vector3(peak.x, 22.0, peak.y)
	var crane := pos + out * 15.0 - side * 5.0 + Vector3.UP * 17.0
	var vista := pos + inland * 45.0 + Vector3.UP * 6.0
	main.get_tree().create_timer(2.8).timeout.connect(func():
		if not story.skipped:
			story.show_title("Une île inconnue", "Quelque part au milieu de l'océan...", 3.2))
	await _move(crane, vista, 8.0, Vector3.UP, 4.0)
	# Panoramique lent vers la montagne et les ruines englouties.
	await _move(crane + side * 12.0 + Vector3.UP * 3.0, vista.lerp(mountain, 0.6), 5.0)
	await _move(pos + out * 9.0 + side * 16.0 + Vector3.UP * 7.0, pos + out * 6.0 - side * 4.0, 5.0)

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
