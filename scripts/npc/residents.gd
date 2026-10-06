class_name Residents
extends Node3D
## Les habitants présents sur l'île : apparition, étiquettes au-dessus de la
## tête, maison de chacun et coins de plage (lieux de promenade).

var main: Main
var beach_spots: Array[Vector3] = []


## (Re)crée les habitants de l'île courante, chez eux s'ils ont une maison.
func spawn_all() -> void:
	for c in get_children():
		c.queue_free()
	for id in Game.residents:
		var info: Dictionary = Game.residents[id]
		if info.get("island", "") == Game.current_island:
			var door := home_door(id)
			var r := make(ResidentDB.get_resident(id), door if door != Vector3.INF else find_spot(main.spawn_point, 18.0))
			r.voice = 0.85 + float(hash(id) % 50) / 100.0
	_find_beach_spots()


func make(d: Dictionary, pos: Vector3) -> Resident:
	var r := Resident.new()
	r.nav = main.nav
	r.setup(d, main.world, pos)
	add_child(r)
	return r


func all() -> Array[Resident]:
	var out: Array[Resident] = []
	for n in get_children():
		if n is Resident and not n.is_queued_for_deletion():
			out.append(n)
	return out


func find(id: String) -> Resident:
	for r in all():
		if r.data["id"] == id:
			return r
	return null


## L'habitant le plus proche de `pos` (null si personne à moins de `max_d`).
func nearest(pos: Vector3, max_d: float) -> Resident:
	var best: Resident = null
	var best_d := max_d
	for r in all():
		var d := r.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = r
	return best


## Un endroit au sol, hors de l'eau et des arbres, autour de `center`.
func find_spot(center: Vector3, radius: float) -> Vector3:
	var world := main.world
	for i in 40:
		var a := main.rng.randf() * TAU
		var r := main.rng.randf_range(2.0, radius)
		var x := floori(center.x + cos(a) * r)
		var z := floori(center.z + sin(a) * r)
		var y := world.top_solid_y(x, z)
		if y <= IslandGenerator.SEA:
			continue
		var b := world.get_block(x, y, z)
		if b in [Blocks.LEAVES, Blocks.PINE_LEAVES, Blocks.PALM_LEAVES, Blocks.AUTUMN_LEAVES, Blocks.WOOL, Blocks.WOOD, Blocks.PALM_WOOD]:
			continue
		return Vector3(x + 0.5, y + 1.0, z + 0.5)
	return center


## Noms affichés quand on s'approche ; « [E] Parler » sur le plus proche.
func update_labels(player_pos: Vector3) -> void:
	var best := nearest(player_pos, 2.6)
	for r in all():
		r.set_label_visible(r.global_position.distance_to(player_pos) < 7.0, r == best)


## Porte de la maison d'un habitant (Vector3.INF : sans maison).
func home_door(owner: String) -> Vector3:
	var key := Game.home_of(owner)
	if key == "":
		return Vector3.INF
	var props := main.props
	for id in props.items:
		if props.key_of(id) == key:
			return props.door_position(id)
	return Vector3.INF


## Un habitant occupe-t-il cette case (pour ne pas poser un bloc sur lui) ?
func overlaps(cell: AABB) -> bool:
	for r in all():
		if cell.intersects(AABB(r.global_position - Vector3(0.3, 0, 0.3), Vector3(0.6, 0.9, 0.6))):
			return true
	return false


func _find_beach_spots() -> void:
	beach_spots.clear()
	var world := main.world
	for i in 400:
		var x := main.rng.randi_range(8, VoxelWorld.SX - 9)
		var z := main.rng.randi_range(8, VoxelWorld.SZ - 9)
		var y := world.top_solid_y(x, z)
		if y == IslandGenerator.SEA + 1 and world.get_block(x, y, z) == Blocks.SAND:
			beach_spots.append(Vector3(x + 0.5, y + 1, z + 0.5))
		if beach_spots.size() >= 25:
			break
