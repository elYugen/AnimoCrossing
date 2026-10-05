class_name CarnetPanel
extends Control
## Carnet : les habitants possibles, rangés par environnement (forêt,
## jardins, mer, montagne, village), et les animaux déjà apparus.

signal closed

var _grid: GridContainer
var _preview: CreaturePreview
var _name: Label
var _info: Label
var _desc: Label
var _req: Label
var _bar: ProgressBar
var _count: Label
var _tab := "forest"
var _tab_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := UIStyle.modal("Carnet", Vector2(980, 600))
	add_child(m["root"])
	(m["close"] as Button).pressed.connect(func(): closed.emit())
	var body: VBoxContainer = m["body"]
	_count = UIStyle.label("", 18, UIStyle.TEXT_SOFT)
	body.add_child(_count)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	for h in ResidentDB.HABITATS:
		_add_tab(tabs, h, ResidentDB.HABITAT_NAMES[h])
	_add_tab(tabs, "animals", "Animaux")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.CREAM, 20, UIStyle.BORDER, 3, 16))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	detail.add_child(dv)
	_preview = CreaturePreview.new()
	_preview.custom_minimum_size = Vector2(340, 220)
	dv.add_child(_preview)
	_name = UIStyle.title("", 26)
	dv.add_child(_name)
	_info = UIStyle.label("", 16, UIStyle.TEXT_SOFT)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(_info)
	_desc = UIStyle.label("", 17)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 340
	dv.add_child(_desc)
	_req = UIStyle.label("", 17, UIStyle.GREEN_DARK)
	_req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_req)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 22)
	_bar.show_percentage = false
	dv.add_child(_bar)


func _add_tab(parent: Control, id: String, text: String) -> void:
	var b := UIStyle.button(text, 16)
	b.toggle_mode = true
	b.pressed.connect(func(): _select_tab(id))
	parent.add_child(b)
	_tab_buttons[id] = b


func open() -> void:
	_count.text = "Habitants : %d / %d   ·   Animaux : %d / %d" % [Game.resident_count(), ResidentDB.ALL.size(), Game.species_seen.size(), Fauna.SPECIES.size()]
	var best := Vitality.best_habitat(Game.current_island)
	_select_tab(best if best != "" else _tab)


func _select_tab(id: String) -> void:
	_tab = id
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).button_pressed = (k == id)
	for c in _grid.get_children():
		c.queue_free()
	if id == "animals":
		for sp in Fauna.SPECIES:
			_grid.add_child(_animal_card(sp))
		_show_animal(Fauna.SPECIES.keys()[0])
		return
	var list: Array[Dictionary] = ResidentDB.habitat_residents(id)
	for c in list:
		_grid.add_child(_make_card(c))
	if not list.is_empty():
		_show_detail(list[0])


func _make_card(c: Dictionary) -> Button:
	var known := Game.residents.has(c["id"])
	var b := UIStyle.button("", 15)
	b.custom_minimum_size = Vector2(124, 124)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(vb)
	var swatch := PanelContainer.new()
	swatch.custom_minimum_size = Vector2(56, 56)
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look: Dictionary = c["look"]
	var hab_colors := {"forest": Color("6cbf4a"), "garden": Color("f07fb0"), "marine": Color("6aa8f2"), "mountain": Color("a7adb5"), "village": Color("f29a45")}
	var col: Color = look.get("body", hab_colors.get(c.get("habitat", ""), UIStyle.BORDER)) if known else Color("cfc4b4")
	swatch.add_theme_stylebox_override("panel", UIStyle.box(col, 28, col.darkened(0.2) if known else Color("b8aa98"), 3, 4))
	vb.add_child(swatch)
	var q := UIStyle.label("" if known else "?", 26, Color("8a7563"))
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.add_child(q)
	var n := UIStyle.label(c["name"] if known else "???", 15)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(n)
	b.pressed.connect(func(): _show_detail(c))
	return b


func _show_detail(c: Dictionary) -> void:
	var known := Game.residents.has(c["id"])
	_preview.set_creature(c["look"], not known)
	_name.text = c["name"] if known else "???"
	if true:
		var hab: String = ResidentDB.HABITAT_NAMES[c["habitat"]]
		_info.text = "Habitat : %s" % hab
		var where := ""
		var b: Array = c.get("biomes", [])
		if not b.is_empty():
			var names := []
			for iid in b:
				names.append(IslandDB.get_island(iid)["name"])
			where = "\nNe vit que sur : " + ", ".join(names) + "."
		_req.text = "✔ S'est installé sur l'île." if known else "Peut venir quand l'environnement « %s » est développé et que l'île est assez accueillante.%s" % [hab, where]
		_bar.visible = false
	if known:
		var home: String = (Game.residents[c["id"]] as Dictionary).get("island", "")
		_desc.text = c["desc"] + ("\nVit sur : " + IslandDB.get_island(home)["name"] if home != "" else "")
	else:
		_desc.text = "Tu n'as pas encore rencontré cette créature."


func _animal_card(sp: String) -> Button:
	var known := Game.species_seen.has(sp)
	var b := UIStyle.button("", 15)
	b.custom_minimum_size = Vector2(124, 124)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(vb)
	var q := UIStyle.title("" if known else "?", 26)
	q.add_theme_color_override("font_color", Color("8a7563"))
	if known:
		var tr := TextureRect.new()
		tr.texture = Thumbs.of("pet_" + sp)
		tr.custom_minimum_size = Vector2(70, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tr)
	else:
		vb.add_child(q)
	var n := UIStyle.label(Fauna.name_of(sp) if known else "???", 15)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(n)
	b.pressed.connect(func(): _show_animal(sp))
	return b


func _show_animal(sp: String) -> void:
	var known := Game.species_seen.has(sp)
	var d: Dictionary = Fauna.SPECIES[sp]
	_preview.clear()
	_name.text = Fauna.name_of(sp) if known else "???"
	_info.text = "Habitat : %s" % ResidentDB.HABITAT_NAMES[d["habitat"]]
	_desc.text = "Il vit sur l'île." if known else "Pas encore aperçu."
	_req.text = "" if known else "Apparaît quand l'environnement « %s » se développe." % ResidentDB.HABITAT_NAMES[d["habitat"]]
	_bar.visible = false
