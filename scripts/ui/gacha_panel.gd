class_name GachaPanel
extends Control
## Machine à capsules : dépense des Étoiles pour obtenir de nouveaux amis.

signal closed

var _machine: _Machine
var _capsule: _Capsule
var _btn1: Button
var _btn10: Button
var _stars: Label
var _result_box: VBoxContainer
var _preview: CreaturePreview
var _res_name: Label
var _res_info: Label
var _grid: GridContainer
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := UIStyle.modal("Machine Gacha", Vector2(940, 560))
	add_child(m["root"])
	(m["close"] as Button).pressed.connect(func():
		if not _busy:
			closed.emit())
	var body: VBoxContainer = m["body"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	body.add_child(row)

	# Colonne machine
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var mc := Control.new()
	mc.custom_minimum_size = Vector2(320, 340)
	left.add_child(mc)
	_machine = _Machine.new()
	_machine.size = Vector2(320, 340)
	_machine.pivot_offset = Vector2(160, 300)
	mc.add_child(_machine)
	_capsule = _Capsule.new()
	_capsule.size = Vector2(60, 60)
	_capsule.pivot_offset = Vector2(30, 30)
	_capsule.visible = false
	mc.add_child(_capsule)
	_stars = UIStyle.label("", 20, UIStyle.STAR)
	_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_stars)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(btns)
	_btn1 = UIStyle.colored_button("Tirer x1  (%d★)" % Game.PULL_COST, UIStyle.PINK, 17)
	_btn1.pressed.connect(func(): _pull(1))
	btns.add_child(_btn1)
	_btn10 = UIStyle.colored_button("Tirer x10  (%d★)" % Game.TEN_PULL_COST, Color("b08ae6"), 17)
	_btn10.pressed.connect(func(): _pull(10))
	btns.add_child(_btn10)
	var rates := UIStyle.label("Commun 70%%  ·  Rare 25%%  ·  Légendaire 5%%\nx10 : un Rare garanti · Légendaire garanti tous les %d tirages" % Game.LEGENDARY_PITY, 13, UIStyle.TEXT_SOFT)
	rates.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(rates)

	# Colonne résultat
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.CREAM, 20, UIStyle.BORDER, 3, 16))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 8)
	right.add_child(_result_box)
	_preview = CreaturePreview.new()
	_preview.custom_minimum_size = Vector2(420, 240)
	_preview.spin_speed = 1.2
	_result_box.add_child(_preview)
	_res_name = UIStyle.title("Tente ta chance !", 28)
	_result_box.add_child(_res_name)
	_res_info = UIStyle.label("Chaque capsule contient un nouvel ami.\nLes doublons te rendent %d★." % Game.DUPLICATE_REFUND, 16, UIStyle.TEXT_SOFT)
	_res_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_box.add_child(_res_info)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_result_box.add_child(_grid)


func open() -> void:
	_refresh()


func _refresh() -> void:
	_stars.text = "★ %d Étoiles" % Game.stars + ("  ·  ADMIN : gratuit" if Game.admin else "")
	_btn1.disabled = _busy or (not Game.admin and Game.stars < Game.PULL_COST)
	_btn10.disabled = _busy or (not Game.admin and Game.stars < Game.TEN_PULL_COST)


