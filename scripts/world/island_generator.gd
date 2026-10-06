class_name IslandGenerator
extends RefCounted
## Génération procédurale des îles voxel + construction des arbres.

const SEA := 6
## Les îles font 384 x 384 blocs (VoxelWorld) : le point d'apparition est au
## sud, à mi-chemin entre le centre et la côte.
const SPAWN := Vector2i(180, 258)
const CENTER := 191.5
const RADIUS := 168.0
## Montagne de l'Île Prairie (visible depuis la plage du naufrage).
const PRAIRIE_PEAK := Vector2(207, 93)
## Sommet enneigé (Île Givrée) et volcan (Île Braise).
const GIVREE_PEAK := Vector2(252, 126)
const BRAISE_VOLCANO := Vector2(198, 138)
## Rayon des grands reliefs (montagnes, volcan).
const RELIEF := 60.0
## Rayon de la clairière plate du campement (autour du point d'apparition).
const CLEARING := 13.0
## Vitalité de l'Île Prairie nécessaire pour dégager l'accès à la montagne.
const MOUNTAIN_UNLOCK := 40

## Plage du naufrage (Île Prairie) : {"pos": Vector3 (sol), "out": Vector3 (vers le large)}.
static var beach := {}
## Petit point d'eau entre la plage et le campement (centre, au niveau de l'eau).
static var pond := Vector3.ZERO
## Campement abandonné (Île Prairie) : centre au sol, position du coffre.
static var camp := {}
## Objets 3D générés (arbres, ruines, débris du naufrage...) : {"kind", "pos", "rot", "scale", "key"}.
static var props: Array[Dictionary] = []


static func _prop(kind: String, pos: Vector3, rot: float, scale_mul: float, key: String) -> void:
	props.append({"kind": kind, "pos": pos, "rot": rot, "scale": scale_mul, "key": key})

const FLOWER_SETS := {
	"prairie": [Blocks.FLOWER_RED, Blocks.FLOWER_YELLOW, Blocks.FLOWER_WHITE, Blocks.FLOWER_PINK, Blocks.FLOWER_BLUE, Blocks.FLOWER_PURPLE],
	"plage": [Blocks.FLOWER_PINK, Blocks.FLOWER_RED, Blocks.FLOWER_YELLOW, Blocks.FLOWER_WHITE],
	"givre": [Blocks.FLOWER_WHITE, Blocks.FLOWER_BLUE, Blocks.FLOWER_PURPLE],
	"braise": [Blocks.FLOWER_RED, Blocks.FLOWER_YELLOW, Blocks.FLOWER_PURPLE, Blocks.FLOWER_PINK],
}


