class_name ResidentJobs
extends Node
## Petites tâches confiées par le joueur à un habitant (« Va nettoyer »,
## « Va planter ») : il s'en charge vraiment, un déchet ou un arbre à la fois,
## de jour, puis vient le dire. (« Va aider » sur un chantier : Construction.)

## Tâches possibles : nom affiché dans le menu, nombre de répétitions.
const JOBS := {
	"clean": {"label": "Va nettoyer les environs", "count": 4},
	"plant": {"label": "Va planter quelques arbres", "count": 3},
}
## Rayon de recherche autour de l'habitant (en blocs).
const RADIUS := 26

var main: Main
var _reserved := {}  # cible (Vector3i) -> habitant, pour ne pas viser la même


func give(c: Resident, type: String) -> void:
	c.job = {"type": type, "left": int(JOBS[type]["count"])}


func stop(c: Resident) -> void:
	c.job = {}
	_release(c)


## Appelé par ResidentAI pour un habitant libre qui a une tâche : il va à la
## prochaine cible. Renvoie false s'il n'y a plus rien à faire.
func step(c: Resident) -> bool:
	_release(c)
	var target := _find_dirty(c) if c.job["type"] == "clean" else _find_planting_spot(c)
	if target == Vector3i(-1, -1, -1):
		_finish(c, "tache_rien")
		return false
	_reserved[target] = c.data["id"]
	var stand := Vector3(target) + Vector3(0.5, 1.0, 0.5)
	var face := stand
	if c.job["type"] == "clean":
		# Il se place à côté du déchet, sans monter dessus.
		var away := (c.global_position - stand)
		away.y = 0.0
		stand += (away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * 1.1
		stand.y = float(main.world.top_solid_y(floori(stand.x), floori(stand.z)) + 1)
	c.go(stand, "pickup", 2.5, face, func(): _do(c, target))
	return true


func _do(c: Resident, target: Vector3i) -> void:
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(c) or c.job.is_empty():
		return
	_reserved.erase(target)
	var world := main.world
	match c.job["type"]:
		"clean":
			var b := world.get_blockv(target)
			if b == Blocks.DEBRIS or b == Blocks.SLUDGE:
				world.set_block(target, Blocks.AIR)
				world.flush()
				main.props.resnap_near(Vector3(target), 3.0)
				main.nav.refresh_area(Vector3(target), 1.5)
				main.burst(Vector3(target) + Vector3(0.5, 0.5, 0.5), Blocks.main_color(b), 10)
				Audio.play("break_soft", -10.0, 0.1)
				if b == Blocks.DEBRIS:
					if target.y <= IslandGenerator.SEA + 3:
						Game.add_stat("clean_shore")
					Game.add_stat("clean_waste")
				else:
					Game.add_stat("clean_water")
		"plant":
			var bc := Vector3(target) + Vector3(0.5, 1.0, 0.5)
			if not main.props.any_near(bc, 2.0):
				if Blocks.is_deco(world.get_blockv(target + Vector3i.UP)):
					world.set_block(target + Vector3i.UP, Blocks.AIR)
					world.flush()
				var biome: String = IslandDB.get_island(Game.current_island)["biome"]
				var kinds: Array = Props.TREES[biome]
				main.props.add_persistent(kinds.pick_random(), bc, randf() * TAU, randf_range(0.9, 1.1), true, {"planted": Game.day})
				main.burst(bc + Vector3(0, 0.5, 0), Color("6cbf4a"), 12)
				Audio.play("tree", -10.0)
	c.job["left"] = int(c.job["left"]) - 1
	if int(c.job["left"]) <= 0:
		_finish(c, "tache_finie")


func _finish(c: Resident, cue: String) -> void:
	c.job = {}
	_release(c)
	var lines := await Dialogues.texts(Dialogues.RESIDENTS, cue)
	if is_instance_valid(c) and not lines.is_empty():
		c.say(Moments.fill(lines[0]), 3.5)


func _release(c: Resident) -> void:
	for k in _reserved.keys():
		if _reserved[k] == c.data["id"]:
			_reserved.erase(k)


## Le déchet ou la vase le plus proche (en cercles de plus en plus grands).
func _find_dirty(c: Resident) -> Vector3i:
	var world := main.world
	var o := Vector2i(floori(c.global_position.x), floori(c.global_position.z))
	for r in range(0, RADIUS):
		for dx in range(-r, r + 1):
			for dz in [-r, r] if absi(dx) != r else range(-r, r + 1):
				var x := o.x + dx
				var z: int = o.y + int(dz)
				if not VoxelWorld.in_bounds(x, 1, z):
					continue
				var y := world.top_solid_y(x, z)
				var b := world.get_block(x, y, z)
				var p := Vector3i(x, y, z)
				if (b == Blocks.DEBRIS or b == Blocks.SLUDGE) and not _reserved.has(p):
					return p
	return Vector3i(-1, -1, -1)


## Un coin d'herbe dégagé pas trop loin, pour un arbre.
func _find_planting_spot(c: Resident) -> Vector3i:
	var world := main.world
	for attempt in 60:
		var a := main.rng.randf() * TAU
		var r := main.rng.randf_range(4.0, float(RADIUS))
		var x := floori(c.global_position.x + cos(a) * r)
		var z := floori(c.global_position.z + sin(a) * r)
		if not VoxelWorld.in_bounds(x, 1, z):
			continue
		var y := world.top_solid_y(x, z)
		var p := Vector3i(x, y, z)
		if y <= IslandGenerator.SEA or _reserved.has(p):
			continue
		if not world.get_block(x, y, z) in [Blocks.GRASS, Blocks.DIRT, Blocks.SNOW, Blocks.MOSS, Blocks.SAND]:
			continue
		if world.is_opaque(x, y + 1, z) or main.props.any_near(Vector3(x + 0.5, y + 1, z + 0.5), 3.0):
			continue
		return p
	return Vector3i(-1, -1, -1)
