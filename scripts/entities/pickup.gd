class_name Pickup
extends Node3D
## Objet à ramasser posé sur l'île (branche, pierre, fruit, plante).
## Ramassé automatiquement quand le joueur passe dessus.

const KINDS := {
	"branch": {"name": "Branche", "color": Color("9b6b45")},
	"stone": {"name": "Pierre", "color": Color("a7adb5")},
	"fruit": {"name": "Fruit", "color": Color("f0663f")},
	"plant": {"name": "Plante", "color": Color("6cbf4a")},
}
const RADIUS := 1.3

static var _meshes := {}

var kind := "branch"
var collected := false
var _t := 0.0
var _pivot: Node3D


static func item_name(k: String) -> String:
	return Items.name_of(k)


static func item_color(k: String) -> Color:
	return Items.color_of(k)


static func mesh_for(k: String) -> Mesh:
	if _meshes.has(k):
		return _meshes[k]
	var mb := MeshBuilder.new()
	match k:
		"branch":
			var wood := Color("9b6b45")
			mb.add_box(Vector3(0, 0.05, 0), Vector3(0.09, 0.09, 0.7), wood)
			mb.add_box(Vector3(0.1, 0.05, 0.12), Vector3(0.22, 0.07, 0.07), wood.darkened(0.1))
			mb.add_box(Vector3(-0.09, 0.05, -0.18), Vector3(0.16, 0.06, 0.06), wood.lightened(0.05))
			mb.add_box(Vector3(0.18, 0.08, 0.16), Vector3(0.08, 0.04, 0.08), Color("6cbf4a"))
		"stone":
			var st := Color("a7adb5")
			mb.add_box(Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.26), st)
			mb.add_box(Vector3(0.05, 0.22, -0.02), Vector3(0.18, 0.08, 0.16), st.lightened(0.08))
			mb.add_box(Vector3(-0.16, 0.06, 0.1), Vector3(0.12, 0.12, 0.12), st.darkened(0.08))
		"fruit":
			var red := Color("f0663f")
			mb.add_box(Vector3(0, 0.13, 0), Vector3(0.24, 0.24, 0.24), red)
			mb.add_box(Vector3(0, 0.13, 0), Vector3(0.28, 0.16, 0.16), red.darkened(0.05))
			mb.add_box(Vector3(0, 0.29, 0), Vector3(0.03, 0.08, 0.03), Color("7a5236"))
			mb.add_box(Vector3(0.06, 0.3, 0), Vector3(0.1, 0.03, 0.06), Color("6cbf4a"))
		_:
			var green := Color("6cbf4a")
			mb.add_box(Vector3(0, 0.12, 0), Vector3(0.05, 0.24, 0.05), green.darkened(0.15))
			for a in 4:
				var d := Vector3(cos(a * PI / 2.0), 0, sin(a * PI / 2.0))
				mb.add_box(d * 0.12 + Vector3(0, 0.1 + a * 0.02, 0), Vector3(0.18, 0.04, 0.18) - Vector3(absf(d.z), 0, absf(d.x)) * 0.1, green)
			mb.add_box(Vector3(0, 0.27, 0), Vector3(0.1, 0.08, 0.1), Color("f9d54a"))
	var mat := MeshBuilder.vertex_color_material()
	mat.roughness = 0.8
	_meshes[k] = mb.commit(mat)
	return _meshes[k]


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_for(kind)
	_pivot.add_child(mi)
	_pivot.rotation.y = randf() * TAU
	_t = randf() * 10.0


func _process(delta: float) -> void:
	if collected:
		return
	_t += delta
	# Léger flottement pour qu'on les repère dans l'herbe.
	_pivot.position.y = 0.12 + sin(_t * 2.2) * 0.05
	_pivot.rotation.y += delta * 0.6


func collect(to: Vector3) -> void:
	collected = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", to + Vector3(0, 1.0, 0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector3.ONE * 0.1, 0.25)
	tw.chain().tween_callback(queue_free)
