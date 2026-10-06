class_name ToolActions
extends Node
## L'outil universel et ses quatre pouvoirs, appliqués à la cible de ToolAim :
##   0 casser · 1 poser (blocs, constructions, meubles) · 2 fleurir · 3 planter.
## Tout ce qu'on récupère est annoncé au joueur (Main.gain).

var main: Main
var cooldown := 0.0


## Utilise le pouvoir sélectionné, ou `force` (0 : casser, pour le clic droit).
func use_power(force := -1) -> void:
	var aim := main.aim
	var target := aim.target
	if target.is_empty() or cooldown > 0.0:
		return
	var power: int = main.power if force < 0 else force
	if main.interior:
		_use_power_inside(power)
		return
	if not main.hud.power_unlocked(power):
		main.deny("Ce pouvoir n'est pas encore débloqué.")
		return
	cooldown = 0.18
	var ok := false
	if target.has("prop"):
		if power == 0:
			ok = _cut_prop()
		elif power == 1:
			main.deny("Vise le sol pour poser.")
		if ok:
			main.player.face_towards(target["point"])
			main.player.play_action("break")
		return
	match power:
		0:
			ok = _break()
		1:
			ok = main.construction.place_structure() if main.structure != "" else _place()
		2:
			ok = _bloom()
		3:
			ok = _tree()
	if ok:
		main.player.face_towards(Vector3(target["pos"] as Vector3i) + Vector3(0.5, 0, 0.5))
		main.player.play_action(["break", "place", "bloom", "tree"][power])


func _break() -> bool:
	var world := main.world
	var target := main.aim.target
	var p: Vector3i = target["pos"]
	var b: int = target["block"]
	if p.y <= 0:
		main.deny("Trop profond pour être cassé.")
		return false
	world.set_block(p, Blocks.AIR)
	var above := p + Vector3i.UP
	if Blocks.is_deco(world.get_blockv(above)):
		world.set_block(above, Blocks.AIR)
	world.flush()
	var center := Vector3(p) + Vector3(0.5, 0.5, 0.5)
	main.burst(center, Blocks.main_color(b), 14)
	Audio.play("break_" + material_sound(b), -2.0, 0.1, 1.25 if Blocks.is_deco(b) else 1.0)
	if b == Blocks.DEBRIS:
		if p.y <= IslandGenerator.SEA + 3:
			Game.add_stat("clean_shore")
		Game.add_stat("clean_waste")
		Game.notify_action("clean_waste")
	elif b == Blocks.SLUDGE:
		Game.add_stat("clean_water")
		Game.notify_action("clean_water")
	# Les objets posés au-dessus ne doivent pas flotter.
	main.props.resnap_near(Vector3(p) + Vector3(0.5, 0, 0.5), 4.0)
	main.nav.refresh_area(Vector3(p), 1.5)
	# On récupère ce qu'on casse (une fleur donne une plante).
	var drop := Blocks.drop_of(b)
	if drop >= 0:
		Game.add_block(drop)
		main.gain(Blocks.block_name(drop), 1, Blocks.main_color(drop), center)
	elif b in Blocks.FLOWERS:
		Game.add_item("plant")
		main.collect("flowers", str(b))
		main.gain(Items.name_of("plant"), 1, Items.color_of("plant"), center, "plant")
	main.construction.count_altitude(p.y)
	Game.add_stat("break")
	Game.notify_action("break")
	main.hud.set_block(main.block)
	return true


## Couper un arbre, ou retirer un feu / un potager posé.
func _cut_prop() -> bool:
	var props := main.props
	var id: int = main.aim.target["prop"]
	var kind := props.kind_of(id)
	var def: Dictionary = Props.KINDS.get(kind, {})
	var mine := props.key_of(id).begins_with("p:")
	if main.worksites.is_targeted(props.key_of(id)):
		main.deny("Un chantier de démolition est déjà prévu ici.")
		return false
	# Grosses choses (maison, ruines) : ce sont les habitants qui démolissent.
	if (Props.is_site(kind) and mine) or def.has("demolish"):
		main.construction.demolish(id)
		return true
	if Props.is_structure(kind) and mine:
		# Une construction posée par le joueur retourne dans l'inventaire.
		var ab0 := props.bounds(id)
		props.remove(id)
		Game.add_structure(kind)
		main.burst(ab0.get_center(), Color("c99d6c"), 14)
		Audio.play("place_wood", -2.0, 0.1, 1.2)
		main.gain(Crafting.structure_name(kind), 1, Color("c99d6c"), ab0.get_center())
		main.hud.set_block(main.block)
		return true
	if not def.get("cut", false):
		main.deny("Mieux vaut laisser ça où c'est.")
		return false
	var ab := props.bounds(id)
	props.remove(id)
	if Props.is_tree(kind):
		main.collect("trees", kind)
		main.burst(ab.get_center() + Vector3(0, ab.size.y * 0.2, 0), Color("6cbf4a"), 24)
		main.burst(ab.position + Vector3(ab.size.x * 0.5, 0.5, ab.size.z * 0.5), Color("c99d6c"), 12)
		Audio.play("break_wood", -2.0, 0.1, 0.8)
		var n := 2 if ab.size.y > 3.0 else 1
		Game.add_item("branch", n)
		main.gain(Items.name_of("branch", n), n, Items.color_of("branch"), ab.position + Vector3(ab.size.x * 0.5, 1.2, ab.size.z * 0.5), "branch")
		Game.add_stat("cut_tree")
	else:
		main.burst(ab.get_center(), Color("c99d6c"), 12)
		Audio.play("break_wood", -2.0, 0.1, 1.1)
	Game.add_stat("break")
	Game.notify_action("break")
	return true


