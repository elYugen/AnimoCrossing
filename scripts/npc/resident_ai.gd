class_name ResidentAI
extends Node
## Routine des habitants, revue une fois par seconde :
##   - la nuit : chacun rentre chez soi (ou se réchauffe près d'un feu) ;
##   - la météo : sous la pluie ou l'orage on rentre, sous la neige on se
##     regroupe près du feu... sauf ceux qui adorent ce temps-là
##     (ResidentDB.WEATHER_LOVERS) : ils sortent exprès et le disent ;
##   - le matin : on ressort ;
##   - en journée : discuter avec un voisin, aller à son lieu préféré,
##     s'asseoir à deux sur un banc, se retrouver à midi, et autour du feu
##     le soir (les conversations elles-mêmes sont dans Moments) ;
##   - les habitants vont travailler sur les chantiers (assign_workers).

## Lieu préféré selon l'environnement de l'habitant.
const FAVORITE := {"forest": ["nature"], "garden": ["flowers", "garden", "nature"], "marine": ["beach"], "mountain": ["nature", "mountain"], "village": ["plaza", "work", "bench"]}
## Objets de l'île qui servent de lieux de vie.
const PLACE_TAGS := {"campfire": "fire", "campfire_old": "fire", "bench": "bench", "fountain": "plaza",
	"stall": "plaza", "lantern": "plaza", "garden": "garden", "planter": "garden", "workbench": "work", "cart": "work"}
## Ce qu'on fait sur place, selon le lieu.
const PLACE_ACT := {"bench": "sit", "fire": "sit", "garden": "pickup", "work": "pickup", "plaza": "idle", "flowers": "idle"}
## Où va celui qui aime le temps qu'il fait, et ce qu'il y fait.
const WEATHER_SPOT := {"rain": ["flowers", "garden", "nature"], "storm": ["beach"], "snow": ["open"], "fog": ["beach", "nature"]}

var main: Main
var timer := 0.0
var _assign_timer := 0.0


