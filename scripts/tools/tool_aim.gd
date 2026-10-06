class_name ToolAim
extends Node3D
## Ce que vise l'outil (au viseur ou à la souris) : bloc, objet 3D, sol ou
## meuble à l'intérieur ; surbrillance de la cible et aperçu fantôme des
## constructions et des meubles avant de les poser.

const REACH := 6.5
const ADMIN_REACH := 24.0

var main: Main
## Cible courante : {"hit", "pos", "normal", "block"} pour un bloc,
## + "prop" (objet 3D), "furn" (meuble) ou "floor" (sol intérieur).
var target := {}
## Rotation des constructions posées (touche R).
var place_rot := 0.0
var ghost: Node3D
var ghost_ok := false
var ghost_pos := Vector3.ZERO
var _ghost_kind := ""
var _highlight: MeshInstance3D
var _highlight_mat: StandardMaterial3D
var _outline: MeshInstance3D


func _ready() -> void:
	_highlight = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	_highlight.mesh = bm
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.albedo_color = Color(1, 1, 1, 0.3)
	_highlight.material_override = _highlight_mat
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_highlight.visible = false
	add_child(_highlight)

	var mb := MeshBuilder.new()
	var t := 0.035
	for a in [-0.5, 0.5]:
		for b in [-0.5, 0.5]:
			mb.add_box(Vector3(0, a, b), Vector3(1 + t, t, t), Color.WHITE, false)
			mb.add_box(Vector3(a, 0, b), Vector3(t, 1 + t, t), Color.WHITE, false)
			mb.add_box(Vector3(a, b, 0), Vector3(t, t, 1 + t), Color.WHITE, false)
	var omat := StandardMaterial3D.new()
	omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	omat.vertex_color_use_as_albedo = true
	_outline = MeshInstance3D.new()
	_outline.mesh = mb.commit(omat)
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline.visible = false
	add_child(_outline)


func hide_marks() -> void:
	_highlight.visible = false
	_outline.visible = false


func rotate_placement() -> void:
	place_rot = wrapf(place_rot + PI * 0.5, 0.0, TAU)


# --- Cible -------------------------------------------------------------------

func update_target() -> void:
	target = {}
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mp = vp.get_visible_rect().size * 0.5
	var cam := main.rig.camera
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if main.interior:
		_update_target_inside(from, dir)
		return
	var reach := ADMIN_REACH if Game.admin else REACH
	var chest_pos := main.player.global_position + Vector3(0, 0.7, 0)
	var hit := main.world.raycast(from, dir, 80.0, _is_cut)
	var voxel_d := INF
	if hit["hit"]:
		var center := Vector3(hit["pos"]) + Vector3(0.5, 0.5, 0.5)
		voxel_d = from.distance_to(center) - 0.5
		if center.distance_to(chest_pos) <= reach:
			target = hit
	# Objets 3D (arbres, feux...) visés au viseur, s'ils sont devant les voxels.
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 80.0, Props.LAYER)
	var ph := get_world_3d().direct_space_state.intersect_ray(q)
	if not ph.is_empty():
		var id := main.props.id_from_collider(ph["collider"])
		var hp: Vector3 = ph["position"]
		if id > 0 and from.distance_to(hp) < voxel_d and hp.distance_to(chest_pos) <= reach + 1.0:
			target = {"hit": true, "prop": id, "point": hp, "pos": Vector3i(hp.floor()), "block": Blocks.AIR}
	_update_highlight()


## À l'intérieur : on vise le sol (pour poser) ou un meuble (pour le reprendre).
func _update_target_inside(from: Vector3, dir: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 30.0, Interior.LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit["position"] as Vector3).distance_to(main.player.global_position) < 9.0:
		var col: Object = hit["collider"]
		if col is Node and (col as Node).has_meta("furn"):
			target = {"hit": true, "furn": int((col as Node).get_meta("furn")), "point": hit["position"], "pos": Vector3i.ZERO, "block": Blocks.AIR}
		elif col is Node and (col as Node).has_meta("floor"):
			target = {"hit": true, "floor": main.interior.to_local(hit["position"]), "point": hit["position"], "pos": Vector3i.ZERO, "block": Blocks.AIR}
	_update_highlight()


## Même test que le shader voxel : bloc d'arbre effacé car entre la caméra et le joueur.
func _is_cut(p: Vector3i) -> bool:
	if not main.world.get_blockv(p) in VoxelWorld.SEE_THROUGH:
		return false
	var c := Vector3(p) + Vector3(0.5, 0.5, 0.5)
	var pp := main.player.global_position
	if c.y + 0.5 <= pp.y - 0.2:
		return false
	var cam := main.rig.camera.global_position
	var to_player := pp + Vector3(0, 0.7, 0) - cam
	var dp := to_player.length()
	if dp < 0.01:
		return false
	var dir := to_player / dp
	var rel := c - cam
	var t := rel.dot(dir)
	if t <= 0.0 or t >= dp - 0.6:
		return false
	var perp := (rel - dir * t).length()
	var r := 2.2 * clampf(t / dp + 0.35, 0.0, 1.0)
	return perp < r * 0.8


