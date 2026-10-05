class_name HUD
extends CanvasLayer
## Interface en jeu : infos de l'île, objectifs, barre de pouvoirs, palette
## de blocs, dialogues, notifications, tutoriel et panneaux modaux.

signal travel_requested(island_id: String)
signal power_selected(index: int)
signal block_selected(id: int)
signal admin_changed(enabled: bool)

const TUTO := [
	{"text": "Bienvenue sur l'Île Prairie ! Je suis le Pr. Hibou.\nCette île est encore bien calme... Grâce à tes pouvoirs, tu vas pouvoir la façonner et attirer plein de créatures !", "button": "Continuer"},
	{"text": "Déplace-toi avec ZQSD (ou WASD), saute avec Espace et cours avec Maj.\nTourne la caméra en maintenant le clic droit (ou avec les flèches), molette pour zoomer.", "wait": "move"},
	{"text": "Pouvoir n°1 : CASSER !\nAppuie sur 1, vise un bloc proche avec la souris et fais un clic gauche.\nCasse 3 blocs.", "wait": "break", "count": 3},
	{"text": "Pouvoir n°2 : POSER !\nAppuie sur 2 et clique pour poser un bloc. Change de bloc avec R / F ou dans la palette.\nPose 3 blocs.", "wait": "place", "count": 3},
	{"text": "Pouvoir n°3 : FAIRE FLEURIR !\nAppuie sur 3 et clique sur la parcelle de terre à côté de moi pour la couvrir de fleurs.", "wait": "bloom", "count": 1},
	{"text": "Pouvoir n°4 : FAIRE POUSSER !\nAppuie sur 4 et clique sur de l'herbe pour faire pousser un arbre.", "wait": "tree", "count": 1},
	{"text": "Tes fleurs ont attiré quelqu'un ! Les créatures arrivent quand l'île leur plaît.\nApproche-toi d'une créature et appuie sur E pour lui parler.", "wait": "talk", "count": 1},
	{"text": "Ouvre ton Carnet avec C (ou le bouton en bas à droite) : tu y verras qui peut venir sur chaque île et ce qu'il aime.", "wait": "carnet", "count": 1},
	{"text": "Façonner l'île te rapporte des Étoiles ★. Dépense-les à la Machine Gacha (G) pour obtenir des amis rares !\nAvec assez d'amis, de nouvelles îles s'ouvriront sur la Carte (M).\nTiens, voici 200★ pour commencer !", "button": "Merci, Professeur !", "reward": 200},
]
const TUTO_DONE := 9

var main: Node

var _root: Control
var _island_label: Label
var _stars_label: Label
var _friends_label: Label
var _obj_list: VBoxContainer
var _power_slots: Array[PanelContainer] = []
var _block_bar: HBoxContainer
var _block_name: Label
var _block_wrap: VBoxContainer
var _toasts: VBoxContainer
var _dialog: PanelContainer
var _dialog_name: Label
var _dialog_text: Label
var _dialog_lines: Array = []
var _dialog_cb: Callable
var _tuto_panel: PanelContainer
var _tuto_text: Label
var _tuto_button: Button
var _tuto_progress: Label
var _tuto_count := 0
var _popup: Control
var _popup_preview: CreaturePreview
var _popup_name: Label
var _popup_timer := 0.0
var _fade: ColorRect
var _pause: Control
var _skin_label: Label
var _hint_label: Label
var _admin_label: Label
var _admin_button: Button
var _admin_box: VBoxContainer

var _carnet: CarnetPanel
var _gacha: GachaPanel
var _map: MapPanel
var _open_panel: Control = null

var _power := 0
var _block := Blocks.GRASS


func setup(m: Node) -> void:
	main = m


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	add_child(_root)
	_build_top_left()
	_build_objectives()
	_build_hotbar()
	_build_menu_buttons()
	_build_hint()
	_build_toasts()
	_build_dialog()
	_build_tutorial()
	_build_popup()
	_build_pause()
	_fade = ColorRect.new()
	_fade.color = Color("fff8ec")
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	# Couche dédiée : le fondu reste visible même quand le HUD est caché.
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 50
	add_child(fade_layer)
	fade_layer.add_child(_fade)

	Game.stars_changed.connect(func(_v): _refresh_top())
	Game.stats_changed.connect(_refresh_objectives)
	Game.friend_unlocked.connect(func(_id):
		_refresh_top()
		_refresh_objectives())
	Game.action_done.connect(_on_action)


