class_name Fauna
extends RefCounted
## Animaux sauvages (Cube Pets de Kenney, CC0). Ils apparaissent d'eux-mêmes
## quand leur environnement se développe : forêt, jardins, mer, montagne,
## village. Chaque espèce a un seuil de développement de son habitat.

const SPECIES := {
	"deer": {"name": "Cerf", "habitat": "forest", "need": 6},
	"fox": {"name": "Renard", "habitat": "forest", "need": 15},
	"beaver": {"name": "Castor", "habitat": "forest", "need": 30},
	"hog": {"name": "Sanglier", "habitat": "forest", "need": 45},
	"bunny": {"name": "Lapin", "habitat": "garden", "need": 5},
	"bee": {"name": "Abeille", "habitat": "garden", "need": 12},
	"chick": {"name": "Poussin", "habitat": "garden", "need": 25},
	"caterpillar": {"name": "Chenille", "habitat": "garden", "need": 40},
	"crab": {"name": "Crabe", "habitat": "marine", "need": 5},
	"parrot": {"name": "Perroquet", "habitat": "marine", "need": 20, "biomes": ["prairie", "corail"]},
	"penguin": {"name": "Manchot", "habitat": "marine", "need": 10, "biomes": ["givree"]},
	"panda": {"name": "Panda", "habitat": "mountain", "need": 10, "biomes": ["prairie", "braise"]},
	"polar": {"name": "Ours polaire", "habitat": "mountain", "need": 10, "biomes": ["givree"]},
	"cat": {"name": "Chat", "habitat": "village", "need": 6},
	"dog": {"name": "Chien", "habitat": "village", "need": 12},
	"pig": {"name": "Cochon", "habitat": "village", "need": 25},
	"cow": {"name": "Vache", "habitat": "village", "need": 40},
}


## Rencontres rares, liées à la météo (WeatherFX) : jamais là par hasard.
const RARE := {
	"spirit_deer": {"name": "Cerf des brumes", "model": "deer", "weather": "fog",
		"desc": "Il n'apparaît que dans le brouillard, au fond des bois. Il regarde, puis s'efface."},
}


static func name_of(sp: String) -> String:
	if RARE.has(sp):
		return RARE[sp]["name"]
	return (SPECIES.get(sp, {}) as Dictionary).get("name", sp)


## Animaux présents sur une île : {espèce: nombre}, selon les habitats.
static func population(island_id: String) -> Dictionary:
	var scores := Vitality.habitat_scores(island_id)
	var out := {}
	for sp in SPECIES:
		var d: Dictionary = SPECIES[sp]
		var b: Array = d.get("biomes", [])
		if not b.is_empty() and not island_id in b:
			continue
		var score := float(scores.get(d["habitat"], 0.0))
		var need := float(d["need"])
		if score >= need:
			out[sp] = clampi(1 + floori((score - need) / (need + 10.0)), 1, 4)
	return out
