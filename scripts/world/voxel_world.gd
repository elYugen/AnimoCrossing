class_name VoxelWorld
extends Node3D
## Monde voxel d'une île : stockage, maillage par chunks avec occlusion
## ambiante par sommet, collisions et raycast DDA.

const SX := 384
const SY := 40
const SZ := 384
const CHUNK := 16
const AO_CURVE: Array[float] = [0.5, 0.67, 0.83, 1.0]
const GRASS_BAND := 0.72

const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const TAN_U: Array[Vector3i] = [Vector3i(0, 1, 0), Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 0)]
const TAN_V: Array[Vector3i] = [Vector3i(0, 0, 1), Vector3i(0, 0, 1), Vector3i(0, 0, 1), Vector3i(0, 0, 1), Vector3i(0, 1, 0), Vector3i(0, 1, 0)]
const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]

const STEM_COLOR := Color("4f9e3a")
## Blocs d'arbres : effacés quand ils cachent le joueur (voir voxel.gdshader).
const SEE_THROUGH: Array[int] = [Blocks.WOOD, Blocks.PALM_WOOD, Blocks.LEAVES, Blocks.AUTUMN_LEAVES, Blocks.PINE_LEAVES, Blocks.PALM_LEAVES, Blocks.WOOL]

var data := PackedByteArray()
var island_id := ""
var material: ShaderMaterial
var _chunks := {}  # Vector2i -> Dictionary
var _dirty := {}
var _max_y := SY - 1  # plus haut bloc non vide (limite le maillage)
var _see := PackedByteArray()  # 1 si le type de bloc est effaçable (arbre)
var _pending := {}  # chunks pas encore maillés (construits progressivement)
## Position autour de laquelle on maille en priorité (le joueur).
var focus := Vector3.ZERO


func _init() -> void:
	data.resize(SX * SY * SZ)
	_see.resize(256)
	for id in SEE_THROUGH:
		_see[id] = 1
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/voxel.gdshader")


## Met à jour la zone « transparente » entre la caméra et le joueur.
func set_view(player_pos: Vector3, cam_pos: Vector3) -> void:
	material.set_shader_parameter("player_pos", player_pos)
	material.set_shader_parameter("cam_pos", cam_pos)


func clear() -> void:
	data.fill(0)


static func idx(x: int, y: int, z: int) -> int:
	return x + z * SX + y * SX * SZ


static func in_bounds(x: int, y: int, z: int) -> bool:
	return x >= 0 and y >= 0 and z >= 0 and x < SX and y < SY and z < SZ


func get_block(x: int, y: int, z: int) -> int:
	if x < 0 or y < 0 or z < 0 or x >= SX or y >= SY or z >= SZ:
		return Blocks.AIR
	return data[x + z * SX + y * SX * SZ]


func get_blockv(p: Vector3i) -> int:
	return get_block(p.x, p.y, p.z)


func set_raw(x: int, y: int, z: int, id: int) -> void:
	if in_bounds(x, y, z):
		data[idx(x, y, z)] = id


## Modification par le joueur : marque les chunks à reconstruire et
## enregistre la modification dans la sauvegarde.
func set_block(p: Vector3i, id: int, record := true) -> void:
	if not in_bounds(p.x, p.y, p.z):
		return
	data[idx(p.x, p.y, p.z)] = id
	_max_y = maxi(_max_y, mini(p.y + 1, SY - 1))
	if record:
		Game.record_edit(island_id, p, id)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var cx := floori(float(p.x + dx) / CHUNK)
			var cz := floori(float(p.z + dz) / CHUNK)
			var key := Vector2i(cx, cz)
			if _chunks.has(key):
				_dirty[key] = true


func flush() -> void:
	for key in _dirty:
		_build_chunk(key)
	_dirty.clear()


func is_opaque(x: int, y: int, z: int) -> bool:
	if x < 0 or y < 0 or z < 0 or x >= SX or y >= SY or z >= SZ:
		return false
	var b := data[x + z * SX + y * SX * SZ]
	return b != 0 and b < Blocks.FLOWER_RED


func top_solid_y(x: int, z: int) -> int:
	for y in range(SY - 1, -1, -1):
		if is_opaque(x, y, z):
			return y
	return -1


