class_name UIStyle
extends RefCounted
## Thème d'Evergrove, inspiré du logo : papier crème, cadres vert forêt,
## boutons en relief (on les enfonce), titres en Fredoka, texte en Nunito.
## Polices : assets/fonts (SIL Open Font License).

# Couleurs
const TEXT := Color("3b2a1e")  # encre
const TEXT_SOFT := Color("7a634f")
const CREAM := Color("fff8e8")  # papier
const PAPER_DARK := Color("f3e6c9")
const PANEL := Color(1.0, 0.973, 0.91, 0.97)
const BORDER := Color("dcc59b")  # bordure claire (boutons, cases)
const FRAME := Color("2f5e2b")  # cadre vert forêt (fenêtres, cartes du HUD)
const GREEN := Color("6fbf4a")
const GREEN_DARK := Color("3f8a32")
const STAR := Color("f5c24b")
const PINK := Color("ec7fa6")
const BLUE := Color("3aa3d8")

const POWER_NAMES := ["Casser", "Poser", "Fleurir", "Pousser"]
const POWER_COLORS := [Color("f29a45"), Color("3aa3d8"), Color("ec7fa6"), Color("6fbf4a")]

const FONT_TITLE := "res://assets/fonts/Fredoka.ttf"
const FONT_BODY := "res://assets/fonts/Nunito.ttf"

static var _theme: Theme
static var _font: Font
static var _title_font: Font


static func _variation(path: String, weight: int) -> Font:
	var base := load(path) as FontFile
	if base == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Nunito", "Segoe UI", "Arial"])
		sf.font_weight = weight
		return sf
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv


## Police du texte (Nunito, gras).
static func font() -> Font:
	if _font == null:
		_font = _variation(FONT_BODY, 700)
	return _font


## Police des titres et des boutons (Fredoka, ronde et épaisse comme le logo).
static func title_font() -> Font:
	if _title_font == null:
		_title_font = _variation(FONT_TITLE, 600)
	return _title_font


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
	s.shadow_color = Color(0.18, 0.13, 0.07, 0.22)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	s.anti_aliasing = true
	return s


## Panneau principal : papier crème et cadre vert forêt.
static func frame(radius := 24, pad := 20) -> StyleBoxFlat:
	return box(PANEL, radius, FRAME, 4, pad)


## Bouton en relief : un contour foncé, plus épais en bas (la « lèvre »),
## qui s'aplatit quand on l'enfonce (le texte descend un peu).
static func _button_box(bg: Color, border: Color, lip: Color, pressed := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(16)
	s.border_color = border if pressed else lip
	s.set_border_width_all(3)
	s.border_width_bottom = 3 if pressed else 7
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 11 if pressed else 8
	s.content_margin_bottom = 6 if pressed else 9
	s.shadow_color = Color(0.18, 0.13, 0.07, 0.0 if pressed else 0.18)
	s.shadow_size = 4
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
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 20, BORDER, 3, 14))
	t.set_stylebox("panel", "Panel", box(PANEL, 20, BORDER, 3, 14))

	t.set_stylebox("normal", "Button", _button_box(CREAM, BORDER, Color("c9ad7c")))
	t.set_stylebox("hover", "Button", _button_box(Color("fffcf3"), GREEN, GREEN_DARK))
	t.set_stylebox("pressed", "Button", _button_box(Color("eef7e4"), GREEN_DARK, GREEN_DARK, true))
	var bd := _button_box(Color("efe7da"), Color("e0d6c8"), Color("d6cab8"))
	bd.shadow_size = 0
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", title_font())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", GREEN_DARK)
	t.set_color("font_disabled_color", "Button", Color("b8aa98"))

	var edit := box(Color.WHITE, 14, BORDER, 3, 14)
	edit.shadow_size = 0
	var edit_focus := box(Color.WHITE, 14, GREEN, 3, 14)
	edit_focus.shadow_size = 0
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit_focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color("b8aa98"))
	t.set_color("caret_color", "LineEdit", TEXT)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("ead9b8")
	bg.set_corner_radius_all(8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = GREEN
	fg.set_corner_radius_all(8)
	fg.border_color = GREEN_DARK
	fg.border_width_bottom = 3
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fg)
	t.set_color("font_color", "ProgressBar", TEXT)

	# Curseurs (volumes).
	var track := StyleBoxFlat.new()
	track.bg_color = Color("ead9b8")
	track.set_corner_radius_all(6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = GREEN
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)

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

	var tip := box(Color("3b2a1e"), 10, Color("3b2a1e"), 0, 10)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", CREAM)
	_theme = t
	return t


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Titre centré (Fredoka).
static func title(text: String, size := 28) -> Label:
	var l := label(text, size, TEXT)
	l.add_theme_font_override("font", title_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): Audio.play("click", -6.0))
	return b


## Bouton coloré (action principale).
static func colored_button(text: String, col: Color, size := 18) -> Button:
	var b := button(text, size)
	b.add_theme_stylebox_override("normal", _button_box(col, col.darkened(0.25), col.darkened(0.4)))
	b.add_theme_stylebox_override("hover", _button_box(col.lightened(0.1), col.darkened(0.25), col.darkened(0.42)))
	b.add_theme_stylebox_override("pressed", _button_box(col.darkened(0.06), col.darkened(0.35), col.darkened(0.35), true))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_outline_color", col.darkened(0.45))
	b.add_theme_constant_override("outline_size", 6)
	return b


## Petite étiquette arrondie (nom de celui qui parle, badge...).
static func tag(text: String, col := FRAME, size := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(col, 12, col.darkened(0.2), 0, 10)
	s.content_margin_top = 3
	s.content_margin_bottom = 4
	s.shadow_size = 3
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, size, CREAM)
	l.add_theme_font_override("font", title_font())
	l.name = "Text"
	p.add_child(l)
	return p


## Panneau modal centré : cadre vert, titre en Fredoka, bouton de fermeture
## rond, séparateur sous l'en-tête.
static func modal(title_text: String, min_size: Vector2) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.06, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", frame(28, 24))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	var t := label(title_text, 32, FRAME)
	t.add_theme_font_override("font", title_font())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := button("✕", 20)
	close.custom_minimum_size = Vector2(48, 48)
	head.add_child(close)
	var sep := ColorRect.new()
	sep.color = Color(BORDER, 0.8)
	sep.custom_minimum_size = Vector2(0, 3)
	vb.add_child(sep)
	return {"root": root, "panel": panel, "body": vb, "close": close, "title": t}
