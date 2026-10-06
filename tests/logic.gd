extends Node
## Test de logique headless : déroule le tutoriel et vérifie la sauvegarde.

var main: Node
var fails := 0
## Ferme tout seul les dialogues (pensées du personnage) pendant l'histoire.
var auto_close := false


func _process(_d: float) -> void:
	if auto_close and main and main.hud.dialog_open():
		main.hud.advance_dialog()


func _ready() -> void:
	Game.reset_game()
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_intro = true
	add_child(main)
	main.story.hint_timer = 1.0e9  # pas de pensées-guides pendant le test
	await _wait(10)
	_check(main.title.visible and main.in_title, "menu de démarrage affiché")
	await main._start_game(true)
	_check(not main.in_title and main.hud.visible, "partie lancée depuis le menu")
	var act: Dictionary = Presence._activity()
	_check(act["details"] == "Sur l'Île Prairie" and str(act["state"]).contains("habitant"), "statut Discord : « %s · %s »" % [act["details"], act["state"]])
	var hud: HUD = main.hud
	var w: VoxelWorld = main.world
	var sp := IslandGenerator.SPAWN
	_check(Game.tutorial_step == 0, "étape 0 : explorer")
	_check(not hud.power_unlocked(0), "aucun outil au départ")
	_check(main.gathering.get_child_count() > 200, "objets à ramasser (%d)" % main.gathering.get_child_count())
	_check(IslandGenerator.pond != Vector3.ZERO and not IslandGenerator.camp.is_empty(), "point d'eau et campement générés")
	auto_close = true
	# Ramasser un objet en marchant dessus.
	var pk: Pickup = main.gathering.get_child(0)
	var kind := pk.kind
	main.player.teleport(pk.global_position)
	await _wait(3)
	_check(Game.item_count(kind) == 1, "objet ramassé (%s)" % kind)
	await _wait(3)
	_check(hud._disc.visible and hud._disc_name.text == Items.name_of(kind) and hud._disc_use.text.begins_with("Sert à"), "première fois : fiche de l'objet (%s)" % hud._disc_use.text)
	var queued := hud._disc_queue.size()
	Game.add_item(kind)
	_check(hud._disc_queue.size() == queued, "pas de fiche la deuxième fois")
	for k in HUD.TUTO[0]["goals"]:
		Game.add_item(k, 5)
	_check(Game.tutorial_step == 0, "il manque encore le point d'eau")
	main.player.teleport(IslandGenerator.pond + Vector3(2.5, 3.0, 0))
	await _wait(5)
	_check(Game.has_flag("water") and Game.tutorial_step >= 1, "point d'eau trouvé, exploration terminée")
	main.player.teleport(IslandGenerator.camp["center"] + Vector3(4, 0.5, 4))
	await _wait(5)
	_check(Game.has_flag("camp") and Game.tutorial_step == 2, "campement découvert")
	main.player.teleport(IslandGenerator.camp["chest"] + Vector3(1.2, 0.3, 0.6))
	await _wait(5)
	_check(not main.nearest_interactable().is_empty(), "coffre à portée")
	await main.story.open_chest()
	_check(Game.has_flag("chest") and main.camp_props.opened, "coffre ouvert")
	_check(Game.tutorial_step == 3 and hud.power_unlocked(0) and hud.power_unlocked(1), "outil universel obtenu")
	await _wait(5)
	auto_close = false

	# Retirer 3 déchets
	var totals: Dictionary = Game.island_totals.get("prairie", {})
	_check(int(totals.get("waste", 0)) > 30 and int(totals.get("water", 0)) > 10, "déchets et vase générés (%s)" % str(totals))
	_check(Vitality.percent("prairie") == Vitality.BASE, "vitalité de départ : %d %%" % Vitality.percent("prairie"))
	main.select_power(0)
	var debris := _find_all(w, Blocks.DEBRIS, 3)
	for i in 3:
		_aim(debris[i], Vector3i.UP)
		main.tools.use_power()
		_check(w.get_blockv(debris[i]) == Blocks.AIR, "déchet retiré %d" % i)
	_check(Game.tutorial_step == 4, "étape nettoyer passée")
	_check(Game.get_stat("prairie", "clean_waste") == 3, "stat déchets")
	_check(Game.block_count(Blocks.DEBRIS) == 0, "un déchet ne se récupère pas")
	var sludge := _find_all(w, Blocks.SLUDGE, 1)
	main.select_power(0)
	_aim(sludge[0], Vector3i.UP)
	main.tools.use_power()
	_check(Game.get_stat("prairie", "clean_water") == 1, "vase retirée")

	# Poser 3 blocs : uniquement ceux qu'on possède.
	main.select_power(1)
	main.select_block(Blocks.PLANK)
	var px0 := sp.x - 3
	var pz0 := sp.y - 4
	_aim(Vector3i(px0, w.top_solid_y(px0, pz0), pz0), Vector3i.UP)
	main.tools.use_power()
	_check(Game.get_stat("prairie", "place") == 0, "pas de planche : impossible de poser")
	# Casser de la terre en donne, et on peut la reposer.
	main.select_power(0)
	var dx0 := sp.x + 3
	var dz0 := sp.y + 6
	var dy0 := w.top_solid_y(dx0, dz0)
	_aim(Vector3i(dx0, dy0, dz0), Vector3i.UP)
	main.tools.use_power()
	_check(Game.block_count(Blocks.DIRT) == 1, "terre récupérée en cassant de l'herbe")
	_check(hud._gain_rows.has("Terre") and (hud._gain_rows["Terre"]["label"] as Label).text == "+1 Terre", "le joueur voit ce qu'il récupère (+1 Terre)")
	# Composants puis blocs : branches -> poutre -> planches.
	_check(Crafting.craft(_recipe("beam")) and Game.item_count("beam") == 1, "composant : poutre")
	_check(Game.tutorial_step == 5, "étape fabriquer passée")
	_check(Crafting.craft(_recipe("plank")) and Game.block_count(Blocks.PLANK) == 4 and Game.item_count("beam") == 0, "fabrication : 4 planches")
	_check(not Crafting.is_unlocked(_recipe("s_house_a")), "maison verrouillée sans habitant")
	for i in 3:
		main.select_power(1)
		main.select_block(Blocks.PLANK)
		var x := sp.x - 3 + i
		var z := sp.y - 4
		var y := w.top_solid_y(x, z)
		_aim(Vector3i(x, y, z), Vector3i.UP)
		main.tools.cooldown = 0.0
		main.tools.use_power()
		_check(w.get_block(x, y + 1, z) == Blocks.PLANK, "bloc posé %d" % i)
	_check(Game.tutorial_step == 6, "étape poser passée")
	_check(Game.get_stat("prairie", "place_7") == 3, "stat planches")
	_check(Game.block_count(Blocks.PLANK) == 1, "planches consommées")
	# Poser, repensé : molette dans la catégorie, F pour en changer, clic
	# droit pour retirer, et la raison quand c'est impossible.
	main.select_power(1)
	main.select_block(Blocks.PLANK)
	main._cycle_block(1)
	_check(main.structure == "" and main.block != Blocks.PLANK and main.place_category() == 0, "molette : bloc suivant (%s)" % Blocks.block_name(main.block))
	main._cycle_block(-1)
	_check(main.block == Blocks.PLANK, "molette arrière : retour aux planches")
	Game.add_structure("f_table")
	main._cycle_category()
	_check(main.place_category() != 0, "F : autre catégorie (%s)" % main.structure)
	Game.add_structure("f_table", -1)
	main.select_block(Blocks.PLANK)
	var rx := sp.x - 1
	var rz := sp.y - 4
	var ry := w.top_solid_y(rx, rz)
	_check(w.get_block(rx, ry, rz) == Blocks.PLANK, "(une planche posée à retirer)")
	_aim(Vector3i(rx, ry, rz), Vector3i.UP)
	main.tools.use_power(0)
	_check(w.get_block(rx, ry, rz) != Blocks.PLANK and main.power == 1, "clic droit : planche retirée sans changer de pouvoir")
	Game.add_block(Blocks.BRICK, 0)
	main.select_block(Blocks.BRICK)
	main.block = Blocks.BRICK
	_aim(Vector3i(rx + 5, w.top_solid_y(rx + 5, rz), rz), Vector3i.UP)
	main._last_deny = ""
	main.tools.use_power()
	_check(hud._reason != null and hud._reason.text.contains("Brique"), "raison sous le viseur : « %s »" % (hud._reason.text if hud._reason else ""))
	main.select_block(Blocks.PLANK)

	# Fleurir la parcelle
	main.select_power(2)
	var py := w.top_solid_y(sp.x + 4, sp.y - 2)
	_aim(Vector3i(sp.x + 4, py, sp.y - 2), Vector3i.UP)
	main.tools.use_power()
	_check(Game.resident_count() == 0, "personne n'arrive tout de suite")
	_check(Game.tutorial_step == 7, "étape fleurir passée")

	# Pousser un arbre
	main.select_power(3)
	var tx := sp.x + 6
	var tz := sp.y
	var ty := w.top_solid_y(tx, tz)
	_check(main.props.tree_count() > 100, "arbres 3D générés (%d)" % main.props.tree_count())
	var trees_before: int = main.props.tree_count()
	_aim(Vector3i(tx, ty, tz), Vector3i.UP)
	main.tools.use_power()
	var tree_spot := Vector3(tx + 0.5, ty + 1, tz + 0.5)
	_check(main.props.tree_count() == trees_before + 1 and main.props.any_near(tree_spot, 0.5, true), "arbre poussé")
	_check(Game.tutorial_step == 8, "étape arbre passée")

	# Feu de camp : se fabrique avec des objets ramassés, puis se pose.
	var branches := Game.item_count("branch")
	_check(Crafting.craft(_recipe("s_campfire")) and Game.item_count("branch") == branches - 2 and Game.structure_count("campfire") == 1, "feu de camp fabriqué (2 branches)")
	main.select_structure("")
	hud._on_crafted(_recipe("s_campfire"))
	_check(main.structure == "campfire" and main.power == 1, "ce qu'on fabrique est prêt à poser")
	var fx := sp.x + 6
	var fz := sp.y - 6
	var fy := w.top_solid_y(fx, fz)
	main.player.teleport(Vector3(fx + 3.5, fy + 1.2, fz + 0.5))
	await _wait(3)
	_aim(Vector3i(fx, fy, fz), Vector3i.UP)
	main.aim.update_ghost()
	_check(main.aim.ghost_ok, "emplacement valide pour le feu")
	main.tools.use_power()
	var fire_spot := Vector3(fx + 0.5, fy + 1, fz + 0.5)
	_check(main.props.any_near(fire_spot, 0.5) and Game.structure_count("campfire") == 0, "feu de camp posé")
	_check(Game.get_stat("prairie", "build_campfire") == 1, "stat feux de camp")
	# La vitalité suit l'état de l'île : déplacer un feu ne rapporte rien.
	var vit_fire := Vitality.percent("prairie")
	var fire_id := -1
	for id in main.props.items:
		if main.props.kind_of(id) == "campfire" and main.props.key_of(id).begins_with("p:"):
			fire_id = id
	main.props.remove(fire_id)
	var vit_nofire := Vitality.percent("prairie")
	main.props.add_persistent("campfire", fire_spot)
	main.props.remove(main.props.items.keys()[-1])
	main.props.add_persistent("campfire", fire_spot)
	_check(vit_nofire < vit_fire and Vitality.percent("prairie") == vit_fire, "vitalité : feu retiré %d %% → reposé %d %% (pas de cumul)" % [vit_nofire, Vitality.percent("prairie")])
	# Le reprendre le remet dans l'inventaire.
	var fid := -1
	for id in main.props.items:
		if main.props.kind_of(id) == "campfire" and main.props.key_of(id).begins_with("p:"):
			fid = id
	main.select_power(0)
	main.aim.target = {"hit": true, "prop": fid, "point": fire_spot, "pos": Vector3i.ZERO, "block": Blocks.AIR}
	main.tools.cooldown = 0.0
	main.tools.use_power()
	_check(Game.structure_count("campfire") == 1 and not main.props.items.has(fid), "feu repris dans l'inventaire")
	_check(hud._gain_rows.has("campfire") or hud._gain_rows.has("Feu de camp"), "le feu repris est annoncé")
	# Un meuble se pose aussi dehors.
	Game.add_structure("f_table")
	_check("f_table" in hud.placeables(), "meuble proposé dans la barre, dehors")
	main.select_structure("f_table")
	var table_ok := false
	for attempt in 30:
		var ax := fx + attempt % 6 * 3 - 6
		var az := fz - attempt / 6 * 3 + 6
		var ay := w.top_solid_y(ax, az)
		main.player.teleport(Vector3(ax + 4.5, ay + 1.2, az + 0.5))
		_aim(Vector3i(ax, ay, az), Vector3i.UP)
		main.aim.update_ghost()
		if main.aim.ghost_ok:
			table_ok = true
			break
	_check(table_ok, "emplacement valide pour la table")
	var builds := Game.get_stat("prairie", "build")
	main.tools.use_power()
	var table_id := -1
	for id in main.props.items:
		if main.props.kind_of(id) == "f_table":
			table_id = id
	_check(table_id > 0 and Game.structure_count("f_table") == 0, "table posée dehors")
	_check(Game.get_stat("prairie", "build") == builds, "un meuble dehors ne gonfle pas la vitalité")
	main.select_power(0)
	main.aim.target = {"hit": true, "prop": table_id, "point": fire_spot, "pos": Vector3i.ZERO, "block": Blocks.AIR}
	main.tools.cooldown = 0.0
	main.tools.use_power()
	_check(Game.structure_count("f_table") == 1 and not main.props.items.has(table_id), "table reprise")
	Game.add_structure("f_table", -1)
	# Couper un arbre généré : il disparaît et donne des branches.
	var tid := -1
	for id in main.props.items:
		if Props.is_tree(main.props.kind_of(id)) and str(main.props.items[id]["key"]).begins_with("g:"):
			tid = id
			break
	var cut_key: String = main.props.items[tid]["key"]
	main.select_power(0)
	main.tools.cooldown = 0.0
	main.aim.target = {"hit": true, "prop": tid, "point": main.props.items[tid]["pos"], "pos": Vector3i.ZERO, "block": Blocks.AIR}
	main.tools.use_power()
	_check(not main.props.items.has(tid) and cut_key in (Game.props_removed["prairie"] as Array), "arbre coupé (retrait sauvegardé)")

	# La vitalité monte ; une île pas assez accueillante n'attire personne.
	var pct := Vitality.percent("prairie")
	_check(pct > Vitality.BASE, "la vitalité monte (%d %%)" % pct)
	_check(Vitality.pick_arrival("givree", RandomNumberGenerator.new()).is_empty(), "île vide : personne ne vient")
	auto_close = true
	await main.days.sleep()
	_check(Game.day == 2 and Vitality.residents("prairie") == (1 if pct >= 15 else 0), "nuit 1 (%d %%)" % pct)
	_check(absf(Game.time - 7.0) < 0.2, "réveil à 7 h (%.2f)" % Game.time)
	_check(Game.weather in SkyCycle.CLIMATES["prairie"], "météo de la prairie : %s" % Game.weather)
	# Le temps passe : une heure de jeu par minute réelle.
	var t_before := Game.time
	main.sky._process(60.0)
	_check(absf(Game.time - t_before - 1.0) < 0.01, "une heure passe en une minute")
	Game.time = 13.0
	Game.weather = "storm"
	main.sky.apply(true)
	_check(main.sky.is_wet() and main.scenery.sun.light_energy < 0.7, "orage : lumière assombrie")
	Game.weather = "clear"
	Game.time = 23.0
	main.sky.apply(true)
	_check(main.sky.is_night() and main.scenery.sun.light_energy < 0.3, "nuit : lune")
	Game.time = 9.0
	main.sky.apply(true)
	# On développe la forêt : l'habitant tiré au sort devrait plutôt être forestier.
	_fake_trees(30)
	_check(Vitality.percent("prairie") >= 22, "vitalité >= 22 %% (%d %%)" % Vitality.percent("prairie"))
	_check(Vitality.best_habitat("prairie") == "forest", "environnement dominant : forêt")
	var residents_before := Vitality.residents("prairie")
	await main.days.sleep()
	_check(Game.day == 3 and Vitality.residents("prairie") == residents_before + 1, "nuit 2 : un habitant arrive")
	_check(Game.tutorial_step == 9, "étape vitalité passée")
	# Beau temps pour la suite (sous la pluie, chacun rentre chez soi).
	Game.weather = "clear"
	Game.weather_left = 999.0
	Game.time = 9.0
	main.sky.apply(true)
	auto_close = false
	var forest := 0
	var rng := RandomNumberGenerator.new()
	for i in 200:
		var pick := Vitality.pick_arrival("prairie", rng)
		if pick.get("habitat", "") == "forest":
			forest += 1
	_check(forest > 100, "tirage pondéré par l'environnement (%d/200 forestiers, %s)" % [forest, str(Vitality.habitat_scores("prairie"))])

	# Parler
	await _wait(5)
	var c: Node3D = main.residents.get_child(main.residents.get_child_count() - 1)
	main.player.global_position = c.global_position + Vector3(1, 0, 0)
	await main.interact()
	_check(hud.dialog_open(), "dialogue ouvert")
	hud.advance_dialog()
	hud.advance_dialog()
	_check(Game.tutorial_step == 10, "progression du début terminée")
	hud.close_panel()  # (le choix « Offrir quelque chose » après la discussion)

	# Chemins : on contourne l'eau et les arbres, un bloc de dénivelé à la fois.
	var nv: Navigator = main.nav
	var camp_c: Vector3 = IslandGenerator.camp["center"]
	var path := nv.find_path(camp_c + Vector3(3, 0, 6), IslandGenerator.beach["pos"])
	_check(path.size() > 5, "chemin du campement à la plage (%d points)" % path.size())
	var path_ok := true
	for i in path.size():
		var q := path[i]
		if not nv.walkable(floori(q.x), floori(q.z)):
			path_ok = false
		if i > 0 and absf(q.y - path[i - 1].y) > 2.01:
			path_ok = false
	_check(path_ok, "chemin praticable (ni eau, ni obstacle, ni falaise)")
	var tree_cell := Vector2i(-1, -1)
	for tid2 in main.props.items:
		if Props.is_tree(main.props.kind_of(tid2)):
			var tp: Vector3 = main.props.items[tid2]["pos"]
			tree_cell = Vector2i(floori(tp.x), floori(tp.z))
			break
	_check(not nv.walkable(tree_cell.x, tree_cell.y), "on ne traverse pas un tronc d'arbre")

	# Amitié : une fois par jour en parlant, plus avec un cadeau qu'il aime.
	var frid: String = Game.residents.keys()[0]
	var fcr: Resident = null
	for n in main.residents.get_children():
		if (n as Resident).data["id"] == frid:
			fcr = n
	var p0 := Friendship.points(frid)
	Friendship.data(frid)["talk_day"] = -1
	main.talk.talk(fcr)
	await _wait(3)
	while hud.dialog_open():
		hud.advance_dialog()
	hud.close_panel()
	_check(Friendship.points(frid) == p0 + 3, "parler : +3 d'amitié")
	main.talk.talk(fcr)
	await _wait(3)
	while hud.dialog_open():
		hud.advance_dialog()
	hud.close_panel()
	_check(Friendship.points(frid) == p0 + 3, "une seule fois par jour")
	var liked_item: String = Friendship.LIKES[Friendship.habitat(frid)]["items"][0]
	Game.add_item(liked_item, 1)
	main.talk.give(fcr, liked_item)
	await _wait(3)
	while hud.dialog_open():
		hud.advance_dialog()
	_check(Friendship.points(frid) == p0 + 9, "cadeau aimé : +6")
	Friendship.data(frid)["request"] = {"item": "stone", "n": 2}
	Friendship.data(frid)["gift_day"] = -1
	Game.add_item("stone", 2)
	var furn_before := 0
	for k in Game.structures:
		if str(k).begins_with("f_"):
			furn_before += int(Game.structures[k])
	main.talk.give(fcr, "stone")
	await _wait(3)
	while hud.dialog_open():
		hud.advance_dialog()
	var furn_after := 0
	for k in Game.structures:
		if str(k).begins_with("f_"):
			furn_after += int(Game.structures[k])
	_check(not Friendship.data(frid).has("request") and furn_after == furn_before + 1, "demande accomplie : un meuble en récompense")
	Friendship.data(frid)["pts"] = 40
	Friendship.data(frid)["talk_day"] = -1
	main.talk.talk(fcr)
	await _wait(3)
	while hud.dialog_open():
		hud.advance_dialog()
	hud.close_panel()
	_check(Friendship.data(frid).get("unique_given", false), "4 cœurs : meuble unique offert")

	# Repousse : une ressource ramassée revient après quelques jours.
	Game.picked["prairie"] = {"10,10": {"d": Game.day - 5, "k": "branch"}}
	var regrown := false
	for i in 6:
		main.days.regrow()
		if not (Game.picked["prairie"] as Dictionary).has("10,10"):
			regrown = true
			break
	_check(regrown, "les ressources ramassées repoussent")
	_check(is_equal_approx(Props.growth({"planted": Game.day}), 0.3) and is_equal_approx(Props.growth({"planted": Game.day - 5}), 1.0), "une pousse devient un arbre en quelques jours")

	# Constructions : une maison se débloque avec les habitants, se pose et s'ouvre.
	_check(Crafting.is_unlocked(_recipe("s_house_a")), "maison débloquée avec un habitant")
	for k in ["beam", "peg", "rope", "cut_stone"]:
		Game.add_item(k, 10)
	_check(Crafting.craft(_recipe("s_house_a")) and Game.structure_count("house_a") == 1, "petite maison fabriquée")
	var hx := sp.x - 14
	var hz := sp.y + 2
	var hy := w.top_solid_y(hx, hz)
	main.select_power(1)
	main.select_structure("house_a")
	main.player.teleport(Vector3(hx + 0.5, hy + 1.2, hz + 9.5))
	await _wait(3)
	var house_ok := false
	for attempt in 30:
		var ax := hx + attempt % 6 * 3
		var az := hz - attempt / 6 * 3
		var ay := w.top_solid_y(ax, az)
		main.player.teleport(Vector3(ax + 0.5, ay + 1.2, az + 9.5))
		_aim(Vector3i(ax, ay, az), Vector3i.UP)
		main.aim.update_ghost()
		if main.aim.ghost_ok:
			main.tools.use_power()
			house_ok = Game.structure_count("house_a") == 0
			break
	_check(house_ok, "plan de la maison posé")
	_check(main.worksites.all().size() == 1, "chantier ouvert")
	var site: Dictionary = main.worksites.all()[0]
	# (l'habitant à qui on vient de parler finit d'abord la conversation)
	var assigned := 0
	var t0 := Time.get_ticks_msec()
	while assigned == 0 and Time.get_ticks_msec() - t0 < 9000:
		await _wait(5)
		for n in main.residents.get_children():
			if (n as Resident).site_id == site["id"]:
				assigned += 1
	_check(assigned > 0, "des habitants libres viennent construire (%d)" % assigned)
	# Le joueur désigne lui-même l'équipe du chantier.
	var worker_id: String = Game.residents.keys()[0]
	_check(main.construction.order(worker_id, site), "habitant envoyé sur le chantier")
	var worker: Resident = main.residents.find(worker_id)
	t0 = Time.get_ticks_msec()
	while worker.site_id != site["id"] and Time.get_ticks_msec() - t0 < 5000:
		await _wait(5)
	var others_left := true
	for r in main.residents.all():
		if r != worker and r.site_id == site["id"]:
			others_left = false
	_check(worker.site_id == site["id"] and others_left, "seule l'équipe désignée travaille sur le chantier")
	var it_site: Dictionary = {}
	main.player.teleport(main.worksites.center_of(site) + Vector3(main.worksites.radius_of(site) + 1.0, 1.0, 0))
	await _wait(3)
	it_site = main.nearest_interactable()
	_check(str(it_site.get("prompt", "")).contains("ouvriers"), "menu du chantier à portée")
	main.worksites.work(site["id"], 999.0)
	await _wait(2)
	_check(main.worksites.all().is_empty(), "construction terminée")
	var free_again := true
	for n in main.residents.get_children():
		if (n as Resident).site_id != "":
			free_again = false
	_check(free_again, "les habitants sont libérés")
	var hid := -1
	for id in main.props.items:
		if main.props.kind_of(id) == "house_a":
			hid = id
	if hid > 0:
		main.player.teleport(main.props.door_position(hid) + Vector3(0, 0.3, 0))
		await _wait(3)
		var it: Dictionary = main.nearest_interactable()
		_check(str(it.get("prompt", "")).contains("[E] Entrer"), "porte de la maison")
		await main.houses.enter(hid)
		_check(main.interior != null and main.player.global_position.y > 150.0, "entrée dans la maison")
		await _wait(5)
		_check(main.player.global_position.y > 150.0, "on reste dans la maison (sol)")
		await main.houses.exit()
		_check(main.interior == null and main.player.global_position.y < 60.0, "sortie de la maison")
		# Attribuer la maison à un habitant.
		var house_key: String = main.props.key_of(hid)
		var rid: String = Game.residents.keys()[0]
		Game.set_home(house_key, rid)
		_check(Game.home_of(rid) == house_key, "maison attribuée à %s" % rid)
		var cr: Resident = null
		for n in main.residents.get_children():
			if (n as Resident).data["id"] == rid:
				cr = n
		# La nuit, il rentre chez lui ; le matin, il ressort.
		Game.time = 22.5
		main.npc_ai.timer = 0.0
		main.npc_ai.tick(0.1)
		_check(cr.state == Resident.State.GO and cr.activity == "home", "la nuit, il rentre chez lui")
		cr.position = main.residents.home_door(rid)
		for i in 10:
			cr._process(0.05)
		_check(cr.state == Resident.State.HOME and not cr.visible, "il est chez lui")
		Game.time = 8.0
		var out_ok := false
		for i in 40:
			main.npc_ai.timer = 0.0
			main.npc_ai.tick(0.1)
			if cr.state != Resident.State.HOME:
				out_ok = true
				break
		_check(out_ok and cr.visible, "le matin, il ressort")
		# Météo : sous la pluie il rentre... mais Iris, qui adore la pluie, reste dehors.
		var lover_id := ""
		for l in ResidentDB.WEATHER_LOVERS["rain"]:
			if not Game.residents.has(l):
				lover_id = l
				break
		Game.add_resident(lover_id, "prairie")
		await _wait(2)
		var iris: Resident = main.residents.find(lover_id)
		Game.time = 10.0
		# (on choisit un temps humide que cet habitant-là n'aime pas)
		Game.weather = "storm" if ResidentDB.loves_weather(rid, "rain") else "rain"
		main.npc_ai.timer = 0.0
		main.npc_ai.tick(0.1)
		_check(cr.state == Resident.State.GO and cr.activity == "home", "sous la pluie, il rentre chez lui (%s)" % Game.weather)
		Game.weather = "rain"
		iris.idle_time = 100.0
		main.npc_ai.timer = 0.0
		main.npc_ai.tick(0.1)
		_check(iris.visible and iris.activity != "home", "%s adore la pluie : reste dehors" % lover_id)
		var rain_line: String = await main.talk.line("meteo_rain")
		_check(rain_line != "..." and ResidentDB.loves_weather(lover_id, "rain"), "réplique d'un amoureux de la pluie : « %s »" % rain_line)
		Game.weather = "clear"
		# Moments : deux voisins assis sur un banc discutent en bulles.
		cr.leave_home(cr.global_position)
		for r in [cr, iris]:
			r.go(r.global_position, "sit", 30.0)
			r.state = Resident.State.ACT
		main.moments._timer = 1.0e9  # (pas de coucou ni d'autre scène pendant la vérification)
		main.moments.play_scene([cr, iris] as Array[Resident], "banc_vue")
		await _wait(5)
		_check(cr._bubble != null and cr._bubble.visible and cr._bubble.text == "D'ici, on voit toute l'île.", "conversation sur le banc (A parle)")
		await get_tree().create_timer(Moments.LINE_TIME + 0.3).timeout
		_check(iris._bubble != null and iris._bubble.visible and iris._bubble.text == "C'est mon endroit préféré.", "conversation sur le banc (B répond)")
		# Coucou au joueur qui passe.
		iris.state = Resident.State.IDLE
		iris.activity = ""
		iris._bubble.visible = false
		main.moments._waved.clear()
		main.moments._in_scene.clear()
		main.player.global_position = iris.global_position + Vector3(5, 0, 0)
		main.moments._waves([iris] as Array[Resident], main.player.global_position)
		await _wait(5)
		_check(iris._bubble.visible and iris._bubble.text != "", "coucou au joueur : « %s »" % iris._bubble.text)
		# Découverte : le lendemain, quelqu'un vient voir la nouvelle maison.
		Game.novelties["prairie"] = [{"key": house_key, "kind": "house_a", "day": Game.day - 1}]
		for r in main.residents.all():
			r.state = Resident.State.IDLE
			r.job = {}
		_check(main.moments.discover_next(main.residents.all()), "un habitant va découvrir la nouvelle maison")
		var visitor: Resident = null
		for r in main.residents.all():
			if r.on_arrive.is_valid():
				visitor = r
		_check(visitor != null and visitor.state == Resident.State.GO and (Game.novelties["prairie"] as Array).is_empty(), "il s'y rend (et la nouveauté est consommée)")
		visitor.on_arrive.call()
		await _wait(5)
		_check(visitor._bubble.visible and visitor._bubble.text != "", "réaction : « %s »" % visitor._bubble.text)
		# Tâches : « Va nettoyer » puis « Va planter ».
		var dirt_spots := _find_all(w, Blocks.DEBRIS, 1)
		iris.position = Vector3(dirt_spots[0]) + Vector3(2.5, 1.0, 0.5)
		iris.state = Resident.State.IDLE
		main.jobs.give(iris, "clean")
		_check(main.jobs.step(iris), "Va nettoyer : une cible trouvée")
		var dirty: Vector3i = main.jobs._reserved.keys()[0]
		iris.state = Resident.State.TALK  # (le test joue la tâche lui-même, pas l'IA)
		iris._timer = 99.0
		var waste_before := Game.get_stat("prairie", "clean_waste") + Game.get_stat("prairie", "clean_water")
		await main.jobs._do(iris, dirty)
		_check(w.get_blockv(dirty) == Blocks.AIR and Game.get_stat("prairie", "clean_waste") + Game.get_stat("prairie", "clean_water") == waste_before + 1, "l'habitant retire vraiment le déchet")
		_check(int(iris.job["left"]) == 3, "il continue (encore 3)")
		main.jobs.give(iris, "plant")
		var trees_now: int = main.props.tree_count()
		_check(main.jobs.step(iris), "Va planter : un coin d'herbe trouvé")
		iris.state = Resident.State.TALK
		iris._timer = 99.0
		await main.jobs._do(iris, main.jobs._reserved.keys()[0])
		_check(main.props.tree_count() == trees_now + 1, "l'habitant plante un arbre")
		main.jobs.stop(iris)
		# Meubler l'intérieur : poser puis reprendre un meuble.
		Game.add_item("beam", 4)
		Game.add_item("peg", 8)
		_check(Crafting.craft(_recipe("m_table")) and Game.structure_count("f_table") == 1, "table fabriquée")
		await main.houses.enter(hid)
		var n_before: int = main.interior.layout().size()
		main.select_power(1)
		main.select_structure("f_table")
		var placed := false
		for gx in range(2, 8):
			for gz in range(2, 6):
				if main.interior.fits("table", gx, gz, 0.0):
					main.aim.target = {"hit": true, "floor": Vector3(gx, 0, gz), "point": Vector3.ZERO, "pos": Vector3i.ZERO, "block": Blocks.AIR}
					main.aim.update_ghost()
					main.tools.cooldown = 0.0
					main.tools.use_power()
					placed = true
					break
			if placed:
				break
		_check(main.interior.layout().size() == n_before + 1 and Game.structure_count("f_table") == 0, "table posée dans la maison")
		_check((Game.interiors[house_key] as Array).size() == n_before + 1, "intérieur sauvegardé")
		main.select_power(0)
		main.aim.target = {"hit": true, "furn": n_before, "point": Vector3.ZERO, "pos": Vector3i.ZERO, "block": Blocks.AIR}
		main.tools.cooldown = 0.0
		main.tools.use_power()
		_check(main.interior.layout().size() == n_before and Game.structure_count("f_table") == 1, "table reprise")
		# L'habitant remarque un nouveau meuble chez lui.
		Friendship.data(rid)["seen_furn"] = []
		for e in main.interior.layout():
			(Friendship.data(rid)["seen_furn"] as Array).append(e["f"])
		main.interior.add_furniture("loungeSofa", 6.0, 3.0, 0.0)
		var reaction: String = await main.talk.furniture_reaction(rid)
		_check(reaction.contains("canapé"), "réaction au nouveau canapé : « %s »" % reaction)
		var spot: Dictionary = main.interior.occupant_spot(19.0)
		_check(spot["act"] == "sit", "le soir, l'habitant s'assoit sur son canapé")
		await main.houses.exit()
		# Démolir la maison (pour la déplacer) : elle revient dans l'inventaire.
		main.select_power(0)
		main.tools.cooldown = 0.0
		main.aim.target = {"hit": true, "prop": hid, "point": main.props.items[hid]["pos"], "pos": Vector3i.ZERO, "block": Blocks.AIR}
		main.tools.use_power()
		_check(main.worksites.all().size() == 1 and main.props.items.has(hid), "chantier de démolition ouvert")
		main.worksites.work(main.worksites.all()[0]["id"], 999.0)
		await _wait(2)
		_check(not main.props.items.has(hid) and Game.structure_count("house_a") == 1, "maison démontée, de retour dans l'inventaire")

	# Démolir une ruine : tous ses murs partent, on récupère des pierres.
	var wall := -1
	for id in main.props.items:
		if main.props.key_of(id).begins_with("g:r:"):
			wall = id
			break
	var group: Array = main.construction.demolish_group(wall)
	_check(group.size() > 3, "la ruine se démolit en entier (%d pièces)" % group.size())
	var stones := Game.item_count("cut_stone")
	main.tools.cooldown = 0.0
	main.aim.target = {"hit": true, "prop": wall, "point": main.props.items[wall]["pos"], "pos": Vector3i.ZERO, "block": Blocks.AIR}
	main.tools.use_power()
	main.worksites.work(main.worksites.all()[0]["id"], 999.0)
	await _wait(2)
	var left := 0
	for id in group:
		if main.props.items.has(id):
			left += 1
	_check(left == 0 and Game.item_count("cut_stone") > stones, "ruine démolie, moellons récupérés")

	# Animaux : ils apparaissent quand leur environnement se développe.
	main.wildlife.spawn(false)
	_check(main.wildlife.get_child_count() > 0, "animaux apparus (%d)" % main.wildlife.get_child_count())
	_check(Game.species_seen.has("deer"), "le cerf vient avec la forêt")

	# Nouvelle zone : l'éboulement de la montagne se dégage à 40 %.
	var rocks := 0
	for id in main.props.items:
		if main.props.key_of(id).begins_with("g:z:"):
			rocks += 1
	_check(rocks > 30, "montagne fermée par un éboulement (%d rochers)" % rocks)
	Game.add_stat("clean_waste", 80)
	Game.add_stat("clean_water", 200)
	_check(Game.has_flag("zone_mountain"), "montagne accessible à %d %%" % Vitality.percent("prairie"))

	# Sauvegarde / rechargement
	Game.save_game()
	var edits_before: int = (Game.edits["prairie"] as Dictionary).size()
	Game.edits = {}
	Game.load_game()
	_check((Game.edits["prairie"] as Dictionary).size() == edits_before, "édits rechargés (%d)" % edits_before)
	main.load_island("prairie")
	_check(main.props.any_near(tree_spot, 0.5, true), "arbre persistant après rechargement")
	var cut_back := false
	for id in main.props.items:
		if main.props.items[id]["key"] == cut_key:
			cut_back = true
	_check(not cut_back, "arbre coupé toujours absent après rechargement")
	var x0 := sp.x - 3
	_check(w.get_block(x0, w.top_solid_y(x0, sp.y - 4), sp.y - 4) == Blocks.PLANK, "planche persistante")

	# Voyage
	Game.residents["sylvain"] = {"island": "prairie"}
	Game.residents["rose"] = {"island": "prairie"}
	Game.residents["marin"] = {"island": "prairie"}
	# Le mystère de la plage, par petites touches.
	auto_close = true
	var had_doubt := Game.has_flag("mystery_doute")
	_check(had_doubt or main.mystery.resident_doubt(), "un habitant doute des vieilles caisses (jour %d)" % Game.day)
	var has_crate := false
	for id in main.props.items:
		if main.props.key_of(id) == "g:oldcrate":
			has_crate = true
	_check(has_crate, "une vieille caisse sur la plage")
	await main.mystery.open_crate()
	_check(Game.has_flag("mystery_carte"), "la caisse contient une carte ancienne")
	await main.mystery.examine_tools()
	_check(Game.has_flag("mystery_carnet"), "un vieux carnet parmi les outils rouillés")
	Game.day += 1
	await main.mystery.on_morning()
	_check(Game.has_flag("mystery_fin"), "le lendemain, une pensée pour cette personne")
	auto_close = false

	# La météo change le monde : flaques, traces dans la neige, animaux cachés.
	var wfx: WeatherFX = main.weather_fx
	Game.time = 10.0
	Game.weather = "rain"
	for i in 5:
		wfx._add_puddle()
	_check(wfx._puddles.size() > 0, "pluie : des flaques se forment (%d)" % wfx._puddles.size())
	Game.weather = "clear"
	var wet_n := wfx._puddles.size()
	wfx._dry_one()
	_check(wfx._puddles.size() == wet_n - 1, "après la pluie, elles sèchent")
	Game.weather = "snow"
	main.player.stepped.emit(main.player.global_position, Blocks.GRASS, 0.0)
	_check(wfx._prints.size() == 1, "neige : des traces de pas")
	Game.weather = "storm"
	await _wait(2)
	_check(not main.wildlife.visible, "orage : les animaux se cachent")
	Game.weather = "clear"
	await _wait(2)
	_check(main.wildlife.visible, "le beau temps revient : les animaux aussi")
	# Le cerf des brumes : dans les bois, un jour de brouillard.
	Game.weather = "fog"
	var wood := Vector3.ZERO
	for id in main.props.items:
		if Props.is_tree(main.props.kind_of(id)) and main.props.key_of(id).begins_with("g:"):
			var tp: Vector3 = main.props.items[id]["pos"]
			if main.props.any_near(tp, 8.0, true) and tp.distance_to(Vector3(IslandGenerator.CENTER, tp.y, IslandGenerator.CENTER)) < 130.0:
				wood = tp
				break
	var deer_ok := false
	for attempt in 12:
		main.player.teleport(wood + Vector3(1.5, 1.0, 0))
		Game.flags.erase("fogdeer_day_%d" % Game.day)
		await _wait(2)
		if wfx._deer != null:
			deer_ok = true
			break
		main.rig.yaw += 0.6
	_check(deer_ok, "brouillard : une silhouette apparaît dans les bois")
	if deer_ok:
		var t_deer := Time.get_ticks_msec()
		while not Game.species_seen.has("spirit_deer") and Time.get_ticks_msec() - t_deer < 20000:
			if wfx._deer and is_instance_valid(wfx._deer):
				main.player.global_position = wfx._deer.global_position + Vector3(4.0, 0.5, 0)
			await _wait(3)
		_check(Game.species_seen.has("spirit_deer"), "le cerf des brumes, enfin vu (noté dans le carnet)")
	auto_close = true
	await _wait(5)
	auto_close = false
	hud.close_panel()
	Game.weather = "clear"

	# Les îles se découvrent par l'histoire : réparer la vieille barque.
	_check(not Game.is_island_unlocked("corail"), "des habitants ne suffisent plus à découvrir Corail")
	var has_boat := false
	for id in main.props.items:
		if main.props.key_of(id) == "g:boat":
			has_boat = true
	_check(has_boat, "une vieille barque sur la plage")
	var boat_r: Dictionary = Expeditions.next_for("g:boat")
	_check(boat_r.get("id", "") == "boat" and not Expeditions.missing(boat_r).is_empty(), "barque : il manque des matériaux (%s)" % ", ".join(Expeditions.missing(boat_r)))
	for k in boat_r["cost"]:
		Game.add_item(k, int(boat_r["cost"][k]))
	auto_close = true
	var repaired: bool = await main.expeditions.repair(boat_r)
	auto_close = false
	_check(repaired and Game.is_island_unlocked("corail"), "barque réparée : Corail découverte")
	_check(Expeditions.next_for("g:boat").get("id", "") == "hull" and Expeditions.next_for("g:obelisk").is_empty(), "ensuite : la coque, puis le phare")
	_check(not Game.is_island_unlocked("givree"), "Givrée pas encore découverte")
	hud.toggle_panel("map")
	await _wait(2)
	_check(hud._open_panel is MapPanel and (hud._map.find_child("Sub", true, false) as Label).text.contains("%d habitants" % Game.resident_count()), "carte de l'archipel")
	hud.close_panel()
	await main.travel_to("corail")
	_check(Game.current_island == "corail", "voyage Corail")

	# Carnet : le journal de l'île, rempli au fil des découvertes.
	hud.toggle_panel("carnet")
	await _wait(2)
	var carnet: CarnetPanel = hud._open_panel
	for t in CarnetPanel.TABS:
		carnet._select_tab(t[0])
		await _wait(1)
		_check(carnet._grid.get_child_count() > 0, "carnet : onglet %s (%s)" % [t[1], carnet._name.text])
	hud.close_panel()
	var prog := CarnetPanel.progress()
	_check(int(prog["herbarium"][0]) > 0 and Game.has_collected("islands", "corail"), "collections : herbier %d/%d, îles %d/%d" % [prog["herbarium"][0], prog["herbarium"][1], prog["islands"][0], prog["islands"][1]])
	_check(int(prog["memories"][0]) >= 4, "souvenirs : %d/%d" % [prog["memories"][0], prog["memories"][1]])
	_check(Game.species_seen.has("spirit_deer") and int(prog["animals"][1]) == Fauna.SPECIES.size() + 1, "le cerf des brumes dans le bestiaire")

	# Mode admin
	Game.residents = {}
	_check(not Game.is_island_unlocked("braise"), "Braise verrouillée sans admin")
	hud.toggle_admin()
	_check(Game.admin and Game.is_island_unlocked("braise"), "admin : îles débloquées")
	_check(Game.available_blocks().size() == Blocks.BUILD_PALETTE.size(), "admin : tous les blocs")
	_check(Crafting.can_craft(_recipe("s_house_n")), "admin : fabrication gratuite")
	main.toggle_fly()
	_check(main.player.flying, "admin : vol activé")
	while hud.dialog_open():
		hud.advance_dialog()
	var y0: float = main.player.global_position.y
	Input.action_press("jump")
	await _wait(30)
	Input.action_release("jump")
	_check(main.player.global_position.y > y0 + 1.0, "admin : on monte en volant")
	Game.admin_all_residents()
	_check(Game.resident_count() == ResidentDB.ALL.size(), "admin : tous les habitants")
	hud.toggle_admin()
	_check(not main.player.flying, "vol coupé en quittant l'admin")
	await main.return_to_title()
	_check(main.in_title and main.title.visible, "retour au menu principal")

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