# --- Construction des chunks ---------------------------------------------

## Crée tous les chunks : ceux proches de `center` sont maillés tout de
## suite, les autres progressivement (les plus proches du joueur d'abord).
func build_all(center: Vector3, sync_radius := 2) -> void:
	for key in _chunks:
		var c: Dictionary = _chunks[key]
		(c["body"] as Node).queue_free()
	_chunks.clear()
	_dirty.clear()
	_pending.clear()
	focus = center
	_max_y = 0
	var layer := SX * SZ
	for y in range(SY - 1, -1, -1):
		if data.slice(y * layer, (y + 1) * layer).count(0) != layer:
			_max_y = y
			break
	_max_y = mini(_max_y + 1, SY - 1)
	for cx in SX / CHUNK:
		for cz in SZ / CHUNK:
			var key := Vector2i(cx, cz)
			var body := StaticBody3D.new()
			body.name = "Chunk_%d_%d" % [cx, cz]
			var shape := CollisionShape3D.new()
			body.add_child(shape)
			var mi := MeshInstance3D.new()
			body.add_child(mi)
			var deco := MeshInstance3D.new()
			deco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(deco)
			add_child(body)
			_chunks[key] = {"body": body, "shape": shape, "mesh": mi, "deco": deco}
			_pending[key] = true
	var ck := Vector2i(floori(center.x / CHUNK), floori(center.z / CHUNK))
	for key in _pending.keys():
		if absi(key.x - ck.x) <= sync_radius and absi(key.y - ck.y) <= sync_radius:
			_build_chunk(key)


func is_fully_built() -> bool:
	return _pending.is_empty()


func _process(_delta: float) -> void:
	if _pending.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var fc := Vector2(focus.x, focus.z) / CHUNK
	while not _pending.is_empty() and Time.get_ticks_usec() - t0 < 5000:
		var best := Vector2i.ZERO
		var best_d := INF
		for key in _pending:
			var d := (Vector2(key) + Vector2(0.5, 0.5)).distance_squared_to(fc)
			if d < best_d:
				best_d = d
				best = key
		_build_chunk(best)


func _build_chunk(key: Vector2i) -> void:
	_pending.erase(key)
	var c: Dictionary = _chunks[key]
	var mb := MeshBuilder.new()
	var deco := MeshBuilder.new()
	var faces := PackedVector3Array()
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	for y in _max_y + 1:
		for z in range(z0, z0 + CHUNK):
			for x in range(x0, x0 + CHUNK):
				var id := data[x + z * SX + y * SX * SZ]
				if id == 0:
					continue
				if id >= Blocks.FLOWER_RED:
					_emit_deco(deco, x, y, z, id)
					continue
				var see := _see[id]
				for d in 6:
					var n := DIRS[d]
					# Face cachée, sauf contre un bloc d'arbre (qui peut s'effacer).
					if is_opaque(x + n.x, y + n.y, z + n.z) and (see == 1 or _see[get_block(x + n.x, y + n.y, z + n.z)] == 0):
						continue
					_emit_face(mb, faces, x, y, z, id, d)
	(c["mesh"] as MeshInstance3D).mesh = mb.commit(material)
	(c["deco"] as MeshInstance3D).mesh = deco.commit(material)
	var shape := c["shape"] as CollisionShape3D
	if faces.is_empty():
		shape.shape = null
	else:
		var cps := ConcavePolygonShape3D.new()
		cps.backface_collision = true
		cps.set_faces(faces)
		shape.shape = cps


static func _hash(x: int, y: int, z: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h >> 8) & 1023) / 1023.0


