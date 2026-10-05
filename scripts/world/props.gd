class_name Props
extends Node3D
## Objets 3D posés sur l'île voxel (arbres, épave, ruines, feux de camp,
## potagers...) : modèles Kenney (CC0). Les sols restent en voxels.
## Les objets générés sont recréés à chaque chargement de l'île (clé "g:...") ;
## ceux ajoutés ou retirés par le joueur sont sauvegardés dans Game.

const LAYER := 2  # couche physique 2 : visée des objets au viseur
const DIR := "res://assets/models/%s.glb"

## model : chemin sous assets/models ; scale : échelle de base ;
## shape : "trunk" (cylindre), "box" (boîte englobante) ou "none" ;
## tree : compte comme un arbre ; cut : peut être retiré avec l'outil.
const KINDS := {
	# Arbres : Fantasy Town & Survival (feuillus), Pirate (palmiers), Holiday (sapins)
	"town_tree": {"model": "town/tree", "scale": 2.4, "shape": "trunk", "tree": true, "cut": true},
	"town_crooked": {"model": "town/tree-crooked", "scale": 2.4, "shape": "trunk", "tree": true, "cut": true},
	"town_high": {"model": "town/tree-high", "scale": 2.2, "shape": "trunk", "tree": true, "cut": true},
	"town_round": {"model": "town/tree-high-round", "scale": 2.3, "shape": "trunk", "tree": true, "cut": true},
	"town_high_crooked": {"model": "town/tree-high-crooked", "scale": 2.2, "shape": "trunk", "tree": true, "cut": true},
	"survival_tree": {"model": "survival/tree", "scale": 4.0, "shape": "trunk", "tree": true, "cut": true},
	"survival_tall": {"model": "survival/tree-tall", "scale": 3.8, "shape": "trunk", "tree": true, "cut": true},
	"autumn": {"model": "survival/tree-autumn", "scale": 4.0, "shape": "trunk", "tree": true, "cut": true},
	"autumn_tall": {"model": "survival/tree-autumn-tall", "scale": 3.8, "shape": "trunk", "tree": true, "cut": true},
	"palm": {"model": "pirate/palm-straight", "scale": 1.4, "shape": "trunk", "tree": true, "cut": true},
	"palm_bend": {"model": "pirate/palm-bend", "scale": 1.4, "shape": "trunk", "tree": true, "cut": true},
	"palm_detailed": {"model": "pirate/palm-detailed-straight", "scale": 1.4, "shape": "trunk", "tree": true, "cut": true},
	"palm_detailed_bend": {"model": "pirate/palm-detailed-bend", "scale": 1.4, "shape": "trunk", "tree": true, "cut": true},
	"pine": {"model": "holiday/pine", "scale": 3.2, "shape": "trunk", "tree": true, "cut": true},
	"pine_snow_a": {"model": "holiday/tree-snow-a", "scale": 3.2, "shape": "trunk", "tree": true, "cut": true},
	"pine_snow_b": {"model": "holiday/tree-snow-b", "scale": 3.1, "shape": "trunk", "tree": true, "cut": true},
	"pine_snow_c": {"model": "holiday/tree-snow-c", "scale": 3.2, "shape": "trunk", "tree": true, "cut": true},
	# Petite végétation
	"bush": {"model": "nature/plant_bush", "scale": 3.0, "shape": "none"},
	"bush_large": {"model": "nature/plant_bushLarge", "scale": 3.4, "shape": "none"},
	"stump": {"model": "nature/stump_round", "scale": 3.0, "shape": "trunk", "cut": true},
	"log": {"model": "nature/log", "scale": 3.0, "shape": "box"},
	"mushroom": {"model": "nature/mushroom_red", "scale": 3.0, "shape": "none"},
	"lily": {"model": "nature/lily_large", "scale": 3.0, "shape": "none"},
	# Constructions fabriquées par le joueur (structure : se reprend dans l'inventaire)
	"campfire": {"model": "survival/campfire-pit", "scale": 4.0, "shape": "none", "structure": true, "fire": true},
	"garden": {"model": "nature/crops_dirtRow", "scale": 1.0, "shape": "none", "structure": true,
		"extra": [["nature/crop_carrot", Vector3(-0.3, 0, 0)], ["nature/crops_leafsStageB", Vector3(0, 0, 0)], ["nature/crop_carrot", Vector3(0.3, 0, 0)]]},
	"fence_low": {"model": "houses/fence-low", "scale": 3.0, "shape": "box", "structure": true},
	"planter": {"model": "houses/planter", "scale": 3.5, "shape": "box", "structure": true},
	"bench": {"model": "town/stall-bench", "scale": 3.0, "shape": "box", "structure": true},
	"lantern": {"model": "town/lantern", "scale": 2.0, "shape": "box", "structure": true, "light": true},
	"stall": {"model": "town/stall-red", "scale": 2.6, "shape": "box", "structure": true, "site": true},
	"cart": {"model": "town/cart", "scale": 2.6, "shape": "box", "structure": true, "site": true},
	"fountain": {"model": "town/fountain-round", "scale": 2.2, "shape": "box", "structure": true, "site": true},
	# Maisons (City Kit Suburban) : on peut y entrer (voir Interior).
	"house_a": {"model": "houses/building-type-a", "scale": 5.0, "shape": "box", "structure": true, "house": true, "site": true},
	"house_b": {"model": "houses/building-type-b", "scale": 5.0, "shape": "box", "structure": true, "house": true, "site": true},
	"house_c": {"model": "houses/building-type-c", "scale": 5.0, "shape": "box", "structure": true, "house": true, "site": true},
	"house_f": {"model": "houses/building-type-f", "scale": 5.0, "shape": "box", "structure": true, "house": true, "site": true},
	"house_h": {"model": "houses/building-type-h", "scale": 5.0, "shape": "box", "structure": true, "house": true, "site": true},
	"house_k": {"model": "houses/building-type-k", "scale": 5.0, "shape": "box", "structure": true, "house": true, "site": true},
	"house_n": {"model": "houses/building-type-n", "scale": 5.0, "shape": "box", "structure": true, "house": true, "site": true},
	"house_p": {"model": "houses/building-type-p", "scale": 5.0, "shape": "box", "structure": true, "house": true, "site": true},
	# Campement abandonné (Survival Kit)
	"tent": {"model": "survival/tent-canvas", "scale": 6.5, "shape": "box"},
	"bedroll": {"model": "survival/bedroll", "scale": 4.5, "shape": "none"},
	"workbench": {"model": "survival/workbench", "scale": 5.5, "shape": "box", "structure": true, "craft": true},
	"box": {"model": "survival/box", "scale": 4.5, "shape": "box"},
	"box_large": {"model": "survival/box-large", "scale": 4.5, "shape": "box"},
	"barrel_old": {"model": "survival/barrel", "scale": 4.5, "shape": "box"},
	"campfire_old": {"model": "survival/campfire-pit", "scale": 4.0, "shape": "none"},
	"signpost": {"model": "survival/signpost", "scale": 4.5, "shape": "box"},
	# Épave et objets échoués (Pirate Kit)
	"wreck": {"model": "pirate/ship-wreck", "scale": 1.0, "shape": "none"},
	"crate": {"model": "pirate/crate", "scale": 0.75, "shape": "box"},
	"barrel": {"model": "pirate/barrel", "scale": 0.6, "shape": "box"},
	"rowboat": {"model": "pirate/boat-row-small", "scale": 0.9, "shape": "box"},
	# Ruines (Nature Kit + Fantasy Town Kit)
	"column": {"model": "nature/statue_column", "scale": 5.0, "shape": "trunk", "demolish": {"cut_stone": 2}},
	"column_broken": {"model": "nature/statue_columnDamaged", "scale": 5.0, "shape": "trunk", "demolish": {"cut_stone": 2}},
	"statue_head": {"model": "nature/statue_head", "scale": 4.0, "shape": "box", "demolish": {"cut_stone": 3}},
	"obelisk": {"model": "nature/statue_obelisk", "scale": 5.0, "shape": "trunk", "demolish": {"cut_stone": 2}},
	"wall_broken": {"model": "town/wall-broken", "scale": 2.0, "shape": "box", "demolish": {"stone": 2, "cut_stone": 1}},
	"wall_half": {"model": "town/wall-half", "scale": 2.0, "shape": "box", "demolish": {"stone": 1, "cut_stone": 1}},
	"wall_wood_broken": {"model": "town/wall-wood-broken", "scale": 2.0, "shape": "box", "demolish": {"beam": 1, "branch": 2}},
	"pillar": {"model": "town/pillar-stone", "scale": 2.6, "shape": "box", "demolish": {"cut_stone": 1}},
	"fence_broken": {"model": "town/fence-broken", "scale": 2.0, "shape": "box"},
	"rock_large": {"model": "town/rock-large", "scale": 1.3, "shape": "box"},
	# Éboulement : mur haut et infranchissable tant que la zone est fermée.
	"barrier_rock": {"model": "town/rock-large", "scale": 2.4, "shape": "wall"},
	# Animaux (miniatures du carnet uniquement)
	"pet_deer": {"model": "pets/animal-deer", "scale": 1.0, "shape": "none"},
	"pet_fox": {"model": "pets/animal-fox", "scale": 1.0, "shape": "none"},
	"pet_beaver": {"model": "pets/animal-beaver", "scale": 1.0, "shape": "none"},
	"pet_hog": {"model": "pets/animal-hog", "scale": 1.0, "shape": "none"},
	"pet_bunny": {"model": "pets/animal-bunny", "scale": 1.0, "shape": "none"},
	"pet_bee": {"model": "pets/animal-bee", "scale": 1.0, "shape": "none"},
	"pet_chick": {"model": "pets/animal-chick", "scale": 1.0, "shape": "none"},
	"pet_caterpillar": {"model": "pets/animal-caterpillar", "scale": 1.0, "shape": "none"},
	"pet_crab": {"model": "pets/animal-crab", "scale": 1.0, "shape": "none"},
	"pet_parrot": {"model": "pets/animal-parrot", "scale": 1.0, "shape": "none"},
	"pet_penguin": {"model": "pets/animal-penguin", "scale": 1.0, "shape": "none"},
	"pet_panda": {"model": "pets/animal-panda", "scale": 1.0, "shape": "none"},
	"pet_polar": {"model": "pets/animal-polar", "scale": 1.0, "shape": "none"},
	"pet_cat": {"model": "pets/animal-cat", "scale": 1.0, "shape": "none"},
	"pet_dog": {"model": "pets/animal-dog", "scale": 1.0, "shape": "none"},
	"pet_pig": {"model": "pets/animal-pig", "scale": 1.0, "shape": "none"},
	"pet_cow": {"model": "pets/animal-cow", "scale": 1.0, "shape": "none"},
}

