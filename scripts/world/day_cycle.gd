class_name DayCycle
extends Node
## Dormir jusqu'au lendemain : l'île repousse, chaque île assez accueillante
## attire un nouvel habitant (tiré au sort selon son environnement), et celui
## qui arrive sur l'île du joueur est accueilli par une petite scène.
## (L'heure et la météo sont gérées par SkyCycle.)

var main: Main
## Arrivées de la nuit : présentées par la scène du matin, pas tout de suite.
var _morning := false


func _ready() -> void:
	Game.resident_arrived.connect(_on_resident_arrived)


func sleep() -> void:
	if main.loading or main.busy or main.cinematic or main.in_title:
		return
	var hud := main.hud
	main.busy = true
	main.cinematic = true
	hud.close_panel()
	main.hide_prompt()
	await main.story.think("dormir")
	var story := StoryOverlay.new()
	main.add_child(story)
	story._set_lid(0.0)
	story._skip_hint.visible = false
	await story.black(1.4)
	Game.day += 1
	main.sky.morning()
	regrow()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var arrivals := {}
	for isl in IslandDB.ISLANDS:
		var iid: String = isl["id"]
		if iid != Game.current_island and Game.get_stat(iid, "place") + Game.get_stat(iid, "break") == 0:
			continue  # île jamais visitée
		var c := Vitality.pick_arrival(iid, rng)
		if not c.is_empty():
			arrivals[iid] = c
	story.show_title("Jour %d" % Game.day, "Le lendemain matin...", 1.4)
	await get_tree().create_timer(3.6).timeout
	_morning = true
	for iid in arrivals:
		Game.add_resident(arrivals[iid]["id"], iid)
	_morning = false
	Game.save_game()
	await story.clear_bars(1.6)
	story.queue_free()
	main.cinematic = false
	main.wildlife.spawn(true)
	for iid in arrivals:
		if iid != Game.current_island:
			hud.toast("%s s'est installé sur l'%s !" % [arrivals[iid]["name"], IslandDB.get_island(iid)["name"]], UIStyle.GREEN_DARK)
	if arrivals.has(Game.current_island) and main.interior == null:
		await _welcome(arrivals[Game.current_island])
	elif arrivals.has(Game.current_island):
		hud.toast("%s s'est installé sur l'île !" % arrivals[Game.current_island]["name"], UIStyle.GREEN_DARK)
		main.residents.spawn_all()
	elif Vitality.next_threshold(Game.current_island) >= 0:
		await main.story.think("matin_vide")
	await main.mystery.on_morning()
	main.busy = false


## Le nouvel habitant arrive près du joueur, regarde autour de lui... et reste.
func _welcome(c: Dictionary) -> void:
	var hud := main.hud
	var player := main.player
	var pp := player.global_position
	var fwd := -main.rig.camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var pos := main.residents.find_spot(pp + fwd * 5.0, 2.5)
	var cr := main.residents.make(c, pos)
	cr.talk_to(pp)
	player.face_towards(pos)
	main.burst(pos + Vector3(0, 0.6, 0), Color("ffd84a"), 18)
	Audio.play("jingle_resident", -4.0, 0.0)
	await get_tree().create_timer(1.0).timeout
	var first := not Game.has_flag("first_arrival")
	var lines := await Dialogues.texts(Dialogues.ARRIVALS, "premiere" if first else "arrivee")
	hud.show_dialog(c["name"], lines)
	while hud.dialog_open():
		await get_tree().process_frame
	hud.show_resident_popup(c["id"])
	hud.toast("%s s'installe sur l'île !" % c["name"], UIStyle.GREEN_DARK)
	if first:
		Game.set_flag("first_arrival")
		get_tree().create_timer(3.5).timeout.connect(func():
			hud.toast("Plus l'île est accueillante, plus elle attire d'habitants !", UIStyle.BLUE.darkened(0.2)))
	Game.notify_action("arrival")
	# Une maison libre ? Il s'y installe ; sinon, il faudra lui en bâtir une.
	var props := main.props
	for id in props.items:
		if Props.is_house(props.kind_of(id)) and not Game.homes.has(props.key_of(id)):
			Game.set_home(props.key_of(id), c["id"])
			hud.toast("%s s'installe dans une maison libre." % c["name"], UIStyle.GREEN_DARK)
			return
	if not Game.has_flag("hint_house"):
		Game.set_flag("hint_house")
		get_tree().create_timer(4.0).timeout.connect(func(): main.story.think("maison_habitant"))


## Un habitant arrivé hors de la nuit (mode admin...) apparaît près du joueur.
func _on_resident_arrived(id: String) -> void:
	if _morning:
		return  # présenté par la scène du matin (_welcome)
	var info: Dictionary = Game.residents.get(id, {})
	if info.get("island", "") == Game.current_island:
		var pos := main.residents.find_spot(main.player.global_position, 4.0)
		var cr := main.residents.make(ResidentDB.get_resident(id), pos)
		cr.celebrate()
		main.burst(pos + Vector3(0, 0.6, 0), Color("ffd84a"), 24)


## Chaque matin : les ressources repoussent peu à peu, des fleurs sauvages
## apparaissent près des autres, et les jeunes arbres grandissent.
func regrow() -> void:
	var world := main.world
	var rng := main.rng
	main.gathering.regrow()
	# Fleurs sauvages : quelques-unes repoussent à côté des fleurs existantes,
	# d'autant plus que l'île est vivante.
	var wild := 4 + main.life.tier * 5
	var biome: String = IslandDB.get_island(Game.current_island)["biome"]
	var flowers: Array = IslandGenerator.FLOWER_SETS[biome]
	if not flowers.is_empty():
		var grown := 0
		for attempt in 400:
			if grown >= wild:
				break
			var x := rng.randi_range(8, VoxelWorld.SX - 9)
			var z := rng.randi_range(8, VoxelWorld.SZ - 9)
			var y := world.top_solid_y(x, z)
			if y <= IslandGenerator.SEA or world.get_block(x, y, z) != Blocks.GRASS or world.get_block(x, y + 1, z) != Blocks.AIR:
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2)]:
				if world.get_block(x + d.x, y + 1, z + d.y) in Blocks.FLOWERS:
					near = true
			if near and not main.props.any_near(Vector3(x + 0.5, y + 1, z + 0.5), 0.8):
				world.set_block(Vector3i(x, y + 1, z), flowers.pick_random())
				grown += 1
		world.flush()
	main.props.update_growth()
