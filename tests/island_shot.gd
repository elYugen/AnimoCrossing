extends Node
## Scène de test : captures des îles (vue du ciel), du campement et de la
## plage du naufrage, pour vérifier la génération et le placement des objets.
## SHOT_DIR=<dossier> godot --path . res://tests/island_shot.tscn

var out := OS.get_environment("SHOT_DIR")
var main: Main


func _ready() -> void:
	Game.reset_game()
	Game.tutorial_step = 10
	for f in ["water", "camp", "chest"]:
		Game.set_flag(f)
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_intro = true
	add_child(main)
	main.story.hint_timer = 1.0e9
	await _wait(60)
	await _shot("49_title")
	if OS.get_environment("SHOT_TITLE_ONLY") != "":
		get_tree().quit()
		return
	await main._start_game(false)
	Game.time = 12.0
	Game.weather = "clear"
	Game.weather_left = 999.0
	main.sky.apply(true)
	main.player.input_enabled = false

	# Le campement, sous quatre angles.
	var c: Vector3 = IslandGenerator.camp["center"]
	for i in 4:
		main.player.teleport(c + Vector3(0, 0.2, 0))
		_cam(i * PI * 0.5 + 0.4, -0.55, 15.0)
		await _wait(40)
		await _shot("50_camp_%d" % i)
	# La plage du naufrage.
	var b: Vector3 = IslandGenerator.beach["pos"]
	main.player.teleport(b + Vector3(0, 0.5, 0))
	var o: Vector3 = IslandGenerator.beach["out"]
	_cam(atan2(-o.x, -o.z) + PI, -0.5, 22.0)
	await _wait(40)
	await _shot("51_beach")
	# Vues du ciel de chaque île.
	for id in ["prairie", "corail", "givree", "braise"]:
		if id != "prairie":
			await main.travel_to(id)
			await _wait(30)
		var mid := VoxelWorld.SX * 0.5
		main.player.teleport(Vector3(mid, VoxelWorld.SY + 4, mid + 8))
		main.player.flying = true
		_cam(0.0, -1.45, 150.0 * VoxelWorld.SX / 256.0)
		main.world.focus = Vector3(mid, 10, mid)
		await _wait(200)
		await _shot("52_top_" + id)
	get_tree().quit()


func _cam(yaw: float, pitch: float, dist: float) -> void:
	main.rig.yaw = yaw
	main.rig.pitch = pitch
	main.rig.distance = dist
	main.rig.snap()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + "/" + shot_name + ".png")
	print("shot ", shot_name)
