class_name Items
extends RefCounted
## Objets de l'inventaire : ressources ramassées sur l'île et composants
## fabriqués à la table d'artisan (qui servent à fabriquer les constructions).

const RAW := ["branch", "stone", "fruit", "plant"]
const COMPONENTS := ["beam", "peg", "rope", "cloth", "cut_stone", "tile", "glass"]

const ALL := {
	"branch": {"name": "Branche", "plural": "Branches", "color": Color("9b6b45")},
	"stone": {"name": "Pierre", "plural": "Pierres", "color": Color("a7adb5")},
	"fruit": {"name": "Fruit", "plural": "Fruits", "color": Color("f0663f")},
	"plant": {"name": "Plante", "plural": "Plantes", "color": Color("6cbf4a")},
	"beam": {"name": "Poutre", "plural": "Poutres", "color": Color("b98552")},
	"peg": {"name": "Cheville", "plural": "Chevilles", "color": Color("e0c08f")},
	"rope": {"name": "Corde", "plural": "Cordes", "color": Color("c9b27a")},
	"cloth": {"name": "Toile", "plural": "Toiles", "color": Color("f3e8d0")},
	"cut_stone": {"name": "Moellon", "plural": "Moellons", "color": Color("b8bec6")},
	"tile": {"name": "Tuile", "plural": "Tuiles", "color": Color("d4705a")},
	"glass": {"name": "Verre", "plural": "Verres", "color": Color("9fd8ef")},
}


static func name_of(k: String, n := 1) -> String:
	var d: Dictionary = ALL.get(k, {})
	return d.get("plural" if n > 1 else "name", k)


static func color_of(k: String) -> Color:
	return (ALL.get(k, {}) as Dictionary).get("color", Color.WHITE)
