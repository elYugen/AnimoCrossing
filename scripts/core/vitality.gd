class_name Vitality
extends RefCounted
## Progression fondée sur l'état de l'île plutôt que sur des quêtes :
## - la Vitalité (0-100 %) mesure à quel point l'île est accueillante ;
## - chaque habitat (forêt, jardins, mer, montagne, village) a un score
##   selon ce qui se trouve sur l'île ;
## - chaque palier de vitalité fait venir un nouvel habitant le lendemain
##   matin, tiré au hasard parmi ceux dont l'habitat est le plus développé.
##
## Tout est mesuré sur l'état ACTUEL de l'île (arbres et constructions
## présents, fleurs en place...), jamais en comptant des actions : déplacer
## un feu de camp ne rapporte rien, le démonter fait baisser la vitalité.
## Seuls déchets et vase retirés sont comptés (ils ne reviennent jamais).

const BASE := 5

## Composantes de la vitalité. `measure` : voir measures() ; `target` : valeur
## pour remplir la jauge (un nombre, ou la quantité générée sur l'île pour
## les déchets / la vase).
const PARTS := [
	{"key": "tree", "label": "Arbres plantés", "measure": "trees", "target": 25, "weight": 15},
	{"key": "flowers", "label": "Fleurs & herbe", "measure": "flowers", "target": 80, "weight": 15},
	{"key": "water", "label": "Points d'eau nettoyés", "measure": "clean_water", "target": "water", "weight": 15},
	{"key": "waste", "label": "Déchets retirés", "measure": "clean_waste", "target": "waste", "weight": 15},
	{"key": "build", "label": "Constructions", "measure": "builds", "target": 12, "weight": 10},
	{"key": "fire", "label": "Feux de camp", "measure": "campfire", "target": 3, "weight": 10},
	{"key": "garden", "label": "Jardins", "measure": "gardens", "target": 10, "weight": 15},
]
## Hauteur à partir de laquelle on aménage la « montagne ».
const MOUNTAIN_Y := IslandGenerator.SEA + 12


## Ce qui se trouve actuellement sur l'île :
##   trees (arbres plantés), flowers (fleurs et herbe qu'on a fait pousser),
##   builds (constructions posées, hors meubles), campfire, gardens
##   (potagers et jardinières), planter, garden, mountain (blocs et
##   constructions posés en hauteur), placed (blocs posés), sand (sable
##   posé), clean_* (retirés).
static func measures(island_id: String) -> Dictionary:
	var m := {"trees": 0, "flowers": 0, "builds": 0, "campfire": 0, "gardens": 0, "garden": 0, "planter": 0,
		"mountain": 0, "placed": 0, "sand": 0}
	for e in Game.props_added.get(island_id, []):
		var kind: String = e["kind"]
		var high := float(e["y"]) >= MOUNTAIN_Y + 1
		if Props.is_tree(kind):
			m["trees"] += 1
		elif Props.is_structure(kind) and not Props.KINDS[kind].has("furniture"):
			m["builds"] += 1
			if m.has(kind):
				m[kind] += 1
			if kind == "garden" or kind == "planter":
				m["gardens"] += 1
		else:
			continue
		if high:
			m["mountain"] += 1
	for key in Game.edits.get(island_id, {}):
		var b := int(Game.edits[island_id][key])
		if b == Blocks.AIR or b == Blocks.DEBRIS or b == Blocks.SLUDGE:
			continue
		if b in Blocks.FLOWERS or b == Blocks.GRASS or b == Blocks.TALL_GRASS:
			m["flowers"] += 1
			continue
		m["placed"] += 1
		if b == Blocks.SAND:
			m["sand"] += 1
		if int(str(key).get_slice(",", 1)) >= MOUNTAIN_Y:
			m["mountain"] += 1
	for k in ["clean_water", "clean_waste", "clean_shore"]:
		m[k] = Game.get_stat(island_id, k)
	return m


static func _target(part: Dictionary, island_id: String) -> float:
	var t = part["target"]
	if t is String:
		var totals: Dictionary = Game.island_totals.get(island_id, {})
		return maxf(1.0, float(totals.get(t, 30)))
	return float(t)


