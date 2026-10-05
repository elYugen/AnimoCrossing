class_name TitleMenu
extends CanvasLayer
## Menu de démarrage : l'île tourne en fond pendant qu'on choisit
## Continuer / Nouvelle partie / Options / Crédits / Quitter.

signal play_requested(new_game: bool)

const CREDITS := "Personnages voxel : Kenney — Blocky Characters (CC0)\nBruitages : Kenney — Impact, Interface, RPG, Casino, Jingles (CC0)\n\nMusiques (OpenGameArt, CC0) :\n« Hush Hamlet » — Zane Little Music\n« Bossa Town » — KarateStudios\n« Snow Theme » — CleytonKauffman\n« Apple Cider » — Zane Little Music"

var main: Node

var _root: Control
var _logo: Control
var _continue: Button
var _new: Button
var _menu: VBoxContainer
var _options: Control
var _credits: Control
var _skin_label: Label
var _admin_button: Button
var _t := 0.0


func setup(m: Node) -> void:
	main = m


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	add_child(_root)

	# Léger voile pour la lisibilité.
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(1.0, 0.97, 0.9, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 26)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)

	# Logo
	_logo = VBoxContainer.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_logo)
	var title := UIStyle.title("Animo", 110)
	title.add_theme_color_override("font_color", Color("7bc95a"))
	title.add_theme_color_override("font_outline_color", Color("fff8ec"))
	title.add_theme_constant_override("outline_size", 28)
	title.add_theme_color_override("font_shadow_color", Color(0.35, 0.25, 0.15, 0.35))
	title.add_theme_constant_override("shadow_offset_y", 8)
	_logo.add_child(title)
	var sub := UIStyle.title("L'archipel des créatures", 26)
	sub.add_theme_color_override("font_color", UIStyle.TEXT)
	sub.add_theme_color_override("font_outline_color", Color("fff8ec"))
	sub.add_theme_constant_override("outline_size", 10)
	_logo.add_child(sub)

	# Boutons
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 26, UIStyle.BORDER, 4, 24))
	center.add_child(panel)
	_menu = VBoxContainer.new()
	_menu.custom_minimum_size = Vector2(340, 0)
	_menu.add_theme_constant_override("separation", 10)
	panel.add_child(_menu)
	_continue = UIStyle.colored_button("Continuer", UIStyle.GREEN, 22)
	_continue.pressed.connect(func(): play_requested.emit(false))
	_menu.add_child(_continue)
	_new = UIStyle.colored_button("Nouvelle partie", UIStyle.BLUE, 22)
	_new.pressed.connect(_on_new)
	_menu.add_child(_new)
	var opt := UIStyle.button("Options", 20)
	opt.pressed.connect(func(): _options.visible = true)
	_menu.add_child(opt)
	var cred := UIStyle.button("Crédits", 20)
	cred.pressed.connect(func(): _credits.visible = true)
	_menu.add_child(cred)
	var quit := UIStyle.button("Quitter", 20)
	quit.pressed.connect(func(): get_tree().quit())
	_menu.add_child(quit)

	var foot := UIStyle.label("v0.3 · Assets Kenney & OpenGameArt (CC0)", 13, UIStyle.TEXT_SOFT)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	foot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.position -= Vector2(16, 12)
	_root.add_child(foot)

	_build_options()
	_build_credits()
	show_menu()


func _build_options() -> void:
	var m := UIStyle.modal("Options", Vector2(460, 0))
	_options = m["root"]
	_options.visible = false
	_root.add_child(_options)
	(m["close"] as Button).pressed.connect(func(): _options.visible = false)
	var body: VBoxContainer = m["body"]
	body.add_child(_slider("Musique", Game.music_volume, func(v):
		Game.music_volume = v
		Audio.apply_volumes()))
	body.add_child(_slider("Sons", Game.sfx_volume, func(v):
		Game.sfx_volume = v
		Audio.apply_volumes()
		Audio.play("click", -6.0)))
	var skin_row := HBoxContainer.new()
	skin_row.add_theme_constant_override("separation", 8)
	body.add_child(skin_row)
	var prev := UIStyle.button("◀", 18)
	skin_row.add_child(prev)
	_skin_label = UIStyle.title("", 18)
	_skin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_row.add_child(_skin_label)
	var nxt := UIStyle.button("▶", 18)
	skin_row.add_child(nxt)
	prev.pressed.connect(func(): _change_skin(-1))
	nxt.pressed.connect(func(): _change_skin(1))
	_admin_button = UIStyle.button("", 18)
	_admin_button.pressed.connect(func():
		Game.admin = not Game.admin
		Game.save_game()
		_refresh_options())
	body.add_child(_admin_button)
	var hint := UIStyle.label("Mode admin : tout débloqué, gacha gratuit, vol libre (V).", 14, UIStyle.TEXT_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 400
	body.add_child(hint)
	_refresh_options()


func _build_credits() -> void:
	var m := UIStyle.modal("Crédits", Vector2(560, 0))
	_credits = m["root"]
	_credits.visible = false
	_root.add_child(_credits)
	(m["close"] as Button).pressed.connect(func(): _credits.visible = false)
	var l := UIStyle.label(CREDITS, 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 500
	(m["body"] as VBoxContainer).add_child(l)


func _slider(text: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UIStyle.label(text, 17)
	l.custom_minimum_size.x = 90
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.drag_ended.connect(func(_c): on_change.call(sl.value))
	row.add_child(sl)
	return row


func _change_skin(step: int) -> void:
	Game.player_skin = Player.next_skin(Game.player_skin, step)
	main.player.set_skin(Game.player_skin)
	Game.save_game()
	_refresh_options()


func _refresh_options() -> void:
	_skin_label.text = "Apparence : %s" % Game.player_skin.to_upper()
	_admin_button.text = "Mode admin : %s" % ("ACTIVÉ" if Game.admin else "désactivé")


func _on_new() -> void:
	# Confirmation si une partie existe déjà.
	if Game.has_save() and _new.text == "Nouvelle partie":
		_new.text = "Effacer la partie ? Confirmer"
		return
	_new.text = "Nouvelle partie"
	play_requested.emit(true)


## Affiche le menu (au lancement ou au retour depuis le jeu).
func show_menu() -> void:
	visible = true
	_options.visible = false
	_credits.visible = false
	_new.text = "Nouvelle partie"
	_continue.visible = Game.has_save()
	_refresh_options()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_logo.position.y = sin(_t * 1.6) * 6.0
