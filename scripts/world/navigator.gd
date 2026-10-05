class_name Navigator
extends RefCounted
## Recherche de chemin (A*) pour les habitants, sur la grille de l'île :
## on ne marche pas dans l'eau, on contourne les arbres, maisons et autres
## objets, et on ne monte (ou ne descend) qu'un bloc à la fois.

const MAX_EXPANDED := 6000
## Étapes de recherche permises par image (toutes recherches confondues).
const STEPS_PER_FRAME := 200
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var world: VoxelWorld
var props: Props
var _h := PackedInt32Array()  # hauteur du sol par cellule (-1 : eau, -2 : pas encore calculée)
## Étapes de recherche encore permises pendant cette image (remis à zéro par main).
var budget := STEPS_PER_FRAME
var _block := PackedByteArray()  # 1 : cellule occupée par un objet


func build(w: VoxelWorld, p: Props) -> void:
	world = w
	props = p
	_h.resize(VoxelWorld.SX * VoxelWorld.SZ)
	_block.resize(VoxelWorld.SX * VoxelWorld.SZ)
	_block.fill(0)
	_h.fill(-2)
	for id in props.items:
		_mark(id, 1)


func _cell_height(x: int, z: int) -> int:
	var y := Props.ground_y(world, x, z)
	if y <= IslandGenerator.SEA + 1:
		return -1
	# Pas de passage sous un bloc (ex. un toit en voxels à hauteur de tête).
	if world.is_opaque(x, y, z) or world.is_opaque(x, y + 1, z):
		return -1
	return y


## Met à jour une zone après une modification du terrain.
func refresh_area(p: Vector3, r: float) -> void:
	if world == null:
		return
	var x0 := maxi(0, floori(p.x - r))
	var x1 := mini(VoxelWorld.SX - 1, floori(p.x + r))
	var z0 := maxi(0, floori(p.z - r))
	var z1 := mini(VoxelWorld.SZ - 1, floori(p.z + r))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			_h[x + z * VoxelWorld.SX] = -2


## Un objet a été posé (1) ou retiré (0).
func mark_prop(id: int, v: int) -> void:
	if world:
		_mark(id, v)


func _mark(id: int, v: int) -> void:
	var it: Dictionary = props.items[id]
	var kind: String = it["kind"]
	var def: Dictionary = Props.KINDS[kind]
	if def["shape"] == "none" or kind.begins_with("pet_"):
		return
	var pos: Vector3 = it["pos"]
	if def["shape"] == "trunk":
		_set_block(floori(pos.x), floori(pos.z), v)
		return
	var ab := Props.local_aabb(kind)
	var s := float(def["scale"]) * float(it.get("scale", 1.0))
	var basis := Basis(Vector3.UP, float(it.get("rot", 0.0)))
	var steps := 6
	for i in steps + 1:
		for j in steps + 1:
			var lp := Vector3(lerpf(ab.position.x, ab.end.x, float(i) / steps), 0, lerpf(ab.position.z, ab.end.z, float(j) / steps)) * s
			var q := pos + basis * lp
			_set_block(floori(q.x), floori(q.z), v)


func _set_block(x: int, z: int, v: int) -> void:
	if x >= 0 and z >= 0 and x < VoxelWorld.SX and z < VoxelWorld.SZ:
		_block[x + z * VoxelWorld.SX] = v


