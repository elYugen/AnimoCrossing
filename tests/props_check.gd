extends Node
## Vérifie le placement de tous les objets générés sur les quatre îles :
## qui flotte, qui est enfoui dans le terrain, qui est dans l'eau, qui en
## chevauche un autre. godot --headless --path . res://tests/props_check.tscn

## Objets volontairement dans l'eau ou à moitié enfoncés.
const WATER_OK := ["wreck", "lily", "column", "column_broken", "statue_head", "obelisk"]
const EMBED_OK := ["barrier_rock", "rock_large", "log", "stump", "statue_head", "fence_broken", "wreck"]

var main: Main
var problems := 0


func _ready() -> void:
	Game.reset_game()
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_intro = true
	add_child(main)
	await _wait(10)
	for id in ["prairie", "corail", "givree", "braise"]:
		if id != "prairie":
			main.load_island(id)
		await _wait(2)
		_check_island(id)
	print("=== PLACEMENT : %d problème(s) ===" % problems)
	get_tree().quit()


func _check_island(island: String) -> void:
	var props := main.props
	var w := main.world
	var n := 0
	var report := {"flotte": [], "enfoui": [], "dans l'eau": [], "chevauche": []}
	var boxes := []  # [id, AABB] des objets solides
	for id in props.items:
		n += 1
		var kind := props.kind_of(id)
		var key := props.key_of(id)
		var pos: Vector3 = props.items[id]["pos"]
		var ab := props.bounds(id)
		# Sol sous l'objet (au centre et aux quatre coins de son emprise).
		var gc := Props.ground_y(w, floori(pos.x), floori(pos.z)) + 0.0
		var lowest := gc
		var highest := gc
		for c in [Vector2(ab.position.x + 0.2, ab.position.z + 0.2), Vector2(ab.end.x - 0.2, ab.position.z + 0.2),
				Vector2(ab.position.x + 0.2, ab.end.z - 0.2), Vector2(ab.end.x - 0.2, ab.end.z - 0.2)]:
			var g := float(Props.ground_y(w, floori(c.x), floori(c.y)))
			lowest = minf(lowest, g)
			highest = maxf(highest, g)
		if pos.y - highest > 0.6 and not kind in WATER_OK:
			report["flotte"].append("%s %s (+%.1f)" % [kind, key, pos.y - highest])
		if gc <= IslandGenerator.SEA + 0.5 and not kind in WATER_OK and kind != "rowboat":
			report["dans l'eau"].append("%s %s" % [kind, key])
		# Blocs pleins à l'intérieur du volume (au-dessus du sol de l'objet).
		var def: Dictionary = Props.KINDS[kind]
		if def["shape"] == "box" and not kind in EMBED_OK:
			var inside := 0
			var total := 0
			for x in range(floori(ab.position.x + 0.3), floori(ab.end.x - 0.3) + 1):
				for z in range(floori(ab.position.z + 0.3), floori(ab.end.z - 0.3) + 1):
					for y in range(floori(pos.y) + 1, floori(ab.end.y)):
						total += 1
						if w.is_opaque(x, y, z):
							inside += 1
			if total > 0 and float(inside) / total > 0.15:
				report["enfoui"].append("%s %s (%d %%)" % [kind, key, 100 * inside / total])
			# (on rétrécit un peu, sans rendre négatifs les objets fins)
			var shrink := Vector3(minf(0.25, ab.size.x * 0.25), minf(0.25, ab.size.y * 0.25), minf(0.25, ab.size.z * 0.25))
			boxes.append([id, AABB(ab.position + shrink, ab.size - shrink * 2.0)])
	# Chevauchements entre objets solides (hors murs d'une même ruine).
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: AABB = boxes[i][1]
			var b: AABB = boxes[j][1]
			if not a.intersects(b):
				continue
			var ka := props.key_of(boxes[i][0])
			var kb := props.key_of(boxes[j][0])
			# Les piliers dans les angles des murs d'une ruine : voulu.
			if (ka.begins_with("g:r:") or ka.begins_with("g:p:")) and (kb.begins_with("g:r:") or kb.begins_with("g:p:")):
				continue
			var inter := a.intersection(b)
			if inter.get_volume() > 0.15 * minf(a.get_volume(), b.get_volume()):
				report["chevauche"].append("%s ↔ %s" % [ka, kb])
	var trees := 0
	var landmarks := {}
	var smalls := 0
	for id in props.items:
		var k2 := props.kind_of(id)
		var key2 := props.key_of(id)
		if Props.is_tree(k2):
			trees += 1
		if key2.begins_with("g:l:"):
			landmarks[key2.get_slice(":", 2)] = true
		if key2.begins_with("g:s:"):
			smalls += 1
	print("--- %s : %d objets (%d arbres, %d petits végétaux, %d lieux à découvrir)" % [island, n, trees, smalls, landmarks.size()])
	for k in report:
		var list: Array = report[k]
		problems += list.size()
		if not list.is_empty():
			print("  %s : %d   ex. %s" % [k, list.size(), ", ".join(list.slice(0, 6))])


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame
