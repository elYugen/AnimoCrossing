class_name MeshBuilder
extends RefCounted
## Petit constructeur de mesh à couleurs de sommets (style voxel).

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()


## Ajoute un quad (a, b, c, d forment une boucle). L'ordre est corrigé
## automatiquement pour respecter le sens horaire de Godot (face avant).
func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3,
		ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = d
		d = t
		var tc := cb
		cb = cd
		cd = tc
	verts.append_array([a, b, c, a, c, d])
	for i in 6:
		normals.append(n)
	colors.append_array([ca, cb, cc, ca, cc, cd])


func add_box(center: Vector3, size: Vector3, col: Color, shade := true) -> void:
	var h := size * 0.5
	var p0 := center - h
	var p1 := center + h
	var top := col
	var side := col.darkened(0.06) if shade else col
	var bottom := col.darkened(0.15) if shade else col
	# +Y
	add_quad(Vector3(p0.x, p1.y, p0.z), Vector3(p1.x, p1.y, p0.z), Vector3(p1.x, p1.y, p1.z), Vector3(p0.x, p1.y, p1.z), Vector3.UP, top, top, top, top)
	# -Y
	add_quad(Vector3(p0.x, p0.y, p0.z), Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p0.y, p1.z), Vector3(p0.x, p0.y, p1.z), Vector3.DOWN, bottom, bottom, bottom, bottom)
	# +X
	add_quad(Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p1.y, p0.z), Vector3(p1.x, p1.y, p1.z), Vector3(p1.x, p0.y, p1.z), Vector3.RIGHT, side, side, side, side)
	# -X
	add_quad(Vector3(p0.x, p0.y, p0.z), Vector3(p0.x, p1.y, p0.z), Vector3(p0.x, p1.y, p1.z), Vector3(p0.x, p0.y, p1.z), Vector3.LEFT, side, side, side, side)
	# +Z
	add_quad(Vector3(p0.x, p0.y, p1.z), Vector3(p1.x, p0.y, p1.z), Vector3(p1.x, p1.y, p1.z), Vector3(p0.x, p1.y, p1.z), Vector3.BACK, side, side, side, side)
	# -Z
	add_quad(Vector3(p0.x, p0.y, p0.z), Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p1.y, p0.z), Vector3(p0.x, p1.y, p0.z), Vector3.FORWARD, side, side, side, side)


func is_empty() -> bool:
	return verts.is_empty()


func commit(material: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(0, material)
	return mesh


static func vertex_color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.92
	return m
