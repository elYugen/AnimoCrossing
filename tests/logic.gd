extends Node
## Test de logique headless : déroule le tutoriel et vérifie la sauvegarde.

var main: Node
var fails := 0


func _ready() -> void:
	Game.reset_game()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(10)
	var hud: HUD = main.hud
	var w: VoxelWorld = main.world
	var sp := IslandGenerator.SPAWN
	_check(Game.tutorial_step == 0, "étape 0")
	hud._tuto_next()
	main.player.distance_walked = 10.0
	await _wait(2)
	_check(Game.tutorial_step == 2, "étape marche passée")

	# Casser 3 blocs
	main.select_power(0)
	for i in 3:
		var x := sp.x - 3 + i
		var z := sp.y + 3
		var y := w.top_solid_y(x, z)
		_aim(Vector3i(x, y, z), Vector3i.UP)
		main._cooldown = 0.0
		main._use_power()
		_check(w.get_block(x, y, z) == Blocks.AIR, "bloc cassé %d" % i)
	_check(Game.tutorial_step == 3, "étape casser passée")

	# Poser 3 blocs
	main.select_block(Blocks.PLANK)
	for i in 3:
		var x := sp.x - 3 + i
		var z := sp.y - 4
		var y := w.top_solid_y(x, z)
		_aim(Vector3i(x, y, z), Vector3i.UP)
		main._cooldown = 0.0
		main._use_power()
		_check(w.get_block(x, y + 1, z) == Blocks.PLANK, "bloc posé %d" % i)
	_check(Game.tutorial_step == 4, "étape poser passée")
	_check(Game.get_stat("prairie", "place_7") == 3, "stat planches")

	# Fleurir la parcelle
	main.select_power(2)
	var py := w.top_solid_y(sp.x + 4, sp.y - 2)
	_aim(Vector3i(sp.x + 4, py, sp.y - 2), Vector3i.UP)
	main._use_power()
	_check(Game.friends.has("bourgeon"), "Bourgeon débloqué")
	_check(Game.tutorial_step == 5, "étape fleurir passée")

	# Pousser un arbre
	main.select_power(3)
	var tx := sp.x + 2
	var tz := sp.y + 4
	var ty := w.top_solid_y(tx, tz)
	_aim(Vector3i(tx, ty, tz), Vector3i.UP)
	main._use_power()
	_check(w.get_block(tx, ty + 1, tz) == Blocks.WOOD, "arbre poussé")
	_check(Game.tutorial_step == 6, "étape arbre passée")

	# Parler
	await _wait(5)
	var c: Node3D = main.creatures_root.get_child(0)
	main.player.global_position = c.global_position + Vector3(1, 0, 0)
	main._interact()
	_check(hud.dialog_open(), "dialogue ouvert")
	hud.advance_dialog()
	hud.advance_dialog()
	_check(Game.tutorial_step == 7, "étape parler passée")
	hud.toggle_panel("carnet")
	hud.close_panel()
	_check(Game.tutorial_step == 8, "étape carnet passée")
	hud._tuto_next()
	_check(Game.tutorial_step == 9 and Game.stars >= 200, "tutoriel terminé + étoiles")

	# Gacha
	var before := Game.friend_count()
	var res := Game.gacha_pull(1)
	_check(res.size() == 1, "tirage gacha")
	_check(Game.friend_count() >= before, "ami gacha")

	# Sauvegarde / rechargement
	Game.save_game()
	var edits_before: int = (Game.edits["prairie"] as Dictionary).size()
	Game.edits = {}
	Game.load_game()
	_check((Game.edits["prairie"] as Dictionary).size() == edits_before, "édits rechargés (%d)" % edits_before)
	main._load_island("prairie")
	_check(w.get_block(tx, ty + 1, tz) == Blocks.WOOD, "arbre persistant après rechargement")
	var x0 := sp.x - 3
	_check(w.get_block(x0, w.top_solid_y(x0, sp.y - 4), sp.y - 4) == Blocks.PLANK, "planche persistante")

	# Voyage
	Game.friends["caillou"] = {"island": "prairie"}
	Game.friends["brindille"] = {"island": "prairie"}
	Game.friends["pomponette"] = {"island": "prairie"}
	_check(Game.is_island_unlocked("corail"), "Corail débloquée")
	await main.travel_to("corail")
	_check(Game.current_island == "corail" and Blocks.SAND in Game.available_blocks(), "voyage Corail")

	# Audio
	var missing := 0
	for n in Audio.SFX:
		if (Audio._streams[n] as Array).size() != int(Audio.SFX[n]):
			missing += 1
			print("    son manquant : ", n)
	_check(missing == 0, "bruitages chargés")
	for isl in Audio.MUSIC:
		_check(load(Audio.MUSIC[isl]) is AudioStream, "musique " + isl)

	print("=== TESTS TERMINÉS : %d échec(s) ===" % fails)
	Game.reset_game()
	get_tree().quit()


func _aim(p: Vector3i, n: Vector3i) -> void:
	main._cooldown = 0.0
	main.target = {"hit": true, "pos": p, "normal": n, "block": main.world.get_blockv(p)}


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  OK   ", label)
	else:
		fails += 1
		print("  FAIL ", label)


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame
