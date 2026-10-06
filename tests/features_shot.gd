extends Node
## Scène de test : captures des astuces, du point d'eau vivant, d'un lieu à
## découvrir et des souvenirs du carnet. SHOT_DIR=<dossier> godot --path . res://tests/features_shot.tscn

var out := OS.get_environment("SHOT_DIR")
var main: Main


func _ready() -> void:
	Game.reset_game()
	Game.tutorial_step = 10
	for f in ["water", "camp", "chest"]:
		Game.set_flag(f)
	Game.player_name = "Lou"
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_intro = true
	add_child(main)
	main.story.hint_timer = 1.0e9
	await _wait(40)
	await main._start_game(false)
	Game.time = 10.0
	Game.weather = "clear"
	Game.weather_left = 999.0
	main.sky.apply(true)

	# 1. Une astuce.
	main.tips.tip("faconneur")
	await _wait(30)
	await _shot("80_tip")
	main.hud._tip.visible = false
	main.hud._tip_queue.clear()

	# 2. Le point d'eau vivant (palier forcé).
	main.life.set_process(false)
	var pc := IslandGenerator.pond
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			var cx := floori(pc.x) + dx
			var cz := floori(pc.z) + dz
			if main.world.get_block(cx, IslandGenerator.SEA, cz) == Blocks.SLUDGE:
				main.world.set_block(Vector3i(cx, IslandGenerator.SEA, cz), Blocks.AIR)
	main.world.flush()
	main.life.tier = 3
	main.life._update_pond()
	var p := IslandGenerator.pond
	main.player.teleport(p + Vector3(7, 1.5, 3))
	main.rig.yaw = atan2(7.0, 3.0)
	main.rig.pitch = -0.5
	main.rig.distance = 9.0
	main.rig.snap()
	await _wait(60)
	await _shot("81_pond")

	# 3. Un lieu à découvrir.
	for id in main.props.items:
		var key := main.props.key_of(id)
		if key.begins_with("g:l:") and (key.ends_with(":stump") or key.ends_with(":head") or key.ends_with(":sign")):
			var lp: Vector3 = main.props.items[id]["pos"]
			main.player.teleport(lp + Vector3(5, 1.5, 5))
			main.rig.yaw = PI * 0.25
			main.rig.pitch = -0.45
			main.rig.distance = 10.0
			main.rig.snap()
			break
	await _wait(60)
	await _shot("82_landmark")

	# 4. Un souvenir (avec sa vraie capture), puis le carnet.
	await main.memories.record("sunrise")
	await _wait(10)
	main.hud.toggle_panel("carnet")
	await _wait(10)
	(main.hud._open_panel as CarnetPanel)._select_tab("memories")
	await _wait(20)
	await _shot("83_carnet_souvenirs")
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + shot_name + ".png")
	print("shot ", shot_name)