func _update_highlight() -> void:
	var power := main.power
	if target.is_empty() or not main.hud.power_unlocked(power) or target.has("floor"):
		hide_marks()
		return
	if target.has("prop") or target.has("furn"):
		# Objet 3D : on entoure toute sa boîte englobante (seul « Casser » s'applique).
		var ab := main.props.bounds(int(target["prop"])) if target.has("prop") else main.interior.furn_bounds(int(target["furn"]))
		var c0: Color = UIStyle.POWER_COLORS[0] if power == 0 else UIStyle.TEXT_SOFT
		_highlight.visible = true
		_highlight.position = ab.get_center()
		_highlight.scale = ab.size + Vector3.ONE * 0.1
		_highlight_mat.albedo_color = Color(c0.r, c0.g, c0.b, 0.18 + sin(Time.get_ticks_msec() * 0.006) * 0.05)
		_outline.visible = false
		return
	var p: Vector3i = target["pos"]
	var col: Color = UIStyle.POWER_COLORS[power]
	var pos := Vector3(p) + Vector3(0.5, 0.5, 0.5)
	var size := Vector3.ONE * 1.02
	var show_outline := true
	match power:
		1:
			if not Blocks.is_deco(int(target["block"])):
				pos += Vector3(target["normal"] as Vector3i)
			col = Blocks.main_color(main.block)
		2:
			if Blocks.is_deco(int(target["block"])):
				pos.y -= 1.0
			pos.y += 0.52
			size = Vector3(5.0, 0.06, 5.0)
			show_outline = false
		3:
			if Blocks.is_deco(int(target["block"])):
				pos.y -= 1.0
			pos.y += 1.0
			size = Vector3(0.5, 1.0, 0.5)
			show_outline = false
	_highlight.visible = true
	_highlight.position = pos
	_highlight.scale = size
	var pulse := 0.3 + sin(Time.get_ticks_msec() * 0.006) * 0.08
	_highlight_mat.albedo_color = Color(col.r, col.g, col.b, pulse + (0.15 if power == 1 else 0.0))
	_outline.visible = show_outline
	_outline.position = pos
	_outline.scale = Vector3.ONE * 1.02


# --- Aperçu fantôme ----------------------------------------------------------

func update_ghost() -> void:
	if main.interior:
		_update_ghost_inside()
		return
	var structure := main.structure
	var show := main.power == 1 and structure != "" and not target.is_empty() \
		and not target.has("prop") and (Game.admin or Game.structure_count(structure) > 0)
	if not show:
		if ghost:
			ghost.visible = false
		return
	_ensure_ghost(structure, func(): return Props.make_model(structure, 1.0))
	var p: Vector3i = target["pos"]
	if Blocks.is_deco(int(target["block"])):
		p.y -= 1
	ghost_pos = Vector3(p.x + 0.5, p.y + 1, p.z + 0.5)
	ghost.visible = true
	ghost.position = ghost_pos
	ghost.rotation.y = place_rot
	ghost_ok = main.construction.structure_fits(structure, ghost_pos, place_rot)
	_tint_ghost()
	hide_marks()


func _update_ghost_inside() -> void:
	var structure := main.structure
	var show := main.power == 1 and structure.begins_with("f_") and target.has("floor") and (Game.admin or Game.structure_count(structure) > 0)
	if not show:
		if ghost:
			ghost.visible = false
		return
	_ensure_ghost(structure, func(): return Interior.make_furn_model(structure.trim_prefix("f_")))
	var lp: Vector3 = target["floor"]
	var x := snappedf(lp.x, 0.5)
	var z := snappedf(lp.z, 0.5)
	ghost_pos = main.interior.to_global(Vector3(x, 0, z))
	ghost.visible = true
	ghost.global_position = ghost_pos
	ghost.rotation.y = place_rot
	ghost_ok = main.interior.fits(structure.trim_prefix("f_"), x, z, place_rot)
	_tint_ghost()


func ghost_shown() -> bool:
	return ghost_ok and ghost != null and ghost.visible


func _ensure_ghost(kind: String, build: Callable) -> void:
	if ghost != null and _ghost_kind == kind:
		return
	if ghost:
		ghost.queue_free()
	ghost = build.call()
	_ghost_kind = kind
	add_child(ghost)


func _tint_ghost() -> void:
	var tint := Color(0.4, 1.0, 0.5, 0.35) if ghost_ok else Color(1.0, 0.35, 0.3, 0.45)
	for m in ghost.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).material_overlay as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			(m as MeshInstance3D).material_overlay = mat
		mat.albedo_color = tint
