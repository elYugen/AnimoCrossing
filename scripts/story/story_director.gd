class_name StoryDirector
extends Node
## Le fil de l'histoire, sans quêtes : nouvelle partie (création du
## personnage puis naufrage), pensées du personnage (story.dialogue),
## découvertes (point d'eau, campement, coffre) et petites pensées qui
## guident le joueur quand il ne sait pas quoi faire.

var main: Main
var hint_timer := 3.0


# --- Nouvelle partie : création du personnage puis naufrage ----------------

func open_creator() -> void:
	main.title.visible = false
	var cc := CharacterCreator.new()
	main.add_child(cc)
	cc.cancelled.connect(func():
		cc.queue_free()
		main.title.show_menu())
	cc.confirmed.connect(func(n: String, skin: String, head: String):
		_new_game_story(cc, n, skin, head))


func _new_game_story(cc: CharacterCreator, player_name: String, skin: String, head: String) -> void:
	if main.loading:
		return
	var hud := main.hud
	main.loading = true
	var story := StoryOverlay.new()
	story.speaker = player_name
	main.add_child(story)
	await story.black(0.8)
	cc.queue_free()
	Game.reset_game()
	# Le naufragé se réveille à l'aube, par beau temps.
	Game.time = 6.6
	Game.weather = "clear"
	Game.weather_left = 5.0
	Game.player_name = player_name
	Game.player_skin = skin
	Game.player_head = head
	main.player.set_skin(skin, head)
	Audio.stop_music(1.2)
	main.load_island("prairie", false)
	hud.close_panel()
	hud.refresh_all()
	hud.visible = false
	main.in_title = false
	main.cinematic = true
	main.title.visible = false
	main.power = 0
	Game.save_game()
	var intro := ShipwreckIntro.new()
	await intro.run(main, story)
	main.cinematic = false
	main.loading = false
	hud.visible = true
	hud.refresh_all()
	hud.fade_in_root(1.0)
	Game.save_game()
	think("reveil")


# --- Pensées --------------------------------------------------------------

## Pensées du personnage (fichier story.dialogue), affichées en bas de l'écran.
## Attend la fin du dialogue.
func think(cue: String) -> void:
	var hud := main.hud
	while hud.dialog_open():
		await get_tree().process_frame
	var lines := await Dialogues.texts(Dialogues.STORY, cue)
	if lines.is_empty():
		return
	hud.show_dialog(Game.player_name if Game.player_name != "" else "Moi", lines)
	while hud.dialog_open():
		await get_tree().process_frame


func on_step_changed(step: int) -> void:
	if step == 1 and not Game.has_flag("camp"):
		think("provisions")


# --- Campement et découvertes ----------------------------------------------

func spawn_camp() -> void:
	if main.camp_props:
		main.camp_props.queue_free()
		main.camp_props = null
	if IslandGenerator.camp.is_empty():
		return
	var cp := CampProps.new()
	cp.world = main.world
	cp.name = "Camp"
	main.add_child(cp)
	main.camp_props = cp


## Le joueur s'approche du point d'eau ou du campement pour la première fois.
func check_discoveries(pp: Vector3) -> void:
	var pond := IslandGenerator.pond
	if pond != Vector3.ZERO and not Game.has_flag("water") and Vector2(pond.x - pp.x, pond.z - pp.z).length() < 5.5:
		Game.set_flag("water")
		main.player.face_towards(pond)
		think("eau")
	var camp: Dictionary = IslandGenerator.camp
	if not camp.is_empty() and not Game.has_flag("camp"):
		var c: Vector3 = camp["center"]
		if Vector2(c.x - pp.x, c.z - pp.z).length() < 8.0:
			Game.set_flag("camp")
			main.player.face_towards(c)
			think("campement")


func open_chest() -> void:
	var camp_props := main.camp_props
	if camp_props.opened:
		think("rouille")
		return
	var hud := main.hud
	main.busy = true
	main.player.face_towards(camp_props.chest.global_position)
	await think("coffre")
	main.player.play_action("open")
	camp_props.open()
	Audio.play("open", -2.0, 0.0, 0.8)
	await get_tree().create_timer(0.8).timeout
	Audio.play("jingle_rare", -4.0, 0.0)
	main.burst(camp_props.chest.global_position + Vector3(0, 0.7, 0), Color("ffd84a"), 24)
	hud.show_item_popup("Tu as trouvé le Façonneur !", "Casser, poser, faire fleurir, planter : il façonne l'île.")
	Game.set_flag("camp")
	Game.set_flag("chest")
	hud.jump_to_step(3)
	Game.save_game()
	await get_tree().create_timer(2.6).timeout
	await think("outil")
	main.busy = false


# --- Pensées qui guident (pas de tutoriel) ---------------------------------

func hints(delta: float) -> void:
	hint_timer -= delta
	if hint_timer > 0.0:
		return
	hint_timer = 2.0
	var hud := main.hud
	if main.cinematic or main.busy or main.loading or hud.dialog_open() or hud.is_blocking() or not Game.has_flag("chest"):
		return
	var raw := 0
	for k in Items.RAW:
		raw += Game.item_count(k)
	var interior := main.interior
	var hint := ""
	if interior and not Game.has_flag("hint_meubler") and Game.interiors.get(interior.house_key, []).size() < 4:
		hint = "meubler"
	elif interior:
		return
	elif main.sky.is_night() and Game.resident_count() == 0 and not Game.has_flag("hint_nuit"):
		hint = "nuit"
	elif main.sky.is_wet() and not Game.has_flag("hint_pluie"):
		hint = "pluie"
	elif raw >= 8 and not Game.has_flag("did_craft") and not Game.has_flag("hint_fabriquer"):
		hint = "fabriquer"
	elif Game.has_flag("did_craft") and not Game.has_flag("did_build") and not Game.has_flag("hint_construire"):
		hint = "construire"
	elif Game.has_flag("did_build") and not Game.has_flag("hint_belle_allure"):
		hint = "belle_allure"
	elif Vitality.percent(Game.current_island) >= Vitality.ARRIVALS[0] and Game.resident_count() == 0 and not Game.has_flag("hint_quelqu_un"):
		hint = "quelqu_un"
	elif Game.resident_count() >= 2 and not Game.has_flag("unlock_corail") and not Game.has_flag("hint_barque_idee"):
		hint = "barque_idee"
	if hint != "":
		Game.set_flag("hint_" + hint)
		think(hint)
