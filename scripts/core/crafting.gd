class_name Crafting
extends RefCounted
## Fabrication à la table d'artisan. Trois étapes :
##   ressources ramassées -> composants -> blocs et constructions.
## Les coûts mélangent objets (branch, beam...) et blocs ("block:<id>").
## Déblocage : « vitality » (vitalité de l'île, %) et « residents »
## (nombre d'habitants installés sur l'île).

const SECTIONS := ["Composants", "Blocs", "Constructions", "Meubles"]

const RECIPES := [
	# --- Composants
	{"id": "beam", "section": 0, "name": "Poutre", "item": "beam", "n": 1, "cost": {"branch": 3}},
	{"id": "peg", "section": 0, "name": "Chevilles", "item": "peg", "n": 4, "cost": {"branch": 1}},
	{"id": "rope", "section": 0, "name": "Corde", "item": "rope", "n": 1, "cost": {"plant": 2}},
	{"id": "cut_stone", "section": 0, "name": "Moellon", "item": "cut_stone", "n": 1, "cost": {"stone": 2}},
	{"id": "cloth", "section": 0, "name": "Toile", "item": "cloth", "n": 1, "cost": {"plant": 3}, "vitality": 10},
	{"id": "tile", "section": 0, "name": "Tuiles", "item": "tile", "n": 2, "cost": {"block:2": 2, "stone": 1}, "vitality": 20},
	{"id": "glass", "section": 0, "name": "Verre", "item": "glass", "n": 1, "cost": {"block:4": 2, "branch": 1}, "vitality": 25},
	# --- Blocs
	{"id": "plank", "section": 1, "name": "Planches", "block": Blocks.PLANK, "n": 4, "cost": {"beam": 1}},
	{"id": "stone_block", "section": 1, "name": "Pierre taillée", "block": Blocks.STONE, "n": 2, "cost": {"cut_stone": 1}},
	{"id": "wood", "section": 1, "name": "Rondin", "block": Blocks.WOOD, "n": 1, "cost": {"beam": 1}},
	{"id": "grass", "section": 1, "name": "Motte d'herbe", "block": Blocks.GRASS, "n": 2, "cost": {"plant": 1, "block:2": 2}, "vitality": 10},
	{"id": "leaves", "section": 1, "name": "Haie", "block": Blocks.LEAVES, "n": 2, "cost": {"plant": 2, "branch": 1}, "vitality": 15},
	{"id": "moss", "section": 1, "name": "Pierre moussue", "block": Blocks.MOSS, "n": 2, "cost": {"plant": 1, "cut_stone": 1}, "vitality": 20},
	{"id": "wool", "section": 1, "name": "Tissu rose", "block": Blocks.WOOL, "n": 2, "cost": {"cloth": 1, "fruit": 1}, "vitality": 25},
	{"id": "clay", "section": 1, "name": "Terre cuite", "block": Blocks.CLAY, "n": 2, "cost": {"tile": 1, "block:2": 1}, "vitality": 30},
	{"id": "brick", "section": 1, "name": "Briques", "block": Blocks.BRICK, "n": 2, "cost": {"tile": 2}, "vitality": 40},
	# --- Constructions (modèles Kenney, posables où l'on veut)
	{"id": "s_workbench", "section": 2, "name": "Table d'artisan", "structure": "workbench", "n": 1, "cost": {"beam": 2, "peg": 4}},
	{"id": "s_campfire", "section": 2, "name": "Feu de camp", "structure": "campfire", "n": 1, "cost": {"branch": 2, "stone": 2}},
	{"id": "s_fence", "section": 2, "name": "Clôture", "structure": "fence_low", "n": 2, "cost": {"beam": 1, "peg": 2}},
	{"id": "s_garden", "section": 2, "name": "Potager", "structure": "garden", "n": 1, "cost": {"plant": 2, "block:2": 1}, "vitality": 10},
	{"id": "s_planter", "section": 2, "name": "Jardinière", "structure": "planter", "n": 1, "cost": {"plant": 2, "cut_stone": 1}, "vitality": 15},
	{"id": "s_tent", "section": 2, "name": "Tente", "structure": "tent", "n": 1, "cost": {"cloth": 2, "beam": 2, "rope": 1}, "vitality": 15},
	{"id": "s_house_a", "section": 2, "name": "Petite maison", "structure": "house_a", "n": 1, "cost": {"beam": 6, "peg": 8, "rope": 2, "cut_stone": 4}, "residents": 1},
	{"id": "s_bench", "section": 2, "name": "Banc", "structure": "bench", "n": 1, "cost": {"beam": 2, "peg": 2}, "residents": 1},
	{"id": "s_lantern", "section": 2, "name": "Lanterne", "structure": "lantern", "n": 1, "cost": {"beam": 1, "glass": 1}, "residents": 2},
	{"id": "s_house_h", "section": 2, "name": "Chalet", "structure": "house_h", "n": 1, "cost": {"beam": 8, "peg": 8, "cloth": 2, "cut_stone": 4}, "residents": 2},
	{"id": "s_stall", "section": 2, "name": "Étal de marché", "structure": "stall", "n": 1, "cost": {"beam": 4, "cloth": 2, "peg": 4}, "residents": 3},
	{"id": "s_cart", "section": 2, "name": "Charrette", "structure": "cart", "n": 1, "cost": {"beam": 3, "peg": 6}, "residents": 3},
	{"id": "s_house_c", "section": 2, "name": "Maison à étage", "structure": "house_c", "n": 1, "cost": {"beam": 8, "cut_stone": 8, "tile": 4, "glass": 2}, "residents": 3},
	{"id": "s_fountain", "section": 2, "name": "Fontaine", "structure": "fountain", "n": 1, "cost": {"cut_stone": 10}, "residents": 4},
	{"id": "s_house_p", "section": 2, "name": "Maison de village", "structure": "house_p", "n": 1, "cost": {"beam": 10, "cut_stone": 8, "tile": 6, "glass": 2}, "residents": 4},
	{"id": "s_house_k", "section": 2, "name": "Maison haute", "structure": "house_k", "n": 1, "cost": {"beam": 10, "cut_stone": 10, "tile": 6, "glass": 4}, "residents": 5},
	{"id": "s_house_f", "section": 2, "name": "Grande maison", "structure": "house_f", "n": 1, "cost": {"beam": 12, "cut_stone": 12, "tile": 8, "glass": 4}, "residents": 6},
	{"id": "s_house_b", "section": 2, "name": "Maison familiale", "structure": "house_b", "n": 1, "cost": {"beam": 14, "cut_stone": 12, "tile": 8, "glass": 6}, "residents": 8},
	{"id": "s_house_n", "section": 2, "name": "Villa", "structure": "house_n", "n": 1, "cost": {"beam": 16, "cut_stone": 16, "tile": 10, "glass": 8}, "residents": 10},
	# --- Meubles (à poser à l'intérieur des maisons)
	{"id": "m_bedSingle", "section": 3, "name": "Lit simple", "furniture": "bedSingle", "n": 1, "cost": {"beam": 2, "cloth": 2, "peg": 4}},
	{"id": "m_bedDouble", "section": 3, "name": "Grand lit", "furniture": "bedDouble", "n": 1, "cost": {"beam": 3, "cloth": 3, "peg": 6}, "residents": 1},
	{"id": "m_cabinetBedDrawerTable", "section": 3, "name": "Table de chevet", "furniture": "cabinetBedDrawerTable", "n": 1, "cost": {"beam": 1, "peg": 2}},
	{"id": "m_table", "section": 3, "name": "Table", "furniture": "table", "n": 1, "cost": {"beam": 2, "peg": 4}},
	{"id": "m_tableRound", "section": 3, "name": "Table ronde", "furniture": "tableRound", "n": 1, "cost": {"beam": 2, "peg": 4}, "residents": 1},
	{"id": "m_chairCushion", "section": 3, "name": "Chaise", "furniture": "chairCushion", "n": 1, "cost": {"beam": 1, "peg": 2, "cloth": 1}},
	{"id": "m_tableCoffee", "section": 3, "name": "Table basse", "furniture": "tableCoffee", "n": 1, "cost": {"beam": 1, "peg": 2}},
	{"id": "m_loungeSofa", "section": 3, "name": "Canapé", "furniture": "loungeSofa", "n": 1, "cost": {"beam": 2, "cloth": 3}, "vitality": 15},
	{"id": "m_loungeChair", "section": 3, "name": "Fauteuil", "furniture": "loungeChair", "n": 1, "cost": {"beam": 1, "cloth": 2}, "vitality": 15},
	{"id": "m_lampRoundFloor", "section": 3, "name": "Lampadaire", "furniture": "lampRoundFloor", "n": 1, "cost": {"beam": 1, "glass": 1}, "vitality": 25},
	{"id": "m_bookcaseOpen", "section": 3, "name": "Étagère", "furniture": "bookcaseOpen", "n": 1, "cost": {"beam": 2, "peg": 4}},
	{"id": "m_bookcaseClosedWide", "section": 3, "name": "Bibliothèque", "furniture": "bookcaseClosedWide", "n": 1, "cost": {"beam": 3, "peg": 6}, "residents": 2},
	{"id": "m_sideTable", "section": 3, "name": "Commode", "furniture": "sideTable", "n": 1, "cost": {"beam": 2, "peg": 4}},
	{"id": "m_kitchenStove", "section": 3, "name": "Cuisinière", "furniture": "kitchenStove", "n": 1, "cost": {"cut_stone": 3, "beam": 1}, "residents": 1},
	{"id": "m_kitchenSink", "section": 3, "name": "Évier", "furniture": "kitchenSink", "n": 1, "cost": {"cut_stone": 2, "glass": 1}, "residents": 2},
	{"id": "m_kitchenCabinet", "section": 3, "name": "Meuble de cuisine", "furniture": "kitchenCabinet", "n": 1, "cost": {"beam": 2, "peg": 4}, "residents": 1},
	{"id": "m_kitchenFridgeSmall", "section": 3, "name": "Réfrigérateur", "furniture": "kitchenFridgeSmall", "n": 1, "cost": {"cut_stone": 2, "glass": 1, "beam": 1}, "residents": 3},
	{"id": "m_rugRectangle", "section": 3, "name": "Grand tapis", "furniture": "rugRectangle", "n": 1, "cost": {"cloth": 2}},
	{"id": "m_rugRound", "section": 3, "name": "Tapis rond", "furniture": "rugRound", "n": 1, "cost": {"cloth": 1, "plant": 1}},
	{"id": "m_rugDoormat", "section": 3, "name": "Paillasson", "furniture": "rugDoormat", "n": 1, "cost": {"plant": 2}},
	{"id": "m_pottedPlant", "section": 3, "name": "Plante en pot", "furniture": "pottedPlant", "n": 1, "cost": {"plant": 2, "stone": 1}},
	{"id": "m_coatRackStanding", "section": 3, "name": "Portemanteau", "furniture": "coatRackStanding", "n": 1, "cost": {"beam": 1, "peg": 1}},
	{"id": "m_radio", "section": 3, "name": "Radio", "furniture": "radio", "n": 1, "cost": {"beam": 1, "glass": 1}, "residents": 3},
]


