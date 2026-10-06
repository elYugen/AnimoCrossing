class_name Wildlife
extends Node3D
## Animaux sauvages de l'île : leur nombre dépend de l'environnement (Fauna),
## chacun apparaît dans son habitat (forêt, jardins, plage, hauteurs, village).
## Quand l'île est assez vivante, des papillons volent au-dessus des
## parterres les plus fleuris (et les habitants viennent les regarder).

## Palier de vie (Vitality.tier_index) à partir duquel les papillons arrivent.
const BUTTERFLY_TIER := 2
const BUTTERFLY_COLORS := [Color("ffd84a"), Color("f7a8c4"), Color("ffffff"), Color("9fd8ef"), Color("f29a45")]

var main: Main
## Parterres où volent les papillons (lieux de promenade des habitants).
var butterfly_spots: Array[Vector3] = []


## Fait apparaître les animaux selon l'environnement. `announce` : bannière
## pour chaque nouvelle espèce (le matin).
func spawn(announce: bool) -> void:
	for c in get_children():
		c.queue_free()
	var pop := Fauna.population(Game.current_island)
	var fresh := []
	for sp in pop:
		for i in int(pop[sp]):
			var pos := _spot(Fauna.SPECIES[sp]["habitat"])
			if pos == Vector3.INF:
				continue
			var a := Animal.new()
			a.setup(sp, main.world, pos)
			add_child(a)
		if not Game.species_seen.has(sp):
			Game.species_seen[sp] = true
			fresh.append(sp)
	var had_butterflies := not butterfly_spots.is_empty()
	_spawn_butterflies()
	if announce:
		for sp in fresh:
			main.hud.show_item_popup("Un %s est apparu !" % Fauna.name_of(sp).to_lower(), "L'environnement lui plaît.", false)
			Audio.play("jingle_common", -6.0, 0.0)
		if not had_butterflies and not butterfly_spots.is_empty() and not Game.has_flag("butterflies_" + Game.current_island):
			Game.set_flag("butterflies_" + Game.current_island)
			main.hud.show_item_popup("Des papillons sont arrivés !", "Ils volent au-dessus de tes fleurs.", false)


## L'animal le plus proche de `pos` (null si aucun à moins de `max_d`).
func nearest(pos: Vector3, max_d: float) -> Animal:
	var best: Animal = null
	var best_d := max_d
	for n in get_children():
		var a := n as Animal
		if a and a.global_position.distance_to(pos) < best_d:
			best_d = a.global_position.distance_to(pos)
			best = a
	return best


## Papillons au-dessus des parterres les plus fleuris (jusqu'à 6).
func _spawn_butterflies() -> void:
	butterfly_spots.clear()
	if Vitality.tier_index(Vitality.percent(Game.current_island)) < BUTTERFLY_TIER:
		return
	var world := main.world
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.day * 31 + hash(Game.current_island)
	for attempt in 2500:
		if butterfly_spots.size() >= 6:
			break
		var x := rng.randi_range(6, VoxelWorld.SX - 7)
		var z := rng.randi_range(6, VoxelWorld.SZ - 7)
		var y := world.top_solid_y(x, z)
		if y <= IslandGenerator.SEA or not world.get_block(x, y + 1, z) in Blocks.FLOWERS:
			continue
		var n := 0
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				if world.get_block(x + dx, world.top_solid_y(x + dx, z + dz) + 1, z + dz) in Blocks.FLOWERS:
					n += 1
		var p := Vector3(x + 0.5, y + 1.0, z + 0.5)
		var far := true
		for q in butterfly_spots:
			if q.distance_to(p) < 12.0:
				far = false
		if n >= 7 and far:
			butterfly_spots.append(p)
			add_child(_butterflies(p, rng))


func _butterflies(pos: Vector3, rng: RandomNumberGenerator) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 0.9, 0)
	p.amount = 5
	p.lifetime = 5.0
	p.preprocess = 5.0
	var m := QuadMesh.new()
	m.size = Vector2(0.16, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material = mat
	p.mesh = m
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.8, 0.5, 1.8)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	# Vol hésitant : petites accélérations dans tous les sens.
	p.tangential_accel_min = -1.5
	p.tangential_accel_max = 1.5
	p.radial_accel_min = -0.4
	p.radial_accel_max = 0.4
	p.color = BUTTERFLY_COLORS[rng.randi() % BUTTERFLY_COLORS.size()]
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = fade
	return p


func _spot(habitat: String) -> Vector3:
	var world := main.world
	var props := main.props
	var rng := main.rng
	for attempt in 60:
		var c := Vector3.ZERO
		match habitat:
			"forest":
				var trees := []
				for id in props.items:
					if Props.is_tree(props.kind_of(id)):
						trees.append(props.items[id]["pos"])
				if trees.is_empty():
					return Vector3.INF
				c = (trees.pick_random() as Vector3) + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			"village":
				var built := []
				for id in props.items:
					if props.key_of(id).begins_with("p:"):
						built.append(props.items[id]["pos"])
				var base: Vector3 = built.pick_random() if not built.is_empty() else main.spawn_point
				c = base + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
			_:
				c = Vector3(rng.randf_range(10, VoxelWorld.SX - 10), 0, rng.randf_range(10, VoxelWorld.SZ - 10))
		var x := floori(c.x)
		var z := floori(c.z)
		var y := world.top_solid_y(x, z)
		if y <= IslandGenerator.SEA:
			continue
		var b := world.get_block(x, y, z)
		match habitat:
			"marine":
				if b != Blocks.SAND or y > IslandGenerator.SEA + 2:
					continue
			"mountain":
				if y < IslandGenerator.SEA + 12:
					continue
			"garden":
				if b != Blocks.GRASS or not Blocks.is_deco(world.get_block(x, y + 1, z)):
					continue
		if not b in [Blocks.GRASS, Blocks.SAND, Blocks.DIRT, Blocks.SNOW, Blocks.MOSS, Blocks.STONE]:
			continue
		return Vector3(x + 0.5, y + 1.0, z + 0.5)
	return Vector3.INF