# --- Construction --------------------------------------------------------

func _anchored(preset: int, margin: Vector2) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(preset)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_theme_constant_override("margin_left", int(margin.x))
	mc.add_theme_constant_override("margin_right", int(margin.x))
	mc.add_theme_constant_override("margin_top", int(margin.y))
	mc.add_theme_constant_override("margin_bottom", int(margin.y))
	_root.add_child(mc)
	return mc


func _build_top_left() -> void:
	var mc := _anchored(Control.PRESET_TOP_LEFT, Vector2(18, 16))
	var p := PanelContainer.new()
	mc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	_island_label = UIStyle.label("", 26)
	vb.add_child(_island_label)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	vb.add_child(hb)
	_stars_label = UIStyle.label("", 20, UIStyle.STAR.darkened(0.1))
	hb.add_child(_stars_label)
	_friends_label = UIStyle.label("", 20, UIStyle.GREEN_DARK)
	hb.add_child(_friends_label)
	_admin_label = UIStyle.label("", 15, Color("d4542a"))
	_admin_label.visible = false
	vb.add_child(_admin_label)


func _build_objectives() -> void:
	var mc := _anchored(Control.PRESET_TOP_RIGHT, Vector2(18, 16))
	mc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(300, 0)
	mc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	vb.add_child(UIStyle.label("Amis à attirer", 20))
	_obj_list = VBoxContainer.new()
	_obj_list.add_theme_constant_override("separation", 6)
	vb.add_child(_obj_list)


func _build_hotbar() -> void:
	var mc := _anchored(Control.PRESET_CENTER_BOTTOM, Vector2(0, 16))
	mc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_END
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 8)
	mc.add_child(vb)

	_block_wrap = VBoxContainer.new()
	_block_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_wrap.add_theme_constant_override("separation", 4)
	vb.add_child(_block_wrap)
	_block_name = UIStyle.title("", 17)
	_block_name.add_theme_color_override("font_outline_color", Color.WHITE)
	_block_name.add_theme_constant_override("outline_size", 6)
	_block_wrap.add_child(_block_name)
	var bp := PanelContainer.new()
	bp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bp.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 16, UIStyle.BORDER, 3, 8))
	_block_wrap.add_child(bp)
	_block_bar = HBoxContainer.new()
	_block_bar.add_theme_constant_override("separation", 4)
	bp.add_child(_block_bar)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	for i in 4:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(88, 96)
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i
		slot.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				power_selected.emit(idx))
		var svb := VBoxContainer.new()
		svb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		svb.add_theme_constant_override("separation", 0)
		slot.add_child(svb)
		var icon := PowerIcon.new()
		icon.kind = i
		icon.custom_minimum_size = Vector2(56, 52)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		svb.add_child(icon)
		var nl := UIStyle.title("%d %s" % [i + 1, UIStyle.POWER_NAMES[i]], 14)
		nl.name = "Name"
		svb.add_child(nl)
		hb.add_child(slot)
		_power_slots.append(slot)


func _build_menu_buttons() -> void:
	var mc := _anchored(Control.PRESET_BOTTOM_RIGHT, Vector2(18, 18))
	mc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	mc.add_child(vb)
	var b1 := UIStyle.colored_button("Carnet  (C)", UIStyle.GREEN, 17)
	b1.pressed.connect(func(): toggle_panel("carnet"))
	vb.add_child(b1)
	var b2 := UIStyle.colored_button("Gacha  (G)", UIStyle.PINK, 17)
	b2.pressed.connect(func(): toggle_panel("gacha"))
	vb.add_child(b2)
	var b3 := UIStyle.colored_button("Carte  (M)", UIStyle.BLUE, 17)
	b3.pressed.connect(func(): toggle_panel("map"))
	vb.add_child(b3)