func _pull(count: int) -> void:
	if _busy:
		return
	var results := Game.gacha_pull(count)
	if results.is_empty():
		return
	_busy = true
	_refresh()
	Audio.play("coins", -4.0)
	Audio.play("shake", -4.0)
	for c in _grid.get_children():
		c.queue_free()
	_preview.clear()
	_res_name.text = "..."
	_res_info.text = ""
	var best: Dictionary = results[0]
	for r in results:
		if int(r["rarity"]) > int(best["rarity"]):
			best = r
	var rcol: Color = CreatureDB.RARITY_COLORS[int(best["rarity"])]

	# Animation : la machine tremble, la capsule tombe, rebondit, s'ouvre.
	_capsule.top_color = rcol
	_capsule.visible = true
	_capsule.scale = Vector2.ONE
	_capsule.modulate = Color.WHITE
	_capsule.position = Vector2(130, 120)
	var tw := create_tween()
	for i in 4:
		tw.tween_property(_machine, "rotation", 0.06, 0.06)
		tw.tween_property(_machine, "rotation", -0.06, 0.06)
	tw.tween_property(_machine, "rotation", 0.0, 0.05)
	tw.tween_property(_capsule, "position", Vector2(130, 262), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_capsule, "rotation", TAU, 0.4)
	tw.parallel().tween_property(_capsule, "scale", Vector2(1.4, 1.4), 0.4)
	tw.tween_property(_capsule, "modulate", Color(3, 3, 3, 0), 0.25)
	await tw.finished
	Audio.play("capsule", -2.0)
	Audio.play(["jingle_common", "jingle_rare", "jingle_legend"][int(best["rarity"])], -3.0, 0.0)
	_capsule.visible = false
	_capsule.rotation = 0.0

	var bc := CreatureDB.get_creature(best["id"])
	_preview.set_creature(bc["look"])
	_res_name.text = bc["name"]
	_res_name.add_theme_color_override("font_color", rcol.darkened(0.25))
	var r: int = best["rarity"]
	_res_info.text = "%s %s · %s" % [CreatureDB.RARITY_NAMES[r], "★".repeat(r + 1), "NOUVEL AMI !" if best["new"] else "Doublon (+%d★)" % Game.DUPLICATE_REFUND]
	if count > 1:
		for res in results:
			var c := CreatureDB.get_creature(res["id"])
			var rr: int = res["rarity"]
			var chip := PanelContainer.new()
			var col: Color = CreatureDB.RARITY_COLORS[rr]
			chip.add_theme_stylebox_override("panel", UIStyle.box(col.lightened(0.6), 12, col, 2, 6))
			var l := UIStyle.label(c["name"] + (" ✦" if res["new"] else ""), 13)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size.x = 72
			chip.add_child(l)
			_grid.add_child(chip)
	_busy = false
	_refresh()


class _Machine extends Control:
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 120)
		# Pied
		draw_rect(Rect2(Vector2(70, 200), Vector2(180, 120)), Color("f07fb0"))
		draw_rect(Rect2(Vector2(70, 200), Vector2(180, 14)), Color("f7a3c8"))
		draw_rect(Rect2(Vector2(60, 314), Vector2(200, 20)), Color("d0628f"))
		# Trappe de sortie
		draw_rect(Rect2(Vector2(118, 252), Vector2(84, 56)), Color("8a4a66"))
		# Molette
		draw_circle(Vector2(225, 240), 18, Color("ffd84a"))
		draw_rect(Rect2(Vector2(221, 226), Vector2(8, 28)), Color("e0a82a"))
		# Dôme
		draw_circle(c, 104, Color("d0628f"))
		draw_circle(c, 96, Color(0.85, 0.95, 1.0, 1.0))
		var cols := [Color("f7a3c8"), Color("8fd16a"), Color("6aa8f2"), Color("f5b83d"), Color("ae84e6"), Color("ec5864")]
		var k := 0
		for gy in range(0, 4):
			for gx in range(-3, 4):
				var p := c + Vector2(gx * 24 + (gy % 2) * 12, 70 - gy * 22)
				if p.distance_to(c) < 84:
					var col: Color = cols[k % cols.size()]
					draw_circle(p, 11, col)
					draw_circle(p + Vector2(-3, -3), 4, Color(1, 1, 1, 0.7))
					k += 1
		draw_circle(c + Vector2(-40, -45), 16, Color(1, 1, 1, 0.55))
		draw_string(UIStyle.font(), Vector2(98, 236), "GACHA", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


class _Capsule extends Control:
	var top_color := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 28, Color("ffffff"))
		draw_arc(c, 28, 0, TAU, 32, Color("5a4636"), 3.0, true)
		var pts := PackedVector2Array()
		for i in 17:
			var a := PI + PI * i / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * 26.5)
		draw_colored_polygon(pts, top_color)
		draw_line(c + Vector2(-28, 0), c + Vector2(28, 0), Color("5a4636"), 3.0)
		draw_circle(c + Vector2(-9, -12), 5, Color(1, 1, 1, 0.7))
