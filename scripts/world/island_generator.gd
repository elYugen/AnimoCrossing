class_name IslandGenerator
extends RefCounted
## Génération procédurale des îles voxel + construction des arbres.

const SEA := 6
const SPAWN := Vector2i(60, 86)
const CENTER := 63.5
const RADIUS := 56.0

const FLOWER_SETS := {
	"prairie": [Blocks.FLOWER_RED, Blocks.FLOWER_YELLOW, Blocks.FLOWER_WHITE, Blocks.FLOWER_PINK, Blocks.FLOWER_BLUE, Blocks.FLOWER_PURPLE],
	"plage": [Blocks.FLOWER_PINK, Blocks.FLOWER_RED, Blocks.FLOWER_YELLOW, Blocks.FLOWER_WHITE],
	"givre": [Blocks.FLOWER_WHITE, Blocks.FLOWER_BLUE, Blocks.FLOWER_PURPLE],
	"braise": [Blocks.FLOWER_RED, Blocks.FLOWER_YELLOW, Blocks.FLOWER_PURPLE, Blocks.FLOWER_PINK],
}


## Génère l'île dans `world` et renvoie la position d'apparition du joueur.
static func generate(world: VoxelWorld, island: Dictionary) -> Vector3:
	world.clear()
	var biome: String = island["biome"]
	var seed_v: int = island["seed"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.032
	noise.fractal_octaves = 3
	var warp := FastNoiseLite.new()
	warp.seed = seed_v + 7
	warp.frequency = 0.04
	var heights := PackedInt32Array()
	heights.resize(VoxelWorld.SX * VoxelWorld.SZ)
	var cone_map := PackedFloat32Array()
	cone_map.resize(VoxelWorld.SX * VoxelWorld.SZ)
	var raw := PackedFloat32Array()
	raw.resize(VoxelWorld.SX * VoxelWorld.SZ)

	for z in VoxelWorld.SZ:
		for x in VoxelWorld.SX:
			var dx := (x - CENTER) / RADIUS
			var dz := (z - CENTER) / RADIUS
			var d := sqrt(dx * dx + dz * dz) + warp.get_noise_2d(x, z) * 0.22
			var f := clampf(1.0 - d, 0.0, 1.0)
			f = f * f * (3.0 - 2.0 * f)
			var hn := (noise.get_noise_2d(x, z) + 1.0) * 0.5
			var h := SEA - 3.0
			var cone := 0.0
			match biome:
				"prairie":
					h += f * 9.0 + hn * 6.0 * f
				"plage":
					h += f * 6.0 + hn * 2.5 * f
				"givre":
					h += f * 8.0 + hn * 4.0 * f
					var pd := Vector2(x - 84, z - 42).length()
					var peak := clampf(1.0 - pd / 26.0, 0.0, 1.0)
					h += peak * peak * 16.0
				"braise":
					h += f * 8.0 + hn * 4.0 * f
					var vd := Vector2(x - 66, z - 46).length()
					cone = clampf(1.0 - vd / 26.0, 0.0, 1.0)
					h += cone * cone * 18.0
					if vd < 5.0:
						h -= (5.0 - vd) * 2.0
			raw[x + z * VoxelWorld.SX] = h
			cone_map[x + z * VoxelWorld.SX] = cone

	# Clairière plate autour du point d'apparition, à la hauteur naturelle
	# moyenne du terrain (évite de créer une cuvette).
	var sum := 0.0
	var n := 0
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			sum += raw[(SPAWN.x + dx) + (SPAWN.y + dz) * VoxelWorld.SX]
			n += 1
	var target := maxf(SEA + 3.0, floorf(sum / n))
	for z in VoxelWorld.SZ:
		for x in VoxelWorld.SX:
			var h := raw[x + z * VoxelWorld.SX]
			var sd := Vector2(x - SPAWN.x, z - SPAWN.y).length()
			if sd < 8.0:
				var t := clampf((8.0 - sd) / 3.5, 0.0, 1.0)
				h = lerpf(h, target, t)
			heights[x + z * VoxelWorld.SX] = clampi(floori(h), 1, VoxelWorld.SY - 12)

	# Remplissage des colonnes.
	for z in VoxelWorld.SZ:
		for x in VoxelWorld.SX:
			var h := heights[x + z * VoxelWorld.SX]
			var cone := cone_map[x + z * VoxelWorld.SX]
			var hn := (noise.get_noise_2d(x * 2.3, z * 2.3) + 1.0) * 0.5
			var top := _top_block(biome, h, hn, cone)
			var sub := Blocks.DIRT
			if biome == "givre":
				sub = Blocks.STONE if h > SEA + 6 else Blocks.DIRT
			elif biome == "braise" and cone > 0.35:
				sub = Blocks.BASALT
			elif top == Blocks.SAND:
				sub = Blocks.SAND
			for y in range(0, h + 1):
				var b := Blocks.STONE
				if y == h:
					b = top
				elif y >= h - 2:
					b = sub
				world.set_raw(x, y, z, b)

	# Parcelle de terre pour le tutoriel.
	if island["id"] == "prairie":
		var sh := heights[SPAWN.x + SPAWN.y * VoxelWorld.SX]
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				world.set_raw(SPAWN.x + 4 + dx, sh, SPAWN.y - 2 + dz, Blocks.DIRT)

	# Ruines de maisons.
	var ruins := _place_ruins(world, heights, biome, rng, 11)

	# Rochers.
	for i in 30:
		var x := rng.randi_range(6, VoxelWorld.SX - 7)
		var z := rng.randi_range(6, VoxelWorld.SZ - 7)
		var y := world.top_solid_y(x, z)
		if y <= SEA + 1 or _near_spawn(x, z, 6):
			continue
		var rock := Blocks.MOSS if biome == "prairie" or biome == "givre" else Blocks.STONE
		if biome == "braise":
			rock = Blocks.BASALT
		for dx in range(0, 2):
			for dz in range(0, 2):
				if rng.randf() < 0.8:
					world.set_raw(x + dx, y + 1, z + dz, rock)
		world.set_raw(x, y + 2, z, rock)

	# Arbres.
	var tree_count := {"prairie": 60, "plage": 40, "givre": 70, "braise": 65}
	var placed := 0
	var attempts := 0
	while placed < int(tree_count[biome]) and attempts < 2500:
		attempts += 1
		var x := rng.randi_range(4, VoxelWorld.SX - 5)
		var z := rng.randi_range(4, VoxelWorld.SZ - 5)
		if _near_spawn(x, z, 10) or _in_rects(ruins, x, z, 3):
			continue
		var y := world.top_solid_y(x, z)
		if y <= SEA:
			continue
		var ground := world.get_block(x, y, z)
		if not ground in [Blocks.GRASS, Blocks.SAND, Blocks.SNOW, Blocks.DIRT]:
			continue
		if biome == "plage" and y > SEA + 4 and rng.randf() < 0.5:
			continue
		if _has_wood_near(world, x, y + 1, z, 3):
			continue
		if grow_tree(world, x, y + 1, z, tree_style(biome, rng), rng, false):
			placed += 1

	# Fleurs et herbes hautes.
	var flowers: Array = FLOWER_SETS[biome]
	var flower_chance := {"prairie": 0.06, "plage": 0.025, "givre": 0.0, "braise": 0.035}
	var grass_chance := {"prairie": 0.09, "plage": 0.05, "givre": 0.0, "braise": 0.07}
	for z in VoxelWorld.SZ:
		for x in VoxelWorld.SX:
			var y := world.top_solid_y(x, z)
			if y < 0 or y >= VoxelWorld.SY - 1:
				continue
			if world.get_block(x, y, z) != Blocks.GRASS or world.get_block(x, y + 1, z) != Blocks.AIR:
				continue
			var r := rng.randf()
			if r < float(flower_chance[biome]):
				world.set_raw(x, y + 1, z, flowers[rng.randi() % flowers.size()])
			elif r < float(flower_chance[biome]) + float(grass_chance[biome]):
				world.set_raw(x, y + 1, z, Blocks.TALL_GRASS)

	var spawn_y := world.top_solid_y(SPAWN.x, SPAWN.y) + 1
	return Vector3(SPAWN.x + 0.5, spawn_y + 0.1, SPAWN.y + 0.5)


## Petites ruines de maisons : murs effondrés, sol, poutres et débris.
static func _place_ruins(world: VoxelWorld, heights: PackedInt32Array, biome: String, rng: RandomNumberGenerator, count: int) -> Array[Rect2i]:
	var mats := {
		"prairie": [Blocks.STONE, Blocks.MOSS, Blocks.PLANK, Blocks.WOOD],
		"plage": [Blocks.CLAY, Blocks.SAND, Blocks.PLANK, Blocks.PALM_WOOD],
		"givre": [Blocks.STONE, Blocks.MOSS, Blocks.PLANK, Blocks.WOOD],
		"braise": [Blocks.BRICK, Blocks.BASALT, Blocks.STONE, Blocks.WOOD],
	}
	var m: Array = mats[biome]
	var wall: int = m[0]
	var wall_alt: int = m[1]
	var floor_b: int = m[2]
	var beam: int = m[3]
	var rects: Array[Rect2i] = []
	var attempts := 0
	while rects.size() < count and attempts < 400:
		attempts += 1
		var w := rng.randi_range(5, 8)
		var d := rng.randi_range(5, 7)
		var x0 := rng.randi_range(8, VoxelWorld.SX - 9 - w)
		var z0 := rng.randi_range(8, VoxelWorld.SZ - 9 - d)
		var rect := Rect2i(x0, z0, w, d)
		if _near_spawn(x0 + w / 2, z0 + d / 2, 14):
			continue
		var overlap := false
		for r in rects:
			if r.grow(4).intersects(rect):
				overlap = true
				break
		if overlap:
			continue
		# Terrain assez plat et hors de l'eau.
		var lo := 999
		var hi := -999
		for z in range(z0, z0 + d):
			for x in range(x0, x0 + w):
				var h := heights[x + z * VoxelWorld.SX]
				lo = mini(lo, h)
				hi = maxi(hi, h)
		if hi - lo > 2 or lo <= SEA + 1:
			continue
		rects.append(rect)
		var base := hi
		var door_side := rng.randi_range(0, 3)
		for z in range(z0, z0 + d):
			for x in range(x0, x0 + w):
				# Fondations jusqu'au terrain.
				for y in range(heights[x + z * VoxelWorld.SX] + 1, base):
					world.set_raw(x, y, z, wall)
				var edge_x := x == x0 or x == x0 + w - 1
				var edge_z := z == z0 or z == z0 + d - 1
				var corner := edge_x and edge_z
				# Sol (troué par endroits).
				world.set_raw(x, base, z, floor_b if rng.randf() < 0.8 else wall_alt)
				for y in range(base + 1, base + 5):
					world.set_raw(x, y, z, Blocks.AIR)
				if not (edge_x or edge_z):
					if rng.randf() < 0.18:
						world.set_raw(x, base + 1, z, Blocks.TALL_GRASS if biome != "givre" else Blocks.SNOW)
					continue
				# Porte au milieu d'un côté.
				var mid_x := x0 + w / 2
				var mid_z := z0 + d / 2
				var is_door := (door_side == 0 and z == z0 and x == mid_x) or (door_side == 1 and z == z0 + d - 1 and x == mid_x) 					or (door_side == 2 and x == x0 and z == mid_z) or (door_side == 3 and x == x0 + w - 1 and z == mid_z)
				if is_door:
					continue
				var hh := 0
				if corner:
					hh = rng.randi_range(2, 4)
				else:
					var r := rng.randf()
					hh = 0 if r < 0.22 else (1 if r < 0.5 else (2 if r < 0.82 else 3))
				for k in hh:
					world.set_raw(x, base + 1 + k, z, wall_alt if rng.randf() < 0.3 else wall)
				if biome == "givre" and hh > 0:
					world.set_raw(x, base + 1 + hh, z, Blocks.SNOW)
		# Une vieille poutre qui traverse.
		if rng.randf() < 0.6:
			var bz := z0 + rng.randi_range(1, d - 2)
			for x in range(x0, x0 + w):
				if rng.randf() < 0.75:
					world.set_raw(x, base + 4, bz, beam)
		# Débris tombés autour.
		for i in rng.randi_range(3, 7):
			var fx := x0 + rng.randi_range(-2, w + 1)
			var fz := z0 + rng.randi_range(-2, d + 1)
			if rect.has_point(Vector2i(fx, fz)):
				continue
			var fy := world.top_solid_y(fx, fz)
			if fy > SEA:
				world.set_raw(fx, fy + 1, fz, wall_alt if rng.randf() < 0.5 else wall)
	return rects


static func _top_block(biome: String, h: int, hn: float, cone: float) -> int:
	if h <= SEA:
		return Blocks.STONE if biome == "givre" else Blocks.SAND
	if h <= SEA + 1:
		return Blocks.SNOW if biome == "givre" else Blocks.SAND
	match biome:
		"prairie":
			return Blocks.GRASS
		"plage":
			return Blocks.GRASS if (hn > 0.55 and h > SEA + 2) else Blocks.SAND
		"givre":
			return Blocks.SNOW
		"braise":
			return Blocks.BASALT if cone > 0.42 else Blocks.GRASS
	return Blocks.GRASS


static func _in_rects(rects: Array[Rect2i], x: int, z: int, margin: int) -> bool:
	for r in rects:
		if r.grow(margin).has_point(Vector2i(x, z)):
			return true
	return false


static func _near_spawn(x: int, z: int, r: float) -> bool:
	return Vector2(x - SPAWN.x, z - SPAWN.y).length() < r


static func _has_wood_near(world: VoxelWorld, x: int, y: int, z: int, r: int) -> bool:
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for dy in range(-2, 3):
				var b := world.get_block(x + dx, y + dy, z + dz)
				if b == Blocks.WOOD or b == Blocks.PALM_WOOD:
					return true
	return false


static func tree_style(biome: String, rng: RandomNumberGenerator) -> String:
	match biome:
		"plage":
			return "palm"
		"givre":
			return "pine"
		"braise":
			return "autumn" if rng.randf() < 0.75 else "oak"
	return "blossom" if rng.randf() < 0.25 else "oak"


static func _put(world: VoxelWorld, x: int, y: int, z: int, id: int, live: bool) -> void:
	if not VoxelWorld.in_bounds(x, y, z):
		return
	var cur := world.get_block(x, y, z)
	if cur != Blocks.AIR and not Blocks.is_deco(cur):
		return
	if live:
		world.set_block(Vector3i(x, y, z), id)
	else:
		world.set_raw(x, y, z, id)


## Fait pousser un arbre dont le tronc commence en (x, y, z).
## `live` = modification du joueur (enregistrée et remaillée).
static func grow_tree(world: VoxelWorld, x: int, y: int, z: int, style: String, rng: RandomNumberGenerator, live: bool) -> bool:
	var trunk_h := rng.randi_range(4, 5)
	if style == "pine":
		trunk_h = rng.randi_range(5, 7)
	elif style == "palm":
		trunk_h = rng.randi_range(5, 6)
	if y + trunk_h + 3 >= VoxelWorld.SY:
		return false
	for i in trunk_h:
		var b := world.get_block(x, y + i, z)
		if b != Blocks.AIR and not Blocks.is_deco(b):
			return false
	match style:
		"pine":
			for i in trunk_h:
				_put(world, x, y + i, z, Blocks.WOOD, live)
			var top := y + trunk_h
			var layers := [2, 2, 1, 1, 0]
			var start := top - 4
			for li in layers.size():
				var r: int = layers[li]
				var ly := start + li
				for dx in range(-r, r + 1):
					for dz in range(-r, r + 1):
						if r == 2 and abs(dx) == 2 and abs(dz) == 2:
							continue
						if dx == 0 and dz == 0 and ly < top:
							continue
						_put(world, x + dx, ly, z + dz, Blocks.PINE_LEAVES, live)
			_put(world, x, top + 1, z, Blocks.PINE_LEAVES, live)
			_put(world, x, top + 2, z, Blocks.SNOW, live)
		"palm":
			var lean := Vector2i([1, -1].pick_random(), 0) if rng.randf() < 0.5 else Vector2i(0, [1, -1].pick_random())
			var tx := x
			var tz := z
			for i in trunk_h:
				if i == 3:
					tx += lean.x
					tz += lean.y
				_put(world, tx, y + i, tz, Blocks.PALM_WOOD, live)
			var top := y + trunk_h
			_put(world, tx, top, tz, Blocks.PALM_LEAVES, live)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var arm := 2 if abs(d.x) + abs(d.y) == 2 else 3
				for k in range(1, arm + 1):
					var ly := top if k < arm else top - 1
					_put(world, tx + d.x * k, ly, tz + d.y * k, Blocks.PALM_LEAVES, live)
		_:
			var leaf := Blocks.LEAVES
			if style == "autumn":
				leaf = Blocks.AUTUMN_LEAVES
			elif style == "blossom":
				leaf = Blocks.WOOL
			for i in trunk_h:
				_put(world, x, y + i, z, Blocks.WOOD, live)
			var cy := y + trunk_h - 1
			for dy in range(-1, 3):
				var r := 2 if dy < 1 else 1
				for dx in range(-r, r + 1):
					for dz in range(-r, r + 1):
						if dx == 0 and dz == 0 and dy < 1:
							continue
						var dist := dx * dx + dz * dz
						if r == 2 and dist >= 8 and rng.randf() < 0.7:
							continue
						if dy == 2 and dist > 0 and rng.randf() < 0.5:
							continue
						_put(world, x + dx, cy + dy, z + dz, leaf, live)
	return true
