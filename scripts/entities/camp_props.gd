class_name CampProps
extends Node3D
## Éléments interactifs du campement abandonné : le vieux coffre (qui
## contient l'outil universel), des outils rouillés et l'entrée de la tente
## (pour dormir). Modèles du Survival Kit de Kenney (CC0) ; le reste du
## campement (tente, établi, feu...) est posé par le générateur (Props).

const RUST := Color("a8562c")

var world: VoxelWorld
var chest: Node3D
var tools: Node3D
var tent: Node3D  # entrée de la tente (pour dormir)
var opened := false
var _lid: Node3D


func _ready() -> void:
	var c: Dictionary = IslandGenerator.camp
	if c.is_empty():
		return
	var center: Vector3 = c["center"]

	# Le coffre, devant la tente.
	chest = Node3D.new()
	add_child(chest)
	chest.global_position = _on_ground(c["chest"])
	chest.rotation.y = 0.35
	var model := Props.scene("survival/chest").instantiate() as Node3D
	model.scale = Vector3.ONE * 3.6
	chest.add_child(model)
	_lid = model.find_child("lid", true, false) as Node3D

	# Outils rouillés, abandonnés près de l'établi.
	tools = Node3D.new()
	add_child(tools)
	tools.global_position = _on_ground(center + Vector3(-2.2, 0.0, 3.6)) + Vector3(0, 0.05, 0)
	tools.rotation.y = -0.4
	var i := 0
	for t in ["tool-pickaxe", "tool-shovel", "tool-hammer"]:
		var tm := Props.scene("survival/" + t).instantiate() as Node3D
		tm.scale = Vector3.ONE * 4.0
		tm.rotation = Vector3(-PI / 2.0, 0.0, 0.3 * i)  # posés à plat
		tm.position = Vector3(i * 0.55 - 0.55, 0.0, 0.0)
		# Teinte rouillée.
		for m in tm.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = _rust_overlay()
		tools.add_child(tm)
		i += 1

	tent = Node3D.new()
	add_child(tent)
	tent.global_position = _on_ground(center + Vector3(-4.0, 0.0, -2.6))

	if Game.has_flag("chest") and _lid:
		opened = true
		_lid.rotation.x = -1.9


## Pose un point sur le vrai sol (le terrain du campement n'est pas tout plat).
func _on_ground(p: Vector3) -> Vector3:
	if world == null:
		return p
	return Vector3(p.x, Props.ground_y(world, floori(p.x), floori(p.z)), p.z)


static func _rust_overlay() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.66, 0.34, 0.17, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return m


func open() -> void:
	if opened:
		return
	opened = true
	if _lid == null:
		return
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", -0.25, 0.15)
	tw.tween_property(_lid, "rotation:x", 0.0, 0.1)
	tw.tween_property(_lid, "rotation:x", -1.9, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