func _emit_face(mb: MeshBuilder, faces: PackedVector3Array, x: int, y: int, z: int, id: int, d: int) -> void:
	var n := DIRS[d]
	var u := TAN_U[d]
	var v := TAN_V[d]
	var p := Vector3i(x, y, z)
	var origin := Vector3(p)
	if n.x + n.y + n.z > 0:
		origin += Vector3(n)
	var base := p + n
	var pos: Array[Vector3] = []
	var ao: Array[float] = []
	for k in 4:
		var cr := CORNERS[k]
		var du := cr.x * 2 - 1
		var dv := cr.y * 2 - 1
		var b1 := base + u * du
		var b2 := base + v * dv
		var b3 := base + u * du + v * dv
		var s1 := is_opaque(b1.x, b1.y, b1.z)
		var s2 := is_opaque(b2.x, b2.y, b2.z)
		var s3 := is_opaque(b3.x, b3.y, b3.z)
		var level := 0 if (s1 and s2) else 3 - (int(s1) + int(s2) + int(s3))
		pos.append(origin + Vector3(u) * cr.x + Vector3(v) * cr.y)
		ao.append(AO_CURVE[level])
	# Variation de teinte par bloc pour le charme voxel.
	var jitter := 0.94 + _hash(x, y, z) * 0.1
	var col := Blocks.face_color(id, d)
	col.a = 0.0 if id in SEE_THROUGH else 1.0
	var nf := Vector3(n)
	# Diagonale choisie selon l'AO pour éviter les artefacts.
	var order: Array[int] = [0, 1, 2, 3]
	if ao[0] + ao[2] < ao[1] + ao[3]:
		order = [1, 2, 3, 0]
	if id == Blocks.GRASS and d != 2 and d != 3:
		# Côté d'herbe : bande verte en haut, terre en dessous.
		var green: Color = Blocks.DEFS[Blocks.GRASS]["top"]
		green = green.darkened(0.08)
		green.a = 1.0
		var mid := float(y) + GRASS_BAND
		var low: Array[Vector3] = []
		var high: Array[Vector3] = []
		for k in 4:
			var pk := pos[k]
			if pk.y > float(y) + 0.5:
				low.append(Vector3(pk.x, mid, pk.z))
				high.append(pk)
			else:
				low.append(pk)
				high.append(Vector3(pk.x, mid, pk.z))
		_quad(mb, low, ao, order, nf, col * jitter)
		_quad(mb, high, ao, order, nf, green * jitter)
	else:
		_quad(mb, pos, ao, order, nf, col * jitter)
	faces.append_array([pos[0], pos[1], pos[2], pos[0], pos[2], pos[3]])


func _quad(mb: MeshBuilder, pos: Array[Vector3], ao: Array[float], order: Array[int], n: Vector3, col: Color) -> void:
	var a := order[0]
	var b := order[1]
	var c := order[2]
	var d := order[3]
	mb.add_quad(pos[a], pos[b], pos[c], pos[d], n,
		_shade(col, ao[a]), _shade(col, ao[b]), _shade(col, ao[c]), _shade(col, ao[d]))


static func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