func _build_hint() -> void:
	var mc := _anchored(Control.PRESET_BOTTOM_LEFT, Vector2(18, 18))
	mc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(Color(1, 0.98, 0.94, 0.8), 14, UIStyle.BORDER, 2, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(p)
	_hint_label = UIStyle.label("ZQSD : marcher · Espace : sauter · Maj : courir\nClic gauche : pouvoir · Clic droit / flèches : caméra\nE : parler · 1-4 : pouvoirs · Échap : menu", 13, UIStyle.TEXT_SOFT)
	p.add_child(_hint_label)


func _build_toasts() -> void:
	var mc := _anchored(Control.PRESET_CENTER_TOP, Vector2(0, 110))
	mc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	mc.add_child(_toasts)


func _build_dialog() -> void:
	var mc := _anchored(Control.PRESET_CENTER_BOTTOM, Vector2(0, 150))
	mc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialog = PanelContainer.new()
	_dialog.custom_minimum_size = Vector2(640, 120)
	_dialog.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 24, UIStyle.GREEN, 4, 20))
	_dialog.visible = false
	_dialog.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			advance_dialog())
	mc.add_child(_dialog)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.add_child(vb)
	_dialog_name = UIStyle.label("", 22, UIStyle.GREEN_DARK)
	vb.add_child(_dialog_name)
	_dialog_text = UIStyle.label("", 19)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.custom_minimum_size.x = 600
	vb.add_child(_dialog_text)
	var more := UIStyle.label("▶ clic / E", 13, UIStyle.TEXT_SOFT)
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(more)


func _build_tutorial() -> void:
	var mc := _anchored(Control.PRESET_CENTER_LEFT, Vector2(18, 0))
	mc.grow_vertical = Control.GROW_DIRECTION_BOTH
	_tuto_panel = PanelContainer.new()
	_tuto_panel.custom_minimum_size = Vector2(360, 0)
	_tuto_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 22, Color("c49a6c"), 4, 18))
	mc.add_child(_tuto_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_tuto_panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)
	var pv := CreaturePreview.new()
	pv.custom_minimum_size = Vector2(72, 72)
	pv.spin_speed = 0.0
	head.add_child(pv)
	pv.set_creature(CreatureDB.GUIDE["look"])
	var hv := VBoxContainer.new()
	head.add_child(hv)
	hv.add_child(UIStyle.label("Pr. Hibou", 22, Color("8a5a3b")))
	_tuto_progress = UIStyle.label("", 14, UIStyle.TEXT_SOFT)
	hv.add_child(_tuto_progress)
	_tuto_text = UIStyle.label("", 17)
	_tuto_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tuto_text.custom_minimum_size.x = 330
	vb.add_child(_tuto_text)
	_tuto_button = UIStyle.colored_button("Continuer", UIStyle.GREEN, 17)
	_tuto_button.pressed.connect(_tuto_next)
	vb.add_child(_tuto_button)


func _build_popup() -> void:
	_popup = CenterContainer.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.visible = false
	_root.add_child(_popup)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 28, UIStyle.STAR, 5, 24))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(p)
	var vb := VBoxContainer.new()
	p.add_child(vb)
	vb.add_child(UIStyle.title("Un nouvel ami est arrivé !", 28))
	_popup_preview = CreaturePreview.new()
	_popup_preview.custom_minimum_size = Vector2(320, 220)
	_popup_preview.spin_speed = 1.5
	vb.add_child(_popup_preview)
	_popup_name = UIStyle.title("", 32)
	_popup_name.add_theme_color_override("font_color", UIStyle.GREEN_DARK)
	vb.add_child(_popup_name)
	vb.add_child(UIStyle.title("+%d ★" % Game.FRIEND_REWARD, 22))


