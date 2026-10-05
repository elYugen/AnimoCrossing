extends Node
## Scène de test : captures de la création de personnage et de l'intro (dev).

var out := OS.get_environment("SHOT_DIR")
var main: Node


func _ready() -> void:
	Game.reset_game()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(40)
	main._start_game(true)
	await _wait(30)
	var cc: CharacterCreator = null
	for c in main.get_children():
		if c is CharacterCreator:
			cc = c
	cc._name_edit.text = "Lou"
	cc._set_look("c", "k")
	await _wait(40)
	await _shot("20_creator")
	cc._confirm()
	var t0 := Time.get_ticks_msec()
	var n := 0
	while main._cinematic or main._loading:
		await _wait(1)
		var story: StoryOverlay = null
		for c in main.get_children():
			if c is StoryOverlay:
				story = c
		if story and story._waiting:
			await _wait(25)
			await _shot("21_line_%02d" % n)
			n += 1
			story.advanced.emit()
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		if t > 14.0 and int(t * 10) % 15 == 0:
			await _shot("22_cut_%03d" % int(t))
		if t > 120.0:
			break
	await _wait(90)
	await _shot("23_play")
	get_tree().quit()


func _wait(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("shot ", name)
