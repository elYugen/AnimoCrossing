class_name UIStyle
extends RefCounted
## Thème « cozy » de l'interface : panneaux crème arrondis, texte brun.

const TEXT := Color("5a4636")
const TEXT_SOFT := Color("8a7563")
const CREAM := Color("fff8ec")
const PANEL := Color(1.0, 0.985, 0.95, 0.96)
const BORDER := Color("ecd9bb")
const GREEN := Color("7bc95a")
const GREEN_DARK := Color("5aa33f")
const STAR := Color("f5b83d")
const PINK := Color("f59ac2")
const BLUE := Color("6aa8f2")

const POWER_NAMES := ["Casser", "Poser", "Fleurir", "Pousser"]
const POWER_COLORS := [Color("f29a45"), Color("6aa8f2"), Color("f07fb0"), Color("6cbf4a")]

static var _theme: Theme
static var _font: SystemFont


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Nunito", "Quicksand", "Varela Round", "Segoe UI", "Arial"])
		_font.font_weight = 700
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _font


static func box(bg: Color, radius := 18, border := BORDER, border_w := 3, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	s.shadow_color = Color(0.35, 0.25, 0.15, 0.18)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.anti_aliasing = true
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("panel", "Panel", box(PANEL))

	var bn := box(CREAM, 14, BORDER, 3, 12)
	var bh := box(Color("fffdf6"), 14, GREEN, 3, 12)
	var bp := box(Color("eaf7df"), 14, GREEN_DARK, 3, 12)
	bp.shadow_size = 2
	var bd := box(Color("f1ebe2"), 14, Color("e0d6c8"), 3, 12)
	bd.shadow_size = 0
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", GREEN_DARK)
	t.set_color("font_disabled_color", "Button", Color("b8aa98"))

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("efe4d2")
	bg.set_corner_radius_all(8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = GREEN
	fg.set_corner_radius_all(8)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fg)
	t.set_color("font_color", "ProgressBar", TEXT)

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0, 0, 0, 0.05)
	sb_bg.set_corner_radius_all(6)
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = BORDER
	sb_grab.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", sb_bg)
	t.set_stylebox("grabber", "VScrollBar", sb_grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb_grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", sb_grab)
	_theme = t
	return t


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size := 28) -> Label:
	var l := label(text, size, TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): Audio.play("click", -6.0))
	return b


static func colored_button(text: String, col: Color, size := 18) -> Button:
	var b := button(text, size)
	var n := box(col, 14, col.darkened(0.2), 3, 12)
	var h := box(col.lightened(0.12), 14, col.darkened(0.25), 3, 12)
	var p := box(col.darkened(0.08), 14, col.darkened(0.3), 3, 12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_outline_color", col.darkened(0.35))
	b.add_theme_constant_override("outline_size", 4)
	return b


## Panneau modal centré avec titre et bouton de fermeture.
static func modal(title_text: String, min_size: Vector2) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.15, 0.1, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", box(PANEL, 26, BORDER, 4, 22))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := label(title_text, 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := button("✕", 20)
	close.custom_minimum_size = Vector2(44, 44)
	head.add_child(close)
	return {"root": root, "panel": panel, "body": vb, "close": close, "title": t}