func _build_pause() -> void:
	var m := UIStyle.modal("Pause", Vector2(420, 0))
	_pause = m["root"]
	_pause.visible = false
	_root.add_child(_pause)
	(m["close"] as Button).pressed.connect(func(): _pause.visible = false)
	var body: VBoxContainer = m["body"]
	var b := UIStyle.colored_button("Reprendre", UIStyle.GREEN, 20)
	b.pressed.connect(func(): _pause.visible = false)
	body.add_child(b)
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
	body.add_child(_volume_row("Musique", Game.music_volume, func(v):
		Game.music_volume = v
		Audio.apply_volumes()))
	body.add_child(_volume_row("Sons", Game.sfx_volume, func(v):
		Game.sfx_volume = v
		Audio.apply_volumes()
		Audio.play("click", -6.0)))
	var s := UIStyle.button("Sauvegarder", 20)
	s.pressed.connect(func():
		Game.save_game()
		toast("Partie sauvegardée !"))
	body.add_child(s)
	var r := UIStyle.button("Recommencer à zéro", 18)
	r.pressed.connect(func():
		if r.text == "Recommencer à zéro":
			r.text = "Sûr ? Clique encore pour confirmer"
			return
		r.text = "Recommencer à zéro"
		_pause.visible = false
		main.reset_game())
	body.add_child(r)
	# Mode admin
	_admin_button = UIStyle.button("", 18)
	_admin_button.pressed.connect(toggle_admin)
	body.add_child(_admin_button)
	_admin_box = VBoxContainer.new()
	_admin_box.add_theme_constant_override("separation", 6)
	body.add_child(_admin_box)
	var fly_b := UIStyle.colored_button("Voler / atterrir  (V)", Color("d4542a"), 17)
	fly_b.pressed.connect(func():
		_pause.visible = false
		main.toggle_fly())
	_admin_box.add_child(fly_b)
	var all_b := UIStyle.button("Obtenir tous les amis", 17)
	all_b.pressed.connect(func():
		Game.admin_unlock_all_friends()
		main.respawn_creatures()
		toast("Tous les amis sont arrivés !", UIStyle.GREEN_DARK))
	_admin_box.add_child(all_b)
	var tuto_b := UIStyle.button("Passer le tutoriel", 17)
	tuto_b.pressed.connect(func():
		Game.tutorial_step = TUTO_DONE
		refresh_all()
		toast("Tutoriel passé."))
	_admin_box.add_child(tuto_b)
	var star_b := UIStyle.button("+10 000 ★", 17)
	star_b.pressed.connect(func(): Game.add_stars(10000))
	_admin_box.add_child(star_b)

	var menu_b := UIStyle.button("Menu principal", 20)
	menu_b.pressed.connect(func():
		_pause.visible = false
		Game.save_game()
		main.return_to_title())
	body.add_child(menu_b)
	var q := UIStyle.button("Quitter", 20)
	q.pressed.connect(func():
		Game.save_game()
		get_tree().quit())
	body.add_child(q)
	body.add_child(UIStyle.label("Personnages voxel : Kenney (CC0)", 12, UIStyle.TEXT_SOFT))
	refresh_admin()


func toggle_admin() -> void:
	Game.admin = not Game.admin
	Game.save_game()
	toast("Mode admin activé : tout est débloqué !" if Game.admin else "Mode admin désactivé.", Color("d4542a"))
	admin_changed.emit(Game.admin)
	refresh_all()


func refresh_admin() -> void:
	_admin_button.text = "Mode admin : %s  (F1)" % ("ACTIVÉ" if Game.admin else "désactivé")
	_admin_box.visible = Game.admin
	_admin_label.visible = Game.admin
	var flying: bool = main != null and main.player != null and main.player.flying
	_admin_label.text = "ADMIN · " + ("EN VOL  (Espace/Ctrl, V pour atterrir)" if flying else "V : voler")


func _volume_row(text: String, value: float, on_change: Callable) -> HBoxContainer:
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
	_skin_label.text = "Apparence : %s" % Game.player_skin.to_upper()
	main.player.set_skin(Game.player_skin)


# --- Rafraîchissement ----------------------------------------------------

func refresh_all() -> void:
	refresh_admin()
	_refresh_top()
	_refresh_objectives()
	_refresh_blocks()
	_refresh_powers()
	_refresh_tutorial()


func _refresh_top() -> void:
	_island_label.text = IslandDB.get_island(Game.current_island)["name"]
	_stars_label.text = "★ %d" % Game.stars
	_friends_label.text = "♥ %d amis" % Game.friend_count()


