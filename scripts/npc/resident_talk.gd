class_name ResidentTalk
extends Node
## Discussions avec les habitants : la réplique du jour (selon le moment, la
## météo, les meubles, l'ancienneté), puis offrir un objet ou rendre service.
## Les règles d'amitié sont dans Friendship ; les répliques dans
## dialogue/residents.dialogue.

var main: Main


## Une réplique d'un habitant (fichier residents.dialogue), avec remplacements.
func line(cue: String, repl := {}) -> String:
	var t := await Dialogues.texts(Dialogues.RESIDENTS, cue)
	var out: String = t[0] if not t.is_empty() else "..."
	for k in repl:
		out = out.replace("{%s}" % k, str(repl[k]))
	return Moments.fill(out)


## Toutes les lignes d'une séquence (pour les remarques en plusieurs phrases).
func all_lines(cue: String) -> Array:
	var out := []
	for t in await Dialogues.texts(Dialogues.RESIDENTS, cue):
		out.append(Moments.fill(t))
	return out


func talk(c: Resident) -> void:
	var rng := main.rng
	var hud := main.hud
	var id: String = c.data["id"]
	var d := Friendship.data(id)
	if d.is_empty():
		return
	var lines: Array = []
	var first_today := int(d.get("talk_day", -1)) != Game.day
	# 1) Ce qui a changé pour lui : un déménagement, de nouveaux meubles.
	var react: String = await furniture_reaction(id)
	if first_today and main.mystery.resident_doubt():
		# Le mystère de la plage : une seule fois, un habitant en parle.
		lines.append_array(await all_lines("epave_doute"))
	elif first_today and int(Game.flags.get("tree_grown_day", -10)) >= Game.day - 1 			and int(Game.flags.get("tree_remark_day", -10)) < int(Game.flags["tree_grown_day"]):
		# Un arbre planté par le joueur vient de devenir adulte.
		Game.flags["tree_remark_day"] = Game.flags["tree_grown_day"]
		lines.append(await line("arbre_grandi"))
	elif first_today and _island_hint() != "":
		# Ce qu'il faudrait pour aller plus loin : une simple remarque.
		var hint := _island_hint()
		lines.append_array(await all_lines(hint))
		Game.set_flag("hint_" + hint)
	elif d.get("moved", false):
		d["moved"] = false
		lines.append(await line("demenage") + " " + Friendship.moved_reason(id))
	elif react != "":
		lines.append(react)
	else:
		# 2) Sinon, une réplique selon le moment, la météo, son ancienneté...
		var cue := ""
		if ResidentDB.loves_weather(id, Game.weather) and rng.randf() < 0.7:
			cue = "meteo_" + Game.weather  # il adore ce temps-là
		elif main.sky.is_wet():
			cue = "pluie"
		elif Game.time >= 20.0 or Game.time < 6.0:
			cue = "nuit"
		elif Game.time < 10.0 and first_today:
			cue = "matin"
		elif Friendship.days_here(id) < 3 and rng.randf() < 0.6:
			cue = "nouveau"
		elif Friendship.days_here(id) >= 10 and Friendship.hearts(id) >= 3 and rng.randf() < 0.5:
			cue = "installe"
		elif Game.home_of(id) == "" and rng.randf() < 0.5:
			cue = "sans_maison"
		elif main.life.tier >= 1 and rng.randf() < 0.35:
			cue = "ile_%d" % main.life.tier  # ce qu'il pense de l'île, selon sa vie
		if cue != "":
			lines.append(await line(cue))
		elif Friendship.hearts(id) >= 1 or rng.randf() < 0.5:
			lines.append((c.data["lines"] as Array).pick_random())
		else:
			lines.append(await line("nouveau"))
	# 3) Une fois par jour : l'amitié grandit, et les cœurs débloquent des choses.
	if first_today:
		d["talk_day"] = Game.day
		Friendship.add(id, 3)
		var h := Friendship.hearts(id)
		if h >= 5 and not d.get("best_friend", false):
			d["best_friend"] = true
			lines.append(await line("ami"))
			main.memories.record("friend")
			get_tree().create_timer(0.5).timeout.connect(func():
				hud.show_item_popup("%s est devenu un véritable ami" % c.data["name"], "♥ 5/5", false))
		elif h >= 4 and not d.get("unique_given", false):
			d["unique_given"] = true
			var f: String = Friendship.UNIQUE[Friendship.habitat(id)]
			Game.add_structure("f_" + f)
			Game.collect("furniture", f)
			lines.append(await line("meuble_unique"))
			lines.append("(Tu reçois : %s)" % Interior.label_of(f))
		elif h >= 3 and not d.has("request") and int(d.get("request_day", -1)) != Game.day:
			var item: String = Friendship.REQUESTS.pick_random()
			var n := rng.randi_range(2, 4)
			d["request"] = {"item": item, "n": n}
			d["request_day"] = Game.day
			lines.append(await line("demande", {"n": n, "item": Items.name_of(item, n).to_lower()}))
		elif h >= 2 and rng.randf() < 0.35:
			var gift: String = (Items.RAW + ["beam", "peg", "rope"]).pick_random()
			Game.add_item(gift, 2)
			lines.append(await line("donne"))
			lines.append("(Tu reçois : 2 %s)" % Items.name_of(gift, 2).to_lower())
	Game.talked[id] = true
	Game.save_game()
	var who := "%s   %s" % [c.data["name"], Friendship.hearts_text(id)]
	hud.show_dialog(who, lines, func(): _offer_menu(c))
	Audio.play("talk", -4.0, 0.2, c.voice)
	Game.notify_action("talk")


