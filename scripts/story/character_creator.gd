class_name CharacterCreator
extends CanvasLayer
## Création du personnage : nom, tête / coiffure et tenue, avec un aperçu 3D
## que l'on peut faire tourner à la souris.

signal confirmed(player_name: String, skin: String, head: String)
signal cancelled

const MAX_NAME := 14
const NAME_IDEAS := ["Lou", "Sacha", "Noa", "Céleste", "Robin", "Alix", "Maé", "Charlie", "Eden", "Sasha", "Jo", "Ilan"]

var skin := "a"
var head := "a"

var _name_edit: LineEdit
var _head_label: Label
var _skin_label: Label
var _error: Label
var _panel: PanelContainer
var _viewport: SubViewport
var _holder: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _dragging := false
var _spin := 0.0


func _ready() -> void:
	layer = 30
	skin = Game.player_skin
	head = Game.player_head
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.2, 0.15, 0.1, 0.35)
	root.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 28, UIStyle.BORDER, 4, 28))
	center.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	_panel.add_child(vb)
	vb.add_child(UIStyle.title("Qui es-tu, voyageur ?", 34))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 28)
	vb.add_child(hb)

	# Aperçu 3D
	var pv_box := PanelContainer.new()
	pv_box.add_theme_stylebox_override("panel", UIStyle.box(Color("dff1fb"), 22, Color("bfdcef"), 3, 6))
	hb.add_child(pv_box)
	var pv_vb := VBoxContainer.new()
	pv_box.add_child(pv_vb)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(330, 400)
	svc.mouse_default_cursor_shape = Control.CURSOR_DRAG
	svc.gui_input.connect(_on_preview_input)
	pv_vb.add_child(svc)
	_build_viewport(svc)
	var hint := UIStyle.title("Glisse pour faire tourner", 14)
	hint.add_theme_color_override("font_color", UIStyle.TEXT_SOFT)
	pv_vb.add_child(hint)

	# Réglages
	var form := VBoxContainer.new()
	form.custom_minimum_size = Vector2(380, 0)
	form.add_theme_constant_override("separation", 10)
	hb.add_child(form)
	form.add_child(UIStyle.label("Comment t'appelles-tu ?", 20))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Ton prénom"
	_name_edit.max_length = MAX_NAME
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.add_theme_color_override("font_color", UIStyle.TEXT)
	_name_edit.add_theme_color_override("font_placeholder_color", Color("b8aa98"))
	_name_edit.add_theme_color_override("caret_color", UIStyle.TEXT)
	_name_edit.add_theme_stylebox_override("normal", UIStyle.box(Color.WHITE, 14, UIStyle.BORDER, 3, 14))
	_name_edit.add_theme_stylebox_override("focus", UIStyle.box(Color.WHITE, 14, UIStyle.GREEN, 3, 14))
	_name_edit.text = Game.player_name
	_name_edit.text_submitted.connect(func(_t): _confirm())
	_name_edit.text_changed.connect(func(_t): _error.text = "")
	form.add_child(_name_edit)
	var name_row := HBoxContainer.new()
	form.add_child(name_row)
	_error = UIStyle.label("", 14, Color("d4542a"))
	_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_error)
	var idea := UIStyle.button("Une idée ?", 14)
	idea.pressed.connect(func():
		_name_edit.text = NAME_IDEAS.pick_random()
		_error.text = "")
	name_row.add_child(idea)

	form.add_child(UIStyle.label("Tête & coiffure", 20))
	_head_label = UIStyle.title("", 18)
	form.add_child(_arrows(_head_label, func(step): _set_look(skin, Player.next_skin(head, step))))
	form.add_child(UIStyle.label("Tenue", 20))
	_skin_label = UIStyle.title("", 18)
	form.add_child(_arrows(_skin_label, func(step): _set_look(Player.next_skin(skin, step), head)))
	var rnd := UIStyle.colored_button("Au hasard !", UIStyle.PINK, 18)
	rnd.pressed.connect(func():
		_set_look(Player.SKINS[randi() % Player.SKINS.length()], Player.SKINS[randi() % Player.SKINS.length()]))
	form.add_child(rnd)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(spacer)
	var go := UIStyle.colored_button("Commencer l'aventure", UIStyle.GREEN, 24)
	go.custom_minimum_size.y = 58
	go.pressed.connect(_confirm)
	form.add_child(go)
	var back := UIStyle.button("Retour", 17)
	back.pressed.connect(func(): cancelled.emit())
	form.add_child(back)

	_set_look(skin, head, false)
	_name_edit.call_deferred("grab_focus")

	# Apparition en douceur.
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.35)


