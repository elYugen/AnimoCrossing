class_name HUD
extends CanvasLayer
## Interface en jeu : infos de l'île, objectifs, barre de pouvoirs, palette
## de blocs, dialogues, notifications, tutoriel et panneaux modaux.

signal travel_requested(island_id: String)
signal power_selected(index: int)
signal block_selected(id: int)
signal structure_selected(kind: String)
signal admin_changed(enabled: bool)
signal step_changed(step: int)
signal sleep_requested

## Étapes du début de partie (suivies sans être affichées : elles débloquent
## les modes de l'outil). Boucle : explorer, récolter, améliorer l'île,
## fabriquer, construire, accueillir de nouveaux habitants...
const TUTO := [
	{"title": "Explorer l'île", "text": "", "wait": "explore", "goals": {"branch": 3, "stone": 3, "fruit": 2, "plant": 2}},
	{"title": "Une vieille structure", "text": "", "wait": "flag_camp"},
	{"title": "Fouiller le campement", "text": "", "wait": "flag_chest"},
	{"title": "Nettoyer l'île", "text": "", "wait": "clean_waste", "count": 3},
	{"title": "Fabriquer", "text": "", "wait": "craft", "count": 1},
	{"title": "Construire", "text": "", "wait": "place", "count": 1},
	{"title": "Faire fleurir", "text": "", "wait": "bloom", "count": 1},
	{"title": "Faire pousser", "text": "", "wait": "tree", "count": 1},
	{"title": "Une île qui revit", "text": "", "wait": "arrival", "count": 1},
	{"title": "Premier habitant", "text": "", "wait": "talk", "count": 1},
]
const TUTO_DONE := 10

var main: Node

var _root: Control
var _island_label: Label
var _stars_label: Label  # (masqué)
var _friends_label: Label  # (masqué)
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
var _tuto_title: Label
var _power_bar: HBoxContainer
var _inv_labels := {}
var _item_popup: Control
var _item_title: Label
var _item_sub: Label
var _item_timer := 0.0
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
var _crosshair: Crosshair
var _vit_pct: Label
var _clock: Label
var _vit_bar: ProgressBar
var _vit_tier: Label
var _vit_next: Label
var _vit_last := {}  # île -> dernier pourcentage affiché
var _item_icons: HBoxContainer

var _carnet: CarnetPanel
var _structure := ""
var _map: MapPanel
var _craft: CraftPanel
var _craft_at_table := false
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
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)
	_build_toasts()
	_build_dialog()
	_build_tutorial()
	_build_popup()
	_build_item_popup()
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

	Game.stats_changed.connect(_refresh_objectives)
	Game.resident_arrived.connect(func(_id):
		_refresh_top()
		_refresh_objectives())
	Game.action_done.connect(_on_action)
	Game.inventory_changed.connect(func():
		_refresh_inventory()
		_refresh_blocks()
		_refresh_powers()
		_on_action("explore"))


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
	mc.visible = false  # HUD minimal : seules les infos utiles restent affichées
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
	var inv := HBoxContainer.new()
	inv.add_theme_constant_override("separation", 12)
	vb.add_child(inv)
	for k in Pickup.KINDS:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = Pickup.item_color(k)
		dot.tooltip_text = Pickup.item_name(k)
		inv.add_child(dot)
		var l := UIStyle.label("0", 16, UIStyle.TEXT_SOFT)
		inv.add_child(l)
		_inv_labels[k] = l
	_admin_label = UIStyle.label("", 15, Color("d4542a"))
	_admin_label.visible = false
	vb.add_child(_admin_label)


