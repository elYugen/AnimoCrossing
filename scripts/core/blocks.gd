class_name Blocks
extends RefCounted
## Définition de tous les types de blocs voxel.

const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const WOOD := 5
const LEAVES := 6
const PLANK := 7
const BRICK := 8
const SNOW := 9
const ICE := 10
const BASALT := 11
const AUTUMN_LEAVES := 12
const PINE_LEAVES := 13
const PALM_LEAVES := 14
const CLAY := 15
const WOOL := 16
const MOSS := 17
const PALM_WOOD := 18

const FLOWER_RED := 30
const FLOWER_YELLOW := 31
const FLOWER_WHITE := 32
const FLOWER_PINK := 33
const FLOWER_BLUE := 34
const FLOWER_PURPLE := 35
const TALL_GRASS := 36

const FLOWERS: Array[int] = [FLOWER_RED, FLOWER_YELLOW, FLOWER_WHITE, FLOWER_PINK, FLOWER_BLUE, FLOWER_PURPLE]

# name, top, side, bottom, deco (non solide, sans collision)
static var DEFS := {
	GRASS: {"name": "Herbe", "top": Color("7bc95a"), "side": Color("a9784e"), "bottom": Color("94663f")},
	DIRT: {"name": "Terre", "top": Color("a9784e"), "side": Color("a1714a"), "bottom": Color("94663f")},
	STONE: {"name": "Pierre", "top": Color("a7adb5"), "side": Color("9aa0a8"), "bottom": Color("8a9098")},
	SAND: {"name": "Sable", "top": Color("f3e2aa"), "side": Color("ead69a"), "bottom": Color("dcc88c")},
	WOOD: {"name": "Bois", "top": Color("c99d6c"), "side": Color("8a5a3b"), "bottom": Color("c99d6c")},
	LEAVES: {"name": "Feuillage", "top": Color("5cbb52"), "side": Color("4fae4a"), "bottom": Color("43993f")},
	PLANK: {"name": "Planches", "top": Color("e0b277"), "side": Color("d4a46a"), "bottom": Color("c2935c")},
	BRICK: {"name": "Brique", "top": Color("d47660"), "side": Color("c8604d"), "bottom": Color("b05442")},
	SNOW: {"name": "Neige", "top": Color("f7faff"), "side": Color("e8eef8"), "bottom": Color("d9e2ef")},
	ICE: {"name": "Glace", "top": Color("bfe8f7"), "side": Color("a8ddf0"), "bottom": Color("94cfe6")},
	BASALT: {"name": "Basalte", "top": Color("5a5462"), "side": Color("4a4550"), "bottom": Color("3e3a44")},
	AUTUMN_LEAVES: {"name": "Feuilles d'automne", "top": Color("f29a45"), "side": Color("e8893a"), "bottom": Color("d47630")},
	PINE_LEAVES: {"name": "Aiguilles", "top": Color("3a8d60"), "side": Color("2f7d54"), "bottom": Color("276b47")},
	PALM_LEAVES: {"name": "Palmes", "top": Color("7cd658"), "side": Color("6ccb4a"), "bottom": Color("5bb53e")},
	CLAY: {"name": "Terre cuite", "top": Color("e39a7a"), "side": Color("d98a6a"), "bottom": Color("c4785a")},
	WOOL: {"name": "Laine rose", "top": Color("f9c4d8"), "side": Color("f6b6cf"), "bottom": Color("e8a3be")},
	MOSS: {"name": "Pierre moussue", "top": Color("78ad5e"), "side": Color("8f9c88"), "bottom": Color("80897a")},
	PALM_WOOD: {"name": "Bois de palmier", "top": Color("e2c08c"), "side": Color("b98f5e"), "bottom": Color("e2c08c")},
	FLOWER_RED: {"name": "Fleur rouge", "deco": true, "petal": Color("ec5864")},
	FLOWER_YELLOW: {"name": "Fleur jaune", "deco": true, "petal": Color("f9d54a")},
	FLOWER_WHITE: {"name": "Fleur blanche", "deco": true, "petal": Color("f2f0e8")},
	FLOWER_PINK: {"name": "Fleur rose", "deco": true, "petal": Color("f7a3c8")},
	FLOWER_BLUE: {"name": "Fleur bleue", "deco": true, "petal": Color("74aef7")},
	FLOWER_PURPLE: {"name": "Fleur violette", "deco": true, "petal": Color("ae84e6")},
	TALL_GRASS: {"name": "Herbes hautes", "deco": true, "petal": Color("6fc052")},
}

## Blocs posables et île à partir de laquelle ils sont disponibles.
const BUILD_PALETTE := [
	{"id": GRASS, "island": "prairie"},
	{"id": DIRT, "island": "prairie"},
	{"id": STONE, "island": "prairie"},
	{"id": PLANK, "island": "prairie"},
	{"id": WOOD, "island": "prairie"},
	{"id": LEAVES, "island": "prairie"},
	{"id": WOOL, "island": "prairie"},
	{"id": SAND, "island": "corail"},
	{"id": CLAY, "island": "corail"},
	{"id": PALM_WOOD, "island": "corail"},
	{"id": SNOW, "island": "givree"},
	{"id": ICE, "island": "givree"},
	{"id": MOSS, "island": "givree"},
	{"id": BASALT, "island": "braise"},
	{"id": BRICK, "island": "braise"},
	{"id": AUTUMN_LEAVES, "island": "braise"},
]


static func is_solid(id: int) -> bool:
	return id != AIR and not is_deco(id)


static func is_deco(id: int) -> bool:
	return id >= FLOWER_RED


static func block_name(id: int) -> String:
	if DEFS.has(id):
		return DEFS[id]["name"]
	return "Air"


static func main_color(id: int) -> Color:
	if not DEFS.has(id):
		return Color.WHITE
	var d: Dictionary = DEFS[id]
	if d.has("petal"):
		return d["petal"]
	return d["top"]


static func face_color(id: int, dir_index: int) -> Color:
	var d: Dictionary = DEFS[id]
	if dir_index == 2:
		return d["top"]
	if dir_index == 3:
		return d["bottom"]
	return d["side"]
