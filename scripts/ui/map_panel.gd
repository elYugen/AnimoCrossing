class_name MapPanel
extends Control
## Carte de l'archipel : voyager entre les îles débloquées.

signal closed
signal travel_requested(island_id: String)

var _row: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := UIStyle.modal("Carte de l'archipel", Vector2(1040, 420))
	add_child(m["root"])
	(m["close"] as Button).pressed.connect(func(): closed.emit())
	var body: VBoxContainer = m["body"]
	var sub := UIStyle.label(_subtitle(), 17, UIStyle.TEXT_SOFT)
	sub.name = "Sub"
	body.add_child(sub)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 14)
	body.add_child(_row)


func open() -> void:
	(find_child("Sub", true, false) as Label).text = _subtitle()
	for c in _row.get_children():
		c.queue_free()
	for isl in IslandDB.ISLANDS:
		_row.add_child(_card(isl))


func _subtitle() -> String:
	var n := Game.resident_count()
	return "Chaque île de l'archipel se découvre à sa manière. %d habitant%s installé%s." % [n, "s" if n > 1 else "", "s" if n > 1 else ""]


func _card(isl: Dictionary) -> PanelContainer:
	var unlocked := Game.is_island_unlocked(isl["id"])
	var here: bool = isl["id"] == Game.current_island
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(240, 300)
	var col: Color = isl["water_shallow"]
	p.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.CREAM if unlocked else Color("efe8de"), 20, col.darkened(0.2) if here else UIStyle.BORDER, 4 if here else 3, 14))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	var pic := _IslandPic.new()
	pic.island = isl
	pic.locked = not unlocked
	pic.custom_minimum_size = Vector2(0, 110)
	vb.add_child(pic)
	vb.add_child(UIStyle.title(isl["name"], 22))
	var d := UIStyle.label(isl["desc"], 15, UIStyle.TEXT_SOFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(210, 60)
	vb.add_child(d)
	if unlocked:
		vb.add_child(UIStyle.label("Habitants : %d  ·  %s" % [Vitality.residents(isl["id"]), Vitality.tier_name(Vitality.percent(isl["id"]))], 15))
	else:
		var h := UIStyle.label(isl.get("hint", ""), 14, UIStyle.TEXT_SOFT)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.custom_minimum_size = Vector2(210, 0)
		vb.add_child(h)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	if here:
		var b := UIStyle.button("Tu es ici", 17)
		b.disabled = true
		vb.add_child(b)
	elif unlocked:
		var b := UIStyle.colored_button("Voyager", UIStyle.BLUE, 17)
		b.pressed.connect(func(): travel_requested.emit(isl["id"]))
		vb.add_child(b)
	else:
		var b := UIStyle.button("Pas encore découverte", 16)
		b.disabled = true
		vb.add_child(b)
	return p


class _IslandPic extends Control:
	var island: Dictionary
	var locked := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var water: Color = island["water_deep"]
		var shallow: Color = island["water_shallow"]
		draw_rect(r, water.lerp(Color("c8c0b4"), 0.6) if locked else water)
		var c := size * 0.5
		var land := {"prairie": Color("7bc95a"), "plage": Color("f3e2aa"), "givre": Color("f4f8ff"), "braise": Color("e8893a")}
		var lc: Color = land.get(island["biome"], Color.GREEN)
		if locked:
			lc = lc.lerp(Color("b8aa98"), 0.7)
			shallow = shallow.lerp(Color("c8c0b4"), 0.7)
		# Île en « pixels » voxel.
		var cell := 8.0
		var seed_v: int = island["seed"]
		for gx in range(-9, 10):
			for gy in range(-5, 6):
				var d := Vector2(gx / 9.0, gy / 5.0).length()
				var n := sin(gx * 1.7 + seed_v) * 0.12 + cos(gy * 2.3 + seed_v * 0.5) * 0.12
				if d + n < 0.95:
					var col := shallow if d + n > 0.8 else lc
					if d + n < 0.35 and island["biome"] != "plage":
						col = col.darkened(0.12)
					draw_rect(Rect2(c + Vector2(gx, gy) * cell - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), col)
		if locked:
			draw_string(UIStyle.font(), c + Vector2(-8, 12), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("6e5f52"))
