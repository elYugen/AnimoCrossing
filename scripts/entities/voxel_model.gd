class_name VoxelModel
extends RefCounted
## Construit un modèle voxel « mignon » à partir d'une description `look`.
## Origine aux pieds, face avant vers +Z.

const EYE := Color("2a2230")
const BLUSH := Color("ff9fb2")
const WHITE := Color("ffffff")

static var _material: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = MeshBuilder.vertex_color_material()
		_material.roughness = 0.75
	return _material


static func build(look: Dictionary) -> MeshInstance3D:
	var mb := MeshBuilder.new()
	var body: Color = look.get("body", Color.WHITE)
	var belly: Color = look.get("belly", Color.WHITE)
	var accent: Color = look.get("accent", Color.GRAY)
	var shape: String = look.get("shape", "round")
	var ears: String = look.get("ears", "none")
	var tail: String = look.get("tail", "none")
	var extra: String = look.get("extra", "")

	var head_c: Vector3
	var head_s: Vector3
	var tail_a: Vector3
	match shape:
		"tall":
			mb.add_box(Vector3(0, 0.3, 0), Vector3(0.56, 0.5, 0.46), body)
			mb.add_box(Vector3(0, 0.28, 0.24), Vector3(0.36, 0.3, 0.04), belly)
			head_c = Vector3(0, 0.82, 0.02)
			head_s = Vector3(0.7, 0.6, 0.62)
			mb.add_box(head_c, head_s, body)
			for sx in [-1, 1]:
				mb.add_box(Vector3(0.34 * sx, 0.36, 0.04), Vector3(0.12, 0.24, 0.14), body.darkened(0.05))
				mb.add_box(Vector3(0.15 * sx, 0.04, 0.06), Vector3(0.18, 0.08, 0.24), accent)
			tail_a = Vector3(0, 0.25, -0.23)
		"long":
			mb.add_box(Vector3(0, 0.44, -0.06), Vector3(0.5, 0.42, 0.86), body)
			mb.add_box(Vector3(0, 0.225, -0.06), Vector3(0.36, 0.03, 0.6), belly)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					mb.add_box(Vector3(0.15 * sx, 0.12, -0.06 + 0.27 * sz), Vector3(0.14, 0.24, 0.14), body.darkened(0.08))
			head_c = Vector3(0, 0.8, 0.36)
			head_s = Vector3(0.56, 0.5, 0.5)
			mb.add_box(head_c, head_s, body)
			mb.add_box(Vector3(0, 0.7, 0.63), Vector3(0.26, 0.16, 0.06), belly)
			tail_a = Vector3(0, 0.5, -0.49)
		_:
			head_c = Vector3(0, 0.4, 0)
			head_s = Vector3(0.8, 0.72, 0.74)
			mb.add_box(head_c, head_s, body)
			mb.add_box(Vector3(0, 0.24, 0.38), Vector3(0.48, 0.3, 0.04), belly)
			for sx in [-1, 1]:
				mb.add_box(Vector3(0.2 * sx, 0.04, 0.1), Vector3(0.22, 0.08, 0.26), accent)
				if extra == "arms":
					mb.add_box(Vector3(0.45 * sx, 0.32, 0.06), Vector3(0.1, 0.2, 0.14), body.darkened(0.05))
			tail_a = Vector3(0, 0.3, -0.37)

	var ht := head_c.y + head_s.y * 0.5
	var hw := head_s.x * 0.5
	var fz := head_c.z + head_s.z * 0.5
	var eye_y := head_c.y + head_s.y * 0.08
	var ex := head_s.x * 0.22

	# Visage
	for sx in [-1, 1]:
		mb.add_box(Vector3(ex * sx, eye_y, fz + 0.012), Vector3(0.1, 0.16, 0.03), EYE, false)
		mb.add_box(Vector3(ex * sx + 0.02, eye_y + 0.04, fz + 0.03), Vector3(0.04, 0.05, 0.01), WHITE, false)
		mb.add_box(Vector3((ex + 0.11) * sx, eye_y - 0.1, fz + 0.008), Vector3(0.11, 0.05, 0.02), BLUSH, false)
	if extra == "beak":
		mb.add_box(Vector3(0, eye_y - 0.1, fz + 0.06), Vector3(0.16, 0.08, 0.12), accent)
	else:
		mb.add_box(Vector3(0, eye_y - 0.11, fz + 0.01), Vector3(0.07, 0.03, 0.02), EYE, false)

	# Oreilles / couvre-chef
	match ears:
		"pointy":
			for sx in [-1, 1]:
				mb.add_box(Vector3(hw * 0.6 * sx, ht + 0.11, head_c.z), Vector3(0.17, 0.22, 0.1), body)
				mb.add_box(Vector3(hw * 0.6 * sx, ht + 0.16, head_c.z), Vector3(0.09, 0.13, 0.11), accent)
		"round":
			for sx in [-1, 1]:
				mb.add_box(Vector3(hw * 0.62 * sx, ht + 0.07, head_c.z), Vector3(0.2, 0.16, 0.09), body)
				mb.add_box(Vector3(hw * 0.62 * sx, ht + 0.07, head_c.z + 0.04), Vector3(0.1, 0.08, 0.02), accent)
		"long":
			for sx in [-1, 1]:
				mb.add_box(Vector3(0.15 * sx, ht + 0.25, head_c.z - 0.02), Vector3(0.13, 0.5, 0.09), body)
				mb.add_box(Vector3(0.15 * sx, ht + 0.25, head_c.z + 0.03), Vector3(0.06, 0.36, 0.01), BLUSH)
		"floppy":
			for sx in [-1, 1]:
				mb.add_box(Vector3((hw + 0.05) * sx, ht - 0.18, head_c.z), Vector3(0.1, 0.3, 0.16), accent)
		"leaf":
			mb.add_box(Vector3(0, ht + 0.07, head_c.z), Vector3(0.05, 0.14, 0.05), Color("4f9e3a"))
			mb.add_box(Vector3(0.11, ht + 0.15, head_c.z), Vector3(0.2, 0.05, 0.14), accent)
			mb.add_box(Vector3(-0.09, ht + 0.12, head_c.z), Vector3(0.14, 0.05, 0.1), accent.lightened(0.15))
		"palm":
			mb.add_box(Vector3(0, ht + 0.06, head_c.z), Vector3(0.06, 0.12, 0.06), Color("b98f5e"))
			for d in [Vector3(0.16, 0, 0), Vector3(-0.16, 0, 0), Vector3(0, 0, 0.16), Vector3(0, 0, -0.16)]:
				mb.add_box(Vector3(0, ht + 0.12, head_c.z) + d, Vector3(0.22, 0.04, 0.22) - Vector3(absf(d.z), 0, absf(d.x)) * 0.6, accent)
		"pine":
			var g := body.darkened(0.25)
			mb.add_box(Vector3(0, ht + 0.06, head_c.z), Vector3(0.46, 0.12, 0.46), g)
			mb.add_box(Vector3(0, ht + 0.18, head_c.z), Vector3(0.3, 0.12, 0.3), g.lightened(0.05))
			mb.add_box(Vector3(0, ht + 0.3, head_c.z), Vector3(0.14, 0.12, 0.14), g.lightened(0.1))
		"tufts":
			for sx in [-1, 1]:
				mb.add_box(Vector3(hw * 0.72 * sx, ht + 0.08, head_c.z), Vector3(0.12, 0.18, 0.08), accent)
		"horns":
			for sx in [-1, 1]:
				mb.add_box(Vector3(hw * 0.5 * sx, ht + 0.1, head_c.z), Vector3(0.1, 0.2, 0.1), accent)
				mb.add_box(Vector3(hw * 0.5 * sx, ht + 0.24, head_c.z), Vector3(0.06, 0.1, 0.06), accent.lightened(0.2))
		"claws":
			for sx in [-1, 1]:
				mb.add_box(Vector3((hw + 0.13) * sx, 0.42, 0.12), Vector3(0.22, 0.22, 0.2), accent)
				mb.add_box(Vector3((hw + 0.13) * sx, 0.56, 0.2), Vector3(0.18, 0.08, 0.12), accent.lightened(0.1))
		"cap":
			mb.add_box(Vector3(0, ht + 0.1, head_c.z), Vector3(head_s.x + 0.24, 0.22, head_s.z + 0.24), accent)
			mb.add_box(Vector3(0, ht + 0.25, head_c.z), Vector3(head_s.x - 0.1, 0.1, head_s.z - 0.1), accent.lightened(0.05))
			for d in [Vector3(0.22, 0, 0.18), Vector3(-0.2, 0, -0.12), Vector3(0.05, 0, -0.25), Vector3(-0.15, 0, 0.25)]:
				mb.add_box(Vector3(0, ht + 0.3, head_c.z) + d, Vector3(0.1, 0.03, 0.1), WHITE)
		"fin":
			mb.add_box(Vector3(0, ht + 0.1, head_c.z - 0.04), Vector3(0.06, 0.22, 0.32), accent)
		"star":
			mb.add_box(Vector3(0, ht + 0.22, head_c.z), Vector3(0.12, 0.32, 0.06), accent)
			mb.add_box(Vector3(0, ht + 0.24, head_c.z), Vector3(0.32, 0.12, 0.06), accent)
			mb.add_box(Vector3(0, ht + 0.05, head_c.z), Vector3(0.05, 0.1, 0.05), accent.darkened(0.1))
		"antlers":
			var wood := Color("9b6b45")
			for sx in [-1, 1]:
				mb.add_box(Vector3(0.18 * sx, ht + 0.15, head_c.z), Vector3(0.06, 0.3, 0.06), wood)
				mb.add_box(Vector3(0.27 * sx, ht + 0.25, head_c.z), Vector3(0.18, 0.06, 0.06), wood)
				mb.add_box(Vector3(0.34 * sx, ht + 0.33, head_c.z), Vector3(0.06, 0.14, 0.06), wood)
				mb.add_box(Vector3(0.18 * sx, ht + 0.34, head_c.z), Vector3(0.12, 0.08, 0.12), accent)
		"eyes_top":
			for sx in [-1, 1]:
				mb.add_box(Vector3(0.22 * sx, ht + 0.06, head_c.z + 0.14), Vector3(0.2, 0.14, 0.18), body)

	# Queue
	match tail:
		"fluffy":
			mb.add_box(tail_a + Vector3(0, 0.18, -0.16), Vector3(0.3, 0.42, 0.28), accent)
			mb.add_box(tail_a + Vector3(0, 0.44, -0.16), Vector3(0.22, 0.12, 0.2), belly)
		"pompom":
			mb.add_box(tail_a + Vector3(0, 0, -0.07), Vector3(0.2, 0.2, 0.16), belly)
		"thin":
			mb.add_box(tail_a + Vector3(0, 0.04, -0.2), Vector3(0.08, 0.08, 0.38), body.darkened(0.08))
			mb.add_box(tail_a + Vector3(0, 0.14, -0.38), Vector3(0.08, 0.2, 0.08), accent)
		"flame":
			mb.add_box(tail_a + Vector3(0, 0.05, -0.16), Vector3(0.1, 0.1, 0.3), body)
			mb.add_box(tail_a + Vector3(0, 0.16, -0.34), Vector3(0.2, 0.22, 0.2), Color("ff7a2a"))
			mb.add_box(tail_a + Vector3(0, 0.22, -0.34), Vector3(0.12, 0.16, 0.12), Color("ffd84a"))
		"fish":
			mb.add_box(tail_a + Vector3(0, 0, -0.16), Vector3(0.14, 0.14, 0.3), body)
			mb.add_box(tail_a + Vector3(0, 0.02, -0.36), Vector3(0.38, 0.06, 0.16), accent)
		"flat":
			mb.add_box(tail_a + Vector3(0, -0.12, -0.22), Vector3(0.3, 0.06, 0.4), accent)
		"zigzag":
			mb.add_box(tail_a + Vector3(0, 0.08, -0.12), Vector3(0.08, 0.16, 0.08), accent)
			mb.add_box(tail_a + Vector3(0.08, 0.18, -0.2), Vector3(0.18, 0.08, 0.08), accent)
			mb.add_box(tail_a + Vector3(0.16, 0.3, -0.24), Vector3(0.08, 0.2, 0.08), accent)
			mb.add_box(tail_a + Vector3(0.12, 0.44, -0.28), Vector3(0.2, 0.12, 0.08), accent)
		"curl":
			mb.add_box(tail_a + Vector3(0, 0, -0.14), Vector3(0.1, 0.1, 0.24), accent)
			mb.add_box(tail_a + Vector3(0, 0.12, -0.28), Vector3(0.1, 0.22, 0.1), accent)
			mb.add_box(tail_a + Vector3(0, 0.22, -0.18), Vector3(0.1, 0.1, 0.18), accent)

	# Extras
	match extra:
		"brows":
			for sx in [-1, 1]:
				mb.add_box(Vector3(ex * sx, eye_y + 0.13, fz + 0.015), Vector3(0.14, 0.04, 0.03), accent.darkened(0.2), false)
		"shell":
			mb.add_box(Vector3(hw * 0.55, ht + 0.02, head_c.z + 0.1), Vector3(0.2, 0.18, 0.08), accent)
			mb.add_box(Vector3(hw * 0.55, ht + 0.02, head_c.z + 0.15), Vector3(0.04, 0.14, 0.02), accent.lightened(0.3))
		"carapace":
			mb.add_box(Vector3(0, 0.7, -0.06), Vector3(0.6, 0.16, 0.9), accent)
			mb.add_box(Vector3(0, 0.79, -0.06), Vector3(0.36, 0.06, 0.56), accent.lightened(0.15))
		"fluff":
			for d in [Vector3(-0.12, 0, 0), Vector3(0.12, 0, 0.04), Vector3(0, 0.05, -0.08)]:
				mb.add_box(Vector3(0, ht + 0.05, head_c.z) + d, Vector3(0.16, 0.1, 0.16), belly)
		"glasses":
			for sx in [-1, 1]:
				mb.add_box(Vector3(ex * sx, eye_y + 0.1, fz + 0.04), Vector3(0.2, 0.03, 0.02), EYE, false)
				mb.add_box(Vector3(ex * sx, eye_y - 0.1, fz + 0.04), Vector3(0.2, 0.03, 0.02), EYE, false)
				mb.add_box(Vector3((ex + 0.1) * sx, eye_y, fz + 0.04), Vector3(0.03, 0.2, 0.02), EYE, false)
				mb.add_box(Vector3((ex - 0.1) * sx, eye_y, fz + 0.04), Vector3(0.03, 0.2, 0.02), EYE, false)
		"halo":
			var gold := Color("ffd84a")
			var hy := ht + 0.3
			mb.add_box(Vector3(0, hy, head_c.z + 0.16), Vector3(0.4, 0.04, 0.05), gold, false)
			mb.add_box(Vector3(0, hy, head_c.z - 0.16), Vector3(0.4, 0.04, 0.05), gold, false)
			mb.add_box(Vector3(0.18, hy, head_c.z), Vector3(0.05, 0.04, 0.3), gold, false)
			mb.add_box(Vector3(-0.18, hy, head_c.z), Vector3(0.05, 0.04, 0.3), gold, false)

	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit(material())
	mi.set_meta("height", ht)
	return mi