## Une remarque sur la prochaine île à découvrir ("" : rien à dire).
func _island_hint() -> String:
	if Game.has_flag("unlock_corail") and not Game.has_flag("unlock_givree") and not Game.has_flag("hint_conseil_coque"):
		return "conseil_coque"
	if Game.has_flag("unlock_givree") and not Game.has_flag("unlock_braise") and not Game.has_flag("hint_conseil_phare"):
		return "conseil_phare"
	return ""


## Après la discussion : lui demander un coup de main (chantier, nettoyage,
## plantations), offrir quelque chose, ou partir.
func _offer_menu(c: Resident) -> void:
	var id: String = c.data["id"]
	var opts := [{"id": "", "label": "Au revoir"}]
	var current := main.construction.ordered_site(id)
	for s in main.worksites.all():
		if current.is_empty() or s["id"] != current["id"]:
			opts.append({"id": "site:" + str(s["id"]), "label": "Va aider : %s" % main.construction.site_label(s)})
	for j in ResidentJobs.JOBS:
		if c.job.get("type", "") != j:
			opts.append({"id": "job:" + j, "label": ResidentJobs.JOBS[j]["label"]})
	if not current.is_empty() or not c.job.is_empty():
		opts.append({"id": "rest", "label": "Repose-toi, tu as bien travaillé"})
	for k in Items.ALL:
		if Game.item_count(k) > 0:
			opts.append({"id": k, "label": "Offrir : %s (%d)" % [Items.name_of(k), Game.item_count(k)]})
	if opts.size() == 1:
		return
	main.hud.show_choice("Que veux-tu dire à %s ?" % c.data["name"], opts, func(pick: String):
		if pick == "":
			return
		if pick == "rest":
			if not current.is_empty():
				main.construction.dismiss(id, current)
			main.jobs.stop(c)
			main.hud.show_dialog(c.data["name"], [await line("repos")])
		elif pick.begins_with("job:"):
			if not current.is_empty():
				main.construction.dismiss(id, current)
			main.jobs.give(c, pick.trim_prefix("job:"))
			c.celebrate()
			main.hud.show_dialog(c.data["name"], [await line("tache_ok")])
		elif pick.begins_with("site:"):
			var site := main.worksites.get_site(pick.trim_prefix("site:"))
			if main.construction.order(id, site):
				c.celebrate()
				main.hud.show_dialog(c.data["name"], [await line("chantier_ok")])
			else:
				main.hud.show_dialog(c.data["name"], [await line("chantier_complet")])
		else:
			give(c, pick))


func give(c: Resident, item: String) -> void:
	var id: String = c.data["id"]
	var d := Friendship.data(id)
	var lines: Array = []
	var req: Dictionary = d.get("request", {})
	if not req.is_empty() and req["item"] == item and Game.item_count(item) >= int(req["n"]):
		# Il avait demandé ça : on lui rend service.
		Game.add_item(item, -int(req["n"]))
		d.erase("request")
		Friendship.add(id, 8)
		var rewards := Friendship.LIKES[Friendship.habitat(id)]["furniture"] as Array
		var f: String = rewards.pick_random()
		Game.add_structure("f_" + f)
		Game.collect("furniture", f)
		lines.append(await line("demande_ok"))
		lines.append("(Tu reçois : %s)" % Interior.label_of(f))
	elif int(d.get("gift_day", -1)) == Game.day:
		lines.append(await line("deja_cadeau"))
	else:
		Game.add_item(item, -1)
		d["gift_day"] = Game.day
		var liked := Friendship.likes_item(id, item)
		Friendship.add(id, 6 if liked else 3)
		lines.append(await line("cadeau_aime" if liked else "cadeau"))
	c.celebrate()
	Game.save_game()
	main.hud.show_dialog("%s   %s" % [c.data["name"], Friendship.hearts_text(id)], lines)


## L'habitant remarque les meubles ajoutés chez lui depuis sa dernière visite.
func furniture_reaction(id: String) -> String:
	var key := Game.home_of(id)
	if key == "" or not Game.interiors.has(key):
		return ""
	var d := Friendship.data(id)
	var seen: Array = d.get("seen_furn", [])
	var fresh := ""
	var names: Array = []
	for e in Game.interiors[key]:
		names.append(e["f"])
		if not e["f"] in seen and fresh == "":
			fresh = e["f"]
	d["seen_furn"] = names
	if fresh == "":
		return ""
	var liked := Friendship.likes_furniture(id, fresh)
	Friendship.add(id, 4 if liked else 2)
	return await line("meuble_aime" if liked else "meuble", {"f": Interior.with_article(fresh)})
