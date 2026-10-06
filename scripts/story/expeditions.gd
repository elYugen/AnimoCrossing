class_name Expeditions
extends Node
## Comment on découvre les autres îles, sans quête : des objets de la
## Prairie à remettre en état, quand on a de quoi les réparer et assez
## d'habitants pour aider.
##   la vieille barque  -> Île Corail
##   une coque solide   -> Île Givrée (eaux glacées)
##   le vieux phare     -> Île Braise (le signal permet de s'y repérer)

## Réparations, dans l'ordre. `prop` : clé de l'objet sur la Prairie.
const REPAIRS := [
	{"id": "boat", "prop": "g:boat", "island": "corail", "residents": 2, "cost": {"beam": 4, "rope": 2, "cloth": 2},
		"name": "la vieille barque", "ask": "Réparer la barque ?", "intro": "barque", "done": "barque_ok"},
	{"id": "hull", "prop": "g:boat", "island": "givree", "residents": 5, "cost": {"beam": 6, "cut_stone": 6, "cloth": 3},
		"name": "la coque de la barque", "ask": "Renforcer la coque ?", "intro": "coque", "done": "coque_ok"},
	{"id": "beacon", "prop": "g:obelisk", "island": "braise", "residents": 8, "cost": {"glass": 4, "cut_stone": 8},
		"name": "le vieux phare", "ask": "Rallumer le signal ?", "intro": "phare", "done": "phare_ok"},
]

var main: Main
var _beacon_light: OmniLight3D


static func is_done(r: Dictionary) -> bool:
	return Game.has_flag("unlock_" + str(r["island"]))


## Prochaine réparation à faire sur cet objet ({} : rien, ou pas encore).
static func next_for(prop_key: String) -> Dictionary:
	for r in REPAIRS:
		if is_done(r):
			continue
		return r if r["prop"] == prop_key else {}
	return {}


## Objets à examiner, pour Main.nearest_interactable.
func interactables() -> Array:
	var out := []
	if Game.current_island != "prairie":
		return out
	var props := main.props
	for id in props.items:
		var key := props.key_of(id)
		if key == "g:boat":
			var r := next_for(key)
			var sailed := Game.has_flag("unlock_corail")
			var prompt := "[E] Examiner la barque" if not sailed else ("[E] La barque" if not r.is_empty() else "[E] Prendre la mer")
			out.append({"node": props.items[id]["node"], "prompt": prompt, "action": func(): _boat(r)})
		elif key == "g:obelisk" and not Game.has_flag("unlock_braise"):
			var r2 := next_for(key)
			var act := func(): inspect(r2)
			if r2.is_empty():
				act = func(): main.story.think("phare_eteint")  # pas encore le moment
			out.append({"node": props.items[id]["node"], "prompt": "[E] Examiner la vieille tour", "action": act})
	return out


func _boat(r: Dictionary) -> void:
	if not Game.has_flag("unlock_corail"):
		inspect(r)
		return
	var opts := [{"id": "map", "label": "Prendre la mer (carte de l'archipel)"}]
	if not r.is_empty():
		opts.append({"id": "repair", "label": "%s (%s)" % [r["ask"], cost_text(r)]})
	opts.append({"id": "", "label": "Pas maintenant"})
	main.hud.show_choice("La barque", opts, func(pick: String):
		if pick == "map":
			main.hud.toggle_panel("map")
		elif pick == "repair":
			inspect(r))


## Examiner : la première fois une pensée, puis ce qu'il manque ; si tout y
## est, on propose de réparer.
func inspect(r: Dictionary) -> void:
	if r.is_empty():
		return
	var flag := "seen_" + str(r["id"])
	if not Game.has_flag(flag):
		Game.set_flag(flag)
		await main.story.think(r["intro"])
	var lines := missing(r)
	if not lines.is_empty():
		lines.push_front("Pour réparer %s, il me faudrait :" % r["name"])
		main.hud.show_dialog(Game.player_name if Game.player_name != "" else "Moi", lines)
		return
	main.hud.show_choice(r["ask"], [{"id": "yes", "label": "Oui (%s)" % cost_text(r)}, {"id": "", "label": "Pas maintenant"}], func(pick: String):
		if pick == "yes":
			repair(r))


## Ce qui manque encore (vide : on peut réparer).
static func missing(r: Dictionary) -> Array:
	var out := []
	for k in r["cost"]:
		var have := Game.item_count(k)
		var need := int(r["cost"][k])
		if have < need and not Game.admin:
			out.append("• %s : %d / %d" % [Items.name_of(k, need), have, need])
	var helpers := Game.resident_count()
	if helpers < int(r["residents"]) and not Game.admin:
		out.append("• des bras pour m'aider : %d / %d habitants" % [helpers, int(r["residents"])])
	return out


static func cost_text(r: Dictionary) -> String:
	var parts := []
	for k in r["cost"]:
		parts.append("%d %s" % [int(r["cost"][k]), Items.name_of(k, int(r["cost"][k])).to_lower()])
	return ", ".join(parts)


func repair(r: Dictionary) -> bool:
	if not missing(r).is_empty():
		return false
	if not Game.admin:
		for k in r["cost"]:
			Game.add_item(k, -int(r["cost"][k]))
	var isl := IslandDB.get_island(r["island"])
	Game.set_flag("unlock_" + str(r["island"]))
	Game.save_game()
	var at := _prop_pos(r["prop"])
	if at != Vector3.INF:
		main.burst(at + Vector3(0, 1.2, 0), Color("ffd84a"), 30)
	Audio.play("jingle_island", -4.0, 0.0)
	if r["id"] == "beacon":
		update_beacon()
	await main.story.think(r["done"])
	main.hud.show_item_popup("Nouvelle destination : %s" % isl["name"], "Ouvre la carte (M) pour t'y rendre.", false)
	return true


func _prop_pos(key: String) -> Vector3:
	for id in main.props.items:
		if main.props.key_of(id) == key:
			return main.props.items[id]["pos"]
	return Vector3.INF


## Le phare rallumé brille la nuit (à chaque chargement de la Prairie).
func update_beacon() -> void:
	if _beacon_light and is_instance_valid(_beacon_light):
		_beacon_light.queue_free()
	_beacon_light = null
	if Game.current_island != "prairie" or not Game.has_flag("unlock_braise"):
		return
	var at := _prop_pos("g:obelisk")
	if at == Vector3.INF:
		return
	_beacon_light = OmniLight3D.new()
	_beacon_light.light_color = Color("ffcf7a")
	_beacon_light.light_energy = 3.0
	_beacon_light.omni_range = 14.0
	main.add_child(_beacon_light)
	_beacon_light.global_position = at + Vector3(0, 6.5, 0)
