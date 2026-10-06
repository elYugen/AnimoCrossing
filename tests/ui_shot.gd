extends Node
## Scène de test : captures de toute l'interface (menus, création de
## personnage, HUD, fenêtres). SHOT_DIR=<dossier> godot --path . res://tests/ui_shot.tscn

var out := OS.get_environment("SHOT_DIR")
var main: Main


func _ready() -> void:
	Game.reset_game()
	Game.tutorial_step = 10
	for f in ["water", "camp", "chest"]:
		Game.set_flag(f)
	Game.player_name = "Lou"
	for k in Items.ALL:
		Game.add_item(k, 6)
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_intro = true
	add_child(main)
	main.story.hint_timer = 1.0e9
	await _wait(60)
	await _shot("60_title")
	main.title._options.visible = true
	await _wait(5)
	await _shot("61_options")
	main.title._options.visible = false

	# Création de personnage.
	var cc := CharacterCreator.new()
	main.add_child(cc)
	await _wait(40)
	cc._name_edit.text = "Lou"
	await _wait(5)
	await _shot("62_creator")
	cc.queue_free()

	await main._start_game(false)
	Game.time = 11.0
	Game.weather = "clear"
	main.sky.apply(true)
	main.select_power(1)
	for b in [Blocks.PLANK, Blocks.STONE, Blocks.DIRT, Blocks.SAND, Blocks.BRICK, Blocks.WOOD]:
		Game.add_block(b, 12)
	Game.add_structure("campfire", 2)
	Game.add_structure("f_table")
	await _wait(20)
	main.hud._disc_queue.clear()
	main.hud._disc.visible = false
	main.select_block(Blocks.PLANK)
	main.deny("Pas de place ici.")
	await _wait(10)
	await _shot("70_place_bar")
	await _wait(30)
	main.hud.show_dialog("Lou", ["Une phrase de dialogue pour voir la boîte, avec son nom et sa petite flèche."])
	await _wait(20)
	await _shot("63_hud_dialog")
	main.hud.advance_dialog()
	await _wait(5)
	main.hud.back()  # pause
	await _wait(10)
	await _shot("64_pause")
	main.hud.back()
	await _wait(5)
	main.hud.open_crafting(true)
	await _wait(20)
	await _shot("65_craft")
	main.hud.close_panel()
	main.hud.toggle_panel("carnet")
	await _wait(20)
	await _shot("66_carnet")
	main.hud.close_panel()
	main.hud.toggle_panel("map")
	await _wait(20)
	await _shot("67_map")
	main.hud.close_panel()
	Game.collections.erase("items")
	Game.add_item("rope")
	await _wait(30)
	await _shot("69_discovery")
	main.hud._disc.visible = false
	main.hud.show_item_popup("Tu as trouvé le Façonneur !", "Casser, poser, faire fleurir, planter : il façonne l'île.")
	main.hud.toast("Une petite notification")
	await _wait(30)
	await _shot("68_popup")
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + shot_name + ".png")
	print("shot ", shot_name)
