class_name Friendship
extends RefCounted
## Amitié avec les habitants, volontairement simple : de 0 à 5 cœurs.
##   parler (une fois par jour) : +3   ·   offrir un objet : +3 (+6 s'il l'aime)
##   rendre service (demande) : +8    ·   remarquer un nouveau meuble : +2 (+4 s'il l'aime)
## Cœurs : 1 = nouvelles répliques, 2 = petits cadeaux, 3 = petites demandes,
## 4 = un meuble fabriqué rien que pour toi, 5 = un véritable ami.

const PER_HEART := 10

## Ce que chacun aime, selon son environnement préféré.
const LIKES := {
	"forest": {"items": ["branch", "beam"], "furniture": ["bookcaseOpen", "bookcaseClosedWide", "loungeChair"]},
	"garden": {"items": ["plant", "fruit"], "furniture": ["pottedPlant", "rugRound", "tableRound"]},
	"marine": {"items": ["fruit", "glass"], "furniture": ["radio", "rugRectangle", "loungeSofa"]},
	"mountain": {"items": ["stone", "cut_stone"], "furniture": ["loungeChair", "lampRoundFloor", "coatRackStanding"]},
	"village": {"items": ["peg", "cloth"], "furniture": ["kitchenStove", "table", "loungeSofa"]},
}
## Le meuble offert à 4 cœurs.
const UNIQUE := {"forest": "bookcaseClosedWide", "garden": "pottedPlant", "marine": "radio", "mountain": "lampRoundFloor", "village": "kitchenStove"}
## Ce que les habitants peuvent demander (3 cœurs).
const REQUESTS := ["branch", "stone", "fruit", "plant", "beam", "peg", "rope", "cut_stone"]


static func data(id: String) -> Dictionary:
	return Game.residents.get(id, {})


static func points(id: String) -> int:
	return int(data(id).get("pts", 0))


static func hearts(id: String) -> int:
	return mini(5, points(id) / PER_HEART)


## Ajoute des points ; renvoie true si un nouveau cœur est gagné.
static func add(id: String, n: int) -> bool:
	var d := data(id)
	var before := hearts(id)
	d["pts"] = mini(5 * PER_HEART, points(id) + n)
	return hearts(id) > before


static func habitat(id: String) -> String:
	return ResidentDB.get_resident(id).get("habitat", "village")


static func likes_item(id: String, item: String) -> bool:
	return item in (LIKES[habitat(id)]["items"] as Array)


static func likes_furniture(id: String, f: String) -> bool:
	return f in (LIKES[habitat(id)]["furniture"] as Array)


static func hearts_text(id: String) -> String:
	return "♥ %d/5" % hearts(id)


## Jours depuis l'arrivée de l'habitant.
static func days_here(id: String) -> int:
	return Game.day - int(data(id).get("since", Game.day))


## Pourquoi il aime sa nouvelle maison (s'il a déménagé).
static func moved_reason(id: String) -> String:
	match habitat(id):
		"forest":
			return "Elle est plus proche des arbres."
		"garden":
			return "Il y a plein de fleurs autour."
		"marine":
			return "On entend la mer d'ici."
		"mountain":
			return "La vue est superbe."
	return "Elle est près de tout le monde."