func _place() -> bool:
	var world := main.world
	var target := main.aim.target
	var block := main.block
	var p: Vector3i = target["pos"]
	if not Blocks.is_deco(int(target["block"])):
		p += target["normal"] as Vector3i
	if not VoxelWorld.in_bounds(p.x, p.y, p.z) or p.y >= VoxelWorld.SY - 1:
		return false
	var cur := world.get_blockv(p)
	if cur != Blocks.AIR and not Blocks.is_deco(cur):
		return false
	if _overlaps_entity(p):
		main.deny("Quelqu'un est dans le passage.")
		return false
	# On ne pose que les blocs qu'on possède (cassés ou fabriqués).
	if not Game.admin and Game.block_count(block) <= 0:
		main.deny("Plus de « %s » : casse-en ou fabrique-en." % Blocks.block_name(block))
		return false
	if main.props.any_near(Vector3(p) + Vector3(0.5, 0, 0.5), 0.6):
		main.deny("Pas de place ici.")
		return false
	world.set_block(p, block)
	world.flush()
	main.props.resnap_near(Vector3(p) + Vector3(0.5, 0, 0.5), 3.0)
	main.nav.refresh_area(Vector3(p), 1.5)
	main.burst(Vector3(p) + Vector3(0.5, 0.5, 0.5), Blocks.main_color(block), 8)
	Audio.play("place_wood" if material_sound(block) == "wood" else "place", -2.0)
	if not Game.admin:
		Game.add_block(block, -1)
	main.construction.count_altitude(p.y)
	Game.add_stat("place")
	Game.add_stat("place_%d" % block)
	Game.notify_action("place")
	main.hud.set_block(block)
	return true


func _bloom() -> bool:
	var world := main.world
	var target := main.aim.target
	var rng := main.rng
	var c: Vector3i = target["pos"]
	if Blocks.is_deco(int(target["block"])):
		c.y -= 1
	var biome: String = IslandDB.get_island(Game.current_island)["biome"]
	var flowers: Array = IslandGenerator.FLOWER_SETS[biome]
	var chance := 1.0 if Game.tutorial_step == 5 else 0.75
	var count := 0
	var converted := 0
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if dx * dx + dz * dz > 5:
				continue
			var x := c.x + dx
			var z := c.z + dz
			var y := -1
			for yy in range(c.y + 2, c.y - 3, -1):
				if world.is_opaque(x, yy, z) and not world.is_opaque(x, yy + 1, z):
					y = yy
					break
			if y < 0 or y + 1 >= VoxelWorld.SY:
				continue
			var g := world.get_block(x, y, z)
			if g == Blocks.DIRT or g == Blocks.SNOW:
				world.set_block(Vector3i(x, y, z), Blocks.GRASS)
				g = Blocks.GRASS
				converted += 1
			if g == Blocks.GRASS or g == Blocks.SAND or g == Blocks.MOSS:
				var above := world.get_block(x, y + 1, z)
				if (above == Blocks.AIR or above == Blocks.TALL_GRASS) and rng.randf() < chance:
					var f: int = flowers.pick_random()
					world.set_block(Vector3i(x, y + 1, z), f)
					main.collect("flowers", str(f))
					count += 1
					main.burst(Vector3(x + 0.5, y + 1.3, z + 0.5), Blocks.main_color(f), 4)
	if count == 0 and converted == 0:
		main.deny("Il n'y a rien à faire fleurir ici.")
		return false
	world.flush()
	main.burst(Vector3(c) + Vector3(0.5, 1.5, 0.5), Color("ffffff"), 10)
	Audio.play("bloom", -3.0, 0.15)
	main.construction.count_altitude(c.y)
	if count > 0:
		Game.add_stat("bloom", count)
	Game.notify_action("bloom")
	return true