## Génère l'île dans `world` et renvoie la position d'apparition du joueur.
static func generate(world: VoxelWorld, island: Dictionary) -> Vector3:
	world.clear()
	props.clear()
	var biome: String = island["biome"]
	var seed_v: int = island["seed"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.024
	noise.fractal_octaves = 3
	var warp := FastNoiseLite.new()
	warp.seed = seed_v + 7
	warp.frequency = 0.03
	var heights := PackedInt32Array()
	heights.resize(VoxelWorld.SX * VoxelWorld.SZ)
	var peak_map := PackedFloat32Array()  # relief ajouté au-delà de la limite habituelle
	peak_map.resize(VoxelWorld.SX * VoxelWorld.SZ)
	var cone_map := PackedFloat32Array()
	cone_map.resize(VoxelWorld.SX * VoxelWorld.SZ)
	var raw := PackedFloat32Array()
	raw.resize(VoxelWorld.SX * VoxelWorld.SZ)
	# Grandes collines (basse fréquence) pour varier les grandes îles.
	var hills := FastNoiseLite.new()
	hills.seed = seed_v + 13
	hills.frequency = 0.009

	for z in VoxelWorld.SZ:
		for x in VoxelWorld.SX:
			var dx := (x - CENTER) / RADIUS
			var dz := (z - CENTER) / RADIUS
			var d := sqrt(dx * dx + dz * dz) + warp.get_noise_2d(x, z) * 0.22
			var f := clampf(1.0 - d, 0.0, 1.0)
			f = f * f * (3.0 - 2.0 * f)
			var hn := (noise.get_noise_2d(x, z) + 1.0) * 0.5
			var hl := maxf(0.0, hills.get_noise_2d(x, z)) * 7.0 * f
			var h := SEA - 3.0 + hl
			var cone := 0.0
			var relief := 0.0  # grand relief, ajouté après le plafond du terrain
			match biome:
				"prairie":
					h += f * 9.0 + hn * 6.0 * f
				"plage":
					h += f * 6.0 + hn * 2.5 * f
				"givre":
					h += f * 8.0 + hn * 4.0 * f
					var pd := Vector2(x, z).distance_to(GIVREE_PEAK)
					var peak := clampf(1.0 - pd / RELIEF, 0.0, 1.0)
					relief = peak * peak * 15.0 + peak * hn * 3.0
				"braise":
					h += f * 8.0 + hn * 4.0 * f
					var vd := Vector2(x, z).distance_to(BRAISE_VOLCANO)
					cone = clampf(1.0 - vd / RELIEF, 0.0, 1.0)
					relief = cone * cone * 16.0
					if vd < 9.0:
						relief -= (9.0 - vd) * 1.1  # le cratère
			raw[x + z * VoxelWorld.SX] = h
			if island["id"] == "prairie":
				var mk := clampf(1.0 - Vector2(x, z).distance_to(PRAIRIE_PEAK) / (RELIEF * 1.1), 0.0, 1.0)
				relief = pow(mk, 1.5) * 27.0 + mk * hn * 5.0
			peak_map[x + z * VoxelWorld.SX] = relief
			cone_map[x + z * VoxelWorld.SX] = cone

	# Clairière plate autour du point d'apparition (le campement s'y installe),
	# à la hauteur naturelle moyenne du terrain (évite de créer une cuvette).
	var sum := 0.0
	var n := 0
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			sum += raw[(SPAWN.x + dx) + (SPAWN.y + dz) * VoxelWorld.SX]
			n += 1
	var target := maxf(SEA + 3.0, floorf(sum / n))
	for z in VoxelWorld.SZ:
		for x in VoxelWorld.SX:
			var h := raw[x + z * VoxelWorld.SX]
			var sd := Vector2(x - SPAWN.x, z - SPAWN.y).length()
			if sd < CLEARING:
				var t := clampf((CLEARING - sd) / 4.0, 0.0, 1.0)
				h = lerpf(h, target, t)
			var hh := clampi(floori(h), 1, VoxelWorld.SY - 12)
			heights[x + z * VoxelWorld.SX] = mini(hh + floori(peak_map[x + z * VoxelWorld.SX]), VoxelWorld.SY - 3)

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

	# Plage du naufrage : débris et ruines englouties.
	beach = {}
	camp = {}
	pond = Vector3.ZERO
	if island["id"] == "prairie":
		beach = _find_beach(heights)
		_flatten_beach(world, heights)
		_place_wreck(world, heights, beach, seed_v + 99)
		heights = _place_pond(world, heights)
		_place_camp(world, heights)

	# Éboulement qui ferme la montagne (nouvelle zone à débloquer).
	if island["id"] == "prairie" and not Game.has_flag("zone_mountain"):
		var steps := 135
		for i in steps:
			var a := TAU * i / steps
			var x := floori(PRAIRIE_PEAK.x + cos(a) * RELIEF)
			var z := floori(PRAIRIE_PEAK.y + sin(a) * RELIEF)
			if x < 2 or z < 2 or x >= VoxelWorld.SX - 2 or z >= VoxelWorld.SZ - 2:
				continue
			var h := heights[x + z * VoxelWorld.SX]
			if h <= SEA:
				continue
			_prop("barrier_rock", Vector3(x + 0.5, h + 1, z + 0.5), a * 3.7, 1.0 + fmod(i * 0.37, 0.4), "g:z:%d" % i)

	# Ruines de maisons.
	var ruins := _place_ruins(world, heights, biome, rng, 18)

	# Rochers.
	for i in 240:
		var x := rng.randi_range(6, VoxelWorld.SX - 7)
		var z := rng.randi_range(6, VoxelWorld.SZ - 7)
		var y := world.top_solid_y(x, z)
		if y <= SEA + 1 or _near_spawn(x, z, CLEARING + 2.0) or _in_rects(ruins, x, z, 2):
			continue
		var rock := Blocks.MOSS if biome == "prairie" or biome == "givre" else Blocks.STONE
		if biome == "braise":
			rock = Blocks.BASALT
		for dx in range(0, 2):
			for dz in range(0, 2):
				if rng.randf() < 0.8:
					world.set_raw(x + dx, y + 1, z + dz, rock)
		world.set_raw(x, y + 2, z, rock)

	# Arbres (modèles 3D) et petite végétation.
	var tree_count := {"prairie": 520, "plage": 340, "givre": 580, "braise": 540}
	var kinds: Array = Props.TREES[biome]
	var taken := {}  # cellules 3x3 occupées (espacement)
	var placed := 0
	var attempts := 0
	while placed < int(tree_count[biome]) and attempts < 30000:
		attempts += 1
		var x := rng.randi_range(4, VoxelWorld.SX - 5)
		var z := rng.randi_range(4, VoxelWorld.SZ - 5)
		if _near_spawn(x, z, CLEARING + 1.0) or _in_rects(ruins, x, z, 3) or _near_beach(x, z, 8.0) \
				or (pond != Vector3.ZERO and Vector2(x - pond.x, z - pond.z).length() < 6.0):
			continue
		var y := world.top_solid_y(x, z)
		if y <= SEA:
			continue
		var ground := world.get_block(x, y, z)
		if not ground in [Blocks.GRASS, Blocks.SAND, Blocks.SNOW, Blocks.DIRT]:
			continue
		if biome == "plage" and y > SEA + 4 and rng.randf() < 0.5:
			continue
		var cell := Vector2i(x / 3, z / 3)
		var crowded := false
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var o = taken.get(cell + Vector2i(dx, dz))
				if o != null and Vector2(o).distance_to(Vector2(x, z)) < 3.3:
					crowded = true
		if crowded:
			continue
		taken[cell] = Vector2i(x, z)
		if Blocks.is_deco(world.get_block(x, y + 1, z)):
			world.set_raw(x, y + 1, z, Blocks.AIR)
		_prop(kinds[rng.randi() % kinds.size()], Vector3(x + 0.5, y + 1, z + 0.5), rng.randf() * TAU, rng.randf_range(0.85, 1.2), "g:t:%d,%d" % [x, z])
		placed += 1
	var small := {"prairie": ["bush", "bush_large", "mushroom", "log", "stump"], "plage": ["bush", "bush_large"],
		"givre": ["log", "stump"], "braise": ["bush", "mushroom", "log", "stump"]}
	var smalls: Array = small[biome]
	for i in 210:
		var x := rng.randi_range(6, VoxelWorld.SX - 7)
		var z := rng.randi_range(6, VoxelWorld.SZ - 7)
		var y := world.top_solid_y(x, z)
		if y <= SEA + 1 or _near_spawn(x, z, CLEARING) or _in_rects(ruins, x, z, 1) or taken.has(Vector2i(x / 3, z / 3)):
			continue
		if not world.get_block(x, y, z) in [Blocks.GRASS, Blocks.SAND, Blocks.SNOW, Blocks.DIRT]:
			continue
		_prop(smalls[rng.randi() % smalls.size()], Vector3(x + 0.5, y + 1, z + 0.5), rng.randf() * TAU, rng.randf_range(0.8, 1.2), "g:s:%d,%d" % [x, z])

	# Fleurs et herbes hautes.
	var flowers: Array = FLOWER_SETS[biome]
	var flower_chance := {"prairie": 0.06, "plage": 0.025, "givre": 0.0, "braise": 0.035}
	var grass_chance := {"prairie": 0.09, "plage": 0.05, "givre": 0.0, "braise": 0.07}
	for z in VoxelWorld.SZ:
		for x in VoxelWorld.SX:
			var y := heights[x + z * VoxelWorld.SX]
			if y < 0 or y >= VoxelWorld.SY - 1:
				continue
			if world.get_block(x, y, z) != Blocks.GRASS or world.get_block(x, y + 1, z) != Blocks.AIR:
				continue
			if _near_spawn(x, z, 9.0) and island["id"] == "prairie":
				continue  # (rien ne doit percer les objets du campement)
			var r := rng.randf()
			if r < float(flower_chance[biome]):
				world.set_raw(x, y + 1, z, flowers[rng.randi() % flowers.size()])
			elif r < float(flower_chance[biome]) + float(grass_chance[biome]):
				world.set_raw(x, y + 1, z, Blocks.TALL_GRASS)

	_place_pollution(world, heights, island, seed_v + 777)

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
	var rects: Array[Rect2i] = []
	var attempts := 0
	while rects.size() < count and attempts < 3000:
		attempts += 1
		var w := rng.randi_range(5, 8)
		var d := rng.randi_range(5, 7)
		var x0 := rng.randi_range(8, VoxelWorld.SX - 9 - w)
		var z0 := rng.randi_range(8, VoxelWorld.SZ - 9 - d)
		var rect := Rect2i(x0, z0, w, d)
		if _near_spawn(x0 + w / 2, z0 + d / 2, CLEARING + 8.0):
			continue
		if pond != Vector3.ZERO and Vector2(x0 + w / 2 - pond.x, z0 + d / 2 - pond.z).length() < 10.0:
			continue
		var overlap := false
		for r in rects:
			if r.grow(14).intersects(rect):
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
		# Socle d'un bloc autour du sol : les murs (posés sur le bord) ne
		# flottent pas au-dessus d'une pente.
		for z in range(z0 - 1, z0 + d + 1):
			for x in range(x0 - 1, x0 + w + 1):
				if rect.has_point(Vector2i(x, z)):
					continue
				for y in range(heights[x + z * VoxelWorld.SX] + 1, base + 1):
					world.set_raw(x, y, z, wall_alt)
		for z in range(z0, z0 + d):
			for x in range(x0, x0 + w):
				# Fondations jusqu'au terrain.
				for y in range(heights[x + z * VoxelWorld.SX] + 1, base):
					world.set_raw(x, y, z, wall)
				var edge_x := x == x0 or x == x0 + w - 1
				var edge_z := z == z0 or z == z0 + d - 1
				# Sol (troué par endroits).
				world.set_raw(x, base, z, floor_b if rng.randf() < 0.8 else wall_alt)
				for y in range(base + 1, base + 5):
					world.set_raw(x, y, z, Blocks.AIR)
				if not (edge_x or edge_z) and rng.randf() < 0.18:
					world.set_raw(x, base + 1, z, Blocks.TALL_GRASS if biome != "givre" else Blocks.SNOW)
			# Murs effondrés (Fantasy Town Kit) : segments de 2 blocs le long des bords.
		_ruin_walls(Rect2i(x0, z0, w, d), base + 1, door_side, biome, rng)
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


## Murs en ruine d'une maison : segments cassés, demi-murs, piliers aux coins.
static func _ruin_walls(r: Rect2i, y: int, door_side: int, biome: String, rng: RandomNumberGenerator) -> void:
	var wood := biome == "plage"
	# [début du bord, direction le long du bord, normale extérieure, longueur]
	var sides := [
		[Vector2(r.position.x, r.position.y + 0.5), Vector2(1, 0), Vector2(0, -1), r.size.x],
		[Vector2(r.position.x, r.end.y - 0.5), Vector2(1, 0), Vector2(0, 1), r.size.x],
		[Vector2(r.position.x + 0.5, r.position.y), Vector2(0, 1), Vector2(-1, 0), r.size.y],
		[Vector2(r.end.x - 0.5, r.position.y), Vector2(0, 1), Vector2(1, 0), r.size.y],
	]
	for si in 4:
		var sd: Array = sides[si]
		var start: Vector2 = sd[0]
		var along: Vector2 = sd[1]
		var outward: Vector2 = sd[2]
		var length: int = sd[3]
		var segs := length / 2
		for k in segs:
			if si == door_side and k == segs / 2:
				continue  # l'entrée
			var roll := rng.randf()
			if roll < 0.2:
				continue
			var kind := "wall_broken"
			if roll < 0.45:
				kind = "wall_half"
			elif wood or roll > 0.9:
				kind = "wall_wood_broken"
			# Le panneau du modèle est sur son bord +X : on le tourne vers l'extérieur.
			var mid := start + along * (k * 2 + 1.0) - outward * 0.92
			var rot := atan2(-outward.y, outward.x)
			_prop(kind, Vector3(mid.x, y, mid.y), rot, 1.0, "g:r:%d,%d:%d:%d" % [r.position.x, r.position.y, si, k])
	for c in [r.position, Vector2i(r.end.x - 1, r.position.y), Vector2i(r.position.x, r.end.y - 1), r.end - Vector2i.ONE]:
		if rng.randf() < 0.75:
			_prop("pillar", Vector3(c.x + 0.5, y, c.y + 0.5), 0.0, rng.randf_range(0.7, 1.2), "g:p:%d,%d" % [c.x, c.y])


static func _top_block(biome: String, h: int, hn: float, cone: float) -> int:
	if h <= SEA:
		return Blocks.STONE if biome == "givre" else Blocks.SAND
	if h <= SEA + 1:
		return Blocks.SNOW if biome == "givre" else Blocks.SAND
	match biome:
		"prairie":
			if h >= SEA + 25:
				return Blocks.SNOW
			if h >= SEA + 17:
				return Blocks.STONE
			return Blocks.GRASS
		"plage":
			return Blocks.GRASS if (hn > 0.55 and h > SEA + 2) else Blocks.SAND
		"givre":
			return Blocks.SNOW
		"braise":
			return Blocks.BASALT if cone > 0.42 else Blocks.GRASS
	return Blocks.GRASS


static func _near_beach(x: int, z: int, r: float) -> bool:
	if beach.is_empty():
		return false
	var p: Vector3 = beach["pos"]
	return Vector2(x - p.x, z - p.z).length() < r


## Part du point d'apparition vers le large et s'arrête sur le dernier
## bloc de sable sec avant l'eau.
static func _find_beach(heights: PackedInt32Array) -> Dictionary:
	var dir := (Vector2(SPAWN) - Vector2(CENTER, CENTER)).normalized()
	var p := Vector2(SPAWN) + Vector2(0.5, 0.5)
	var dry := p
	var water_run := 0.0
	for i in 400:
		p += dir * 0.5
		var x := floori(p.x)
		var z := floori(p.y)
		if x < 3 or z < 3 or x >= VoxelWorld.SX - 3 or z >= VoxelWorld.SZ - 3:
			break
		if heights[x + z * VoxelWorld.SX] <= SEA:
			# Le large (et pas un simple lagon) : beaucoup d'eau d'affilée.
			water_run += 0.5
			if water_run >= 14.0:
				break
		else:
			water_run = 0.0
			dry = p
	var bx := floori(dry.x)
	var bz := floori(dry.y)
	var h := heights[bx + bz * VoxelWorld.SX]
	return {"pos": Vector3(bx + 0.5, h + 1, bz + 0.5), "out": Vector3(dir.x, 0, dir.y), "cell": Vector2i(bx, bz)}


## Épave du bateau échouée dans les vagues, planches sur le sable et
## vieilles ruines à moitié englouties de part et d'autre de la plage.
static func _place_wreck(world: VoxelWorld, heights: PackedInt32Array, b: Dictionary, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var cell: Vector2i = b["cell"]
	var o: Vector3 = b["out"]
	# Axes « cardinaux » : vers le large et le long du rivage.
	var out := Vector2i(signi(roundi(o.x)), 0) if absf(o.x) > absf(o.z) else Vector2i(0, signi(roundi(o.z)))
	if out == Vector2i.ZERO:
		out = Vector2i(0, 1)
	var side := Vector2i(-out.y, out.x)
	var at := func(u: int, v: int) -> Vector2i: return cell + out * u + side * v
	var ground := func(c: Vector2i) -> int:
		if c.x < 0 or c.y < 0 or c.x >= VoxelWorld.SX or c.y >= VoxelWorld.SZ:
			return 0
		return heights[c.x + c.y * VoxelWorld.SX]

	# Caisses et tonneaux rejetés sur le sable (Pirate Kit).
	var flotsam := ["crate", "barrel", "crate", "barrel", "barrel", "crate"]
	for i in flotsam.size():
		var c: Vector2i = at.call(rng.randi_range(-4, 1), rng.randi_range(-7, 7))
		if (c - cell).length() < 3.0:
			continue
		var g: int = ground.call(c)
		if g < SEA:
			continue
		_prop(flotsam[i], Vector3(c.x + 0.5, g + 1, c.y + 0.5), rng.randf() * TAU, rng.randf_range(0.9, 1.1), "g:f:%d" % i)

	# La vieille barque, à réparer pour explorer l'archipel (Expeditions), et
	# une caisse bien plus ancienne que le naufrage (le mystère).
	var boat := _shore_spot(at, ground, [-9, -10, -8, -11, -7, -12, -6, -13, 9, 10, 8, 11, 12, 7])
	if boat != Vector2i(-1, -1):
		_prop("rowboat", Vector3(boat.x + 0.5, ground.call(boat) + 1, boat.y + 0.5), atan2(float(out.x), float(out.y)), 1.25, "g:boat")
	var crate := _shore_spot(at, ground, [5, 6, 4, 7, 3, 8, -4, -5, -3])
	if crate != Vector2i(-1, -1) and crate.distance_to(boat) > 3.0:
		_prop("crate", Vector3(crate.x + 0.5, ground.call(crate) + 1, crate.y + 0.5), 0.6, 1.1, "g:oldcrate")

	# (L'épave du bateau est retirée pour l'instant : elle n'avait ni
	# collision ni intérieur.)

	# Ruines englouties : colonnes, une tête de statue et un obélisque.
	for sgn in [-1, 1]:
		var base: Vector2i = at.call(rng.randi_range(5, 8), sgn * rng.randi_range(13, 16))
		for k in 4:
			var c: Vector2i = base + side * (k * 3 * sgn)
			var g: int = ground.call(c)
			var kind := "column" if k == 1 or k == 2 else "column_broken"
			_prop(kind, Vector3(c.x + 0.5, g + 1, c.y + 0.5), rng.randf() * TAU, rng.randf_range(0.9, 1.1), "g:c:%d:%d" % [sgn, k])
	var tw: Vector2i = at.call(17, -6)
	_prop("statue_head", Vector3(tw.x + 0.5, ground.call(tw) + 1, tw.y + 0.5), atan2(-float(out.x), -float(out.y)) + 0.4, 1.3, "g:head")
	var ob: Vector2i = at.call(14, 9)
	_prop("obelisk", Vector3(ob.x + 0.5, ground.call(ob) + 1, ob.y + 0.5), 0.3, 1.2, "g:obelisk")


## Aplanit le sable autour de l'endroit où le naufragé se réveille (intro).
static func _flatten_beach(world: VoxelWorld, heights: PackedInt32Array) -> void:
	var c: Vector2i = beach["cell"]
	var target := SEA + 1
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			if dx * dx + dz * dz > 10:
				continue
			var x := c.x + dx
			var z := c.y + dz
			var i := x + z * VoxelWorld.SX
			var h := heights[i]
			if h < SEA:
				continue  # (on laisse l'eau)
			for y in range(target + 1, h + 1):
				world.set_raw(x, y, z, Blocks.AIR)
			for y in range(h + 1, target + 1):
				world.set_raw(x, y, z, Blocks.SAND)
			world.set_raw(x, target, z, Blocks.SAND)
			heights[i] = target
	beach["pos"] = Vector3(c.x + 0.5, target + 1, c.y + 0.5)


## Une case de plage (hors de l'eau, à peine au-dessus de la mer) le long du
## rivage, à la distance `v` de la plage du naufrage ; Vector2i(-1, -1) sinon.
static func _shore_spot(at: Callable, ground: Callable, sides: Array) -> Vector2i:
	for v in sides:
		for u in [-1, 0, -2, 1, -3, -4]:
			var c: Vector2i = at.call(u, v)
			var g: int = ground.call(c)
			if g >= SEA and g <= SEA + 2:
				return c
	return Vector2i(-1, -1)


## Creuse une petite mare (l'océan, sous l'île, affleure au fond).
static func _place_pond(world: VoxelWorld, heights: PackedInt32Array) -> PackedInt32Array:
	var b: Vector3 = beach["pos"]
	var sp := Vector2(SPAWN) + Vector2(0.5, 0.5)
	var dir := (sp - Vector2(b.x, b.z)).normalized()
	# Près de la plage, là où le terrain est bas : l'eau affleure presque.
	var c := Vector2(b.x, b.z).lerp(sp, 0.3) + Vector2(-dir.y, dir.x) * 7.0
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			var x := floori(c.x) + dx
			var z := floori(c.y) + dz
			var d := Vector2(dx / 3.4, dz / 2.6).length()
			if d > 1.75 or x < 1 or z < 1 or x >= VoxelWorld.SX - 1 or z >= VoxelWorld.SZ - 1:
				continue
			var i := x + z * VoxelWorld.SX
			var h := heights[i]
			var floor_y := SEA - 3 if d < 0.6 else SEA - 2
			if d > 1.0:
				floor_y = mini(h, SEA + floori((d - 1.0) * 2.5))  # berges en pente
			if floor_y >= h:
				continue
			for y in range(floor_y + 1, h + 1):
				world.set_raw(x, y, z, Blocks.AIR)
			world.set_raw(x, floor_y, z, Blocks.SAND if d <= 1.0 else (Blocks.MOSS if (dx + dz) % 3 == 0 else Blocks.GRASS))
			heights[i] = floor_y
	pond = Vector3(floori(c.x) + 0.5, SEA + 0.75, floori(c.y) + 0.5)
	return heights


## Le campement abandonné, dans la clairière du point d'apparition :
## une vieille tente, un établi cassé, un feu de camp éteint, une clôture.
## Le coffre et les outils rouillés sont des objets (voir CampProps).
static func _place_camp(world: VoxelWorld, heights: PackedInt32Array) -> void:
	var sx := SPAWN.x
	var sz := SPAWN.y
	var g := heights[sx + sz * VoxelWorld.SX]
	var put := func(dx: int, dy: int, dz: int, id: int) -> void:
		world.set_raw(sx + dx, g + dy, sz + dz, id)
	var at := func(dx: float, dz: float) -> Vector3: return Vector3(sx + 0.5 + dx, g + 1, sz + 0.5 + dz)
	# La tente au nord, le sac de couchage dedans ; l'établi, les caisses et le
	# tonneau à l'ouest ; le feu de camp et sa bûche au sud-est.
	_prop("tent", at.call(-4.0, -5.5), PI, 1.0, "g:camp:tent")
	_prop("bedroll", at.call(-4.0, -5.6), 0.0, 1.0, "g:camp:bed")
	_prop("workbench", at.call(-4.0, 2.4), 0.2, 1.0, "g:camp:bench")
	_prop("box", at.call(-5.8, 1.6), 0.6, 1.0, "g:camp:box")
	_prop("box_large", at.call(-5.8, 3.4), -0.3, 1.0, "g:camp:box2")
	_prop("barrel_old", at.call(-1.0, 5.2), 0.0, 1.0, "g:camp:barrel")
	_prop("campfire_old", at.call(2.0, 3.0), 0.0, 1.0, "g:camp:fire")
	_prop("log", at.call(3.6, 4.2), 1.2, 1.0, "g:camp:log")
	_prop("signpost", at.call(5.0, 6.0), 0.5, 1.0, "g:camp:sign")
	# Restes de clôture.
	for a in [0.3, 0.9, 1.5, 2.2, 2.9, 3.4, 4.9, 5.6]:
		_prop("fence_broken", at.call(cos(a) * 7.5, sin(a) * 7.5), -a, 1.0, "g:camp:fence%d" % roundi(a * 10))
	camp = {"center": Vector3(sx + 0.5, g + 1, sz + 0.5), "chest": Vector3(sx - 0.5, g + 1, sz - 1.5), "ground": g + 1}


## Déchets sur la terre ferme et vase sur les points d'eau : les retirer
## rend l'île plus accueillante. Les quantités servent de cibles à la vitalité.
static func _place_pollution(world: VoxelWorld, heights: PackedInt32Array, island: Dictionary, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var waste := 0
	var water := 0
	var pile := func(x: int, z: int) -> int:
		var y := world.top_solid_y(x, z)
		if y <= SEA or y >= VoxelWorld.SY - 3:
			return 0
		if not world.get_block(x, y, z) in [Blocks.GRASS, Blocks.SAND, Blocks.DIRT, Blocks.SNOW, Blocks.BASALT, Blocks.MOSS, Blocks.STONE]:
			return 0
		if Blocks.is_deco(world.get_block(x, y + 1, z)):
			world.set_raw(x, y + 1, z, Blocks.AIR)
		world.set_raw(x, y + 1, z, Blocks.DEBRIS)
		var n := 1
		if rng.randf() < 0.45:
			var d: Vector2i = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)].pick_random()
			if world.top_solid_y(x + d.x, z + d.y) == y:
				world.set_raw(x + d.x, y + 1, z + d.y, Blocks.DEBRIS)
				n += 1
		if rng.randf() < 0.2:
			world.set_raw(x, y + 2, z, Blocks.DEBRIS)
			n += 1
		return n
	# Un peu partout sur l'île.
	var placed := 0
	for attempt in 1500:
		if placed >= 60:
			break
		var x := rng.randi_range(10, VoxelWorld.SX - 11)
		var z := rng.randi_range(10, VoxelWorld.SZ - 11)
		if _near_spawn(x, z, CLEARING + 1.0):
			continue
		var n: int = pile.call(x, z)
		if n > 0:
			waste += n
			placed += 1
	# Autour du campement et de la plage (Île Prairie) : de quoi commencer.
	if island["id"] == "prairie":
		var spots: Array[Vector2] = []
		for i in 6:
			var a := rng.randf() * TAU
			spots.append(Vector2(SPAWN) + Vector2(cos(a), sin(a)) * rng.randf_range(CLEARING + 1.0, CLEARING + 5.0))
		if not beach.is_empty():
			var b: Vector3 = beach["pos"]
			for i in 6:
				var a := rng.randf() * TAU
				# (pas là où le naufragé se réveille)
				spots.append(Vector2(b.x, b.z) + Vector2(cos(a), sin(a)) * rng.randf_range(7.0, 13.0))
		for sp in spots:
			waste += pile.call(floori(sp.x), floori(sp.y))
	# Vase : sur la mare et dans les lagons à l'intérieur de l'île.
	var cells: Array[Vector2i] = []
	for z in range(8, VoxelWorld.SZ - 8, 2):
		for x in range(8, VoxelWorld.SX - 8, 2):
			if heights[x + z * VoxelWorld.SX] > SEA - 1:
				continue
			if Vector2(x - CENTER, z - CENTER).length() > RADIUS * 0.72:
				continue
			cells.append(Vector2i(x, z))
	if pond != Vector3.ZERO:
		cells.push_front(Vector2i(floori(pond.x), floori(pond.z)))
	var patches := 0
	for c in cells:
		if patches >= 18:
			break
		if patches > 0 and rng.randf() > 0.08:
			continue
		patches += 1
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				if dx * dx + dz * dz > 5 or rng.randf() < 0.3:
					continue
				var x := c.x + dx
				var z := c.y + dz
				if heights[x + z * VoxelWorld.SX] >= SEA or world.get_block(x, SEA, z) != Blocks.AIR:
					continue
				world.set_raw(x, SEA, z, Blocks.SLUDGE)
				water += 1
	Game.island_totals[island["id"]] = {"waste": waste, "water": water}


static func _in_rects(rects: Array[Rect2i], x: int, z: int, margin: int) -> bool:
	for r in rects:
		if r.grow(margin).has_point(Vector2i(x, z)):
			return true
	return false


static func _near_spawn(x: int, z: int, r: float) -> bool:
	return Vector2(x - SPAWN.x, z - SPAWN.y).length() < r
