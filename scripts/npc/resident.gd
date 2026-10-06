class_name Resident
extends Node3D
## Habitant de l'île : se promène tranquillement, discute avec le joueur,
## et va travailler sur les chantiers (construction, démolition) quand il
## n'est affecté à aucun autre.

enum State { IDLE, WALK, TALK, WORK_GO, WORKING, GO, ACT, HOME }

const CHATTER := ["Hm-hm !", "Oh ?", "Haha !", "Ah !", "Hmm...", "Hé hé !", "Ooh !", "Tiens !"]

var data: Dictionary
var world: VoxelWorld
var home := Vector3.ZERO
var state := State.IDLE

var _pivot: Node3D
var _model: Node3D
var _human := false  # habitant humain (modèle Kenney, comme le joueur)
var _anim_player: AnimationPlayer
var _label: Label3D
var _target := Vector3.ZERO
var _timer := 1.0
var _anim := 0.0
var _facing := 0.0
var _speed := 1.3
var _celebrate := 0.0
## Chantier auquel l'habitant est affecté ("" : libre).
var site_id := ""
var _slot := Vector3.ZERO
var _site_center := Vector3.ZERO
var _stuck := 0.0
## Routine : activité en cours (voir ResidentAI).
var activity := ""
var idle_time := 0.0
var _goal := Vector3.ZERO
var _goal_face := Vector3.ZERO
var _act_anim := ""
var _bubble: Label3D
## Appelé quand l'habitant arrive là où on l'a envoyé (go) : réagir à une
## nouveauté, ramasser un déchet, planter un arbre...
var on_arrive := Callable()
## Tâche confiée par le joueur (« Va nettoyer », « Va planter ») : {"type", "left"}.
var job := {}
var _bubble_t := 0.0
var voice := 1.0
## Recherche de chemin (partagée) ; sans elle, l'habitant marche tout droit.
var nav: Navigator
var _path := PackedVector3Array()
var _pi := 0
var _need_path := false
var _job := {}
var _path_for := Vector3.INF

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
	var look: Dictionary = data["look"]
	var h := 1.0
	if look.has("skin"):
		_human = true
		_model = Player.build_model(look["skin"], look.get("head", ""))
		_pivot.add_child(_model)
		h = Player.MODEL_HEIGHT
		_anim_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _anim_player:
			for n in ["idle", "walk", "sit"]:
				if _anim_player.has_animation(n):
					_anim_player.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			_anim_player.play("idle")
	else:
		_model = VoxelModel.build(look)
		_pivot.add_child(_model)
		h = _model.get_meta("height", 1.0)
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
	# Pendant qu'il parle (bulle), son nom s'efface pour ne pas la masquer.
	_label.visible = v and not (_bubble != null and _bubble.visible)
	_label.text = data["name"] + ("\n[E] Parler" if prompt else "")


func celebrate() -> void:
	_celebrate = 1.6


func talk_to(player_pos: Vector3) -> void:
	if site_id != "":
		return  # en plein travail : il répond sans s'arrêter
	state = State.TALK
	_timer = 5.0
	var d := player_pos - position
	_facing = atan2(d.x, d.z)


## Affecte l'habitant à un chantier : il s'y rend puis travaille.
func assign(id: String, slot: Vector3, center: Vector3) -> void:
	site_id = id
	_slot = slot
	_site_center = center
	_stuck = 0.0
	state = State.WORK_GO
	_request_path(slot)
	if Vector2(slot.x - position.x, slot.z - position.z).length() > 110.0:
		position = slot


## Va quelque part puis y fait une activité pendant `dur` secondes.
## act : "idle", "sit", "pickup", "chat", "home" (rentrer chez soi), "dance".
## `arrive` : appelé à l'arrivée (remplace l'éventuel précédent).
func go(pos: Vector3, act: String, dur: float, face := Vector3.INF, arrive := Callable()) -> void:
	on_arrive = arrive
	_goal = pos
	_goal_face = face
	activity = act
	_timer = dur
	_stuck = 0.0
	idle_time = 0.0
	state = State.GO
	_request_path(pos)
	if Vector2(pos.x - position.x, pos.z - position.z).length() > 110.0:
		position = pos  # vraiment trop loin : il arrive directement


## Rentré chez lui : invisible jusqu'au matin.
func enter_home() -> void:
	state = State.HOME
	activity = "home"
	visible = false
	_label.visible = false


func leave_home(door: Vector3) -> void:
	position = door
	home = door
	visible = true
	state = State.IDLE
	activity = ""
	idle_time = 0.0
	_timer = randf_range(1.0, 3.0)


func is_free() -> bool:
	return state == State.IDLE or state == State.WALK


## Petite bulle et petit son (« Hm-hm ! ») quand il parle à un voisin.
func chatter() -> void:
	say(CHATTER.pick_random(), 2.0)


## Une phrase dans une bulle au-dessus de la tête (et un petit son).
func say(text: String, dur := 3.0) -> void:
	if _bubble == null:
		_bubble = Label3D.new()
		_bubble.font = UIStyle.font()
		_bubble.font_size = 26
		_bubble.outline_size = 9
		_bubble.modulate = UIStyle.TEXT
		_bubble.outline_modulate = Color(1, 1, 1, 0.95)
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.fixed_size = true
		_bubble.pixel_size = 0.001
		_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubble.width = 420.0
		# Le texte pousse vers le haut à partir d'au-dessus de la tête.
		_bubble.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_bubble.position.y = _label.position.y + 0.1
		add_child(_bubble)
	_bubble.text = text
	_bubble.visible = true
	_label.visible = false
	_bubble_t = dur
	if visible and is_inside_tree():
		Audio.play("talk", -12.0, 0.15, voice)


