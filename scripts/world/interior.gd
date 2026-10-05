class_name Interior
extends Node3D
## Intérieur d'une maison, instancié à part (au-dessus des nuages) quand on
## entre par la porte. Les meubles (Furniture Kit de Kenney, CC0) sont
## enregistrés par maison (Game.interiors) : on les fabrique à l'établi, puis
## on les pose, déplace ou reprend avec l'outil, comme dehors.

const ORIGIN := Vector3(-400, 200, -400)
const WALL_H := 2.6
const SCALE := 3.0
## Couche physique 4 : sol et meubles visés au viseur à l'intérieur.
const LAYER := 8

## Meubles fabricables : nom du modèle -> nom affiché.
const FURNITURE := {
	"bedSingle": "Lit simple", "bedDouble": "Grand lit", "cabinetBedDrawerTable": "Table de chevet",
	"table": "Table", "tableRound": "Table ronde", "chairCushion": "Chaise", "tableCoffee": "Table basse",
	"loungeSofa": "Canapé", "loungeChair": "Fauteuil", "lampRoundFloor": "Lampadaire",
	"bookcaseOpen": "Étagère", "bookcaseClosedWide": "Bibliothèque", "sideTable": "Commode",
	"kitchenStove": "Cuisinière", "kitchenSink": "Évier", "kitchenCabinet": "Meuble de cuisine",
	"kitchenFridgeSmall": "Réfrigérateur", "rugRectangle": "Grand tapis", "rugRound": "Tapis rond",
	"rugDoormat": "Paillasson", "pottedPlant": "Plante en pot", "coatRackStanding": "Portemanteau",
	"radio": "Radio",
}
## Meubles qu'on traverse (tapis).
const FLAT := ["rugRectangle", "rugRound", "rugDoormat"]

static var _aabbs := {}

var house_key := ""
var size := Vector2i(10, 8)  # largeur (x), profondeur (z)
var door_inside := Vector3.ZERO
var spawn := Vector3.ZERO
var bed := Vector3.ZERO
var _body: StaticBody3D
var _furn_root: Node3D


static func label_of(name: String) -> String:
	return FURNITURE.get(name, name)


const FEMININE := ["table", "tableRound", "chairCushion", "tableCoffee", "bookcaseOpen", "bookcaseClosedWide",
	"sideTable", "kitchenStove", "pottedPlant", "radio", "cabinetBedDrawerTable"]


## « le canapé », « la table », « l'étagère ».
static func with_article(name: String) -> String:
	var l := label_of(name).to_lower()
	if l.substr(0, 1) in ["a", "e", "é", "i", "o", "u"]:
		return "l'" + l
	return ("la " if name in FEMININE else "le ") + l


## Modèle d'un meuble, centré sur son origine (le Furniture Kit a l'origine dans un coin).
static func make_furn_model(name: String) -> Node3D:
	var holder := Node3D.new()
	var sc := Props.scene("furniture/" + name)
	if sc == null:
		return holder
	var m := sc.instantiate() as Node3D
	m.scale = Vector3.ONE * SCALE
	var ab := furn_aabb(name)
	var c := (ab.position + ab.size * 0.5) * SCALE
	m.position = Vector3(-c.x, 0, -c.z)
	holder.add_child(m)
	return holder


## Boîte englobante (non mise à l'échelle) d'un meuble.
static func furn_aabb(name: String) -> AABB:
	if _aabbs.has(name):
		return _aabbs[name]
	var sc := Props.scene("furniture/" + name)
	var ab := AABB(Vector3.ZERO, Vector3.ONE * 0.3)
	if sc:
		var n := sc.instantiate() as Node3D
		ab = _aabb(n)
		n.free()
	_aabbs[name] = ab
	return ab


## Demi-taille au sol d'un meuble tourné de `rot`.
static func half_extent(name: String, rot: float) -> Vector2:
	var s := furn_aabb(name).size * SCALE * 0.5
	var r := absf(fmod(rot, PI)) > 0.78 and absf(fmod(rot, PI)) < 2.36
	return Vector2(s.z, s.x) if r else Vector2(s.x, s.z)


