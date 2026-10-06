class_name Houses
extends Node
## Maisons : qui habite où (attribution automatique ou au choix, touche G),
## entrer et sortir. L'intérieur courant est dans main.interior.

var main: Main
var _outside_pos := Vector3.ZERO


## Une maison terminée accueille un habitant sans logement (celui dont
## l'environnement préféré est le plus proche).
func auto_home(house_key: String, pos: Vector3) -> void:
	var best := ""
	var best_score := -INF
	for id in Game.residents:
		if (Game.residents[id] as Dictionary).get("island", "") != Game.current_island or Game.home_of(id) != "":
			continue
		var hab: String = ResidentDB.get_resident(id).get("habitat", "")
		var score := 0.0
		match hab:
			"marine":
				for b in main.residents.beach_spots:
					score = maxf(score, 40.0 - b.distance_to(pos))
			"forest":
				score = 10.0 if main.props.any_near(pos, 12.0, true) else 0.0
			_:
				score = 5.0
		score += main.rng.randf()
		if score > best_score:
			best_score = score
			best = id
	if best != "":
		Game.set_home(house_key, best)
		main.hud.toast("%s s'installe dans cette maison !" % ResidentDB.get_resident(best)["name"], UIStyle.GREEN_DARK)


## Choix de l'occupant d'une maison (touche G devant la porte).
func choose_resident(house_id: int) -> void:
	var hud := main.hud
	var key := main.props.key_of(house_id)
	var options := [{"id": "", "label": "Personne"}, {"id": "player", "label": "Moi (%s)" % (Game.player_name if Game.player_name != "" else "joueur")}]
	for id in Game.residents:
		if (Game.residents[id] as Dictionary).get("island", "") != Game.current_island:
			continue
		var cur := Game.home_of(id)
		var where := "" if cur == "" else (" — habite déjà ailleurs" if cur != key else " — habite ici")
		options.append({"id": id, "label": ResidentDB.get_resident(id)["name"] + where})
	hud.show_choice("Qui habite ici ?", options, func(owner: String):
		var before := Game.home_of(owner) if owner != "" else ""
		Game.set_home(key, owner)
		if owner != "" and owner != "player":
			var d := Friendship.data(owner)
			d["seen_furn"] = []
			for e in Game.interiors.get(key, []):
				(d["seen_furn"] as Array).append(e["f"])
			if before != "" and before != key:
				d["moved"] = true
				hud.toast("%s a déménagé !" % ResidentDB.get_resident(owner)["name"], UIStyle.GREEN_DARK)
			else:
				hud.toast("%s s'installe ici !" % ResidentDB.get_resident(owner)["name"], UIStyle.GREEN_DARK))


func enter(id: int) -> void:
	if main.loading or main.interior:
		return
	main.loading = true
	var props := main.props
	var hud := main.hud
	var rig := main.rig
	var kind := props.kind_of(id)
	var key := props.key_of(id)
	_outside_pos = props.door_position(id)
	await hud.fade(true, 0.35)
	var interior := Interior.new()
	interior.setup(kind, key)
	main.add_child(interior)
	main.interior = interior
	main.structure = ""
	hud.set_block(main.block)
	# L'habitant est chez lui ? On le retrouve à l'intérieur.
	var owner: String = Game.homes.get(key, "")
	var c := main.residents.find(owner)
	if c and c.state == Resident.State.HOME:
		# Il profite de ses meubles : canapé, table, cuisine, lit...
		var spot := interior.occupant_spot(Game.time)
		var guest := Resident.new()
		guest.setup(c.data, main.world, interior.to_local(spot["pos"]))
		interior.add_child(guest)
		guest.state = Resident.State.ACT
		guest.activity = spot["act"]
		guest._timer = 1.0e9
		var fd: Vector3 = spot["face"] - spot["pos"]
		guest._facing = atan2(fd.x, fd.z)
	if owner != "":
		hud.toast("Chez moi" if owner == "player" else "Chez %s" % ResidentDB.get_resident(owner).get("name", ""), UIStyle.TEXT_SOFT)
	main.set_outside_visible(false)
	main.weather_fx.visible = false
	main.sky.indoor = true
	main.player.teleport(interior.to_global(interior.spawn))
	main.player.face_towards(interior.to_global(interior.spawn) - Vector3(0, 0, 3))
	rig.world = null
	rig.yaw = 0.0
	rig.pitch = -0.85
	rig.distance = 8.0
	rig.snap()
	Audio.play("open", -4.0)
	await get_tree().process_frame
	await hud.fade(false, 0.35)
	main.loading = false


func exit() -> void:
	if main.loading or main.interior == null:
		return
	main.loading = true
	var hud := main.hud
	var rig := main.rig
	await hud.fade(true, 0.35)
	main.interior.queue_free()
	main.interior = null
	main.structure = ""
	hud.set_block(main.block)
	main.set_outside_visible(true)
	main.weather_fx.visible = true
	main.sky.indoor = false
	main.player.teleport(_outside_pos + Vector3(0, 0.2, 0))
	rig.world = main.world
	rig.distance = 6.0
	rig.pitch = -0.3
	rig.snap()
	Audio.play("close", -4.0)
	await get_tree().process_frame
	await hud.fade(false, 0.35)
	main.loading = false