## Arbres par biome.
const TREES := {
	"prairie": ["town_tree", "town_crooked", "town_high", "town_round", "town_high_crooked", "survival_tree", "survival_tall"],
	"plage": ["palm", "palm_bend", "palm_detailed", "palm_detailed_bend"],
	"givre": ["pine", "pine_snow_a", "pine_snow_b", "pine_snow_c"],
	"braise": ["autumn", "autumn_tall", "autumn", "town_crooked", "town_high_crooked"],
}

## Couleurs du Nature Kit ramenées à la palette des blocs voxel.
const PALETTE := {
	"leafsGreen": Color("5cbb52"), "leafsDark": Color("3f9a4a"), "leafsFall": Color("f29a45"),
	"grass": Color("7bc95a"), "woodBark": Color("8a5a3b"), "woodBarkDark": Color("6b4430"),
	"woodInner": Color("d8b48a"), "woodBirch": Color("efe6d6"), "dirt": Color("a9784e"),
	"woodDark": Color("8a5a3b"),
	"dirtDark": Color("7a5236"), "stone": Color("a7adb5"), "stoneDark": Color("8a9098"),
	"colorRed": Color("e8584a"),
	# Furniture Kit
	"wood": Color("c99d6c"), "carpet": Color("e8889a"), "carpetDarker": Color("c26d7f"),
	"carpetWhite": Color("f3ece0"), "plant": Color("5cbb52"), "metal": Color("b8c2c6"),
	"metalLight": Color("e6ecee"), "metalDark": Color("5d6a6e"), "metalMedium": Color("8a9698"),
	"glass": Color("bfe8f7"), "lamp": Color("fff1b8"),
}