func setup(kind: String, key: String) -> void:
	house_key = key
	var ab := Props.local_aabb(kind)
	var s := float(Props.KINDS[kind]["scale"])
	size = Vector2i(clampi(roundi(ab.size.x * s * 1.5), 9, 14), clampi(roundi(ab.size.z * s * 1.5), 7, 11))
	if not Game.interiors.has(key):
		# Une maison neuve : juste de quoi dormir. Au joueur de la meubler.
		Game.interiors[key] = [
			{"f": "bedSingle", "x": 1.6, "z": 1.9, "r": 0.0},
			{"f": "cabinetBedDrawerTable", "x": 3.2, "z": 0.6, "r": 0.0},
			{"f": "rugRound", "x": 2.2, "z": 4.2, "r": 0.0},
			{"f": "rugDoormat", "x": size.x * 0.5, "z": size.y - 0.4, "r": 0.0},
		]


func layout() -> Array:
	return Game.interiors.get(house_key, [])


func _ready() -> void:
	position = ORIGIN
	_body = StaticBody3D.new()
	add_child(_body)
	var w := float(size.x)
	var d := float(size.y)
	# Sol (visé pour poser les meubles), murs crème, soubassement en bois.
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1 | LAYER
	floor_body.set_meta("floor", true)
	add_child(floor_body)
	_box(Vector3(w * 0.5, -0.25, d * 0.5), Vector3(w + 1.0, 0.5, d + 1.0), Color("c99d6c"), floor_body)
	for i in range(0, size.x):
		_box(Vector3(i + 0.5, 0.005, d * 0.5), Vector3(0.04, 0.01, d), Color("b8895a"), null)
	var wall := Color("f5ead6")
	var trim := Color("a5774e")
	_box(Vector3(w * 0.5, WALL_H * 0.5, -0.15), Vector3(w + 0.6, WALL_H, 0.3), wall, _body)
	_box(Vector3(-0.15, WALL_H * 0.5, d * 0.5), Vector3(0.3, WALL_H, d), wall, _body)
	_box(Vector3(w + 0.15, WALL_H * 0.5, d * 0.5), Vector3(0.3, WALL_H, d), wall, _body)
	var dx := w * 0.5
	_box(Vector3((dx - 0.8) * 0.5, WALL_H * 0.5, d + 0.15), Vector3(dx - 0.8, WALL_H, 0.3), wall, _body)
	_box(Vector3(dx + 0.8 + (w - dx - 0.8) * 0.5, WALL_H * 0.5, d + 0.15), Vector3(w - dx - 0.8, WALL_H, 0.3), wall, _body)
	_box(Vector3(dx, 0.01, d + 0.15), Vector3(1.6, 0.02, 0.3), Color("6b4430"), null)
	for z in [-0.12, d + 0.12]:
		_box(Vector3(w * 0.5, 0.35, z), Vector3(w + 0.6, 0.7, 0.32), trim, null)
	for x in [-0.12, w + 0.12]:
		_box(Vector3(x, 0.35, d * 0.5), Vector3(0.32, 0.7, d), trim, null)
	# Seuil : mur invisible (on sort avec E).
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.0, WALL_H, 0.3)
	cs.shape = bs
	cs.position = Vector3(dx, WALL_H * 0.5, d + 0.9)
	_body.add_child(cs)
	door_inside = Vector3(dx, 0.0, d - 0.3)
	spawn = Vector3(dx, 0.1, d - 1.4)
	_furn_root = Node3D.new()
	add_child(_furn_root)
	rebuild()
	var l := OmniLight3D.new()
	l.light_color = Color("ffe2b0")
	l.light_energy = 1.4
	l.omni_range = maxf(w, d) * 1.2
	l.position = Vector3(w * 0.5, WALL_H + 1.5, d * 0.5)
	add_child(l)


## Recrée tous les meubles depuis la sauvegarde.
func rebuild() -> void:
	for c in _furn_root.get_children():
		c.queue_free()
	bed = Vector3(size.x * 0.5, 0, size.y * 0.5)
	var list := layout()
	for i in list.size():
		var e: Dictionary = list[i]
		var name: String = e["f"]
		var pos := Vector3(float(e["x"]), 0, float(e["z"]))
		var rot := float(e["r"])
		if name.begins_with("bed"):
			bed = pos
		var body := StaticBody3D.new()
		body.collision_layer = LAYER if name in FLAT else (1 | LAYER)
		body.position = pos
		body.rotation.y = rot
		body.set_meta("furn", i)
		_furn_root.add_child(body)
		body.add_child(make_furn_model(name))
		var ab := furn_aabb(name)
		var sh := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(ab.size.x, maxf(ab.size.y, 0.1), ab.size.z) * SCALE
		sh.shape = box
		sh.position.y = box.size.y * 0.5
		body.add_child(sh)