## Avancement de chaque composante (0..1).
static func parts(island_id: String) -> Array[Dictionary]:
	var m := measures(island_id)
	var out: Array[Dictionary] = []
	for p in PARTS:
		var have := int(m.get(p["measure"], 0))
		var target := _target(p, island_id)
		out.append({"key": p["key"], "label": p["label"], "have": have, "target": int(target),
			"frac": clampf(have / target, 0.0, 1.0), "weight": p["weight"]})
	return out


static func percent(island_id: String) -> int:
	var v := float(BASE)
	for p in parts(island_id):
		v += float(p["weight"]) * float(p["frac"])
	return clampi(roundi(v), 0, 100)


## Paliers de vie de l'île (voir IslandLife : ce qui change à chacun).
const TIERS := [
	[0, "Une île silencieuse"],
	[20, "L'île commence à revivre"],
	[40, "L'île reprend des couleurs"],
	[60, "Une île pleine de vie"],
	[80, "Un petit paradis"],
	[100, "Un véritable paradis"],
]

## Vitalité requise pour le n-ième habitant d'une île (puis +8 % par habitant).
const ARRIVALS := [15, 22, 30, 38, 46, 54, 62, 70, 78, 86, 94]


static func tier_index(pct: int) -> int:
	var i := 0
	for k in TIERS.size():
		if pct >= int(TIERS[k][0]):
			i = k
	return i


static func tier_name(pct: int) -> String:
	return TIERS[tier_index(pct)][1]


## Score de chaque habitat selon ce qui se trouve sur l'île.
static func habitat_scores(island_id: String) -> Dictionary:
	var m := measures(island_id)
	var f := func(k: String) -> float: return float(m.get(k, 0))
	return {
		"forest": f.call("trees") * 3.0,
		"garden": f.call("flowers") * 0.5 + f.call("garden") * 4.0 + f.call("planter") * 3.0,
		"marine": f.call("clean_water") * 1.5 + f.call("clean_shore") * 2.0 + f.call("sand") * 0.5,
		"mountain": f.call("mountain") * 1.5,
		"village": f.call("builds") * 3.0 + f.call("placed") * 0.1 + f.call("campfire") * 4.0,
	}


## Nombre d'habitants installés sur l'île.
static func residents(island_id: String) -> int:
	var n := 0
	for id in Game.residents:
		var c := ResidentDB.get_resident(id)
		if not c.is_empty() and (Game.residents[id] as Dictionary).get("island", "") == island_id:
			n += 1
	return n


## Vitalité nécessaire pour le prochain habitant (-1 s'il n'en reste plus).
static func next_threshold(island_id: String) -> int:
	if available(island_id).is_empty():
		return -1
	var n := residents(island_id)
	if n < ARRIVALS.size():
		return ARRIVALS[n]
	return mini(100, ARRIVALS[-1] + (n - ARRIVALS.size() + 1) * 8)


## Habitants pas encore venus qui pourraient s'installer sur l'île.
static func available(island_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in ResidentDB.island_residents(island_id):
		if not Game.residents.has(c["id"]):
			out.append(c)
	return out


## Tire au sort le prochain habitant : un habitat est choisi selon les
## scores (les plus développés ont plus de chances), puis un habitant de
## cet habitat. Renvoie {} si personne ne vient cette nuit.
static func pick_arrival(island_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var th := next_threshold(island_id)
	if th < 0 or percent(island_id) < th:
		return {}
	var pool := available(island_id)
	var scores := habitat_scores(island_id)
	var by_habitat := {}
	for c in pool:
		(by_habitat.get_or_add(c["habitat"], []) as Array).append(c)
	var total := 0.0
	var weights := {}
	for h in by_habitat:
		# Un petit poids de base garde une part de surprise.
		var w := 1.0 + float(scores.get(h, 0.0))
		weights[h] = w
		total += w
	var r := rng.randf() * total
	for h in weights:
		r -= float(weights[h])
		if r <= 0.0:
			return (by_habitat[h] as Array).pick_random()
	return pool.pick_random()


## Habitat le plus développé (pour l'affichage).
static func best_habitat(island_id: String) -> String:
	var scores := habitat_scores(island_id)
	var best := ""
	var best_v := 0.0
	for h in scores:
		if float(scores[h]) > best_v:
			best_v = scores[h]
			best = h
	return best