func _arrows(lbl: Label, on_step: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var prev := UIStyle.button("◀", 18)
	prev.custom_minimum_size = Vector2(52, 0)
	prev.pressed.connect(func(): on_step.call(-1))
	row.add_child(prev)
	var lp := PanelContainer.new()
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.add_theme_stylebox_override("panel", UIStyle.box(Color("fffdf6"), 14, UIStyle.BORDER, 2, 8))
	lp.add_child(lbl)
	row.add_child(lp)
	var nxt := UIStyle.button("▶", 18)
	nxt.custom_minimum_size = Vector2(52, 0)
	nxt.pressed.connect(func(): on_step.call(1))
	row.add_child(nxt)
	return row


func _build_viewport(svc: SubViewportContainer) -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_viewport)
	var cam := Camera3D.new()
	cam.fov = 32
	_viewport.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.0, 4.1), Vector3(0, 0.68, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	light.light_energy = 1.1
	_viewport.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff4e6")
	e.ambient_light_energy = 0.6
	env.environment = e
	_viewport.add_child(env)
	_holder = Node3D.new()
	_viewport.add_child(_holder)
	# Petit socle d'herbe.
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.8
	cyl.height = 0.12
	var bm := StandardMaterial3D.new()
	bm.albedo_color = UIStyle.GREEN
	cyl.material = bm
	base.mesh = cyl
	base.position.y = -0.06
	_viewport.add_child(base)


func _set_look(new_skin: String, new_head: String, animate := true) -> void:
	skin = new_skin
	head = new_head
	_head_label.text = "Style %d / %d" % [Player.SKINS.find(head) + 1, Player.SKINS.length()]
	_skin_label.text = "Style %d / %d" % [Player.SKINS.find(skin) + 1, Player.SKINS.length()]
	if _model:
		_model.queue_free()
	_model = Player.build_model(skin, head)
	if _model == null:
		return
	_holder.add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		_anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		_anim.animation_finished.connect(func(_n): _anim.play("idle", 0.2))
		if animate and _anim.has_animation("emote-yes"):
			_anim.play("emote-yes")
		else:
			_anim.play("idle")
	if animate:
		Audio.play("select", -8.0)


func _on_preview_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (ev as InputEventMouseButton).pressed
	elif ev is InputEventMouseMotion and _dragging:
		_holder.rotation.y += (ev as InputEventMouseMotion).relative.x * 0.012
		_spin = 2.5


func _confirm() -> void:
	var n := _name_edit.text.strip_edges()
	if n.is_empty():
		_error.text = "Il te faut un prénom !"
		Audio.play("error", -6.0)
		_name_edit.grab_focus()
		var tw := create_tween()
		for dx in [10.0, -10.0, 6.0, -6.0, 0.0]:
			tw.tween_property(_panel, "position:x", _panel.position.x + dx, 0.04)
		return
	Audio.play("confirm", -4.0, 0.0)
	confirmed.emit(n, skin, head)


func _process(delta: float) -> void:
	# Rotation lente quand on ne manipule pas l'aperçu.
	_spin = maxf(0.0, _spin - delta)
	if not _dragging and _spin <= 0.0:
		_holder.rotation.y = lerp_angle(_holder.rotation.y, sin(Time.get_ticks_msec() * 0.0006) * 0.5, delta * 2.0)