## Le meuble tient-il ici (dans la pièce, sans chevaucher un autre meuble,
## en laissant le passage de la porte) ? Les tapis se posent sous les meubles.
func fits(name: String, x: float, z: float, rot: float, ignore := -1) -> bool:
	var h := half_extent(name, rot)
	if x - h.x < 0.05 or x + h.x > size.x - 0.05 or z - h.y < 0.05 or z + h.y > size.y - 0.05:
		return false
	if not name in FLAT and absf(x - size.x * 0.5) < 0.9 + h.x and z + h.y > size.y - 1.4:
		return false
	var list := layout()
	for i in list.size():
		if i == ignore:
			continue
		var e: Dictionary = list[i]
		if (name in FLAT) != (e["f"] in FLAT):
			continue
		var h2 := half_extent(e["f"], float(e["r"]))
		if absf(x - float(e["x"])) < h.x + h2.x - 0.05 and absf(z - float(e["z"])) < h.y + h2.y - 0.05:
			return false
	return true


func add_furniture(name: String, x: float, z: float, rot: float) -> void:
	layout().append({"f": name, "x": x, "z": z, "r": rot})
	rebuild()


## Retire un meuble et renvoie son nom.
func take_furniture(idx: int) -> String:
	var list := layout()
	if idx < 0 or idx >= list.size():
		return ""
	var name: String = list[idx]["f"]
	list.remove_at(idx)
	rebuild()
	return name


## Où l'habitant se tient chez lui : au lit la nuit, sur le canapé ou à
## table le soir, à la cuisine le reste du temps. {"pos", "act", "face"}.
func occupant_spot(hour: float) -> Dictionary:
	var prefs := ["loungeSofa", "loungeChair", "chairCushion", "kitchenStove", "kitchenSink", "table"]
	if hour >= 21.0 or hour < 7.0:
		prefs = ["bedDouble", "bedSingle"] + prefs
	elif hour < 11.0:
		prefs = ["kitchenStove", "kitchenSink", "table"] + prefs
	for want in prefs:
		for e in layout():
			if e["f"] != want:
				continue
			var p := Vector3(float(e["x"]), 0, float(e["z"]))
			var front := Basis(Vector3.UP, float(e["r"])) * Vector3(0, 0, 1)
			match want:
				"loungeSofa", "loungeChair", "chairCushion", "bedDouble", "bedSingle":
					return {"pos": to_global(p + Vector3(0, 0.35, 0)), "act": "sit", "face": to_global(p + front * 2.0)}
				_:
					return {"pos": to_global(p + front * 1.4), "act": "idle", "face": to_global(p)}
	return {"pos": to_global(bed + Vector3(1.4, 0, 1.2)), "act": "idle", "face": to_global(bed)}


func furn_bounds(idx: int) -> AABB:
	var e: Dictionary = layout()[idx]
	var h := half_extent(e["f"], float(e["r"]))
	var hy := furn_aabb(e["f"]).size.y * SCALE
	return AABB(to_global(Vector3(float(e["x"]) - h.x, 0, float(e["z"]) - h.y)), Vector3(h.x * 2.0, maxf(hy, 0.1), h.y * 2.0))


static func _aabb(n: Node3D) -> AABB:
	var ab := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var q: Node = m
		while q and q != n:
			if q is Node3D:
				xf = (q as Node3D).transform * xf
			q = q.get_parent()
		var b := xf * (m as MeshInstance3D).get_aabb()
		ab = b if first else ab.merge(b)
		first = false
	return ab


func _box(c: Vector3, s: Vector3, col: Color, body: StaticBody3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	bm.material = mat
	mi.mesh = bm
	mi.position = c
	add_child(mi)
	if body:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = s
		cs.shape = box
		cs.position = c
		body.add_child(cs)
