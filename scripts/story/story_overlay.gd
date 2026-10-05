class_name StoryOverlay
extends CanvasLayer
## Couche « narration » : écran noir, bulles de pensée (texte qui s'écrit),
## paupières qui s'ouvrent, bandes cinéma et carton de titre.
## Échap passe la séquence (`skipped`).

signal advanced

const CHARS_PER_SEC := 34.0
const LETTERBOX := 0.1

var skipped := false
var speaker := ""

var _root: Control
var _top: ColorRect
var _bottom: ColorRect
var _flash: ColorRect
var _bubble_wrap: Control
var _bubble: PanelContainer
var _name: Label
var _text: Label
var _more: Label
var _title: Label
var _subtitle: Label
var _skip_hint: Label
var _typing := false
var _waiting := false
var _lid := 0.5  # 0.5 = yeux fermés, LETTERBOX = bandes cinéma, 0 = rien


func _ready() -> void:
	layer = 40
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	add_child(_root)
	_top = _black()
	_bottom = _black()
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.55, 0.05, 0.05, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_set_lid(0.5)

	# Bulle de texte, en bas de l'écran.
	_bubble_wrap = MarginContainer.new()
	_bubble_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bubble_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_wrap.add_theme_constant_override("margin_bottom", 60)
	_root.add_child(_bubble_wrap)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_END
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 0)
	_bubble_wrap.add_child(col)
	_bubble = PanelContainer.new()
	_bubble.custom_minimum_size = Vector2(720, 0)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.CREAM, 34, UIStyle.BORDER, 4, 30))
	col.add_child(_bubble)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	_bubble.add_child(vb)
	_name = UIStyle.label("", 16, UIStyle.TEXT_SOFT)
	vb.add_child(_name)
	_text = UIStyle.title("", 28)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(660, 44)
	vb.add_child(_text)
	_more = UIStyle.label("▶ clic", 14, UIStyle.TEXT_SOFT)
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_more)
	_bubble_wrap.modulate.a = 0.0

	# Carton de titre
	var tc := VBoxContainer.new()
	tc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tc.alignment = BoxContainer.ALIGNMENT_END
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_theme_constant_override("separation", 0)
	tc.offset_bottom = -130
	_root.add_child(tc)
	_title = UIStyle.title("", 64)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 0.8))
	_title.add_theme_constant_override("outline_size", 14)
	tc.add_child(_title)
	_subtitle = UIStyle.title("", 24)
	_subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_subtitle.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 0.7))
	_subtitle.add_theme_constant_override("outline_size", 8)
	tc.add_child(_subtitle)
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0

	_skip_hint = UIStyle.label("Échap : passer", 14, Color(1, 1, 1, 0.35))
	_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip_hint.position -= Vector2(18, 12)
	_root.add_child(_skip_hint)


func _black() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(r)
	return r


## 0.5 : écran noir. LETTERBOX : bandes cinéma. 0 : rien.
func _set_lid(v: float) -> void:
	_lid = v
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.anchor_bottom = v
	_top.offset_bottom = 2.0 if v >= 0.5 else 0.0
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.anchor_top = 1.0 - v
	_bottom.offset_top = 0.0


func _lid_to(v: float, duration: float, trans := Tween.TRANS_SINE) -> void:
	var tw := create_tween()
	tw.tween_method(_set_lid, _lid, v, duration).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back") and not skipped:
		skipped = true
		_skip_hint.visible = false
		advanced.emit()
		get_viewport().set_input_as_handled()
		return
	if not (_typing or _waiting):
		return
	# On avance uniquement au clic.
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if _typing:
			_typing = false
			_text.visible_ratio = 1.0
		elif _waiting:
			advanced.emit()