func _refresh_objectives() -> void:
	for c in _obj_list.get_children():
		c.queue_free()
	for c in CreatureDB.island_creatures(Game.current_island):
		var known := Game.friends.has(c["id"])
		var have := Game.get_stat(Game.current_island, c["stat"])
		var need: int = c["amount"]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var top := HBoxContainer.new()
		row.add_child(top)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var look: Dictionary = c["look"]
		dot.color = look["body"] if known else Color("cfc4b4")
		top.add_child(dot)
		var name_l := UIStyle.label((" " + c["name"]) if known else " ???", 16, UIStyle.GREEN_DARK if known else UIStyle.TEXT)
		top.add_child(name_l)
		if known:
			top.add_child(UIStyle.label("  ✔ arrivé", 14, UIStyle.GREEN))
		else:
			row.add_child(UIStyle.label("%s  (%d/%d)" % [c["req"], mini(have, need), need], 14, UIStyle.TEXT_SOFT))
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(260, 8)
			bar.show_percentage = false
			bar.max_value = need
			bar.value = mini(have, need)
			row.add_child(bar)
		_obj_list.add_child(row)


func _refresh_powers() -> void:
	for i in 4:
		var slot := _power_slots[i]
		var unlocked := power_unlocked(i)
		var col: Color = UIStyle.POWER_COLORS[i]
		var sel := i == _power
		var st := UIStyle.box(col.lightened(0.75) if sel else UIStyle.PANEL, 18, col if sel else UIStyle.BORDER, 5 if sel else 3, 6)
		slot.add_theme_stylebox_override("panel", st)
		slot.modulate = Color(1, 1, 1, 1) if unlocked else Color(1, 1, 1, 0.4)
		slot.scale = Vector2.ONE
		var nl := slot.find_child("Name", true, false) as Label
		nl.text = "%d %s" % [i + 1, UIStyle.POWER_NAMES[i]] if unlocked else "%d  ? ? ?" % (i + 1)
	_block_wrap.visible = _power == 1 and power_unlocked(1)


func _refresh_blocks() -> void:
	for c in _block_bar.get_children():
		c.queue_free()
	for id in Game.available_blocks():
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(46, 46)
		var sel: bool = id == _block
		slot.add_theme_stylebox_override("panel", UIStyle.box(Color("fffdf6") if sel else Color(0, 0, 0, 0), 10, UIStyle.POWER_COLORS[1] if sel else Color(0, 0, 0, 0), 3, 2))
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.tooltip_text = Blocks.block_name(id)
		var icon := PowerIcon.new()
		icon.is_block = true
		icon.block_color = Blocks.main_color(id)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var bid: int = id
		slot.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				block_selected.emit(bid))
		_block_bar.add_child(slot)
	_block_name.text = Blocks.block_name(_block) + "   (R / F)"


func set_power(i: int) -> void:
	_power = i
	_refresh_powers()
	var slot := _power_slots[i]
	slot.pivot_offset = slot.size * 0.5
	var tw := create_tween()
	tw.tween_property(slot, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(slot, "scale", Vector2.ONE, 0.12)


func set_block(id: int) -> void:
	_block = id
	_refresh_blocks()


func power_unlocked(i: int) -> bool:
	return Game.admin or Game.tutorial_step >= 2 + i


# --- Notifications -------------------------------------------------------

func toast(text: String, col := UIStyle.TEXT) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 16, UIStyle.BORDER, 3, 14))
	var l := UIStyle.title(text, 19)
	l.add_theme_color_override("font_color", col)
	p.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).free()
	var tw := p.create_tween()
	p.modulate.a = 0.0
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func show_friend_popup(id: String) -> void:
	var c := CreatureDB.get_creature(id)
	_popup_preview.set_creature(c["look"])
	_popup_name.text = c["name"]
	_popup.visible = true
	_popup.modulate.a = 0.0
	_popup.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(_popup, "modulate:a", 1.0, 0.3)
	_popup_timer = 3.2


func show_dialog(speaker: String, lines: Array, on_done := Callable()) -> void:
	_dialog_lines = lines.duplicate()
	_dialog_name.text = speaker
	_dialog_cb = on_done
	_dialog.visible = true
	advance_dialog()


func advance_dialog() -> void:
	if _dialog_lines.is_empty():
		_dialog.visible = false
		if _dialog_cb.is_valid():
			_dialog_cb.call()
		return
	_dialog_text.text = _dialog_lines.pop_front()


func dialog_open() -> bool:
	return _dialog.visible


func fade(out: bool, duration := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0 if out else 0.0, duration)
	await tw.finished


# --- Panneaux ------------------------------------------------------------

func is_blocking() -> bool:
	return _open_panel != null or _pause.visible or _dialog.visible


