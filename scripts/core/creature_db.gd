class_name CreatureDB
extends RefCounted
## Toutes les créatures du jeu : 5 par île (débloquées en façonnant l'île)
## et un pool gacha avec raretés.

const COMMON := 0
const RARE := 1
const LEGENDARY := 2

const RARITY_NAMES := ["Commun", "Rare", "Légendaire"]
const RARITY_COLORS := [Color("8fd16a"), Color("6aa8f2"), Color("f5b83d")]

# look : body, belly, accent, shape (round/tall/long), ears, tail, extra, size
static var ALL: Array[Dictionary] = [
	# --- Île Prairie ---
	{"id": "bourgeon", "name": "Bourgeon", "island": "prairie", "stat": "bloom", "amount": 5,
	"req": "Fais fleurir 5 fleurs", "desc": "Une petite pousse qui adore le parfum des fleurs fraîches.",
	"look": {"body": Color("8ed36a"), "belly": Color("d9f5b8"), "accent": Color("4c9e3c"), "shape": "round", "ears": "leaf", "tail": "none"},
	"lines": ["Ces fleurs sentent si bon...", "Je pourrais faire la sieste ici toute la journée !", "Tu veux qu'on plante encore plus de fleurs ?"]},
	{"id": "caillou", "name": "Caillou", "island": "prairie", "stat": "break", "amount": 10,
	"req": "Casse 10 blocs", "desc": "Robuste et têtu, il adore les chantiers et le bruit des pierres.",
	"look": {"body": Color("a8aeb8"), "belly": Color("d4d8de"), "accent": Color("7d838d"), "shape": "round", "ears": "none", "tail": "none", "extra": "brows"},
	"lines": ["Toc toc ! Encore un bloc de cassé !", "J'aime le son des pierres qui roulent.", "Tu es costaud, toi !"]},
	{"id": "brindille", "name": "Brindille", "island": "prairie", "stat": "tree", "amount": 3,
	"req": "Fais pousser 3 arbres", "desc": "Un écureuil malicieux qui cache des glands dans chaque arbre.",
	"look": {"body": Color("c8814b"), "belly": Color("f3d6b0"), "accent": Color("9b5d33"), "shape": "tall", "ears": "pointy", "tail": "fluffy"},
	"lines": ["Chut... j'ai caché un gland dans cet arbre !", "Plus il y a d'arbres, plus je suis heureux.", "Tu as vu ma queue ? Elle est toute douce."]},
	{"id": "pomponette", "name": "Pomponette", "island": "prairie", "stat": "bloom", "amount": 30,
	"req": "Fais fleurir 30 fleurs", "desc": "Une lapine coquette qui ne sort que dans les prairies très fleuries.",
	"look": {"body": Color("f7c3d6"), "belly": Color("fff0f5"), "accent": Color("e889aa"), "shape": "tall", "ears": "long", "tail": "pompom"},
	"lines": ["Quelle jolie prairie !", "Je vais me faire une couronne de fleurs.", "Hop hop hop !"]},
	{"id": "charpenti", "name": "Charpenti", "island": "prairie", "stat": "place_7", "amount": 10,
	"req": "Pose 10 planches", "desc": "Un castor bâtisseur, toujours à la recherche d'un bon chantier.",
	"look": {"body": Color("b0723f"), "belly": Color("e8c49a"), "accent": Color("6b4428"), "shape": "long", "ears": "round", "tail": "flat"},
	"lines": ["Belles planches ! On construit une cabane ?", "Le bois, c'est la vie.", "J'ai des idées de maison plein la tête !"]},

	# --- Île Corail ---
	{"id": "crabouille", "name": "Crabouille", "island": "corail", "stat": "break", "amount": 15,
	"req": "Casse 15 blocs", "desc": "Un petit crabe qui creuse des trous partout sur la plage.",
	"look": {"body": Color("ef6b5b"), "belly": Color("ffd2c4"), "accent": Color("c44a3c"), "shape": "round", "ears": "claws", "tail": "none"},
	"lines": ["Clic clac ! Je creuse, je creuse !", "Le sable est tout chaud aujourd'hui.", "Tu as trouvé des coquillages ?"]},
	{"id": "plouf", "name": "Plouf", "island": "corail", "stat": "place_4", "amount": 15,
	"req": "Pose 15 blocs de sable", "desc": "Un phoque joueur qui adore les plages bien larges.",
	"look": {"body": Color("8fbfe6"), "belly": Color("e6f3ff"), "accent": Color("5f8fbf"), "shape": "long", "ears": "none", "tail": "fish"},
	"lines": ["Plouf ! L'eau est bonne !", "Encore un peu de sable et ce sera parfait.", "Je glisse, je glisse !"]},
	{"id": "coquillette", "name": "Coquillette", "island": "corail", "stat": "bloom", "amount": 15,
	"req": "Fais fleurir 15 fleurs", "desc": "Elle porte un coquillage rose et fredonne avec le ressac.",
	"look": {"body": Color("ffd9a8"), "belly": Color("fff4e2"), "accent": Color("f49ab8"), "shape": "round", "ears": "none", "tail": "none", "extra": "shell"},
	"lines": ["Écoute... on entend la mer dans mon coquillage.", "Les fleurs de plage sont les plus belles.", "La la la ~"]},
	{"id": "palmi", "name": "Palmi", "island": "corail", "stat": "tree", "amount": 4,
	"req": "Fais pousser 4 arbres", "desc": "Toujours à l'ombre d'un palmier, une noix de coco à la main.",
	"look": {"body": Color("f6d55c"), "belly": Color("fff3c0"), "accent": Color("6ccb4a"), "shape": "tall", "ears": "palm", "tail": "thin"},
	"lines": ["Rien de tel que l'ombre d'un palmier.", "Tu veux une noix de coco ?", "Ahhh, les vacances..."]},
	{"id": "tortulo", "name": "Tortulo", "island": "corail", "stat": "place", "amount": 40,
	"req": "Pose 40 blocs", "desc": "Une vieille tortue sage qui admire les grandes constructions.",
	"look": {"body": Color("7fc48f"), "belly": Color("e4f2d0"), "accent": Color("a5733f"), "shape": "long", "ears": "none", "tail": "thin", "extra": "carapace"},
	"lines": ["Tout doux... rien ne presse.", "Tes constructions sont magnifiques.", "J'ai vu cette île naître, tu sais."]},

	# --- Île Givrée ---
	{"id": "flocon", "name": "Flocon", "island": "givree", "stat": "place_9", "amount": 15,
	"req": "Pose 15 blocs de neige", "desc": "Un renard des neiges discret qui aime les congères moelleuses.",
	"look": {"body": Color("f4f8ff"), "belly": Color("ffffff"), "accent": Color("b8c8e8"), "shape": "long", "ears": "pointy", "tail": "fluffy"},
	"lines": ["La neige craque sous mes pattes...", "Tu as froid ? Moi jamais !", "Faisons un bonhomme de neige !"]},
	{"id": "pingouille", "name": "Pingouille", "island": "givree", "stat": "break", "amount": 25,
	"req": "Casse 25 blocs", "desc": "Un pingouin maladroit qui glisse sur tout ce qui bouge.",
	"look": {"body": Color("34466e"), "belly": Color("f4f6fb"), "accent": Color("f5a43a"), "shape": "tall", "ears": "none", "tail": "none", "extra": "beak"},
	"lines": ["Woups ! J'ai encore glissé.", "La glace, c'est mon terrain de jeu !", "Tu veux faire une course ?"]},
	{"id": "givrou", "name": "Givrou", "island": "givree", "stat": "place_10", "amount": 10,
	"req": "Pose 10 blocs de glace", "desc": "Un ourson cristallin dont la fourrure scintille au soleil.",
	"look": {"body": Color("a8ddf0"), "belly": Color("e6f8ff"), "accent": Color("6fb6d6"), "shape": "tall", "ears": "round", "tail": "none"},
	"lines": ["Brrr... c'est parfait !", "Regarde comme la glace brille.", "Un câlin glacé ?"]},
	{"id": "sapinou", "name": "Sapinou", "island": "givree", "stat": "tree", "amount": 5,
	"req": "Fais pousser 5 arbres", "desc": "Il ressemble à un petit sapin et sent bon la résine.",
	"look": {"body": Color("3f9a68"), "belly": Color("bfe6c8"), "accent": Color("8a5a3b"), "shape": "round", "ears": "pine", "tail": "none"},
	"lines": ["Une vraie forêt de sapins !", "J'adore l'odeur de la résine.", "Les arbres me tiennent chaud."]},
	{"id": "moufle", "name": "Moufle", "island": "givree", "stat": "bloom", "amount": 25,
	"req": "Fais fleurir 25 fleurs", "desc": "Une boule de poils lavande qui réchauffe les fleurs des neiges.",
	"look": {"body": Color("c7b2f0"), "belly": Color("efe8ff"), "accent": Color("9a7fd6"), "shape": "round", "ears": "round", "tail": "pompom", "extra": "fluff"},
	"lines": ["Des fleurs dans la neige ? Magique !", "Je suis toute douce, touche !", "Mmmh... chaud..."]},

	# --- Île Braise ---
	{"id": "flammeche", "name": "Flammèche", "island": "braise", "stat": "place_11", "amount": 15,
	"req": "Pose 15 blocs de basalte", "desc": "Un petit lézard dont la queue brûle d'une flamme douce.",
	"look": {"body": Color("f28c3c"), "belly": Color("ffe0a8"), "accent": Color("d4602a"), "shape": "tall", "ears": "none", "tail": "flame"},
	"lines": ["Ma flamme ne brûle que les mauvaises idées !", "Le basalte est encore tiède.", "Fsshhh !"]},
	{"id": "magmi", "name": "Magmi", "island": "braise", "stat": "break", "amount": 30,
	"req": "Casse 30 blocs", "desc": "Une boule de roche en fusion, gentille mais un peu brusque.",
	"look": {"body": Color("c9483a"), "belly": Color("ffb05a"), "accent": Color("4a4550"), "shape": "round", "ears": "horns", "tail": "none"},
	"lines": ["BOUM ! Haha, je plaisante.", "J'aime quand ça chauffe !", "Casse, casse, casse !"]},
	{"id": "cendre", "name": "Cendre", "island": "braise", "stat": "place_8", "amount": 15,
	"req": "Pose 15 briques", "desc": "Une chatte grise qui adore les maisons en brique bien chaudes.",
	"look": {"body": Color("8d8a96"), "belly": Color("d8d6de"), "accent": Color("5e5b66"), "shape": "long", "ears": "pointy", "tail": "thin"},
	"lines": ["Une maison en brique... rrrr.", "Je fais la sieste près du feu.", "Miaou ?"]},
	{"id": "feuillou", "name": "Feuillou", "island": "braise", "stat": "tree", "amount": 5,
	"req": "Fais pousser 5 arbres", "desc": "Il porte une feuille d'érable et danse avec le vent d'automne.",
	"look": {"body": Color("f0a64a"), "belly": Color("fde4b8"), "accent": Color("d4542a"), "shape": "round", "ears": "leaf", "tail": "none"},
	"lines": ["Les feuilles tombent, tombent...", "L'automne est ma saison préférée.", "Tu veux danser ?"]},
	{"id": "braisette", "name": "Braisette", "island": "braise", "stat": "bloom", "amount": 30,
	"req": "Fais fleurir 30 fleurs", "desc": "Une lapine au pelage de braise, elle fait fleurir les cendres.",
	"look": {"body": Color("e8665a"), "belly": Color("ffd8c8"), "accent": Color("ffb05a"), "shape": "tall", "ears": "long", "tail": "pompom"},
	"lines": ["Même les volcans aiment les fleurs !", "Tu sens cette chaleur ?", "Hop ! Hop !"]},

	# --- Gacha ---
	{"id": "nuagelle", "name": "Nuagelle", "island": "", "rarity": COMMON, "desc": "Un mouton-nuage qui flotte un peu quand il est content.",
	"look": {"body": Color("ffffff"), "belly": Color("f4f4f8"), "accent": Color("6d6680"), "shape": "long", "ears": "round", "tail": "pompom", "extra": "fluff"},
	"lines": ["Bêêê ~", "Je flotte, je flotte...", "Tu veux un câlin tout doux ?"]},
	{"id": "miellat", "name": "Miellat", "island": "", "rarity": COMMON, "desc": "Un ourson gourmand qui sent toujours le miel.",
	"look": {"body": Color("f2b84b"), "belly": Color("ffe9b0"), "accent": Color("b07a2a"), "shape": "tall", "ears": "round", "tail": "none"},
	"lines": ["Tu n'aurais pas du miel ?", "Miam miam.", "Les abeilles sont mes amies."]},
	{"id": "ronron", "name": "Ronron", "island": "", "rarity": COMMON, "desc": "Un chat paresseux qui dort partout.",
	"look": {"body": Color("f5d2a8"), "belly": Color("fff4e6"), "accent": Color("d08a4a"), "shape": "long", "ears": "pointy", "tail": "thin"},
	"lines": ["Zzz... hein ?", "Rrrrr...", "Une sieste au soleil ?"]},
	{"id": "gribouille", "name": "Gribouille", "island": "", "rarity": COMMON, "desc": "Une grenouille artiste qui peint avec sa langue.",
	"look": {"body": Color("9b7fd6"), "belly": Color("e8dcff"), "accent": Color("f7d046"), "shape": "round", "ears": "eyes_top", "tail": "none"},
	"lines": ["Croâ ! Tu aimes l'art ?", "Je vais peindre ton portrait.", "Splash !"]},
	{"id": "bouillotte", "name": "Bouillotte", "island": "", "rarity": COMMON, "desc": "Un petit chiot tout chaud qui aime les câlins.",
	"look": {"body": Color("e8c9a0"), "belly": Color("fff4e2"), "accent": Color("8a5a3b"), "shape": "long", "ears": "floppy", "tail": "thin"},
	"lines": ["Ouaf !", "Tu veux jouer à la balle ?", "Je suis tout chaud !"]},
	{"id": "etincelle", "name": "Étincelle", "island": "", "rarity": RARE, "desc": "Une souris électrique qui fait clignoter les lucioles.",
	"look": {"body": Color("5fd0c4"), "belly": Color("e0fff9"), "accent": Color("f7d046"), "shape": "tall", "ears": "round", "tail": "zigzag"},
	"lines": ["Bzzt ! Pardon, ça m'a échappé.", "Les lucioles sont mes cousines.", "Je suis plein d'énergie !"]},
	{"id": "champi", "name": "Champi", "island": "", "rarity": RARE, "desc": "Un champignon timide qui pousse après la pluie.",
	"look": {"body": Color("fff0dc"), "belly": Color("ffffff"), "accent": Color("e8505b"), "shape": "round", "ears": "cap", "tail": "none"},
	"lines": ["Il va pleuvoir bientôt, je le sens.", "Je suis un peu timide...", "Pas touche à mon chapeau !"]},
	{"id": "ondine", "name": "Ondine", "island": "", "rarity": RARE, "desc": "Une sirène miniature qui chante avec les vagues.",
	"look": {"body": Color("6ea8f5"), "belly": Color("dceaff"), "accent": Color("f59ac2"), "shape": "tall", "ears": "fin", "tail": "fish"},
	"lines": ["La la la ~", "L'océan est si vaste...", "Tu veux entendre une chanson ?"]},
	{"id": "aquarelle", "name": "Aquarelle", "island": "", "rarity": RARE, "desc": "Un caméléon dont les couleurs changent avec son humeur.",
	"look": {"body": Color("f59ac2"), "belly": Color("a8ddf0"), "accent": Color("f7d046"), "shape": "long", "ears": "none", "tail": "curl"},
	"lines": ["Aujourd'hui je suis rose, demain qui sait ?", "Les couleurs, c'est la joie !", "Tu me vois ? Et maintenant ?"]},
	{"id": "celeste", "name": "Céleste", "island": "", "rarity": LEGENDARY, "desc": "Une créature légendaire née d'une étoile filante.",
	"look": {"body": Color("fdf6e3"), "belly": Color("ffffff"), "accent": Color("f5c842"), "shape": "tall", "ears": "star", "tail": "fluffy", "extra": "halo"},
	"lines": ["Je viens de très, très loin...", "Fais un vœu !", "Les étoiles t'ont vu travailler."]},
	{"id": "aurora", "name": "Aurora", "island": "", "rarity": LEGENDARY, "desc": "Elle danse dans les aurores boréales des nuits polaires.",
	"look": {"body": Color("b8f0e0"), "belly": Color("ffffff"), "accent": Color("f59ac2"), "shape": "long", "ears": "fin", "tail": "fluffy", "extra": "halo"},
	"lines": ["As-tu déjà vu le ciel danser ?", "Les couleurs du nord sont en moi.", "Quel calme, ici..."]},
	{"id": "sylvestre", "name": "Sylvestre", "island": "", "rarity": LEGENDARY, "desc": "Le gardien des forêts, des bois d'arbre sur la tête.",
	"look": {"body": Color("e8d4b0"), "belly": Color("fff8ea"), "accent": Color("7bc95a"), "shape": "long", "ears": "antlers", "tail": "pompom"},
	"lines": ["Chaque arbre que tu plantes me rend plus fort.", "La forêt te remercie.", "Écoute le vent dans les feuilles."]},
]

## PNJ guide du tutoriel (pas collectable).
const GUIDE := {"id": "guide", "name": "Pr. Hibou",
	"look": {"body": Color("a0794f"), "belly": Color("f0dcb8"), "accent": Color("6b4a2e"), "shape": "round", "ears": "tufts", "tail": "none", "extra": "glasses"}}


static func get_creature(id: String) -> Dictionary:
	if id == "guide":
		return GUIDE
	for c in ALL:
		if c["id"] == id:
			return c
	return {}


static func island_creatures(island_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in ALL:
		if c["island"] == island_id:
			out.append(c)
	return out


static func gacha_pool(rarity: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in ALL:
		if c["island"] == "" and c.get("rarity", COMMON) == rarity:
			out.append(c)
	return out


static func gacha_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in ALL:
		if c["island"] == "":
			out.append(c)
	return out
