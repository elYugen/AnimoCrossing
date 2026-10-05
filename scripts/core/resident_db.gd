class_name ResidentDB
extends RefCounted
## Les habitants : des humains attirés par l'environnement de l'île
## (forêt, jardins, mer, montagne, village).

# look : body, belly, accent, shape (round/tall/long), ears, tail, extra, size
static var ALL: Array[Dictionary] = [
	# --- Habitants (humains) : ils arrivent selon l'environnement ---
	{"id": "sylvain", "name": "Sylvain", "habitat": "forest", "desc": "Un bûcheron au grand cœur qui ne coupe jamais un arbre sans en replanter deux.",
	"look": {"skin": "d", "head": "b"},
	"lines": ["Un arbre coupé, deux arbres plantés. C'est ma règle.", "Rien ne vaut l'odeur du bois frais.", "Cette forêt a bien grandi, dis donc !"]},
	{"id": "maelle", "name": "Maëlle", "habitat": "forest", "desc": "Elle connaît chaque baie et chaque champignon des sous-bois.",
	"look": {"skin": "k", "head": "g"},
	"lines": ["J'ai trouvé des myrtilles près du ruisseau !", "Les bois sont pleins de trésors, il suffit de regarder.", "Tu veux que je te montre un coin à champignons ?"]},
	{"id": "basile", "name": "Basile", "habitat": "forest", "desc": "Il veille sur les arbres comme sur de vieux amis.",
	"look": {"skin": "r", "head": "l"},
	"lines": ["Je fais ma ronde : tout va bien dans les bois.", "Plante encore quelques arbres, la forêt te le rendra.", "Écoute... c'est le vent dans les feuilles."]},
	{"id": "iris", "name": "Iris", "habitat": "forest", "desc": "Elle prépare des tisanes avec les plantes de la forêt.",
	"look": {"skin": "g", "head": "q"},
	"lines": ["Une petite tisane ? C'est bon pour le moral.", "Chaque plante a son secret.", "La forêt est une vraie pharmacie !"]},
	{"id": "lucien", "name": "Lucien", "habitat": "forest", "desc": "Il taille de petites figurines dans les branches tombées.",
	"look": {"skin": "n", "head": "d"},
	"lines": ["Regarde, j'ai sculpté un petit écureuil.", "Une branche tombée, c'est une histoire qui commence.", "Le bois a toujours quelque chose à dire."]},
	{"id": "capucine", "name": "Capucine", "habitat": "forest", "desc": "Carnet en main, elle répertorie toutes les espèces de l'île.",
	"look": {"skin": "c", "head": "i"},
	"lines": ["J'ai noté trois nouvelles espèces aujourd'hui !", "Cette île est un paradis pour une botaniste.", "Tu savais que les arbres communiquent par leurs racines ?"]},
	{"id": "rose", "name": "Rose", "habitat": "garden", "desc": "Elle a les mains vertes et le sourire toujours fleuri.",
	"look": {"skin": "j", "head": "n"},
	"lines": ["Ces fleurs sentent si bon...", "Un jardin, c'est de la patience et beaucoup d'amour.", "Tu veux qu'on plante encore plus de fleurs ?"]},
	{"id": "hugo", "name": "Hugo", "habitat": "garden", "desc": "Il élève des abeilles et récolte le meilleur miel de l'archipel.",
	"look": {"skin": "q", "head": "a"},
	"lines": ["Mes abeilles adorent tes fleurs !", "Un peu de miel ? Il est tout frais.", "Plus il y a de fleurs, plus les abeilles sont heureuses."]},
	{"id": "leonie", "name": "Léonie", "habitat": "garden", "desc": "Elle compose des bouquets pour tous les habitants de l'île.",
	"look": {"skin": "f", "head": "f"},
	"lines": ["Je te prépare un bouquet ?", "Les couleurs de cette île me donnent plein d'idées.", "Une fleur par jour, et tout va mieux."]},
	{"id": "jules", "name": "Jules", "habitat": "garden", "desc": "Ses carottes sont les plus croquantes de toute l'île.",
	"look": {"skin": "m", "head": "k"},
	"lines": ["Tu as vu mes carottes ? Énormes !", "Un bon potager, c'est la base.", "Avec ces légumes, on va bien manger cet hiver."]},
	{"id": "margot", "name": "Margot", "habitat": "garden", "desc": "Elle rêve de transformer l'île en un immense jardin.",
	"look": {"skin": "b", "head": "p"},
	"lines": ["Ici, je verrais bien une allée de fleurs.", "Un jardin, c'est un tableau vivant.", "Cette île a tellement de potentiel !"]},
	{"id": "victor", "name": "Victor", "habitat": "garden", "desc": "Il sème, arrose et récolte du lever au coucher du soleil.",
	"look": {"skin": "i", "head": "c"},
	"lines": ["Le soleil, l'eau et un peu de patience.", "La terre est bonne par ici.", "Encore quelques potagers et on sera autonomes !"]},
	{"id": "marin", "name": "Marin", "habitat": "marine", "desc": "Patient comme personne au bord de l'eau.",
	"look": {"skin": "p", "head": "h"},
	"lines": ["Chut... ça mord !", "L'eau est si claire depuis que tu l'as nettoyée.", "Un jour, j'attraperai le poisson légendaire."]},
	{"id": "coralie", "name": "Coralie", "habitat": "marine", "desc": "Elle explore les fonds marins autour de l'île.",
	"look": {"skin": "e", "head": "m"},
	"lines": ["J'ai vu des poissons multicolores près des ruines !", "Sous l'eau, tout est calme.", "Les vieilles colonnes cachent sûrement des secrets."]},
	{"id": "yann", "name": "Yann", "habitat": "marine", "desc": "Un vieux loup de mer qui a fait le tour de l'archipel.",
	"look": {"skin": "l", "head": "r"},
	"lines": ["J'ai connu des tempêtes bien pires que la tienne.", "La mer est capricieuse, mais généreuse.", "Un jour, on construira un vrai port ici."]},
	{"id": "perle", "name": "Perle", "habitat": "marine", "desc": "Elle fabrique des colliers avec ce que la mer rapporte.",
	"look": {"skin": "a", "head": "e"},
	"lines": ["Regarde ce coquillage, il brille !", "La plage est bien plus jolie sans déchets.", "Je te fais un collier ?"]},
	{"id": "gaspard", "name": "Gaspard", "habitat": "marine", "desc": "Son bateau a fait naufrage, comme le tien... il est resté.",
	"look": {"skin": "h", "head": "j"},
	"lines": ["Nous sommes deux naufragés, toi et moi !", "Une île comme celle-ci, ça ne se quitte pas.", "Un bon capitaine sait quand jeter l'ancre."]},
	{"id": "nina", "name": "Nina", "habitat": "marine", "desc": "Elle attend la vague parfaite depuis des semaines.",
	"look": {"skin": "o", "head": "o"},
	"lines": ["Les vagues sont belles aujourd'hui !", "Le sable est tout propre, c'est génial.", "Tu veux apprendre à surfer ?"]},
	{"id": "pierre", "name": "Pierre", "habitat": "mountain", "desc": "Il taille la roche avec une précision incroyable.",
	"look": {"skin": "d", "head": "b"},
	"lines": ["Cette pierre est de très bonne qualité.", "La montagne, c'est solide comme un roc.", "Tu as besoin de pierres ? Je suis ton homme."]},
	{"id": "solene", "name": "Solène", "habitat": "mountain", "desc": "Rien ne lui plaît plus qu'un sommet à gravir.",
	"look": {"skin": "k", "head": "g"},
	"lines": ["La vue d'en haut est incroyable !", "Plus c'est haut, plus c'est beau.", "Tu as aménagé la montagne ? Génial !"]},
	{"id": "bastien", "name": "Bastien", "habitat": "mountain", "desc": "Il mène ses chèvres sur les pentes de la montagne.",
	"look": {"skin": "r", "head": "l"},
	"lines": ["Mes chèvres adorent l'herbe des hauteurs.", "L'air de la montagne, rien de tel.", "Un bon berger connaît chaque sentier."]},
	{"id": "alix", "name": "Alix", "habitat": "mountain", "desc": "Elle connaît chaque sentier et chaque cachette des sommets.",
	"look": {"skin": "g", "head": "q"},
	"lines": ["Je peux te montrer un raccourci vers le sommet.", "Toujours prévoir une écharpe là-haut.", "La montagne se mérite."]},
	{"id": "roch", "name": "Roch", "habitat": "mountain", "desc": "Un costaud qui creuse à la recherche de minéraux rares.",
	"look": {"skin": "n", "head": "d"},
	"lines": ["Toc toc ! J'ai trouvé un joli cristal.", "Il y a des trésors sous nos pieds.", "Le travail de la pierre, ça forge le caractère."]},
	{"id": "elsa", "name": "Elsa", "habitat": "mountain", "desc": "Elle parcourt l'île avec son grand sac à dos.",
	"look": {"skin": "c", "head": "i"},
	"lines": ["J'ai fait le tour de l'île ce matin !", "Les chemins de montagne sont les plus beaux.", "Une bonne marche, et tout va mieux."]},
	{"id": "marjolaine", "name": "Marjolaine", "habitat": "village", "desc": "Elle rêve d'ouvrir une boutique au cœur du village.",
	"look": {"skin": "j", "head": "n"},
	"lines": ["Un village qui grandit, c'est bon pour les affaires !", "Bientôt, j'ouvrirai ma boutique ici.", "Tu as besoin de quelque chose ?"]},
	{"id": "gustave", "name": "Gustave", "habitat": "village", "desc": "Il mijote de bons petits plats sur les feux de camp.",
	"look": {"skin": "q", "head": "a"},
	"lines": ["Rien de tel qu'un bon feu pour mijoter une soupe !", "Tu as faim ? J'ai fait une tarte aux fruits.", "Avec les légumes du potager, je vais me régaler."]},
	{"id": "armand", "name": "Armand", "habitat": "village", "desc": "Un bâtisseur toujours à la recherche d'un nouveau chantier.",
	"look": {"skin": "f", "head": "f"},
	"lines": ["Belles constructions ! On fait une cabane ?", "Le bois, c'est la vie.", "J'ai des idées de maisons plein la tête !"]},
	{"id": "odette", "name": "Odette", "habitat": "village", "desc": "Son pain chaud embaume tout le village au petit matin.",
	"look": {"skin": "m", "head": "k"},
	"lines": ["Du pain tout chaud, ça te dit ?", "Il me faudrait un vrai four...", "Le matin, c'est le meilleur moment de la journée."]},
	{"id": "felix", "name": "Félix", "habitat": "village", "desc": "Il répare les outils et rêve d'une vraie forge.",
	"look": {"skin": "b", "head": "p"},
	"lines": ["Ton outil est vraiment étrange... et fascinant.", "Le feu, le fer et un bon marteau.", "Si tu trouves du métal, apporte-le-moi !"]},
	{"id": "louise", "name": "Louise", "habitat": "village", "desc": "Elle coud des vêtements pour tous les habitants.",
	"look": {"skin": "i", "head": "c"},
	"lines": ["Je t'ai fait une écharpe, tu veux l'essayer ?", "Un bon tissu, ça change tout.", "Ce village a besoin de couleurs !"]},
]

static func get_resident(id: String) -> Dictionary:
	for c in ALL:
		if c["id"] == id:
			return c
	return {}


const HABITATS := ["forest", "garden", "marine", "mountain", "village"]
const HABITAT_NAMES := {"forest": "Forêt", "garden": "Jardins", "marine": "Mer & plage", "mountain": "Montagne", "village": "Village"}


## Ce personnage peut-il s'installer sur cette île ?
static func can_live_on(c: Dictionary, island_id: String) -> bool:
	var b: Array = c.get("biomes", [])
	return b.is_empty() or island_id in b


## Habitants susceptibles de venir sur une île.
static func island_residents(island_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in ALL:
		if can_live_on(c, island_id):
			out.append(c)
	return out


static func habitat_residents(h: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in ALL:
		if c.get("habitat", "") == h:
			out.append(c)
	return out
