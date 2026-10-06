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
	shade.color = Color(0.1, 0.12, 0.06, 0.45)
	root.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.frame(30, 28))
	center.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	var title := UIStyle.title("Qui es-tu, voyageur ?", 38)
	title.add_theme_color_override("font_color", UIStyle.FRAME)
	vb.add_child(title)
	vb.add_child(UIStyle.title("Choisis ton nom et ton allure avant de prendre la mer.", 16))
	(vb.get_child(1) as Label).add_theme_color_override("font_color", UIStyle.TEXT_SOFT)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	vb.add_child(gap)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	vb.add_child(hb)

	# Aperçu 3D, sur un socle d'herbe.
	var pv_box := PanelContainer.new()
	var pst := UIStyle.box(Color("e7f2da"), 24, UIStyle.BORDER, 3, 8)
	pst.shadow_size = 0
	pv_box.add_theme_stylebox_override("panel", pst)
	hb.add_child(pv_box)
	var pv_vb := VBoxContainer.new()
	pv_box.add_child(pv_vb)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(340, 410)
	svc.mouse_default_cursor_shape = Control.CURSOR_DRAG
	svc.gui_input.connect(_on_preview_input)
	pv_vb.add_child(svc)
	_build_viewport(svc)
	var hint := UIStyle.title("Glisse pour faire tourner", 14)
	hint.add_theme_color_override("font_color", UIStyle.TEXT_SOFT)
	pv_vb.add_child(hint)

	# Réglages
	var form := VBoxContainer.new()
	form.custom_minimum_size = Vector2(400, 0)
	form.add_theme_constant_override("separation", 10)
	hb.add_child(form)
	form.add_child(_section("Ton prénom"))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	form.add_child(name_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Ton prénom"
	_name_edit.max_length = MAX_NAME
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.text = Game.player_name
	_name_edit.text_submitted.connect(func(_t): _confirm())
	_name_edit.text_changed.connect(func(_t): _error.text = "")
	name_row.add_child(_name_edit)
	var idea := UIStyle.button("Une idée ?", 15)
	idea.pressed.connect(func():
		_name_edit.text = NAME_IDEAS.pick_random()
		_error.text = "")
	name_row.add_child(idea)
	_error = UIStyle.label("", 14, Color("d4542a"))
	form.add_child(_error)

	form.add_child(_section("Tête & coiffure"))
	_head_label = UIStyle.title("", 19)
	form.add_child(_arrows(_head_label, func(step): _set_look(skin, Player.next_skin(head, step))))
	form.add_child(_section("Tenue"))
	_skin_label = UIStyle.title("", 19)
	form.add_child(_arrows(_skin_label, func(step): _set_look(Player.next_skin(skin, step), head)))
	var rnd := UIStyle.button("Au hasard", 17)
	rnd.pressed.connect(func():
		_set_look(Player.SKINS[randi() % Player.SKINS.length()], Player.SKINS[randi() % Player.SKINS.length()]))
	form.add_child(rnd)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(spacer)
	var go := UIStyle.colored_button("Commencer l'aventure", UIStyle.GREEN, 26)
	go.custom_minimum_size.y = 66
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


## Intitulé de rubrique (petites capitales vertes).
func _section(text: String) -> Label:
	var l := UIStyle.label(text.to_upper(), 14, UIStyle.GREEN_DARK)
	l.add_theme_font_override("font", UIStyle.title_font())
	return l


func _arrows(lbl: Label, on_step: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var prev := UIStyle.button("◀", 18)
	prev.custom_minimum_size = Vector2(52, 0)
	prev.pressed.connect(func(): on_step.call(-1))
	row.add_child(prev)
	var lp := PanelContainer.new()
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lst := UIStyle.box(Color.WHITE, 14, UIStyle.BORDER, 2, 8)
	lst.shadow_size = 0
	lp.add_theme_stylebox_override("panel", lst)
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
	# Petit socle : un bloc d'herbe sur de la terre, à la façon des îles.
	for layer_i in 2:
		var base := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(1.4, 0.12 if layer_i == 0 else 0.28, 1.4)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color("7bc95a") if layer_i == 0 else Color("a9784e")
		bx.material = bm
		base.mesh = bx
		base.position.y = -0.06 if layer_i == 0 else -0.26
		_viewport.add_child(base)


func _set_look(new_skin: String, new_head: String, animate := true) -> void:
	skin = new_skin
	head = new_head
	_head_label.text = "%d / %d" % [Player.SKINS.find(head) + 1, Player.SKINS.length()]
	_skin_label.text = "%d / %d" % [Player.SKINS.find(skin) + 1, Player.SKINS.length()]
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
