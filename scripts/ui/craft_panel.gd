class_name CraftPanel
extends Control
## Inventaire (touche I) : ressources, composants, blocs et constructions
## (miniatures 3D). À une table d'artisan (`table`), on peut aussi fabriquer.

signal closed

var table := false

var _title: Label
var _left: VBoxContainer
var _right: VBoxContainer
var _recipes: VBoxContainer
var _section := 0
var _tabs := []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := UIStyle.modal("Inventaire", Vector2(1000, 600))
	add_child(m["root"])
	_title = m["title"]
	(m["close"] as Button).pressed.connect(func(): closed.emit())
	var body: VBoxContainer = m["body"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)

	var ls := ScrollContainer.new()
	ls.custom_minimum_size = Vector2(430, 500)
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(ls)
	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.add_theme_constant_override("separation", 8)
	ls.add_child(_left)

	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 8)
	row.add_child(_right)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_right.add_child(tabs)
	for i in Crafting.SECTIONS.size():
		var b := UIStyle.button(Crafting.SECTIONS[i], 15)
		b.toggle_mode = true
		var idx := i
		b.pressed.connect(func():
			_section = idx
			_refresh())
		tabs.add_child(b)
		_tabs.append(b)
	var rs := ScrollContainer.new()
	rs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rs.custom_minimum_size.y = 450
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.add_child(rs)
	_recipes = VBoxContainer.new()
	_recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipes.add_theme_constant_override("separation", 6)
	rs.add_child(_recipes)
	Game.inventory_changed.connect(_refresh)


func open() -> void:
	_title.text = "Table d'artisan" if table else "Inventaire"
	_right.visible = table
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	for c in _left.get_children():
		c.queue_free()
	_left.add_child(UIStyle.label("Ressources", 19))
	_left.add_child(_item_grid(Items.RAW))
	_left.add_child(UIStyle.label("Composants", 19))
	_left.add_child(_item_grid(Items.COMPONENTS))
	_left.add_child(UIStyle.label("Blocs", 19))
	var blocks := GridContainer.new()
	blocks.columns = 6
	blocks.add_theme_constant_override("h_separation", 6)
	blocks.add_theme_constant_override("v_separation", 6)
	for entry in Blocks.BUILD_PALETTE:
		var id := int(entry["id"])
		if Game.block_count(id) > 0:
			blocks.add_child(_slot(_block_icon(id), Blocks.block_name(id), Game.block_count(id)))
	_left.add_child(blocks if blocks.get_child_count() > 0 else UIStyle.label("—", 15, UIStyle.TEXT_SOFT))
	_left.add_child(UIStyle.label("Constructions", 19))
	var builds := GridContainer.new()
	builds.columns = 4
	builds.add_theme_constant_override("h_separation", 6)
	builds.add_theme_constant_override("v_separation", 6)
	for r in Crafting.RECIPES:
		var k: String = r.get("structure", "")
		if k != "" and Game.structure_count(k) > 0:
			builds.add_child(_slot(_thumb(k, 84), r["name"], Game.structure_count(k), Vector2(96, 112)))
	_left.add_child(builds if builds.get_child_count() > 0 else UIStyle.label("—", 15, UIStyle.TEXT_SOFT))
	_left.add_child(UIStyle.label("Meubles", 19))
	var furn := GridContainer.new()
	furn.columns = 4
	furn.add_theme_constant_override("h_separation", 6)
	furn.add_theme_constant_override("v_separation", 6)
	for r in Crafting.RECIPES:
		var fk: String = "f_" + str(r.get("furniture", ""))
		if r.has("furniture") and Game.structure_count(fk) > 0:
			furn.add_child(_slot(_thumb(fk, 84), r["name"], Game.structure_count(fk), Vector2(96, 112)))
	_left.add_child(furn if furn.get_child_count() > 0 else UIStyle.label("—", 15, UIStyle.TEXT_SOFT))
	if not table:
		return
	for i in _tabs.size():
		(_tabs[i] as Button).button_pressed = i == _section
	for c in _recipes.get_children():
		c.queue_free()
	for r in Crafting.RECIPES:
		if int(r["section"]) == _section:
			_recipes.add_child(_recipe_row(r))


func _item_grid(keys: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for k in keys:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(22, 22)
		dot.color = Items.color_of(k)
		var c := CenterContainer.new()
		c.custom_minimum_size = Vector2(36, 30)
		c.add_child(dot)
		g.add_child(_slot(c, Items.name_of(k), Game.item_count(k), Vector2(96, 64)))
	return g


func _slot(icon: Control, text: String, n: int, min_size := Vector2(64, 70)) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.tooltip_text = text
	p.add_theme_stylebox_override("panel", UIStyle.box(Color("fffdf6"), 10, UIStyle.BORDER, 2, 4))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	p.add_child(vb)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(icon)
	var l := UIStyle.title("%s ×%d" % [text, n] if min_size.x > 70 else "×%d" % n, 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)
	return p


func _block_icon(id: int) -> Control:
	var icon := PowerIcon.new()
	icon.is_block = true
	icon.block_color = Blocks.main_color(id)
	icon.custom_minimum_size = Vector2(40, 34)
	return icon


func _thumb(kind: String, s: int) -> Control:
	var tr := TextureRect.new()
	tr.texture = Thumbs.of(kind)
	tr.custom_minimum_size = Vector2(s, s * 0.8)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr


func _recipe_row(r: Dictionary) -> PanelContainer:
	var unlocked := Crafting.is_unlocked(r)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.CREAM if unlocked else Color("f1ebe2"), 12, UIStyle.BORDER, 2, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var icon: Control
	if r.has("structure") or r.has("furniture"):
		icon = _thumb(r["structure"] if r.has("structure") else "f_" + r["furniture"], 60)
		icon.modulate = Color.WHITE if unlocked else Color(0.4, 0.36, 0.32, 0.5)
	elif r.has("block"):
		icon = _block_icon(int(r["block"]))
	else:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(26, 26)
		dot.color = Items.color_of(r["item"])
		icon = CenterContainer.new()
		icon.custom_minimum_size = Vector2(40, 36)
		icon.add_child(dot)
	h.add_child(icon)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	h.add_child(vb)
	vb.add_child(UIStyle.label("%s ×%d" % [r["name"], int(r["n"])] if unlocked else "???", 17))
	if unlocked:
		var parts := []
		for k in r["cost"]:
			var need: int = r["cost"][k]
			parts.append("%s %d/%d" % [Crafting.cost_label(k, need), Crafting.have(k), need])
		var cl := UIStyle.label(" · ".join(parts), 13, UIStyle.TEXT_SOFT)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size.x = 260
		vb.add_child(cl)
	else:
		vb.add_child(UIStyle.label(Crafting.lock_text(r), 13, UIStyle.TEXT_SOFT))
	var b := UIStyle.colored_button("Fabriquer", UIStyle.GREEN, 15) if unlocked else UIStyle.button("Verrouillé", 14)
	b.disabled = not Crafting.can_craft(r)
	b.pressed.connect(func():
		if Crafting.craft(r):
			Audio.play("place_wood", -4.0)
			Game.save_game())
	h.add_child(b)
	return p