static func is_unlocked(r: Dictionary) -> bool:
	if Game.admin:
		return true
	if Vitality.percent(Game.current_island) < int(r.get("vitality", 0)):
		return false
	return Vitality.residents(Game.current_island) >= int(r.get("residents", 0))


## Condition de déblocage, pour l'affichage (« Île à 20 % », « 3 habitants »).
static func lock_text(r: Dictionary) -> String:
	var parts := []
	if int(r.get("vitality", 0)) > 0:
		parts.append("Île à %d %%" % int(r["vitality"]))
	if int(r.get("residents", 0)) > 0:
		var n := int(r["residents"])
		parts.append("%d habitant%s" % [n, "s" if n > 1 else ""])
	return " · ".join(parts)


static func have(key: String) -> int:
	if key.begins_with("block:"):
		return Game.block_count(int(key.trim_prefix("block:")))
	return Game.item_count(key)


static func can_craft(r: Dictionary) -> bool:
	if not is_unlocked(r):
		return false
	if Game.admin:
		return true
	for k in r["cost"]:
		if have(k) < int(r["cost"][k]):
			return false
	return true


static func craft(r: Dictionary) -> bool:
	if not can_craft(r):
		return false
	if not Game.admin:
		for k in r["cost"]:
			var n: int = r["cost"][k]
			if k.begins_with("block:"):
				Game.add_block(int(k.trim_prefix("block:")), -n)
			else:
				Game.add_item(k, -n)
	if r.has("item"):
		Game.add_item(r["item"], int(r["n"]))
	elif r.has("block"):
		Game.add_block(int(r["block"]), int(r["n"]))
	elif r.has("furniture"):
		Game.add_structure("f_" + r["furniture"], int(r["n"]))
		Game.collect("furniture", r["furniture"])
	else:
		Game.add_structure(r["structure"], int(r["n"]))
	Game.notify_action("craft")
	return true


static func cost_label(key: String, n := 1) -> String:
	if key.begins_with("block:"):
		return Blocks.block_name(int(key.trim_prefix("block:")))
	return Items.name_of(key, n)


## Nom affiché d'une construction (type d'objet Props).
static func structure_name(kind: String) -> String:
	if kind.begins_with("f_"):
		return Interior.label_of(kind.trim_prefix("f_"))
	for r in RECIPES:
		if r.get("structure", "") == kind:
			return r["name"]
	return kind


## Recettes devenues disponibles depuis la dernière annonce.
static func newly_unlocked() -> Array:
	var out := []
	for r in RECIPES:
		if is_unlocked(r) and not Game.recipes_seen.has(r["id"]):
			Game.recipes_seen[r["id"]] = true
			if int(r.get("vitality", 0)) > 0 or int(r.get("residents", 0)) > 0:
				out.append(r)
	return out
