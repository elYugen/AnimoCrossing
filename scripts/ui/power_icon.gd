class_name PowerIcon
extends Control
## Icône dessinée d'un pouvoir (casser, poser, fleurir, pousser) ou d'un bloc.

var kind := 0
var block_color := Color.WHITE
var is_block := false


func _draw() -> void:
	var s := size
	var c := s * 0.5
	var u := minf(s.x, s.y) / 48.0
	if is_block:
		_draw_cube(c, 15.0 * u, block_color)
		return
	match kind:
		0:  # Casser : bloc fissuré + éclats
			_draw_cube(c + Vector2(0, 3) * u, 13.0 * u, Color("b48a62"))
			var pts := PackedVector2Array([c + Vector2(-3, -6) * u, c + Vector2(1, -1) * u, c + Vector2(-2, 3) * u, c + Vector2(3, 10) * u])
			draw_polyline(pts, Color("5a4636"), 2.2 * u, true)
			draw_rect(Rect2(c + Vector2(12, -16) * u, Vector2(5, 5) * u), Color("d9a46c"))
			draw_rect(Rect2(c + Vector2(-18, -13) * u, Vector2(4, 4) * u), Color("d9a46c"))
		1:  # Poser : bloc + signe plus
			_draw_cube(c + Vector2(-3, 3) * u, 12.0 * u, Color("8fc1f5"))
			draw_circle(c + Vector2(11, -11) * u, 8.0 * u, Color.WHITE)
			draw_rect(Rect2(c + Vector2(7, -12.5) * u, Vector2(8, 3) * u), Color("4a8ad8"))
			draw_rect(Rect2(c + Vector2(9.5, -15) * u, Vector2(3, 8) * u), Color("4a8ad8"))
		2:  # Fleurir : fleur
			draw_rect(Rect2(c + Vector2(-1.5, 2) * u, Vector2(3, 16) * u), Color("4f9e3a"))
			draw_rect(Rect2(c + Vector2(1, 9) * u, Vector2(7, 3) * u), Color("6cbf4a"))
			for a in 5:
				var ang := a * TAU / 5.0 - PI / 2.0
				draw_circle(c + Vector2(0, -5) * u + Vector2(cos(ang), sin(ang)) * 7.0 * u, 5.0 * u, Color("f7a3c8"))
			draw_circle(c + Vector2(0, -5) * u, 4.0 * u, Color("f9d54a"))
		3:  # Pousser : arbre voxel
			draw_rect(Rect2(c + Vector2(-3, 4) * u, Vector2(6, 14) * u), Color("8a5a3b"))
			draw_rect(Rect2(c + Vector2(-13, -14) * u, Vector2(26, 18) * u), Color("5cbb52"))
			draw_rect(Rect2(c + Vector2(-8, -20) * u, Vector2(16, 8) * u), Color("7bd05f"))


func _draw_cube(c: Vector2, r: float, col: Color) -> void:
	var top := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, -r * 0.5), c + Vector2(0, 0), c + Vector2(-r, -r * 0.5)])
	var left := PackedVector2Array([c + Vector2(-r, -r * 0.5), c, c + Vector2(0, r), c + Vector2(-r, r * 0.5)])
	var right := PackedVector2Array([c, c + Vector2(r, -r * 0.5), c + Vector2(r, r * 0.5), c + Vector2(0, r)])
	draw_colored_polygon(top, col.lightened(0.15))
	draw_colored_polygon(left, col.darkened(0.08))
	draw_colored_polygon(right, col.darkened(0.22))