## Joue une suite de pensées. Chaque ligne : String, ou {"text", "tags"}
## (lignes de Dialogue Manager ; le tag « hurt » secoue l'écran).
## On passe à la ligne suivante uniquement au clic.
func play_lines(lines: Array) -> void:
	_name.text = speaker
	for entry in lines:
		if skipped:
			break
		var line: String = entry if entry is String else entry["text"]
		var fx: String = ""
		if entry is Dictionary and "hurt" in (entry.get("tags", []) as Array):
			fx = "hurt"
		await _show_line(line, fx)
	_waiting = false
	_typing = false
	var tw := create_tween()
	tw.tween_property(_bubble_wrap, "modulate:a", 0.0, 0.4)
	await tw.finished


func _show_line(line: String, fx: String) -> void:
	var silent := line.strip_edges() == "..."
	_text.text = line
	_text.visible_characters = 0
	_more.modulate.a = 0.0
	_bubble_wrap.pivot_offset = _bubble_wrap.size * 0.5
	_bubble_wrap.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bubble_wrap, "modulate:a", 1.0, 0.25)
	tw.tween_property(_bubble_wrap, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if fx == "hurt":
		_hurt()
	# Le texte s'écrit lettre par lettre.
	_typing = true
	var speed := CHARS_PER_SEC * (0.18 if silent else 1.0)
	var total := line.length()
	var shown := 0
	var acc := 0.0
	var pause := 0.0
	while _typing and shown < total and not skipped:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		# Petite pause après la ponctuation (le curseur ne recule jamais).
		if pause > 0.0:
			pause -= dt
			continue
		acc += dt * speed
		while acc >= 1.0 and shown < total:
			acc -= 1.0
			shown += 1
			var ch := line[shown - 1]
			if not silent and ch in ".,?!" and (shown >= total or line[shown] == " "):
				pause = 0.18
				acc = 0.0
				break
			if not silent and shown % 2 == 0 and ch != " ":
				Audio.play("talk", -19.0, 0.12, 1.45)
		_text.visible_characters = shown
	_typing = false
	_text.visible_ratio = 1.0
	if skipped:
		return
	_waiting = true
	create_tween().tween_property(_more, "modulate:a", 1.0, 0.3)
	await advanced
	_waiting = false
	Audio.play("click", -16.0, 0.05, 0.8)
	var out := create_tween()
	out.tween_property(_bubble_wrap, "modulate:a", 0.0, 0.18)
	await out.finished
	await get_tree().create_timer(0.15).timeout


func _hurt() -> void:
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.35, 0.06)
	tw.tween_property(_flash, "color:a", 0.0, 0.7)
	var sh := create_tween()
	for i in 8:
		var a := 14.0 * (1.0 - i / 8.0)
		sh.tween_property(_bubble_wrap, "position", Vector2(randf_range(-a, a), randf_range(-a, a)), 0.035)
	sh.tween_property(_bubble_wrap, "position", Vector2.ZERO, 0.05)


## Les yeux s'ouvrent difficilement : un clignement, puis bandes cinéma.
func open_eyes() -> void:
	_skip_hint.visible = true
	await _lid_to(0.42, 0.9)
	await _lid_to(0.5, 0.25)
	await get_tree().create_timer(0.5).timeout
	await _lid_to(0.3, 0.8)
	await _lid_to(0.47, 0.18)
	await _lid_to(LETTERBOX, 1.4)


## Retire les bandes cinéma.
func clear_bars(duration := 0.8) -> void:
	_skip_hint.visible = false
	await _lid_to(0.0, duration)


## Remet l'écran au noir (ex. au début de l'intro).
func black(duration := 0.6) -> void:
	await _lid_to(0.5, duration)


func show_title(title: String, sub: String, hold := 3.0) -> void:
	_title.text = title
	_subtitle.text = sub
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property(_subtitle, "modulate:a", 1.0, 1.2).set_delay(0.6)
	tw.tween_interval(hold)
	tw.tween_property(_title, "modulate:a", 0.0, 1.0)
	tw.parallel().tween_property(_subtitle, "modulate:a", 0.0, 1.0)