func _emit_deco(mb: MeshBuilder, x: int, y: int, z: int, id: int) -> void:
	var ox := (_hash(x, y, z) - 0.5) * 0.4
	var oz := (_hash(z, x, y) - 0.5) * 0.4
	var cx := x + 0.5 + ox
	var cz := z + 0.5 + oz
	var petal: Color = Blocks.DEFS[id]["petal"]
	if id == Blocks.CAMPFIRE:
		# Bûches croisées, cercle de pierres et flammes.
		var fx := x + 0.5
		var fz := z + 0.5
		var log := Color("8a5a3b")
		mb.add_box(Vector3(fx, y + 0.07, fz), Vector3(0.7, 0.13, 0.14), log)
		mb.add_box(Vector3(fx, y + 0.12, fz), Vector3(0.14, 0.13, 0.7), log.darkened(0.1))
		for a in 8:
			var d := Vector3(cos(a * TAU / 8.0), 0, sin(a * TAU / 8.0)) * 0.4
			mb.add_box(Vector3(fx, y + 0.06, fz) + d, Vector3(0.14, 0.12, 0.14), Color("9aa0a8"))
		mb.add_box(Vector3(fx, y + 0.3, fz), Vector3(0.26, 0.3, 0.26), Color("ff7a2a"), false)
		mb.add_box(Vector3(fx + 0.04, y + 0.42, fz - 0.03), Vector3(0.16, 0.3, 0.16), Color("ffb03a"), false)
		mb.add_box(Vector3(fx - 0.02, y + 0.55, fz + 0.02), Vector3(0.08, 0.16, 0.08), Color("ffe27a"), false)
		return
	if id == Blocks.GARDEN:
		# Potager : terre retournée, pousses et fanes de carottes.
		mb.add_box(Vector3(x + 0.5, y + 0.04, z + 0.5), Vector3(0.9, 0.08, 0.9), Color("7a5236"))
		for i in 3:
			for j in 2:
				var px := x + 0.22 + i * 0.28
				var pz := z + 0.3 + j * 0.4
				mb.add_box(Vector3(px, y + 0.1, pz), Vector3(0.1, 0.06, 0.1), Color("f08a3a"))
				mb.add_box(Vector3(px, y + 0.22, pz), Vector3(0.05, 0.2, 0.05), petal)
				mb.add_box(Vector3(px + 0.05, y + 0.27, pz), Vector3(0.1, 0.04, 0.06), petal.lightened(0.1))
		return
	if id == Blocks.TALL_GRASS:
		mb.add_box(Vector3(cx - 0.12, y + 0.2, cz), Vector3(0.08, 0.4, 0.08), petal)
		mb.add_box(Vector3(cx + 0.1, y + 0.27, cz + 0.08), Vector3(0.08, 0.54, 0.08), petal.lightened(0.1))
		mb.add_box(Vector3(cx, y + 0.16, cz - 0.12), Vector3(0.08, 0.32, 0.08), petal.darkened(0.08))
		return
	var h := 0.42 + _hash(y, z, x) * 0.12
	mb.add_box(Vector3(cx, y + h * 0.5, cz), Vector3(0.07, h, 0.07), STEM_COLOR)
	mb.add_box(Vector3(cx + 0.08, y + h * 0.4, cz), Vector3(0.12, 0.05, 0.08), STEM_COLOR.lightened(0.1))
	var center_col := Color("f9d54a") if id != Blocks.FLOWER_YELLOW else Color("f29a45")
	var top := y + h
	mb.add_box(Vector3(cx, top, cz), Vector3(0.11, 0.11, 0.11), center_col)
	for off in [Vector3(0.11, 0, 0), Vector3(-0.11, 0, 0), Vector3(0, 0, 0.11), Vector3(0, 0, -0.11)]:
		mb.add_box(Vector3(cx, top - 0.01, cz) + off, Vector3(0.12, 0.08, 0.12), petal)


# --- Raycast -------------------------------------------------------------

## Raycast voxel (DDA). Renvoie {hit, pos: Vector3i, normal: Vector3i, block}.
## `skip(pos) -> bool` permet d'ignorer certains blocs (ex. blocs effacés).
func raycast(origin: Vector3, dir: Vector3, max_dist: float, skip := Callable()) -> Dictionary:
	dir = dir.normalized()
	var p := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i(int(signf(dir.x)), int(signf(dir.y)), int(signf(dir.z)))
	var t_delta := Vector3(
		absf(1.0 / dir.x) if dir.x != 0.0 else INF,
		absf(1.0 / dir.y) if dir.y != 0.0 else INF,
		absf(1.0 / dir.z) if dir.z != 0.0 else INF)
	var t_max := Vector3(
		((p.x + (1 if step.x > 0 else 0)) - origin.x) / dir.x if dir.x != 0.0 else INF,
		((p.y + (1 if step.y > 0 else 0)) - origin.y) / dir.y if dir.y != 0.0 else INF,
		((p.z + (1 if step.z > 0 else 0)) - origin.z) / dir.z if dir.z != 0.0 else INF)
	var normal := Vector3i.ZERO
	var t := 0.0
	while t <= max_dist:
		var b := get_block(p.x, p.y, p.z)
		if b != Blocks.AIR and not (skip.is_valid() and skip.call(p)):
			return {"hit": true, "pos": p, "normal": normal, "block": b, "dist": t}
		if t_max.x < t_max.y and t_max.x < t_max.z:
			p.x += step.x
			t = t_max.x
			t_max.x += t_delta.x
			normal = Vector3i(-step.x, 0, 0)
		elif t_max.y < t_max.z:
			p.y += step.y
			t = t_max.y
			t_max.y += t_delta.y
			normal = Vector3i(0, -step.y, 0)
		else:
			p.z += step.z
			t = t_max.z
			t_max.z += t_delta.z
			normal = Vector3i(0, 0, -step.z)
	return {"hit": false}
