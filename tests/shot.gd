extends Node
## Scène de test : captures d'écran automatisées (dev uniquement).

var out := OS.get_environment("SHOT_DIR")
var main: Node


func _ready() -> void:
	Game.reset_game()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(90)
	await _shot("01_start")
	main.hud._tuto_next()
	Game.tutorial_step = 4
	main.hud.refresh_all()
	main.select_power(2)
	# Fleurir la parcelle de terre.
	var sp := IslandGenerator.SPAWN
	var y: int = main.world.top_solid_y(sp.x + 4, sp.y - 2)
	main.target = {"hit": true, "pos": Vector3i(sp.x + 4, y, sp.y - 2), "normal": Vector3i.UP, "block": main.world.get_block(sp.x + 4, y, sp.y - 2)}
	main._do_bloom()
	await _wait(30)
	await _shot("02_bloom")
	await _wait(150)
	main.rig.yaw = 2.2
	main.rig.distance = 7.0
	await _wait(40)
	await _shot("03_friend")
	Game.tutorial_step = 9
	Game.add_stars(1500)
	main.hud.refresh_all()
	main.hud.toggle_panel("gacha")
	await _wait(5)
	main.hud._gacha._pull(10)
	await _wait(150)
	await _shot("04_gacha")
	main.hud.toggle_panel("carnet")
	await _wait(20)
	await _shot("05_carnet")
	main.hud.close_panel()
	for id in ["corail", "givree", "braise"]:
		main.travel_to(id)
		await _wait(120)
		await _shot("06_" + id)
	main.hud.toggle_panel("map")
	await _wait(20)
	await _shot("07_map")
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("shot ", name)
