class_name Moments
extends Node
## Petites scènes de la vie de l'île, sans quête ni récompense :
##   - deux habitants assis sur un banc ou autour du feu discutent (en
##     bulles, répliques de residents.dialogue) ;
##   - ceux qui voient passer le joueur lui font coucou ;
##   - le lendemain d'une construction, quelqu'un vient la découvrir
##     (« Oh... c'était là hier ? ») et s'en sert : la récompense, c'est de
##     voir l'île utiliser ce qu'on a construit.

## Scènes possibles selon le lieu (séquences de residents.dialogue, avec
## A / B / C pour le premier, deuxième, troisième habitant présent).
const SCENES := {
	"bench": ["banc_village", "banc_vue", "banc_souvenir", "banc_meteo"],
	"fire": ["feu_histoire", "feu_etoiles", "feu_cuisine"],
}
const LINE_TIME := 2.9
## Pas deux coucous du même habitant en moins de 90 s.
const WAVE_COOLDOWN := 90000
## Réplique de découverte selon la construction (sinon « decouvre »).
const DISCOVER_CUE := {"fountain": "decouvre_fontaine", "garden": "decouvre_potager", "planter": "decouvre_potager",
	"bench": "decouvre_banc", "campfire": "decouvre_feu", "lantern": "decouvre_lanterne", "stall": "decouvre_etal",
	"cart": "decouvre_etal", "fence_low": "decouvre_cloture"}
## Qui vient de préférence découvrir quoi (selon son environnement préféré).
const DISCOVER_HABITAT := {"garden": "garden", "planter": "garden", "stall": "village", "cart": "village",
	"campfire": "village", "fountain": "village", "bench": "village"}

var main: Main
var _timer := 2.0
var _in_scene := {}  # habitant -> true pendant une scène
var _waved := {}  # habitant -> heure du dernier coucou (ms)
var _discover_wait := 5.0


## Une construction vient d'être posée : les habitants la découvriront
## demain.
static func add_novelty(key: String, kind: String) -> void:
	if key == "":
		return
	(Game.novelties.get_or_add(Game.current_island, []) as Array).append({"key": key, "kind": kind, "day": Game.day})


## Remplace {joueur} par le nom du joueur.
static func fill(text: String) -> String:
	var who := Game.player_name if Game.player_name != "" else "la personne de l'épave"
	return text.replace("{joueur}", who)


func tick(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.5
	if main.busy or main.cinematic or main.interior != null:
		return
	var pp := main.player.global_position
	var crs := main.residents.all()
	_waves(crs, pp)
	_discover_wait -= 1.5
	if _discover_wait <= 0.0:
		_discover_wait = 20.0
		discover_next(crs)
	# Plus l'île est vivante, plus ces petites scènes sont fréquentes.
	if not _in_scene.is_empty() or main.rng.randf() > 0.15 + main.life.tier * 0.08:
		return
	for p in main.npc_ai.places():
		var tag: String = p["tag"]
		if not SCENES.has(tag) or (p["pos"] as Vector3).distance_to(pp) > 30.0:
			continue
		var group: Array[Resident] = []
		for c in crs:
			if c.state == Resident.State.ACT and c.activity == "sit" \
					and c.global_position.distance_to(p["pos"]) < 2.8:
				group.append(c)
		if group.size() >= 2:
			play_scene(group.slice(0, 3), (SCENES[tag] as Array).pick_random())
			return


## Joue une conversation : chaque réplique s'affiche au-dessus de celui qui
## la dit ; ils restent assis jusqu'à la fin.
func play_scene(group: Array[Resident], cue: String) -> void:
	var lines := await Dialogues.fetch(Dialogues.RESIDENTS, cue)
	if lines.is_empty():
		return
	for c in group:
		_in_scene[c.data["id"]] = true
		c.stay(lines.size() * LINE_TIME + 2.0)
	for l in lines:
		var i := maxi(0, "ABC".find(str(l["speaker"])))
		if i >= group.size() or not is_instance_valid(group[i]) or group[i].activity != "sit":
			break
		group[i].say(fill(l["text"]), LINE_TIME - 0.2)
		await get_tree().create_timer(LINE_TIME).timeout
	for c in group:
		if is_instance_valid(c):
			_in_scene.erase(c.data["id"])


## Le lendemain d'une construction : un habitant (deux pour un banc) vient
## la découvrir, la commente et s'en sert. Renvoie true si quelqu'un y va.
func discover_next(crs: Array[Resident]) -> bool:
	if main.sky.is_night() or main.sky.is_wet():
		return false
	var list: Array = Game.novelties.get(Game.current_island, [])
	while not list.is_empty():
		var n: Dictionary = list[0]
		if int(n["day"]) >= Game.day:
			return false  # construit aujourd'hui : on le découvrira demain
		list.pop_front()
		var id := _prop_id(n["key"])
		if id < 0:
			continue  # déjà retiré
		var who := _visitors(crs, n["kind"], 2 if n["kind"] == "bench" else 1)
		if who.is_empty():
			list.push_front(n)
			return false
		var center: Vector3 = main.props.items[id]["pos"]
		var act := "sit" if n["kind"] in ["bench", "campfire"] else "idle"
		var cue: String = DISCOVER_CUE.get(n["kind"], "decouvre")
		for i in who.size():
			var a := main.rng.randf() * TAU + i * 1.0
			var dist := 0.9 if n["kind"] == "bench" else 2.2
			var spot := center + Vector3(cos(a), 0, sin(a)) * dist
			var c: Resident = who[i]
			c.go(spot, act, 18.0, center, (func(): _say_discovery(c, cue)) if i == 0 else Callable())
		return true
	return false


func _prop_id(key: String) -> int:
	for id in main.props.items:
		if main.props.key_of(id) == key:
			return id
	return -1


## Habitants libres qui iront voir : d'abord ceux à qui ça plaira le plus.
func _visitors(crs: Array[Resident], kind: String, n: int) -> Array[Resident]:
	var free: Array[Resident] = []
	for c in crs:
		if c.is_free() and c.site_id == "" and c.job.is_empty() and c.visible:
			free.append(c)
	var hab: String = DISCOVER_HABITAT.get(kind, "")
	free.sort_custom(func(a: Resident, b: Resident) -> bool:
		return a.data.get("habitat", "") == hab and b.data.get("habitat", "") != hab)
	return free.slice(0, n)


func _say_discovery(c: Resident, cue: String) -> void:
	var lines := await Dialogues.texts(Dialogues.RESIDENTS, cue)
	if is_instance_valid(c) and not lines.is_empty():
		c.say(fill(lines[0]), 3.5)


## Les habitants qui voient passer le joueur (pas trop près : sinon on
## leur parle) lui font coucou, de temps en temps.
func _waves(crs: Array[Resident], pp: Vector3) -> void:
	var now := Time.get_ticks_msec()
	for c in crs:
		var id: String = c.data["id"]
		if not c.visible or _in_scene.has(id) or c.site_id != "" or c.state == Resident.State.TALK:
			continue
		var d := c.global_position.distance_to(pp)
		if d < 3.0 or d > 7.0 or now - int(_waved.get(id, -WAVE_COOLDOWN)) < WAVE_COOLDOWN:
			continue
		_waved[id] = now
		_wave(c, pp)


func _wave(c: Resident, pp: Vector3) -> void:
	var lines := await Dialogues.texts(Dialogues.RESIDENTS, "coucou")
	if is_instance_valid(c) and not lines.is_empty():
		c.wave(pp, fill(lines[0]))
