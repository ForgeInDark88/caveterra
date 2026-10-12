extends Node2D
## Декор пещеры: светящиеся кристаллы, грибы, сталагмиты.

var type := 0
var seed_value := 0.0
var _t := 0.0


func _ready() -> void:
	z_index = -5
	if type == 0 or type == 1:
		var light := PointLight2D.new()
		light.texture = Game.light_texture()
		light.texture_scale = 0.9
		light.energy = 0.6
		light.color = _color()
		add_child(light)


func _color() -> Color:
	if type == 0:
		return Color.from_hsv(0.5 + seed_value * 0.35, 0.7, 1.0)
	return Color(0.4, 1.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	if type != 2:
		queue_redraw()


func _draw() -> void:
	match type:
		0:  # кристаллы
			var c := _color()
			c.a = 0.85 + 0.15 * sin(_t * 2.0 + seed_value * 10.0)
			for i in 3:
				var off := Vector2((i - 1) * 7.0, 0)
				var hgt := 14.0 + i % 2 * 8.0 + seed_value * 6.0
				draw_colored_polygon(PackedVector2Array([off + Vector2(-4, 6), off + Vector2(0, 6 - hgt), off + Vector2(4, 6)]), c)
		1:  # грибы
			for i in 3:
				var p := Vector2((i - 1) * 8.0, (i % 2) * 4.0)
				draw_line(p + Vector2(0, 6), p, Color(0.85, 0.85, 0.75), 2.0)
				draw_circle(p, 4.5, Color(0.3, 0.9, 0.55, 0.8 + 0.2 * sin(_t * 3.0 + i)))
		3:  # сталактит (висит с потолка)
			var hl := 16.0 + seed_value * 22.0
			draw_colored_polygon(PackedVector2Array([Vector2(-8, -16), Vector2(8, -16), Vector2(1, -16 + hl)]), Color(0.3, 0.26, 0.24))
			draw_circle(Vector2(1, -16 + hl + 3.0 + fmod(_t * 20.0 + seed_value * 30.0, 30.0)), 1.5, Color(0.5, 0.7, 0.9, 0.6))
		4:  # лианы
			var pts := PackedVector2Array()
			var vl := 30.0 + seed_value * 50.0
			for i in 8:
				var k := i / 7.0
				pts.append(Vector2(sin(_t * 1.5 + k * 4.0 + seed_value * 9.0) * 4.0 * k, -16 + vl * k))
			draw_polyline(pts, Color(0.25, 0.45, 0.22), 2.0)
			for i in range(1, 8, 2):
				draw_circle(pts[i] + Vector2(3, 0), 2.5, Color(0.3, 0.55, 0.25))
		_:  # сталагмит/камень
			draw_colored_polygon(PackedVector2Array([Vector2(-9, 8), Vector2(-2, -12 - seed_value * 8.0), Vector2(9, 8)]), Color(0.3, 0.26, 0.24))
			draw_line(Vector2(-2, -12 - seed_value * 8.0), Vector2(3, 6), Color(0.4, 0.35, 0.32), 1.5)