func tick(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = 1.0
	var rng := main.rng
	var hour := Game.time
	var weather := Game.weather
	var night := main.sky.is_night()
	var wet := main.sky.is_wet()
	var spots := places()
	var crs := main.residents.all()
	for c in crs:
		var id: String = c.data["id"]
		var door := main.residents.home_door(id)
		var lover := not night and ResidentDB.loves_weather(id, weather)
		# Nuit, pluie ou orage : chacun rentre chez soi (ou se réchauffe près
		# d'un feu)... sauf ceux qui aiment ce temps-là.
		if night or (wet and not lover):
			if night or door != Vector3.INF:
				if c.site_id != "":
					c.release()
				if c.state == Resident.State.HOME or (c.state == Resident.State.GO and c.activity == "home"):
					continue
				if door != Vector3.INF:
					c.go(door, "home", 0.0)
					continue
			# Sans maison : sous un abri s'il pleut, sinon près d'un feu.
			var fire := nearest_place(spots, c.global_position, ["shelter", "fire"] if wet else ["fire"])
			if not fire.is_empty() and c.is_free() and c.site_id == "":
				var a := rng.randf() * TAU
				if fire["tag"] == "shelter":
					c.go(fire["pos"] + Vector3(cos(a), 0, sin(a)) * 0.6, "idle", 30.0)
				else:
					c.go(fire["pos"] + Vector3(cos(a), 0, sin(a)) * 1.8, "sit", 30.0, fire["pos"])
			if night or door != Vector3.INF or not fire.is_empty():
				continue
		# Le matin (ou quand le temps qu'il aime arrive), on sort de chez soi.
		if c.state == Resident.State.HOME:
			if door != Vector3.INF and (rng.randf() < 0.35 or lover):
				c.leave_home(door)
			elif door == Vector3.INF:
				c.leave_home(c.global_position)
			continue
		# Une tâche confiée par le joueur passe avant le reste.
		if not c.job.is_empty():
			if c.is_free() and c.site_id == "":
				main.jobs.step(c)
			continue
		if not c.is_free() or c.idle_time < rng.randf_range(5.0, 12.0):
			continue
		# Il adore ce temps : il en profite, et le dit.
		if lover and rng.randf() < 0.6:
			var ws := activity_spot(spots, c, WEATHER_SPOT[weather])
			c.go(ws["pos"], ws["act"], rng.randf_range(12.0, 25.0), ws.get("face", Vector3.INF))
			if rng.randf() < 0.5:
				_say_cue(c, "meteo_" + weather, rng.randf_range(2.0, 6.0))
			continue
		# Journée : discuter avec un voisin, aller à son lieu préféré, à la place...
		if rng.randf() < 0.25:
			var other := _free_neighbor(crs, c, 25.0)
			if other:
				_chat(c, other)
				continue
		var hab: String = c.data.get("habitat", "village")
		var wanted: Array = FAVORITE.get(hab, ["plaza"])
		if weather == "snow":
			wanted = ["fire", "plaza"]  # il fait froid : on se réchauffe ensemble
		elif hour >= 18.0:
			wanted = ["fire", "bench", "plaza"]  # le soir : autour du feu
		elif hour >= 12.0 and hour < 14.0:
			wanted = ["plaza", "bench", "fire"]  # midi : on se retrouve
		elif main.life.tier >= 3 and rng.randf() < 0.4:
			wanted = ["bench", "plaza", "garden", "flowers"] + wanted  # l'île vit : on profite des installations
		var spot := activity_spot(spots, c, wanted)
		if spot.is_empty():
			continue
		var dur := rng.randf_range(8.0, 20.0)
		c.go(spot["pos"], spot["act"], dur, spot.get("face", Vector3.INF))
		# Sur un banc, on aime avoir de la compagnie.
		if spot.get("tag", "") == "bench" and rng.randf() < 0.6:
			var mate := _free_neighbor(crs, c, 30.0)
			if mate:
				var center: Vector3 = spot["face"]
				var rel: Vector3 = spot["pos"] - center
				mate.go(center + rel.rotated(Vector3.UP, 1.0), "sit", dur + 4.0, center)


func _free_neighbor(crs: Array[Resident], c: Resident, radius: float) -> Resident:
	for o in crs:
		if o != c and o.is_free() and o.site_id == "" and o.global_position.distance_to(c.global_position) < radius:
			return o
	return null


## Deux voisins se rejoignent à mi-chemin pour bavarder.
func _chat(a: Resident, b: Resident) -> void:
	var mid := (a.global_position + b.global_position) * 0.5
	var off := (a.global_position - b.global_position).normalized() * 0.8
	a.go(mid + off, "chat", 5.0, mid)
	b.go(mid - off, "chat", 5.0, mid)
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(b):
			b.chatter())


## Une réplique de residents.dialogue dans une bulle, après `delay` secondes.
func _say_cue(c: Resident, cue: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var lines := await Dialogues.texts(Dialogues.RESIDENTS, cue)
	if is_instance_valid(c) and c.visible and not lines.is_empty():
		c.say(Moments.fill(lines[0]), 3.5)


## Lieux d'intérêt de l'île : [{"pos", "tag"}] (feu, banc, place, jardin,
## atelier, parterres fleuris où volent les papillons...).
func places() -> Array:
	var props := main.props
	var out := []
	for id in props.items:
		var k := props.kind_of(id)
		if PLACE_TAGS.has(k):
			out.append({"pos": props.items[id]["pos"], "tag": PLACE_TAGS[k]})
		# Abris contre la pluie : étals, tentes posées par le joueur.
		if k == "stall" or (k == "tent" and props.key_of(id).begins_with("p:")):
			out.append({"pos": props.items[id]["pos"], "tag": "shelter"})
	for p in main.wildlife.butterfly_spots:
		out.append({"pos": p, "tag": "flowers"})
	return out


func nearest_place(list: Array, from: Vector3, tags: Array) -> Dictionary:
	var best := {}
	var best_d := INF
	for p in list:
		if not p["tag"] in tags:
			continue
		var d := from.distance_to(p["pos"])
		if d < best_d:
			best_d = d
			best = p
	return best


## Endroit où faire une activité : lieux posés par le joueur, nature, plage,
## grand air. Renvoie {"pos", "act", "face", "tag"}.
func activity_spot(list: Array, c: Resident, tags: Array) -> Dictionary:
	var rng := main.rng
	var props := main.props
	for tag in tags:
		match tag:
			"beach":
				var beach := main.residents.beach_spots
				if not beach.is_empty():
					var b: Vector3 = beach.pick_random()
					return {"pos": b, "act": "idle", "face": b + Vector3(0, 0, 5), "tag": tag}
			"nature":
				var trees := []
				for id in props.items:
					if Props.is_tree(props.kind_of(id)) and (props.items[id]["pos"] as Vector3).distance_to(c.global_position) < 40.0:
						trees.append(props.items[id]["pos"])
				if not trees.is_empty():
					var t: Vector3 = trees.pick_random()
					return {"pos": t + Vector3(1.6, 0, 1.2), "act": "pickup" if rng.randf() < 0.5 else "idle", "face": t, "tag": tag}
			"open":
				# Dans la neige : on danse un peu, pas loin.
				var a1 := rng.randf() * TAU
				var p1 := main.residents.find_spot(c.global_position + Vector3(cos(a1), 0, sin(a1)) * 6.0, 4.0)
				return {"pos": p1, "act": "dance", "tag": tag}
			"mountain":
				pass
			_:
				var cands := []
				for p in list:
					if p["tag"] == tag:
						cands.append(p)
				if not cands.is_empty():
					var p: Dictionary = cands.pick_random()
					var a := rng.randf() * TAU
					var dist := 0.9 if tag == "bench" else 2.0
					return {"pos": (p["pos"] as Vector3) + Vector3(cos(a), 0, sin(a)) * dist, "act": PLACE_ACT.get(tag, "idle"), "face": p["pos"], "tag": tag}
	# Sinon une petite balade.
	var a2 := rng.randf() * TAU
	return {"pos": c.global_position + Vector3(cos(a2), 0, sin(a2)) * rng.randf_range(4.0, 10.0), "act": "idle"}


## Les habitants vont aux chantiers (deux fois par seconde), de jour
## seulement et pas sous l'orage ; au plus Worksites.MAX_WORKERS par chantier.
## Ceux que le joueur a envoyés sur un chantier y vont en priorité (quoi qu'ils
## fassent) ; un chantier avec une équipe désignée n'accueille qu'elle, les
## autres prennent les habitants libres.
func assign_workers(delta: float) -> void:
	var worksites := main.worksites
	var sites := worksites.all()
	if sites.is_empty():
		return
	_assign_timer -= delta
	if _assign_timer > 0.0 or main.sky.is_night() or Game.weather == "storm":
		return
	_assign_timer = 0.5
	var workers := {}
	var ordered := {}  # habitant -> chantier où le joueur l'a envoyé
	for site in sites:
		for rid in Construction.crew_of(site):
			ordered[rid] = site
	for c in main.residents.all():
		if c.site_id != "":
			var cur := worksites.get_site(c.site_id)
			var mine: Dictionary = ordered.get(c.data["id"], {})
			if cur.is_empty() or (not mine.is_empty() and mine["id"] != cur["id"]) \
					or (mine.is_empty() and not Construction.crew_of(cur).is_empty()):
				c.release()
			else:
				workers[c.site_id] = int(workers.get(c.site_id, 0)) + 1
	# 1) Les ordres du joueur.
	for c in main.residents.all():
		var site: Dictionary = ordered.get(c.data["id"], {})
		if site.is_empty() or c.site_id == site["id"]:
			continue
		if c.state == Resident.State.TALK or c.state == Resident.State.HOME:
			continue
		var i := int(workers.get(site["id"], 0))
		workers[site["id"]] = i + 1
		c.assign(site["id"], worksites.slot(site, i), worksites.center_of(site))
	# 2) Les habitants libres, sur les chantiers sans équipe désignée.
	for c in main.residents.all():
		if c.site_id != "" or not c.is_free() or ordered.has(c.data["id"]):
			continue
		var best := {}
		var best_d := INF
		for site in sites:
			if int(workers.get(site["id"], 0)) >= Worksites.MAX_WORKERS or not Construction.crew_of(site).is_empty():
				continue
			var d := c.global_position.distance_to(worksites.center_of(site))
			if d < best_d:
				best_d = d
				best = site
		if best.is_empty():
			continue
		var i := int(workers.get(best["id"], 0))
		workers[best["id"]] = i + 1
		c.assign(best["id"], worksites.slot(best, i), worksites.center_of(best))