func _recipe(id: String) -> Dictionary:
	for r in Crafting.RECIPES:
		if r["id"] == id:
			return r
	return {}


func _find_all(w: VoxelWorld, id: int, n: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for z in VoxelWorld.SZ:
		for x in VoxelWorld.SX:
			for y in range(IslandGenerator.SEA, IslandGenerator.SEA + 30):
				if w.get_block(x, y, z) == id:
					out.append(Vector3i(x, y, z))
					if out.size() >= n:
						return out
	return out


func _aim(p: Vector3i, n: Vector3i) -> void:
	main.tools.cooldown = 0.0
	main.aim.target = {"hit": true, "pos": p, "normal": n, "block": main.world.get_blockv(p)}


## Arbres plantés « pour de faux » (entrées de sauvegarde) pour faire monter
## la vitalité sans tout planter à la main.
func _fake_trees(n: int) -> void:
	var list: Array = Game.props_added.get_or_add("prairie", [])
	for i in n:
		list.append({"kind": "town_tree", "x": 20.0 + i, "y": 0.0, "z": 20.0, "rot": 0.0, "scale": 1.0, "key": "p:test:%d" % i})
	Game.stats_changed.emit()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  OK   ", label)
	else:
		fails += 1
		print("  FAIL ", label)


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame
