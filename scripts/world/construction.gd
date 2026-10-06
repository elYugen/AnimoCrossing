class_name Construction
extends Node
## Poser des constructions (petites : tout de suite ; grosses : un plan que les
## habitants viennent bâtir), démolir, et ce qui se passe quand un chantier
## se termine. Gère aussi l'éboulement qui ferme la montagne de la Prairie.

var main: Main


## La construction tient-elle ici ? Sol assez plat, hors de l'eau, sans
## chevaucher d'autre objet ni le joueur.
func structure_fits(kind: String, pos: Vector3, rot: float) -> bool:
	var world := main.world
	var props := main.props
	var ab := Props.local_aabb(kind)
	var s := float(Props.KINDS[kind]["scale"])
	var half := Vector2(ab.size.x, ab.size.z) * s * 0.5
	var basis := Basis(Vector3.UP, rot)
	var base_y := floori(pos.y) - 1
	for fx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for fz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var q := pos + basis * Vector3(fx * half.x * 0.9, 0, fz * half.y * 0.9)
			var top := world.top_solid_y(floori(q.x), floori(q.z))
			if top <= IslandGenerator.SEA or absi(top - base_y) > 1:
				return false
	var radius := maxf(half.x, half.y)
	for id in props.items:
		var q: Vector3 = props.items[id]["pos"]
		var r2 := maxf(0.6, minf(2.5, Props.local_aabb(props.kind_of(id)).size.x * float(Props.KINDS[props.kind_of(id)]["scale"]) * 0.4))
		if Vector2(q.x - pos.x, q.z - pos.z).length() < radius * 0.8 + r2 and absf(q.y - pos.y) < 4.0:
			return false
	var worksites := main.worksites
	for site in worksites.all():
		var c := worksites.center_of(site)
		if Vector2(c.x - pos.x, c.z - pos.z).length() < radius * 0.8 + worksites.radius_of(site):
			return false
	var pp := main.player.global_position
	if Vector2(pp.x - pos.x, pp.z - pos.z).length() < radius * 0.7 + 0.4:
		return false
	return true


## Pose la construction sélectionnée à l'emplacement de l'aperçu fantôme.
func place_structure() -> bool:
	var aim := main.aim
	var kind := main.structure
	if not Game.admin and Game.structure_count(kind) <= 0:
		main.deny("Il n'en reste plus : fabrique-en à la table d'artisan.")
		return false
	if not aim.ghost_shown():
		main.deny("Pas de place ici : terrain trop pentu ou encombré.")
		return false
	var world := main.world
	var pos := aim.ghost_pos
	# On dégage la petite végétation sous l'emprise.
	var ab := Props.local_aabb(kind)
	var s := float(Props.KINDS[kind]["scale"])
	var half := Vector2(ab.size.x, ab.size.z) * s * 0.5
	var changed := false
	for dx in range(-ceili(half.x), ceili(half.x) + 1):
		for dz in range(-ceili(half.y), ceili(half.y) + 1):
			var q := Vector3i(floori(pos.x) + dx, floori(pos.y), floori(pos.z) + dz)
			if Blocks.is_deco(world.get_blockv(q)):
				world.set_block(q, Blocks.AIR)
				changed = true
	if changed:
		world.flush()
	if not Game.admin:
		Game.add_structure(kind, -1)
	if Props.is_site(kind):
		# Grosse construction : on pose le plan, les habitants viendront bâtir.
		main.worksites.add_build(kind, pos, aim.place_rot)
		main.tips.tip("chantier")
		Audio.play("place", -4.0, 0.05, 0.7)
		Game.notify_action("place")
		if Vitality.residents(Game.current_island) == 0:
			main.story.think("chantier_seul")
		Game.save_game()
	else:
		var new_id := main.props.add_persistent(kind, pos, aim.place_rot, 1.0, true)
		Moments.add_novelty(main.props.key_of(new_id), kind)
		main.burst(pos + Vector3(0, 1.0, 0), Color("ffd84a"), 16)
		Audio.play("place_wood", -2.0, 0.05, 0.8)
		Game.notify_action("place")
		# Un meuble posé dehors est de la décoration : il ne compte pas
		# comme une construction pour la vitalité.
		if not Props.KINDS[kind].has("furniture"):
			count_altitude(floori(pos.y))
			Game.add_stat("build")
			Game.add_stat("build_" + kind)
			Game.notify_action("build")
	main.hud.set_structure(kind)
	if Game.structure_count(kind) <= 0 and not Game.admin:
		main.select_block(main.block)
	return true


## Ouvre un chantier de démolition (maison posée, ruine entière...).
func demolish(id: int) -> void:
	main.worksites.add_demolish(demolish_group(id))
	Audio.play("break_stone", -6.0, 0.05, 0.8)
	if Vitality.residents(Game.current_island) == 0:
		main.story.think("chantier_seul")
	Game.save_game()


## Une ruine se démolit en entier (tous ses murs et piliers).
func demolish_group(id: int) -> Array:
	var props := main.props
	var key := props.key_of(id)
	if not key.begins_with("g:r:") and not key.begins_with("g:p:"):
		return [id]
	var c: Vector3 = props.items[id]["pos"]
	var out := []
	for other in props.items:
		var k := props.key_of(other)
		if not (k.begins_with("g:r:") or k.begins_with("g:p:")) or main.worksites.is_targeted(k):
			continue
		var q: Vector3 = props.items[other]["pos"]
		if Vector2(q.x - c.x, q.z - c.z).length() < 6.5:
			out.append(other)
	return out


# --- Équipes : le joueur choisit qui travaille où ------------------------------

## « Construction : Petite maison », « Démolition ».
func site_label(site: Dictionary) -> String:
	if site["type"] == "build":
		return "Construction : %s" % Crafting.structure_name(site["kind"])
	return "Démolition"


## Habitants désignés par le joueur pour ce chantier (vide : les habitants
## libres s'en chargent d'eux-mêmes).
static func crew_of(site: Dictionary) -> Array:
	return site.get_or_add("crew", [])


## Le chantier où le joueur a envoyé cet habitant ({} : aucun).
func ordered_site(resident_id: String) -> Dictionary:
	for s in main.worksites.all():
		if resident_id in crew_of(s):
			return s
	return {}


## Envoie un habitant sur un chantier (il quitte l'équipe d'un autre).
## Renvoie false si l'équipe est déjà complète.
func order(resident_id: String, site: Dictionary) -> bool:
	var crew := crew_of(site)
	if resident_id in crew:
		return true
	if crew.size() >= Worksites.MAX_WORKERS:
		return false
	for s in main.worksites.all():
		crew_of(s).erase(resident_id)
	crew.append(resident_id)
	var r := main.residents.find(resident_id)
	if r:
		main.jobs.stop(r)  # le chantier passe avant le reste
	if r and r.site_id != "" and r.site_id != site["id"]:
		r.release()
	Game.save_game()
	return true


func dismiss(resident_id: String, site: Dictionary) -> void:
	crew_of(site).erase(resident_id)
	var r := main.residents.find(resident_id)
	if r and r.site_id == site["id"]:
		r.release()
	Game.save_game()


## Menu du chantier (E devant le chantier) : cocher les habitants qui y
## travaillent. Le menu se rouvre après chaque choix.
func open_crew_menu(site_id: String) -> void:
	var site := main.worksites.get_site(site_id)
	if site.is_empty():
		return
	var crew := crew_of(site)
	var options := [{"id": "", "label": "Terminé"}]
	for id in Game.residents:
		if (Game.residents[id] as Dictionary).get("island", "") != Game.current_island:
			continue
		var rname: String = ResidentDB.get_resident(id)["name"]
		var status := "disponible"
		if id in crew:
			status = "✔ sur ce chantier"
		elif not ordered_site(id).is_empty():
			status = "sur un autre chantier"
		options.append({"id": id, "label": "%s — %s" % [rname, status]})
	if options.size() == 1:
		main.hud.toast("Personne n'habite encore sur l'île pour construire.", UIStyle.TEXT_SOFT)
		return
	options.append({"id": "*auto", "label": "Laisser faire les habitants libres"})
	var title := "%s (%d/%d)" % [site_label(site), crew.size(), Worksites.MAX_WORKERS]
	main.hud.show_choice(title, options, func(pick: String):
		if pick == "":
			return
		if pick == "*auto":
			for id in crew.duplicate():
				dismiss(id, site)
			main.hud.toast("Les habitants libres s'en occupent.", UIStyle.GREEN_DARK)
			return
		var rname: String = ResidentDB.get_resident(pick)["name"]
		if pick in crew:
			dismiss(pick, site)
		elif order(pick, site):
			main.hud.toast("%s part sur le chantier !" % rname, UIStyle.GREEN_DARK)
			Audio.play("confirm", -6.0)
		else:
			main.hud.toast("L'équipe est complète (%d habitants)." % Worksites.MAX_WORKERS, UIStyle.TEXT_SOFT)
			Audio.play("error", -6.0)
		open_crew_menu(site_id))