## Seule information permanente : la vitalité de l'île.
func _build_objectives() -> void:
	var mc := _anchored(Control.PRESET_TOP_RIGHT, Vector2(18, 16))
	mc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(Color(1, 0.98, 0.94, 0.85), 16, UIStyle.BORDER, 2, 12))
	mc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)
	_vit_tier = UIStyle.label("", 15, UIStyle.TEXT_SOFT)
	_vit_tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_vit_tier)
	_vit_pct = UIStyle.label("", 26, UIStyle.GREEN_DARK)
	head.add_child(_vit_pct)
	_vit_bar = ProgressBar.new()
	_vit_bar.custom_minimum_size = Vector2(170, 8)
	_vit_bar.show_percentage = false
	vb.add_child(_vit_bar)
	_clock = UIStyle.label("", 13, UIStyle.TEXT_SOFT)
	vb.add_child(_clock)
	_obj_list = VBoxContainer.new()
	_vit_next = Label.new()


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
	_power_bar = hb
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
		var nl := UIStyle.title("%d" % (i + 1), 14)
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
	_hint_label = UIStyle.label("ZQSD : marcher · Espace : sauter · Maj : courir\nSouris : regarder · Molette : zoom · Clic gauche : pouvoir\nE : parler · 1-4 : pouvoirs · Alt : curseur · Échap : menu", 13, UIStyle.TEXT_SOFT)
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
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	hv.add_child(UIStyle.label("MISSION", 13, Color("c49a6c")))
	_tuto_title = UIStyle.label("", 23, Color("8a5a3b"))
	hv.add_child(_tuto_title)
	_tuto_text = UIStyle.label("", 17)
	_tuto_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tuto_text.custom_minimum_size.x = 330
	vb.add_child(_tuto_text)
	_tuto_progress = UIStyle.label("", 15, UIStyle.TEXT_SOFT)
	vb.add_child(_tuto_progress)
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
	vb.add_child(UIStyle.title("Un nouvel habitant est arrivé !", 28))
	_popup_preview = CreaturePreview.new()
	_popup_preview.custom_minimum_size = Vector2(320, 220)
	_popup_preview.spin_speed = 1.5
	vb.add_child(_popup_preview)
	_popup_name = UIStyle.title("", 32)
	_popup_name.add_theme_color_override("font_color", UIStyle.GREEN_DARK)
	vb.add_child(_popup_name)


func _build_item_popup() -> void:
	_item_popup = CenterContainer.new()
	_item_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_item_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_popup.visible = false
	_root.add_child(_item_popup)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, 28, UIStyle.STAR, 5, 26))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_popup.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	var icons := HBoxContainer.new()
	_item_icons = icons
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 16)
	vb.add_child(icons)
	for i in 2:
		var icon := PowerIcon.new()
		icon.kind = i
		icon.custom_minimum_size = Vector2(90, 84)
		icons.add_child(icon)
	_item_title = UIStyle.title("", 30)
	_item_title.add_theme_color_override("font_color", UIStyle.GREEN_DARK)
	vb.add_child(_item_title)
	_item_sub = UIStyle.title("", 19)
	_item_sub.add_theme_color_override("font_color", UIStyle.TEXT_SOFT)
	vb.add_child(_item_sub)


## Grand encart « objet obtenu ».
func show_item_popup(title: String, sub: String, icons := true) -> void:
	_item_icons.visible = icons
	_item_title.text = title
	_item_sub.text = sub
	_item_popup.visible = true
	_item_popup.modulate.a = 0.0
	create_tween().tween_property(_item_popup, "modulate:a", 1.0, 0.3)
	_item_timer = 3.8


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
	var sl := UIStyle.colored_button("Dormir jusqu'au lendemain", Color("7d6bc4"), 18)
	sl.pressed.connect(func():
		_pause.visible = false
		sleep_requested.emit())
	body.add_child(sl)
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
	var all_b := UIStyle.button("Faire venir tous les habitants", 17)
	all_b.pressed.connect(func():
		Game.admin_all_residents()
		main.respawn_creatures()
		toast("Tous les habitants sont arrivés !", UIStyle.GREEN_DARK))
	_admin_box.add_child(all_b)
	var tuto_b := UIStyle.button("Passer le tutoriel", 17)
	tuto_b.pressed.connect(func():
		Game.tutorial_step = TUTO_DONE
		refresh_all()
		toast("Tutoriel passé."))
	_admin_box.add_child(tuto_b)
	var res_b := UIStyle.button("+20 de chaque ressource", 17)
	res_b.pressed.connect(func():
		for k in Items.ALL:
			Game.add_item(k, 20)
		toast("Ressources ajoutées."))
	_admin_box.add_child(res_b)

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
	_skin_label.text = "Tenue : %s" % Game.player_skin.to_upper()
	main.player.set_skin(Game.player_skin, Game.player_head)


# --- Rafraîchissement ----------------------------------------------------

func refresh_all() -> void:
	refresh_admin()
	_refresh_top()
	_refresh_inventory()
	_refresh_objectives()
	_refresh_blocks()
	_refresh_powers()
	_refresh_tutorial()


func _refresh_inventory() -> void:
	for k in _inv_labels:
		(_inv_labels[k] as Label).text = str(Game.item_count(k))


func _refresh_top() -> void:
	_island_label.text = IslandDB.get_island(Game.current_island)["name"]
	_friends_label.text = "%d habitants" % Game.resident_count()


