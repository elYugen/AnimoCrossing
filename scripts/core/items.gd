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


## Ce qu'on apprend d'un objet la première fois qu'on l'obtient :
## description et usage.
const INFO := {
	"branch": {"desc": "Une branche sèche, tombée d'un arbre.", "use": "Fabriquer des poutres et des chevilles à la table d'artisan."},
	"stone": {"desc": "Un caillou bien solide.", "use": "Tailler des moellons, construire un feu de camp."},
	"fruit": {"desc": "Un fruit sucré, cueilli au pied d'un arbre.", "use": "Faire plaisir aux habitants, teindre du tissu."},
	"plant": {"desc": "Une touffe de plantes et de fibres.", "use": "Tresser des cordes et de la toile, faire un potager."},
	"beam": {"desc": "Une poutre taillée dans des branches.", "use": "Planches, rondins, constructions et meubles."},
	"peg": {"desc": "De petites chevilles de bois.", "use": "Assembler les meubles, les clôtures et les maisons."},
	"rope": {"desc": "Une corde tressée avec des fibres.", "use": "Tentes, maisons... et peut-être réparer une vieille barque."},
	"cloth": {"desc": "Une toile tissée, souple et solide.", "use": "Tentes, coussins, canapés, voiles."},
	"cut_stone": {"desc": "Une pierre taillée bien carrée.", "use": "Pierre taillée, maisons, fontaine, jardinières."},
	"tile": {"desc": "Des tuiles en terre cuite.", "use": "Les toits des grandes maisons, les briques."},
	"glass": {"desc": "Du verre, fondu à partir du sable.", "use": "Lanternes, lampes, fenêtres."},
}

## Blocs : description (l'usage est toujours le même : les poser).
const BLOCK_INFO := {
	Blocks.GRASS: "Une motte d'herbe, avec sa terre.",
	Blocks.DIRT: "De la bonne terre, prête à accueillir des fleurs.",
	Blocks.STONE: "Un bloc de pierre brute.",
	Blocks.SAND: "Du sable fin de la plage.",
	Blocks.WOOD: "Un rondin de bois.",
	Blocks.PLANK: "Des planches bien rabotées.",
	Blocks.LEAVES: "Du feuillage touffu, pour faire des haies.",
	Blocks.BRICK: "Des briques de terre cuite.",
	Blocks.SNOW: "Un bloc de neige tassée.",
	Blocks.ICE: "Un bloc de glace transparente.",
	Blocks.BASALT: "Une pierre volcanique, noire et dure.",
	Blocks.CLAY: "De la terre cuite, chaude et colorée.",
	Blocks.WOOL: "Un tissu rose tout doux.",
	Blocks.MOSS: "Une pierre couverte de mousse.",
	Blocks.PALM_WOOD: "Le tronc fibreux d'un palmier.",
}


## Fiche de découverte : {"name", "desc", "use", "color", "block"} pour
## "item:<id>" ou "block:<id>".
static func discovery(key: String) -> Dictionary:
	if key.begins_with("block:"):
		var id := int(key.trim_prefix("block:"))
		return {"name": Blocks.block_name(id), "desc": BLOCK_INFO.get(id, "Un bloc de construction."),
			"use": "Se pose avec le pouvoir Poser (touche 2) pour construire où tu veux.", "color": Blocks.main_color(id), "block": true}
	var k := key.trim_prefix("item:")
	var info: Dictionary = INFO.get(k, {})
	return {"name": name_of(k), "desc": info.get("desc", ""), "use": info.get("use", ""), "color": color_of(k), "block": false}
