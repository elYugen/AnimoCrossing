extends Node
## Scène de test : captures d'écran automatisées (dev uniquement).

var out := OS.get_environment("SHOT_DIR")
var main: Node


func _ready() -> void:
	Game.reset_game()
	Game.tutorial_step = 9
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(60)
	var w: VoxelWorld = main.world
	# 1. Derrière un arbre : la caméra doit voir le joueur à travers.
	var trunk := _find(w, Blocks.WOOD, 6)
	main.player.teleport(Vector3(trunk.x + 2.5, trunk.y, trunk.z + 0.5))
	main.rig.yaw = -PI / 2.0
	main.rig.pitch = -0.45
	main.rig.distance = 9.0
	main.rig.snap()
	await _wait(30)
	await _shot("10_behind_tree")
	# 2. Une ruine.
	var ruin := _find(w, Blocks.PLANK, 0)
	main.player.teleport(Vector3(ruin.x + 0.5, ruin.y + 1.2, ruin.z + 4.5))
	main.rig.yaw = 0.6
	main.rig.pitch = -0.6
	main.rig.distance = 12.0
	main.rig.snap()
	await _wait(30)
	await _shot("11_ruin")
	# 3. Vue d'ensemble.
	main.player.teleport(Vector3(64, 30, 64))
	main.rig.pitch = -1.0
	main.rig.distance = 28.0
	main.rig.snap()
	await _wait(40)
	await _shot("12_overview")
	for id in ["corail", "givree", "braise"]:
		main.travel_to(id)
		await _wait(150)
		var r := _find(w, Blocks.PLANK if id != "braise" else Blocks.BRICK, 0)
		main.player.teleport(Vector3(r.x + 0.5, w.top_solid_y(r.x, r.z + 5) + 1.2, r.z + 5.5))
		main.rig.distance = 16.0
		main.rig.pitch = -0.7
		main.rig.snap()
		await _wait(30)
		await _shot("13_" + id)
	get_tree().quit()


## Trouve un bloc du type donné ayant au moins `min_y_above_sea` de hauteur.
func _find(w: VoxelWorld, id: int, min_h: int) -> Vector3i:
	for z in range(10, VoxelWorld.SZ - 10):
		for x in range(10, VoxelWorld.SX - 10):
			for y in range(IslandGenerator.SEA + 1 + min_h, VoxelWorld.SY):
				if w.get_block(x, y, z) == id:
					return Vector3i(x, y - min_h, z)
	return Vector3i(64, 20, 64)


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("shot ", name)
