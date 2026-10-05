class_name Worksites
extends Node3D
## Chantiers de l'île. Les grosses constructions (maisons...) ne se posent
## pas d'un coup : le joueur place un plan (fantôme), et les habitants
## libres viennent le construire. Même chose pour démolir une maison (pour la
## déplacer) ou des ruines. Les chantiers sont sauvegardés (Game.sites).

signal finished(site: Dictionary)

const MAX_WORKERS := 3
## Travail nécessaire (secondes de travail d'un habitant).
const BUILD_WORK := 24.0
const DEMOLISH_WORK := 10.0

var props: Props
var world: VoxelWorld
var _island := ""
var _visuals := {}  # id -> {"root": Node3D, "label": Label3D, "dust": CPUParticles3D}


func _sites() -> Array:
	return Game.sites.get_or_add(_island, [])


func load_island(island_id: String) -> void:
	for id in _visuals:
		(_visuals[id]["root"] as Node3D).queue_free()
	_visuals.clear()
	_island = island_id
	for s in _sites():
		_make_visual(s)


func all() -> Array:
	return _sites()


func get_site(id: String) -> Dictionary:
	for s in _sites():
		if s["id"] == id:
			return s
	return {}


## Nouveau chantier de construction : le plan est posé, il reste à bâtir.
func add_build(kind: String, pos: Vector3, rot: float) -> Dictionary:
	var ab := Props.local_aabb(kind)
	var size := ab.size * float(Props.KINDS[kind]["scale"])
	var s := {"id": "s:%d:%d" % [Time.get_ticks_msec(), randi() % 100000], "type": "build", "kind": kind,
		"x": pos.x, "y": pos.y, "z": pos.z, "rot": rot, "progress": 0.0,
		"work": BUILD_WORK * clampf(size.x * size.z / 30.0, 0.6, 2.0)}
	_sites().append(s)
	_make_visual(s)
	return s


## Nouveau chantier de démolition (une maison, des ruines...).
func add_demolish(ids: Array) -> Dictionary:
	var keys := []
	var center := Vector3.ZERO
	for id in ids:
		keys.append(props.key_of(id))
		center += props.items[id]["pos"]
	center /= maxf(1.0, ids.size())
	var s := {"id": "d:%d:%d" % [Time.get_ticks_msec(), randi() % 100000], "type": "demolish", "targets": keys,
		"x": center.x, "y": center.y, "z": center.z, "rot": 0.0, "progress": 0.0,
		"work": DEMOLISH_WORK * clampf(ids.size() * 0.6, 1.0, 3.0)}
	_sites().append(s)
	_make_visual(s)
	return s


## Cet objet est-il déjà visé par une démolition ?
func is_targeted(key: String) -> bool:
	for s in _sites():
		if s["type"] == "demolish" and key in s["targets"]:
			return true
	return false


func center_of(s: Dictionary) -> Vector3:
	return Vector3(s["x"], s["y"], s["z"])


## Rayon de l'emprise (pour éviter de construire par-dessus un chantier).
func radius_of(s: Dictionary) -> float:
	if s["type"] != "build":
		return 3.0
	var ab := Props.local_aabb(s["kind"])
	return maxf(ab.size.x, ab.size.z) * float(Props.KINDS[s["kind"]]["scale"]) * 0.5


## Places de travail autour du chantier.
func slot(s: Dictionary, i: int) -> Vector3:
	var a := TAU * (i + 0.5) / MAX_WORKERS + float(s["rot"])
	var r := radius_of(s) + 0.9
	var p := center_of(s) + Vector3(cos(a), 0, sin(a)) * r
	if world:
		p.y = Props.ground_y(world, floori(p.x), floori(p.z))
	return p


## Avance un chantier ; renvoie true s'il vient d'être terminé.
func work(id: String, amount: float) -> bool:
	var s := get_site(id)
	if s.is_empty():
		return false
	s["progress"] = minf(float(s["work"]), float(s["progress"]) + amount)
	_update_visual(s)
	if float(s["progress"]) >= float(s["work"]):
		_complete(s)
		return true
	return false


func _complete(s: Dictionary) -> void:
	_sites().erase(s)
	if _visuals.has(s["id"]):
		(_visuals[s["id"]]["root"] as Node3D).queue_free()
		_visuals.erase(s["id"])
	if s["type"] == "build":
		props.add_persistent(s["kind"], center_of(s), float(s["rot"]), 1.0, true)
	finished.emit(s)


func _make_visual(s: Dictionary) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = center_of(s)
	var top := 3.0
	if s["type"] == "build":
		var ghost := Props.make_model(s["kind"], 1.0)
		ghost.rotation.y = float(s["rot"])
		root.add_child(ghost)
		var ab := Props.local_aabb(s["kind"])
		top = ab.end.y * float(Props.KINDS[s["kind"]]["scale"]) + 0.8
		# Échafaudage aux coins.
		var r := radius_of(s) * 0.8
		for k in 4:
			var post := Props.make_model("pillar", 0.0)
			post.scale = Vector3(1.6, top / 1.0, 1.6) * 1.0
			post.position = Vector3(cos(k * PI / 2 + 0.78), 0, sin(k * PI / 2 + 0.78)) * r
			root.add_child(post)
	var label := Label3D.new()
	label.font = UIStyle.font()
	label.font_size = 34
	label.outline_size = 10
	label.modulate = UIStyle.TEXT
	label.outline_modulate = Color(1, 1, 1, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.position.y = top
	root.add_child(label)
	var dust := CPUParticles3D.new()
	dust.amount = 10
	dust.lifetime = 0.9
	dust.emitting = false
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.18
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d8c8b0")
	m.material = mat
	dust.mesh = m
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = radius_of(s) * 0.6
	dust.direction = Vector3.UP
	dust.initial_velocity_min = 0.6
	dust.initial_velocity_max = 1.4
	dust.gravity = Vector3(0, -1.0, 0)
	dust.position.y = 0.5
	root.add_child(dust)
	_visuals[s["id"]] = {"root": root, "label": label, "dust": dust}
	_update_visual(s)


func _update_visual(s: Dictionary) -> void:
	if not _visuals.has(s["id"]):
		return
	var v: Dictionary = _visuals[s["id"]]
	var t := float(s["progress"]) / maxf(0.01, float(s["work"]))
	(v["label"] as Label3D).text = "%s %d %%" % ["Chantier" if s["type"] == "build" else "Démolition", roundi(t * 100.0)]
	if s["type"] == "build":
		# Le plan se « remplit » au fil du travail.
		var root := v["root"] as Node3D
		for mi in root.get_child(0).find_children("*", "MeshInstance3D", true, false):
			var ov := (mi as MeshInstance3D).material_overlay as StandardMaterial3D
			if ov == null:
				ov = StandardMaterial3D.new()
				ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ov.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				(mi as MeshInstance3D).material_overlay = ov
			ov.albedo_color = Color(0.55, 0.75, 1.0, lerpf(0.75, 0.15, t))
			(mi as MeshInstance3D).transparency = lerpf(0.55, 0.0, t)


## Poussière quand quelqu'un travaille.
func set_busy(id: String, busy: bool) -> void:
	if _visuals.has(id):
		(_visuals[id]["dust"] as CPUParticles3D).emitting = busy