## Fait coucou au joueur qui passe (sans se lever s'il est assis).
func wave(at: Vector3, text: String) -> void:
	if activity != "sit":
		var d := at - position
		_facing = atan2(d.x, d.z)
		_celebrate = 1.0
	say(text, 2.2)


## Prolonge l'activité en cours (une conversation sur le banc...).
func stay(seconds: float) -> void:
	if state == State.ACT:
		_timer = maxf(_timer, seconds)


func release() -> void:
	site_id = ""
	state = State.IDLE
	home = position
	_timer = randf_range(0.5, 2.0)


func is_working() -> bool:
	return state == State.WORKING


func _process(delta: float) -> void:
	_anim += delta
	_timer -= delta
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0 and _bubble:
			_bubble.visible = false
	match state:
		State.HOME:
			return
		State.GO:
			if _move_to(_goal, 1.9, delta):
				state = State.ACT
				if _goal_face != Vector3.INF:
					var fd := _goal_face - position
					_facing = atan2(fd.x, fd.z)
				if activity == "home":
					enter_home()
					return
				if activity == "chat":
					chatter()
				if on_arrive.is_valid():
					var cb := on_arrive
					on_arrive = Callable()
					cb.call()
		State.ACT:
			if _timer <= 0.0:
				activity = ""
				state = State.IDLE
				home = position
				_timer = randf_range(1.0, 3.0)
		State.WORK_GO:
			_go_to_site(delta)
		State.WORKING:
			var d := _site_center - position
			_facing = atan2(d.x, d.z)
		State.IDLE:
			idle_time += delta
			if _timer <= 0.0:
				_pick_target()
		State.TALK:
			if _timer <= 0.0:
				state = State.IDLE
				_timer = randf_range(1.0, 3.0)
		State.WALK:
			_walk(delta)

	# Garde l'habitant posé sur le sol.
	var gy := _ground_at(position.x, position.z, position.y + 1.4)
	if gy > -100.0:
		position.y = lerpf(position.y, gy, minf(1.0, delta * 10.0))
	rotation.y = lerp_angle(rotation.y, _facing, minf(1.0, delta * 7.0))

	if _human:
		_animate_human(delta)
		return
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


func _go_to_site(delta: float) -> void:
	if _move_to(_slot, 2.4, delta):
		state = State.WORKING


func _request_path(target: Vector3) -> void:
	_path = PackedVector3Array()
	_pi = 0
	_need_path = nav != null
	_job = {}
	_path_for = target


## Marche vers une cible en suivant son chemin ; renvoie true une fois arrivé.
## Sans chemin (ou s'il reste bloqué), il « fait le tour » : il arrive après
## un court moment.
func _move_to(target: Vector3, speed: float, delta: float) -> bool:
	if Vector2(target.x - position.x, target.z - position.z).length() < 0.6:
		_need_path = false
		_path = PackedVector3Array()
		return true
	if _need_path:
		# La recherche du chemin se fait par petits bouts, image après image.
		if _job.is_empty():
			_job = nav.start(position, target)
		var n := mini(nav.budget, 150)
		if n <= 0 and not _job["done"]:
			return false
		nav.budget -= n
		if not nav.step(_job, n):
			return false
		_need_path = false
		_path = _job["result"]
		_job = {}
		_pi = 0
	if _pi < _path.size():
		var wp := _path[_pi]
		var tw := wp - position
		tw.y = 0.0
		if tw.length() < 0.35:
			_pi += 1
			_stuck = 0.0
			return false
		var d := tw.normalized()
		_facing = atan2(d.x, d.z)
		position.x += d.x * speed * delta
		position.z += d.z * speed * delta
		_stuck += delta * 0.15
		if _stuck > 3.0:
			position = wp
			_stuck = 0.0
		return false
	var to := target - position
	to.y = 0.0
	if to.length() < 0.6:
		return true
	var dir := to.normalized()
	_facing = atan2(dir.x, dir.z)
	var probe := position + dir * 0.45
	var gy := _ground_at(probe.x, probe.z, position.y + 1.4)
	if gy < -100.0 or gy - position.y > 1.1 or gy < IslandGenerator.SEA + 1.0:
		_stuck += delta
	else:
		position.x += dir.x * speed * delta
		position.z += dir.z * speed * delta
		_stuck = maxf(0.0, _stuck - delta * 0.5)
	if _stuck > 2.0:
		position = target
		return true
	return false


func _animate_human(delta: float) -> void:
	if _anim_player == null:
		return
	if state == State.WORKING:
		# Coups de marteau en boucle.
		var a := "attack-melee-right" if int(_anim / 1.6) % 3 != 2 else "interact-right"
		if not _anim_player.is_playing() or _anim_player.current_animation != a:
			_anim_player.play(a, 0.1)
		return
	if state == State.ACT:
		var a := {"sit": "sit", "pickup": "pick-up", "dance": "emote-yes", "chat": "emote-yes"}.get(activity, "idle") as String
		if a == "pick-up" or a == "emote-yes":
			if not _anim_player.is_playing() or _anim_player.current_animation != a:
				_anim_player.play(a, 0.2)
			return
		if _anim_player.has_animation(a) and _anim_player.current_animation != a:
			_anim_player.play(a, 0.25)
		return
	var want := "walk" if state in [State.WALK, State.WORK_GO, State.GO] else "idle"
	if _celebrate > 0.0:
		_celebrate -= delta
		want = "emote-yes"
	elif state == State.TALK and _timer > 4.2:
		want = "emote-yes"
	if _anim_player.has_animation(want) and _anim_player.current_animation != want:
		_anim_player.play(want, 0.2)


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