func toggle_panel(which: String) -> void:
	if _open_panel and _open_panel.name == which:
		close_panel()
		return
	close_panel()
	match which:
		"carnet":
			if _carnet == null:
				_carnet = CarnetPanel.new()
				_carnet.closed.connect(close_panel)
			_open_panel = _carnet
			Game.notify_action("carnet")
		"gacha":
			if _gacha == null:
				_gacha = GachaPanel.new()
				_gacha.closed.connect(close_panel)
			_open_panel = _gacha
		"map":
			if _map == null:
				_map = MapPanel.new()
				_map.closed.connect(close_panel)
				_map.travel_requested.connect(func(id):
					close_panel()
					travel_requested.emit(id))
			_open_panel = _map
	_open_panel.name = which
	_root.add_child(_open_panel)

	_open_panel.call("open")
	Audio.play("book" if which == "carnet" else "open", -4.0)
	_open_panel.modulate.a = 0.0
	create_tween().tween_property(_open_panel, "modulate:a", 1.0, 0.15)


func close_panel() -> void:
	if _open_panel:
		Audio.play("close", -6.0)
		_root.remove_child(_open_panel)
		_open_panel = null


func back() -> void:
	if _dialog.visible:
		_dialog.visible = false
	elif _open_panel:
		close_panel()
	else:
		_pause.visible = not _pause.visible
		_skin_label.text = "Apparence : %s" % Game.player_skin.to_upper()


# --- Tutoriel ------------------------------------------------------------

func _refresh_tutorial() -> void:
	var step := Game.tutorial_step
	if step >= TUTO_DONE or Game.current_island != "prairie":
		_tuto_panel.visible = false
		_refresh_powers()
		return
	_tuto_panel.visible = true
	var t: Dictionary = TUTO[step]
	_tuto_text.text = t["text"]
	_tuto_button.visible = t.has("button")
	if t.has("button"):
		_tuto_button.text = t["button"]
	_tuto_progress.text = "Tutoriel · étape %d / %d" % [step + 1, TUTO.size()]
	if t.has("count") and int(t["count"]) > 1:
		_tuto_progress.text += "   (%d/%d)" % [_tuto_count, int(t["count"])]
	_refresh_powers()


func _tuto_next() -> void:
	var step := Game.tutorial_step
	if step >= TUTO_DONE:
		return
	var t: Dictionary = TUTO[step]
	if t.has("reward"):
		Game.add_stars(int(t["reward"]))
		toast("+%d ★" % int(t["reward"]), UIStyle.STAR.darkened(0.15))
	Game.tutorial_step += 1
	_tuto_count = 0
	Audio.play("confirm", -4.0, 0.0)
	if Game.tutorial_step >= TUTO_DONE:
		_tuto_panel.visible = false
		toast("Tutoriel terminé ! Amuse-toi bien sur l'archipel !", UIStyle.GREEN_DARK)
		_refresh_powers()
		Game.save_game()
		return
	# Sélectionne automatiquement le pouvoir présenté.
	var power_for_step := {2: 0, 3: 1, 4: 2, 5: 3}
	if power_for_step.has(Game.tutorial_step):
		power_selected.emit(int(power_for_step[Game.tutorial_step]))
	_refresh_tutorial()
	_tuto_panel.pivot_offset = _tuto_panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(_tuto_panel, "scale", Vector2(1.04, 1.04), 0.08)
	tw.tween_property(_tuto_panel, "scale", Vector2.ONE, 0.12)
	Game.save_game()


func _on_action(kind: String) -> void:
	var step := Game.tutorial_step
	if step >= TUTO_DONE:
		return
	var t: Dictionary = TUTO[step]
	if t.get("wait", "") != kind:
		return
	_tuto_count += 1
	if _tuto_count >= int(t.get("count", 1)):
		_tuto_next()
	else:
		_refresh_tutorial()


func _process(delta: float) -> void:
	if Game.tutorial_step == 1 and main and main.player and main.player.distance_walked > 8.0:
		_tuto_next()
	if _popup.visible:
		_popup_timer -= delta
		if _popup_timer <= 0.0:
			_popup.modulate.a -= delta * 3.0
			if _popup.modulate.a <= 0.0:
				_popup.visible = false
