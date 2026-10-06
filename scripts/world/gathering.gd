class_name Gathering
extends Node3D
## Ressources à ramasser (branches, pierres, fruits, plantes) : réparties sur
## l'île, ramassées en marchant dessus, elles repoussent après quelques jours.

## Jours avant qu'une ressource ramassée repousse.
const REGROW_DAYS := {"branch": 1, "plant": 1, "fruit": 2, "stone": 3}
const COUNTS := {"branch": 220, "stone": 180, "fruit": 120, "plant": 170}

var main: Main


## Objets à ramasser : un peu partout, et quelques-uns sur le chemin
## entre la plage du naufrage et le campement.
func spawn() -> void:
	for c in get_children():
		c.queue_free()
	var isl := IslandDB.get_island(Game.current_island)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(isl["seed"]) + 5
	for k in COUNTS:
		var placed := 0
		for attempt in 9000:
			if placed >= int(COUNTS[k]):
				break
			var x := rng.randi_range(8, VoxelWorld.SX - 9)
			var z := rng.randi_range(8, VoxelWorld.SZ - 9)
			if _add(k, x, z, k == "fruit"):
				placed += 1
	var b: Dictionary = IslandGenerator.beach
	if b.is_empty():
		return
	var from: Vector3 = b["pos"]
	var to := Vector3(IslandGenerator.SPAWN.x, 0, IslandGenerator.SPAWN.y)
	var side := (to - from).cross(Vector3.UP).normalized()
	for k in HUD.TUTO[0]["goals"]:
		var need: int = int(HUD.TUTO[0]["goals"][k]) + 1
		for attempt in 60:
			if need <= 0:
				break
			var p := from.lerp(to, rng.randf_range(0.12, 0.8)) + side * rng.randf_range(-7.0, 7.0)
			if _add(k, floori(p.x), floori(p.z), false):
				need -= 1


func _add(kind: String, x: int, z: int, near_tree: bool) -> bool:
	var world := main.world
	var props := main.props
	var y := world.top_solid_y(x, z)
	if y <= IslandGenerator.SEA:
		return false
	if not world.get_block(x, y, z) in [Blocks.GRASS, Blocks.SAND, Blocks.DIRT, Blocks.SNOW, Blocks.MOSS]:
		return false
	var p := Vector3(x + 0.5, y + 1.0, z + 0.5)
	if near_tree and not props.any_near(p, 3.0, true):
		return false
	if props.any_near(p, 0.9):
		return false
	# Déjà ramassé et pas encore repoussé : la place reste vide.
	var key := "%d,%d" % [x, z]
	if (Game.picked.get(Game.current_island, {}) as Dictionary).has(key):
		return true
	var pk := Pickup.new()
	pk.kind = kind
	pk.set_meta("key", key)
	pk.position = p
	add_child(pk)
	return true


## Un objet en plus, pour la journée (fruits tombés d'un arbre planté...).
func add_extra(kind: String, pos: Vector3) -> void:
	var y := main.world.top_solid_y(floori(pos.x), floori(pos.z))
	if y <= IslandGenerator.SEA:
		return
	var pk := Pickup.new()
	pk.kind = kind
	pk.position = Vector3(pos.x, y + 1.0, pos.z)
	add_child(pk)


## Ramassage automatique quand le joueur passe dessus.
func collect_near(pp: Vector3) -> void:
	for n in get_children():
		var pk := n as Pickup
		if pk == null or pk.collected:
			continue
		var d := pk.global_position - pp
		if Vector2(d.x, d.z).length() < Pickup.RADIUS and absf(d.y) < 1.6:
			pk.collect(pp)
			Game.add_item(pk.kind)
			if pk.has_meta("key"):
				(Game.picked.get_or_add(Game.current_island, {}) as Dictionary)[pk.get_meta("key")] = {"d": Game.day, "k": pk.kind}
			Audio.play("select", -6.0, 0.12, 1.5)
			main.gain(Items.name_of(pk.kind), 1, Items.color_of(pk.kind), Vector3.INF, pk.kind)


## Chaque matin : les ressources ramassées depuis assez longtemps repoussent
## (pas toutes d'un coup).
func regrow() -> void:
	for isl in Game.picked:
		var picked: Dictionary = Game.picked[isl]
		for key in picked.keys():
			var e: Dictionary = picked[key]
			if Game.day - int(e["d"]) >= int(REGROW_DAYS.get(e["k"], 2)) and main.rng.randf() < 0.7:
				picked.erase(key)
	spawn()
