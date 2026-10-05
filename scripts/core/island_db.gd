class_name IslandDB
extends RefCounted
## Définition des îles (biomes, couleurs, conditions de déblocage).

static var ISLANDS: Array[Dictionary] = [
	{"id": "prairie", "name": "Île Prairie", "biome": "prairie", "seed": 1337, "residents_needed": 0,
	"desc": "Une île verdoyante parsemée de fleurs. Idéale pour débuter.",
	"sky_top": Color("6fb4f0"), "sky_horizon": Color("cfeaff"), "water_shallow": Color("6fe0d8"), "water_deep": Color("2f8fd0"),
	"sun": Color("fff3dc"), "fog": Color("cfeaff")},
	{"id": "corail", "name": "Île Corail", "biome": "plage", "seed": 4242, "residents_needed": 3,
	"desc": "Plages de sable fin, palmiers et eau turquoise.",
	"sky_top": Color("4fb0f5"), "sky_horizon": Color("d8f6ff"), "water_shallow": Color("7ff2e0"), "water_deep": Color("1fa0d8"),
	"sun": Color("fff6e0"), "fog": Color("d8f6ff")},
	{"id": "givree", "name": "Île Givrée", "biome": "givre", "seed": 777, "residents_needed": 7,
	"desc": "Montagnes enneigées, sapins et lacs gelés.",
	"sky_top": Color("8fb8e8"), "sky_horizon": Color("eef4ff"), "water_shallow": Color("9fdcf0"), "water_deep": Color("3f78b8"),
	"sun": Color("eef4ff"), "fog": Color("e6eefa")},
	{"id": "braise", "name": "Île Braise", "biome": "braise", "seed": 9001, "residents_needed": 12,
	"desc": "Un volcan endormi entouré de forêts d'automne.",
	"sky_top": Color("e89a7a"), "sky_horizon": Color("ffe0c0"), "water_shallow": Color("7fd0c8"), "water_deep": Color("2f6f9f"),
	"sun": Color("ffd8b0"), "fog": Color("ffe4cc")},
]


static func get_island(id: String) -> Dictionary:
	for i in ISLANDS:
		if i["id"] == id:
			return i
	return ISLANDS[0]


static func index_of(id: String) -> int:
	for k in ISLANDS.size():
		if ISLANDS[k]["id"] == id:
			return k
	return 0