func _refresh_objectives() -> void:
	var isl := Game.current_island
	var pct := Vitality.percent(isl)
	_vit_pct.text = "%d %%" % pct
	_vit_bar.value = pct
	_vit_tier.text = IslandDB.get_island(isl)["name"]
	# Annonce quand l'île change de palier.
	var last: int = _vit_last.get(isl, -1)
	_vit_last[isl] = pct
	if last >= 0 and Vitality.tier_index(pct) > Vitality.tier_index(last):
		var sub := "Mais il reste encore beaucoup de choses à découvrir..." if pct >= 100 else "L'île devient plus accueillante."
		show_item_popup("%d %% — %s" % [pct, Vitality.tier_name(pct)], sub, false)
		Audio.play("jingle_common", -6.0, 0.0)


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
		nl.text = "%d" % (i + 1)
	_block_wrap.visible = _power == 1 and power_unlocked(1) and not placeables().is_empty()
	# Pas d'outil, pas de barre de pouvoirs.
	_power_bar.visible = power_unlocked(0)


## Ce qu'on peut poser : ids de blocs (int) puis constructions (String).
func placeables() -> Array:
	var out: Array = []
	if main and main.interior:
		# Dans une maison : les meubles.
		for r in Crafting.RECIPES:
			if r.has("furniture"):
				var fk: String = "f_" + r["furniture"]
				if Game.admin or Game.structure_count(fk) > 0:
					out.append(fk)
		return out
	for id in Game.available_blocks():
		out.append(id)
	for r in Crafting.RECIPES:
		var k: String = r.get("structure", "")
		if k != "" and not k in out and (Game.admin or Game.structure_count(k) > 0):
			out.append(k)
	return out


func _refresh_blocks() -> void:
	for c in _block_bar.get_children():
		c.queue_free()
	for entry in placeables():
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(52, 52)
		var sel: bool = (entry is String and entry == _structure) or (entry is int and _structure == "" and entry == _block)
		slot.add_theme_stylebox_override("panel", UIStyle.box(Color("fffdf6") if sel else Color(0, 0, 0, 0), 10, UIStyle.POWER_COLORS[1] if sel else Color(0, 0, 0, 0), 3, 2))
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var count := 0
		if entry is String:
			slot.tooltip_text = Crafting.structure_name(entry)
			var tr := TextureRect.new()
			tr.texture = Thumbs.of(entry)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(tr)
			count = Game.structure_count(entry)
		else:
			slot.tooltip_text = Blocks.block_name(entry)
			var icon := PowerIcon.new()
			icon.is_block = true
			icon.block_color = Blocks.main_color(entry)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)
			count = Game.block_count(entry)
		if not Game.admin:
			var cnt := UIStyle.label(str(count), 13, UIStyle.TEXT)
			cnt.add_theme_color_override("font_outline_color", Color.WHITE)
			cnt.add_theme_constant_override("outline_size", 5)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cnt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(cnt)
		var e: Variant = entry
		slot.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if e is String:
					structure_selected.emit(e)
				else:
					block_selected.emit(e))
		_block_bar.add_child(slot)
	_block_name.visible = false


func set_structure(kind: String) -> void:
	_structure = kind
	_refresh_blocks()
	_refresh_powers()


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
	if main and main.structure == "":
		_structure = ""
	_refresh_blocks()


func power_unlocked(i: int) -> bool:
	# L'outil universel (coffre, mission 3) détruit et construit ; les
	# modes « fleurir » et « pousser » se réveillent ensuite.
	return Game.admin or Game.tutorial_step >= [3, 3, 6, 7][i]


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


func show_resident_popup(id: String) -> void:
	var c := ResidentDB.get_resident(id)
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


func set_crosshair(v: bool, col: Color) -> void:
	_crosshair.visible = v
	if _crosshair.color != col:
		_crosshair.color = col
		_crosshair.queue_redraw()


## Le curseur doit rester libre (bouton du tutoriel à cliquer).
func wants_cursor() -> bool:
	return _tuto_panel.visible and _tuto_button.visible


func fade_in_root(duration := 0.8) -> void:
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, duration)


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
		"craft":
			if _craft == null:
				_craft = CraftPanel.new()
				_craft.closed.connect(close_panel)
			_open_panel = _craft
			_craft.table = _craft_at_table
			_craft_at_table = false
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


## Petite fenêtre de choix (ex. : qui habite cette maison ?).
func show_choice(title: String, options: Array, on_pick: Callable) -> void:
	close_panel()
	var m := UIStyle.modal(title, Vector2(420, 0))
	var root: Control = m["root"]
	root.name = "choice"
	var body: VBoxContainer = m["body"]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, mini(options.size() * 52, 420))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for o in options:
		var b := UIStyle.button(o["label"], 17)
		var oid: String = o["id"]
		b.pressed.connect(func():
			close_panel()
			on_pick.call(oid))
		list.add_child(b)
	(m["close"] as Button).pressed.connect(close_panel)
	_open_panel = root
	_root.add_child(root)
	Audio.play("open", -6.0)


## Inventaire (I) ou fabrication (à une table d'artisan).
func open_crafting(at_table: bool) -> void:
	_craft_at_table = at_table
	if _open_panel and _open_panel.name == "craft":
		close_panel()
	toggle_panel("craft")