## Le travail avance avec chaque habitant à l'ouvrage.
func advance_work(delta: float) -> void:
	var worksites := main.worksites
	var busy := {}
	for c in main.residents.all():
		if c.is_working():
			busy[c.site_id] = true
			worksites.work(c.site_id, delta)
	for site in worksites.all():
		worksites.set_busy(site["id"], busy.has(site["id"]))


func on_site_finished(site: Dictionary) -> void:
	var props := main.props
	var hud := main.hud
	for c in main.residents.all():
		if c.site_id == site["id"]:
			c.release()
	var pos := main.worksites.center_of(site)
	if site["type"] == "build":
		var kind: String = site["kind"]
		main.burst(pos + Vector3(0, 2.0, 0), Color("ffd84a"), 30)
		Audio.play("jingle_common", -6.0, 0.0)
		count_altitude(floori(pos.y))
		Game.add_stat("build")
		Game.add_stat("build_" + kind)
		Game.notify_action("build")
		hud.toast("%s : construction terminée !" % Crafting.structure_name(kind), UIStyle.GREEN_DARK)
		for id in props.items:
			if props.kind_of(id) == kind and (props.items[id]["pos"] as Vector3).distance_to(pos) < 0.5:
				Moments.add_novelty(props.key_of(id), kind)
				if Props.is_house(kind):
					main.houses.auto_home(props.key_of(id), pos)
					main.tips.tip("maison")
					main.memories.record("house")
	else:
		for key in site["targets"]:
			for id in props.items.keys():
				if props.key_of(id) != key:
					continue
				var kind := props.kind_of(id)
				var center := props.bounds(id).get_center()
				main.burst(center, Color("c9b99f"), 16)
				if key.begins_with("p:") and Props.is_structure(kind):
					Game.add_structure(kind)  # la maison démontée peut être reposée ailleurs
					main.gain(Crafting.structure_name(kind), 1, Color("c99d6c"), center)
				if Game.homes.has(key):
					Game.homes.erase(key)
					Game.interiors.erase(key)
				var loot: Dictionary = (Props.KINDS[kind] as Dictionary).get("demolish", {})
				for item in loot:
					Game.add_item(item, int(loot[item]))
					main.gain(Items.name_of(item, int(loot[item])), int(loot[item]), Items.color_of(item), center, item)
				props.remove(id)
		props.resnap_near(pos, 8.0)
		Audio.play("break_stone", -2.0, 0.05, 0.8)
		Game.add_stat("demolish")
		hud.set_block(main.block)
	Game.save_game()


## La montagne de l'Île Prairie est bloquée par un éboulement qui se dégage
## quand l'île devient assez accueillante.
func check_zones() -> void:
	if Game.current_island != "prairie" or Game.has_flag("zone_mountain"):
		return
	if Vitality.percent("prairie") < IslandGenerator.MOUNTAIN_UNLOCK:
		return
	Game.set_flag("zone_mountain")
	var props := main.props
	for id in props.items.keys():
		if props.key_of(id).begins_with("g:z:"):
			main.burst(props.bounds(id).get_center(), Color("a7adb5"), 10)
			props.remove(id)
	Audio.play("break_stone", 0.0, 0.0, 0.7)
	main.hud.show_item_popup("La montagne est accessible !", "L'éboulement s'est dégagé.", false)
	Game.save_game()


## Aménager les hauteurs développe l'habitat « montagne ».
func count_altitude(y: int) -> void:
	if y >= IslandGenerator.SEA + 12:
		Game.add_stat("mountain")