static var _scenes := {}
static var _aabbs := {}

var items := {}  # id -> {"kind", "node", "key", "pos", "rot", "scale"}
## Monde voxel : sert à poser les objets sur le vrai sol.
var world: VoxelWorld
## Appelé quand un objet est posé (id, 1) ou retiré (id, 0) : la navigation suit.
var on_change := Callable()
## Objets volontairement à moitié immergés : on ne les recale pas sur le sol.
const NO_SNAP := ["wreck", "lily"]
## Objets naturels qu'on laisse s'enfoncer dans les pentes.
const EMBED := ["barrier_rock", "rock_large", "log", "stump", "statue_head", "fence_broken"]
var _next_id := 1
var _island := ""


static func scene(model: String) -> PackedScene:
	if not _scenes.has(model):
		var sc := load(DIR % model) as PackedScene
		if sc:
			fix_materials(sc)
		_scenes[model] = sc
	return _scenes[model]


## Les glTF de Kenney ne précisent pas « metallic », qui vaut alors 1 :
## les modèles reflètent le ciel et virent au bleu. On les rend mats.
static func fix_materials(sc: PackedScene) -> void:
	var inst := sc.instantiate()
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh := (n as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as BaseMaterial3D
			if m:
				if PALETTE.has(m.resource_name):
					m.albedo_color = PALETTE[m.resource_name]
				m.metallic = 0.0
				m.metallic_specular = 0.25
				m.roughness = maxf(m.roughness, 0.85)
	inst.free()


## Instancie le modèle d'un type d'objet (sans collision), à l'échelle.
static func make_model(kind: String, scale_mul := 1.0) -> Node3D:
	var def: Dictionary = KINDS[kind]
	var root := Node3D.new()
	var sc := scene(def["model"])
	if sc:
		root.add_child(sc.instantiate())
	for e in def.get("extra", []):
		var es := scene(e[0])
		if es:
			var n := es.instantiate() as Node3D
			n.position = e[1]
			root.add_child(n)
	root.scale = Vector3.ONE * float(def["scale"]) * scale_mul
	return root


## Boîte englobante locale (avant mise à l'échelle) d'un type d'objet.
static func local_aabb(kind: String) -> AABB:
	if _aabbs.has(kind):
		return _aabbs[kind]
	var tmp := make_model(kind, 1.0)
	tmp.scale = Vector3.ONE
	var ab := Player._compute_aabb(tmp)
	tmp.free()
	_aabbs[kind] = ab
	return ab


static func is_structure(kind: String) -> bool:
	return bool((KINDS.get(kind, {}) as Dictionary).get("structure", false))


## Grosse construction : bâtie (ou démolie) par les habitants.
static func is_site(kind: String) -> bool:
	return bool((KINDS.get(kind, {}) as Dictionary).get("site", false))


static func is_house(kind: String) -> bool:
	return bool((KINDS.get(kind, {}) as Dictionary).get("house", false))


## Position (globale) devant la porte d'une maison : la porte est sur la face +Z du modèle.
func door_position(id: int) -> Vector3:
	var it: Dictionary = items[id]
	var n := it["node"] as Node3D
	var ab := local_aabb(it["kind"])
	var s := float(KINDS[it["kind"]]["scale"])
	return n.global_position + n.global_basis * Vector3(0, 0, ab.end.z * s + 0.9)


func key_of(id: int) -> String:
	return items[id]["key"] if items.has(id) else ""


static func is_tree(kind: String) -> bool:
	return bool((KINDS.get(kind, {}) as Dictionary).get("tree", false))


func clear() -> void:
	for id in items:
		(items[id]["node"] as Node3D).queue_free()
	items.clear()


## Recrée les objets d'une île : ceux générés (sauf retirés) et ceux du joueur.
func spawn_island(island_id: String, generated: Array) -> void:
	clear()
	_island = island_id
	var removed: Array = Game.props_removed.get(island_id, [])
	for g in generated:
		if g["key"] in removed:
			continue
		add(g["kind"], g["pos"], g.get("rot", 0.0), g.get("scale", 1.0), g["key"])
	for p in Game.props_added.get(island_id, []):
		add(p["kind"], Vector3(p["x"], p["y"], p["z"]), float(p["rot"]), float(p["scale"]) * growth(p), str(p["key"]))


## Un arbre planté grandit sur quelques jours : pousse, jeune arbre, adulte.
static func growth(entry: Dictionary) -> float:
	if not entry.has("planted"):
		return 1.0
	var age := Game.day - int(entry["planted"])
	return [0.3, 0.55, 0.8, 1.0][clampi(age, 0, 3)]


## Le matin : les jeunes arbres prennent de la taille.
func update_growth() -> void:
	for p in Game.props_added.get(_island, []):
		if not p.has("planted"):
			continue
		for id in items:
			if items[id]["key"] == p["key"]:
				var body := items[id]["node"] as Node3D
				var model := body.get_child(0) as Node3D
				var s := float(KINDS[p["kind"]]["scale"]) * float(p["scale"]) * growth(p)
				body.create_tween().tween_property(model, "scale", Vector3.ONE * s, 1.5).set_trans(Tween.TRANS_SINE)
				items[id]["scale"] = float(p["scale"]) * growth(p)


func add(kind: String, pos: Vector3, rot := 0.0, scale_mul := 1.0, key := "") -> int:
	if not KINDS.has(kind):
		push_warning("Objet inconnu : %s" % kind)
		return -1
	var def: Dictionary = KINDS[kind]
	if world and not kind in NO_SNAP:
		pos.y = ground_for(world, kind, pos, rot, scale_mul)
	var body := StaticBody3D.new()
	body.collision_layer = 1 | LAYER
	body.collision_mask = 0
	add_child(body)
	body.position = pos
	body.rotation.y = rot
	var model := make_model(kind, scale_mul)
	body.add_child(model)
	var s := float(def["scale"]) * scale_mul
	var ab := local_aabb(kind)
	match def["shape"]:
		"trunk":
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = maxf(0.28, minf(ab.size.x, ab.size.z) * s * 0.14)
			cyl.height = maxf(0.5, ab.size.y * s * 0.6)
			cs.shape = cyl
			cs.position.y = cyl.height * 0.5
			body.add_child(cs)
		"box":
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = (ab.size * s * 0.92).max(Vector3.ONE * 0.2)
			cs.shape = box
			cs.position = (ab.position + ab.size * 0.5) * s
			body.add_child(cs)
		"wall":
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(ab.size.x * s * 1.1, 9.0, ab.size.z * s * 1.1)
			cs.shape = box
			cs.position = Vector3((ab.position.x + ab.size.x * 0.5) * s, 4.0, (ab.position.z + ab.size.z * 0.5) * s)
			body.add_child(cs)
		_:
			# Pas de collision physique pour le joueur, mais visable au viseur.
			body.collision_layer = LAYER
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = (ab.size * s).max(Vector3.ONE * 0.4)
			cs.shape = box
			cs.position = (ab.position + ab.size * 0.5) * s
			body.add_child(cs)
	if def.get("fire", false):
		_add_fire(body, s)
	if def.get("light", false):
		var l := OmniLight3D.new()
		l.light_color = Color("ffd38a")
		l.light_energy = 1.2
		l.omni_range = 6.0
		l.position.y = ab.end.y * s * 0.85
		body.add_child(l)
	var id := _next_id
	_next_id += 1
	body.set_meta("prop_id", id)
	items[id] = {"kind": kind, "node": body, "key": key, "pos": pos, "rot": rot, "scale": scale_mul}
	if on_change.is_valid():
		on_change.call(id, 1)
	return id


## Ajout par le joueur (sauvegardé). `grow` : animation de pousse.
## `extra` : données en plus (ex. {"planted": jour} pour un arbre qui grandit).
func add_persistent(kind: String, pos: Vector3, rot := 0.0, scale_mul := 1.0, grow := false, extra := {}) -> int:
	var list: Array = Game.props_added.get_or_add(_island, [])
	var key := "p:%d:%d" % [Time.get_ticks_msec(), randi() % 100000]
	var entry := {"kind": kind, "x": pos.x, "y": pos.y, "z": pos.z, "rot": rot, "scale": scale_mul, "key": key}
	entry.merge(extra)
	list.append(entry)
	var id := add(kind, pos, rot, scale_mul * growth(entry), key)
	if grow and id > 0:
		var model := (items[id]["node"] as Node3D).get_child(0) as Node3D
		var full := model.scale
		model.scale = full * 0.05
		create_tween().tween_property(model, "scale", full, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return id


## Hauteur du sol (dessus du dernier bloc de terrain) en (x, z). Les déchets
## et la vase ne comptent pas : ils peuvent être retirés plus tard.
static func ground_y(w: VoxelWorld, x: int, z: int) -> int:
	for y in range(VoxelWorld.SY - 1, -1, -1):
		var b := w.get_block(x, y, z)
		if Blocks.is_solid(b) and b != Blocks.DEBRIS and b != Blocks.SLUDGE:
			return y + 1
	return 0


## Hauteur où poser un objet : le point le plus haut sous son emprise
## (pour qu'il ne s'enfonce jamais dans une pente).
static func ground_for(w: VoxelWorld, kind: String, pos: Vector3, rot: float, scale_mul: float) -> float:
	var def: Dictionary = KINDS[kind]
	var pts: Array[Vector3] = [pos]
	if def["shape"] != "trunk":
		var ab := local_aabb(kind)
		var s := float(def["scale"]) * scale_mul
		var c := Vector3(ab.position.x + ab.size.x * 0.5, 0, ab.position.z + ab.size.z * 0.5) * s
		var hx := ab.size.x * s * 0.35
		var hz := ab.size.z * s * 0.35
		var basis := Basis(Vector3.UP, rot)
		pts = [pos, pos + basis * c]
		for o in [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(-hx, 0, hz), Vector3(hx, 0, hz)]:
			pts.append(pos + basis * (c + o))
	var hs: Array[int] = []
	for q in pts:
		hs.append(ground_y(w, floori(q.x), floori(q.z)))
	hs.sort()
	if hs[-1] <= 0:
		return pos.y
	# Rochers et bûches s'enfoncent dans la pente (naturel) ; le reste se pose
	# sur le point le plus haut, ou à mi-hauteur si la pente est raide.
	if kind in EMBED:
		return float(hs[0])
	if hs[-1] - hs[0] <= 1:
		return float(hs[-1])
	return float(hs[hs.size() / 2])


## Après une modification du terrain, recale les objets proches sur le sol.
func resnap_near(p: Vector3, r: float) -> void:
	if world == null:
		return
	for id in items:
		var it: Dictionary = items[id]
		if it["kind"] in NO_SNAP:
			continue
		var q: Vector3 = it["pos"]
		if Vector2(q.x - p.x, q.z - p.z).length() > r:
			continue
		var y := ground_for(world, it["kind"], q, float(it.get("rot", 0.0)), float(it.get("scale", 1.0)))
		if absf(y - q.y) > 0.01:
			q.y = y
			it["pos"] = q
			(it["node"] as Node3D).position.y = y
			# Les constructions du joueur gardent leur nouvelle hauteur.
			var key: String = it["key"]
			if key.begins_with("p:"):
				for e in Game.props_added.get(_island, []):
					if e["key"] == key:
						e["y"] = y


## Retire un objet (enregistré dans la sauvegarde).
func remove(id: int) -> void:
	if not items.has(id):
		return
	var it: Dictionary = items[id]
	var key: String = it["key"]
	if key.begins_with("p:"):
		var list: Array = Game.props_added.get(_island, [])
		for i in range(list.size() - 1, -1, -1):
			if list[i]["key"] == key:
				list.remove_at(i)
	elif key != "":
		(Game.props_removed.get_or_add(_island, []) as Array).append(key)
	if on_change.is_valid():
		on_change.call(id, 0)
	(it["node"] as Node3D).queue_free()
	items.erase(id)


func kind_of(id: int) -> String:
	return items[id]["kind"] if items.has(id) else ""


func id_from_collider(c: Object) -> int:
	if c and c is Node and (c as Node).has_meta("prop_id"):
		return int((c as Node).get_meta("prop_id"))
	return -1


## Boîte englobante globale d'un objet (surbrillance).
func bounds(id: int) -> AABB:
	var it: Dictionary = items[id]
	var def: Dictionary = KINDS[it["kind"]]
	var s := float(def["scale"]) * float(it.get("scale", 1.0))
	var ab := local_aabb(it["kind"])
	var n := it["node"] as Node3D
	return AABB(n.global_position + ab.position * s, ab.size * s)


## Un arbre (ou autre objet) trop proche ?
func any_near(p: Vector3, r: float, trees_only := false) -> bool:
	for id in items:
		var it: Dictionary = items[id]
		if trees_only and not is_tree(it["kind"]):
			continue
		var q: Vector3 = it["pos"]
		if Vector2(q.x - p.x, q.z - p.z).length() < r and absf(q.y - p.y) < 6.0:
			return true
	return false


func tree_count() -> int:
	var n := 0
	for id in items:
		if is_tree(items[id]["kind"]):
			n += 1
	return n


func _add_fire(parent: Node3D, s: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color("ffa04a")
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.position.y = 0.8
	parent.add_child(light)
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.8
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.16
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ff9a3a")
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	p.mesh = m
	p.position.y = 0.2 * s * 0.25
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.2, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.1
	var grad := Gradient.new()
	grad.set_color(0, Color("ffe27a"))
	grad.set_color(1, Color(1.0, 0.35, 0.1, 0.0))
	p.color_ramp = grad
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	parent.add_child(p)
	# Petite lueur vacillante.
	var tw := light.create_tween().set_loops()
	tw.tween_property(light, "light_energy", 1.2, 0.18)
	tw.tween_property(light, "light_energy", 1.8, 0.23)