func close_panel() -> void:
	if _open_panel:
		Audio.play("close", -6.0)
		_root.remove_child(_open_panel)
		if _open_panel.name == "choice":
			_open_panel.queue_free()
		_open_panel = null


func back() -> void:
	if _dialog.visible:
		_dialog.visible = false
	elif _open_panel:
		close_panel()
	else:
		_pause.visible = not _pause.visible
		_skin_label.text = "Tenue : %s" % Game.player_skin.to_upper()


# --- Tutoriel ------------------------------------------------------------

func _refresh_tutorial() -> void:
	var step := Game.tutorial_step
	if step >= TUTO_DONE or Game.current_island != "prairie":
		_tuto_panel.visible = false
		_refresh_powers()
		return
	# HUD minimal : la progression reste suivie mais n'est plus affichée.
	_tuto_panel.visible = false
	var t: Dictionary = TUTO[step]
	if t.has("button"):
		_tuto_next.call_deferred()
		return
	_tuto_title.text = t["title"]
	_tuto_text.text = t["text"]
	_tuto_button.visible = t.has("button")
	if t.has("button"):
		_tuto_button.text = t["button"]
	_tuto_progress.text = ""
	_tuto_progress.visible = false
	if t.has("goals"):
		var parts := []
		for k in t["goals"]:
			parts.append("%s %s : %d/%d" % ["✔" if Game.item_count(k) >= int(t["goals"][k]) else "•", Pickup.item_name(k) + "s", mini(Game.item_count(k), int(t["goals"][k])), int(t["goals"][k])])
		parts.append("%s Trouver un point d'eau" % ("✔" if Game.has_flag("water") else "•"))
		_tuto_progress.text = "\n".join(parts)
		_tuto_progress.visible = true
	elif t.has("count") and int(t["count"]) > 1:
		_tuto_progress.text = "%d / %d" % [_tuto_count, int(t["count"])]
		_tuto_progress.visible = true
	_refresh_powers()


func _tuto_next() -> void:
	var step := Game.tutorial_step
	if step >= TUTO_DONE:
		return
	var t: Dictionary = TUTO[step]
	Game.tutorial_step += 1
	_tuto_count = 0
	step_changed.emit(Game.tutorial_step)
	Audio.play("confirm", -4.0, 0.0)
	if Game.tutorial_step >= TUTO_DONE:
		_tuto_panel.visible = false
		toast("L'aventure commence ! Façonne l'île à ton goût.", UIStyle.GREEN_DARK)
		_refresh_powers()
		Game.save_game()
		return
	# Sélectionne automatiquement le pouvoir présenté.
	var power_for_step := {3: 0, 5: 1, 6: 2, 7: 3}
	if power_for_step.has(Game.tutorial_step):
		power_selected.emit(int(power_for_step[Game.tutorial_step]))
	_refresh_tutorial()
	# Une mission déjà accomplie (ex. campement trouvé avant) passe toute seule.
	_on_action("check")
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
	var wait: String = t.get("wait", "")
	if wait == "explore":
		_refresh_tutorial()
		if _explore_done(t):
			_tuto_next()
		return
	if wait.begins_with("flag_"):
		if Game.has_flag(wait.trim_prefix("flag_")):
			_tuto_next()
		return
	if wait != kind:
		return
	_tuto_count += 1
	if _tuto_count >= int(t.get("count", 1)):
		_tuto_next()
	else:
		_refresh_tutorial()


func _explore_done(t: Dictionary) -> bool:
	for k in t["goals"]:
		if Game.item_count(k) < int(t["goals"][k]):
			return false
	return Game.has_flag("water")


## Saute directement à une mission (ex. coffre ouvert avant d'avoir tout exploré).
func jump_to_step(step: int) -> void:
	if Game.tutorial_step >= step:
		return
	Game.tutorial_step = step - 1
	_tuto_next()


func _process(delta: float) -> void:
	if main and main.sky and _clock:
		_clock.text = main.sky.clock_text()
	if _item_popup.visible:
		_item_timer -= delta
		if _item_timer <= 0.0:
			_item_popup.modulate.a -= delta * 2.5
			if _item_popup.modulate.a <= 0.0:
				_item_popup.visible = false
	if _popup.visible:
		_popup_timer -= delta
		if _popup_timer <= 0.0:
			_popup.modulate.a -= delta * 3.0
			if _popup.modulate.a <= 0.0:
				_popup.visible = false


## Viseur au centre de l'écran (couleur du pouvoir actif).
class Crosshair:
	extends Control

	var color := Color.WHITE

	func _draw() -> void:
		draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 4.0, true)
		draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 32, color, 2.0, true)
		draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