func _tree() -> bool:
	var world := main.world
	var target := main.aim.target
	var rng := main.rng
	var g: Vector3i = target["pos"]
	var gb: int = target["block"]
	if Blocks.is_deco(gb):
		g.y -= 1
		gb = world.get_blockv(g)
	if not gb in [Blocks.GRASS, Blocks.DIRT, Blocks.SAND, Blocks.SNOW, Blocks.MOSS]:
		main.deny("Les arbres poussent sur l'herbe, la terre, le sable ou la neige.")
		return false
	var base := g + Vector3i.UP
	var bc := Vector3(base) + Vector3(0.5, 0, 0.5)
	var pp := main.player.global_position
	if Vector2(bc.x - pp.x, bc.z - pp.z).length() < 1.2 and absf(bc.y - pp.y) < 3.0:
		main.deny("Recule un peu pour laisser pousser l'arbre.")
		return false
	if main.props.any_near(bc, 2.0) or world.is_opaque(base.x, base.y, base.z) or world.is_opaque(base.x, base.y + 1, base.z):
		main.deny("Pas assez de place pour un arbre.")
		return false
	if Blocks.is_deco(world.get_blockv(base)):
		world.set_block(base, Blocks.AIR)
		world.flush()
	var biome: String = IslandDB.get_island(Game.current_island)["biome"]
	var kinds: Array = Props.TREES[biome]
	var tree_kind: String = kinds[rng.randi() % kinds.size()]
	main.props.add_persistent(tree_kind, bc, rng.randf() * TAU, rng.randf_range(0.9, 1.15), true, {"planted": Game.day})
	main.collect("trees", tree_kind)
	main.burst(bc + Vector3(0, 3.5, 0), Color("6cbf4a"), 22)
	Audio.play("tree", -4.0)
	Audio.play("place_wood", -4.0, 0.1, 0.8)
	main.burst(bc + Vector3(0, 0.5, 0), Color("c99d6c"), 10)
	main.construction.count_altitude(g.y)
	Game.add_stat("tree")
	Game.notify_action("tree")
	return true


# --- À l'intérieur : meubler -------------------------------------------------

func _use_power_inside(power: int) -> void:
	cooldown = 0.2
	var aim := main.aim
	var interior := main.interior
	var structure := main.structure
	if power == 0 and aim.target.has("furn"):
		var name := interior.take_furniture(int(aim.target["furn"]))
		if name != "":
			Game.add_structure("f_" + name)
			Audio.play("place_wood", -4.0, 0.1, 1.2)
			main.player.play_action("break")
			main.gain(Interior.label_of(name), 1, Color("c99d6c"), aim.target["point"])
			main.hud.set_block(main.block)
			Game.save_game()
	elif power == 1 and structure.begins_with("f_") and aim.ghost_shown():
		var name := structure.trim_prefix("f_")
		var lp := interior.to_local(aim.ghost_pos)
		interior.add_furniture(name, lp.x, lp.z, aim.place_rot)
		if not Game.admin:
			Game.add_structure(structure, -1)
		Audio.play("place_wood", -3.0, 0.05, 0.9)
		main.player.play_action("place")
		Game.notify_action("place")
		main.hud.set_structure(structure)
		if Game.structure_count(structure) <= 0 and not Game.admin:
			main.select_block(main.block)
		Game.save_game()
	elif power == 1 and not structure.begins_with("f_"):
		main.deny("À l'intérieur, on ne pose que des meubles.")
	elif power == 1:
		main.deny("Pas de place ici pour ce meuble.")
	else:
		main.deny()


# --- Utilitaires -------------------------------------------------------------

static func material_sound(b: int) -> String:
	if b in [Blocks.WOOD, Blocks.PLANK, Blocks.PALM_WOOD]:
		return "wood"
	if b in [Blocks.STONE, Blocks.BRICK, Blocks.BASALT, Blocks.MOSS, Blocks.ICE, Blocks.CLAY]:
		return "stone"
	return "soft"


## Le joueur ou un habitant occupe-t-il cette case ?
func _overlaps_entity(p: Vector3i) -> bool:
	var cell := AABB(Vector3(p), Vector3.ONE)
	var pp := main.player.global_position
	if cell.intersects(AABB(pp - Vector3(0.3, 0, 0.3), Vector3(0.6, 1.3, 0.6))):
		return true
	return main.residents.overlaps(cell)