func walkable(x: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= VoxelWorld.SX or z >= VoxelWorld.SZ:
		return false
	var i := x + z * VoxelWorld.SX
	return _height(i) >= 0 and _block[i] == 0


func _height(i: int) -> int:
	if _h[i] == -2:
		_h[i] = _cell_height(i % VoxelWorld.SX, i / VoxelWorld.SX)
	return _h[i]


## Cellule praticable la plus proche (la destination est souvent un banc, un feu...).
func _nearest_walkable(c: Vector2i, radius := 4) -> Vector2i:
	if walkable(c.x, c.y):
		return c
	for r in range(1, radius + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) == r and walkable(c.x + dx, c.y + dz):
					return c + Vector2i(dx, dz)
	return Vector2i(-1, -1)


## Chemin de `from` à `to` d'un coup (tests, outils). Vide si aucun.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var job := start(from, to)
	while not job["done"]:
		step(job, MAX_EXPANDED)
	return job["result"]


## Démarre une recherche incrémentale (avancée par `step`, image après image).
func start(from: Vector3, to: Vector3) -> Dictionary:
	var job := {"done": true, "result": PackedVector3Array()}
	if world == null:
		return job
	var s := _nearest_walkable(Vector2i(floori(from.x), floori(from.z)))
	var g := _nearest_walkable(Vector2i(floori(to.x), floori(to.z)))
	if s.x < 0 or g.x < 0:
		return job
	if s == g:
		(job["result"] as PackedVector3Array).append(_center(g))
		return job
	var st := s.x + s.y * VoxelWorld.SX
	return {"done": false, "result": PackedVector3Array(), "goal": g.x + g.y * VoxelWorld.SX, "g": g,
		"came": {st: -1}, "cost": {st: 0.0}, "heap": [[_heur(s, g), st]], "expanded": 0}


## Avance une recherche d'au plus `n` étapes ; renvoie true quand elle est finie.
func step(job: Dictionary, n: int) -> bool:
	if job["done"]:
		return true
	var w := VoxelWorld.SX
	var goal: int = job["goal"]
	var g: Vector2i = job["g"]
	var came: Dictionary = job["came"]
	var cost: Dictionary = job["cost"]
	var heap: Array = job["heap"]
	for k in n:
		if heap.is_empty() or int(job["expanded"]) > MAX_EXPANDED:
			job["done"] = true  # pas de chemin
			return true
		var cur: int = _pop(heap)[1]
		if cur == goal:
			job["done"] = true
			job["result"] = _rebuild(came, goal)
			return true
		job["expanded"] = int(job["expanded"]) + 1
		var cx := cur % w
		var cz := cur / w
		var ch := _height(cur)
		for d in DIRS:
			var nx := cx + d.x
			var nz := cz + d.y
			if not walkable(nx, nz):
				continue
			var ni := nx + nz * w
			if absi(_height(ni) - ch) > 1:
				continue
			# Pas de coin coupé en diagonale.
			if d.x != 0 and d.y != 0 and (not walkable(cx + d.x, cz) or not walkable(cx, cz + d.y)):
				continue
			var nc: float = cost[cur] + (1.414 if d.x != 0 and d.y != 0 else 1.0) + (0.3 if _height(ni) != ch else 0.0)
			if not cost.has(ni) or nc < float(cost[ni]):
				cost[ni] = nc
				came[ni] = cur
				_push(heap, [nc + _heur(Vector2i(nx, nz), g), ni])
	return false


func _rebuild(came: Dictionary, goal: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var w := VoxelWorld.SX
	var cells: Array[int] = []
	var c := goal
	while c != -1:
		cells.push_front(c)
		c = came[c]
	# On saute un point sur deux pour une marche plus naturelle.
	for i in cells.size():
		if i > 0 and i < cells.size() - 1 and i % 2 == 1:
			continue
		out.append(_center(Vector2i(cells[i] % w, cells[i] / w)))
	return out


func _center(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, _height(c.x + c.y * VoxelWorld.SX), c.y + 0.5)


static func _heur(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dz := absi(a.y - b.y)
	return float(maxi(dx, dz)) + 0.414 * float(mini(dx, dz))


# Tas binaire (file de priorité) : éléments [priorité, valeur].
static func _push(h: Array, e: Array) -> void:
	h.append(e)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if float(h[p][0]) <= float(h[i][0]):
			break
		var t: Array = h[p]
		h[p] = h[i]
		h[i] = t
		i = p


static func _pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if h.is_empty():
		return top
	h[0] = last
	var i := 0
	var n := h.size()
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < n and float(h[l][0]) < float(h[m][0]):
			m = l
		if r < n and float(h[r][0]) < float(h[m][0]):
			m = r
		if m == i:
			break
		var t: Array = h[m]
		h[m] = h[i]
		h[i] = t
		i = m
	return top
