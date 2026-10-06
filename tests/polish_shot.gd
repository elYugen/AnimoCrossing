extends Node
## Scène de test : captures pour vérifier le rendu des nouveautés (dev).
## SHOT_DIR=<dossier> godot --path . res://tests/polish_shot.tscn

var out := OS.get_environment("SHOT_DIR")
var main: Main


func _ready() -> void:
	Game.reset_game()
	Game.tutorial_step = 10
	for f in ["water", "camp", "chest"]:
		Game.set_flag(f)
	Game.player_name = "Lou"
	# Une île déjà un peu vivante (palier 1 : chants, lucioles).
	var trees: Array = Game.props_added.get_or_add("prairie", [])
	for i in 30:
		trees.append({"kind": "town_tree", "x": 0.0, "y": 0.0, "z": 0.0, "rot": 0.0, "scale": 1.0, "key": "p:shot:%d" % i})
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_intro = true
	add_child(main)
	main.story.hint_timer = 1.0e9
	await _wait(40)
	await main._start_game(false)
	Game.time = 11.0
	Game.weather = "clear"
	Game.weather_left = 999.0
	main.sky.apply(true)
	var w := main.world
	var sp := IslandGenerator.SPAWN

	# 1. Casser un bloc : « +1 Terre » qui s'envole, fil des gains.
	var gx := sp.x + 3
	var gz := sp.y + 6
	var gy := w.top_solid_y(gx, gz)
	main.player.teleport(Vector3(gx + 2.5, gy + 1.2, gz + 0.5))
	_cam(-PI / 2.0, -0.35, 5.0)
	await _wait(20)
	main.select_power(0)
	for i in 3:
		main.aim.target = {"hit": true, "pos": Vector3i(gx, w.top_solid_y(gx, gz), gz), "normal": Vector3i.UP, "block": w.get_block(gx, w.top_solid_y(gx, gz), gz)}
		main.tools.cooldown = 0.0
		main.tools.use_power()
		await _wait(6)
	await _wait(10)
	await _shot("30_gain")

	# 2. Meubles posés dehors, à côté du joueur et d'un feu de camp.
	var fx := sp.x + 6
	var fz := sp.y - 6
	for k in [["f_table", 0], ["f_chairCushion", 2], ["f_loungeSofa", -3], ["campfire", 5]]:
		var x: int = fx + int(k[1])
		main.props.add_persistent(k[0], Vector3(x + 0.5, w.top_solid_y(x, fz) + 1, fz + 0.5), 0.0)
	main.player.teleport(Vector3(fx + 0.5, w.top_solid_y(fx, fz + 4) + 1.2, fz + 4.5))
	_cam(0.0, -0.3, 7.0)
	await _wait(30)
	await _shot("31_furniture_outside")

	# 3. Habitants : conversation sur un banc, coucou.
	for id in ["rose", "hugo", "iris"]:
		Game.add_resident(id, "prairie")
	await _wait(5)
	var bx := fx - 8
	var bpos := Vector3(bx + 0.5, w.top_solid_y(bx, fz) + 1, fz + 0.5)
	main.props.add_persistent("bench", bpos, 0.0)
	var rs := main.residents.all()
	for i in 2:
		rs[i].position = bpos + Vector3(-0.6 + i * 1.2, 0, 0.9)
		rs[i].state = Resident.State.ACT
		rs[i].activity = "sit"
		rs[i]._timer = 60.0
	main.moments.play_scene([rs[0], rs[1]] as Array[Resident], "banc_village")
	main.player.teleport(bpos + Vector3(0, 0.2, 5.0))
	_cam(0.0, -0.25, 6.0)
	await _wait(25)
	await _shot("32_bench_talk")

	# 4. Le carnet (onglet Habitants) et la carte.
	main.hud.toggle_panel("carnet")
	await _wait(20)
	await _shot("33_carnet")
	(main.hud._open_panel as CarnetPanel)._select_tab("memories")
	await _wait(10)
	await _shot("34_carnet_souvenirs")
	main.hud.close_panel()
	main.hud.toggle_panel("map")
	await _wait(20)
	await _shot("35_map")
	main.hud.close_panel()

	# 5. La vieille barque.
	for id in main.props.items:
		if main.props.key_of(id) == "g:boat":
			var bp: Vector3 = main.props.items[id]["pos"]
			main.player.teleport(bp + Vector3(2.0, 0.5, 2.0))
			_cam(0.8, -0.35, 6.0)
	await _wait(30)
	await _shot("36_boat")

	# 6. Pluie : flaques.
	main.player.teleport(Vector3(sp.x + 0.5, w.top_solid_y(sp.x, sp.y) + 1.2, sp.y + 0.5))
	_cam(0.3, -0.5, 8.0)
	Game.weather = "rain"
	main.sky.apply(true)
	for i in 20:
		main.weather_fx._add_puddle()
	await _wait(200)
	await _shot("37_rain_puddles")

	# 7. Neige : traces de pas.
	Game.weather = "snow"
	main.sky.apply(true)
	for i in 14:
		var p := main.player.global_position + Vector3(i * 0.35, 0, sin(i * 0.5) * 0.4)
		main.player.stepped.emit(p, Blocks.GRASS, PI * 0.5)
	await _wait(30)
	await _shot("38_snow_prints")

	# 8. Nuit : lucioles (île vivante).
	Game.weather = "clear"
	Game.time = 22.5
	main.sky.apply(true)
	await _wait(150)
	await _shot("39_night_fireflies")

	# 9. Le cerf des brumes.
	Game.time = 9.0
	Game.weather = "fog"
	main.sky.apply(true)
	var deer := SpiritDeer.new()
	deer.fx = main.weather_fx
	main.weather_fx.add_child(deer)
	deer.set_process(false)
	var dpos := main.player.global_position + Vector3(0, 0, -7)
	dpos.y = w.top_solid_y(floori(dpos.x), floori(dpos.z)) + 1.0
	deer.appear(dpos, main.player.global_position)
	_cam(0.0, -0.2, 5.0)
	await _wait(90)
	await _shot("40_spirit_deer")
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
