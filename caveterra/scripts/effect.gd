extends Node2D
## Короткоживущие визуальные эффекты: взмах, кольцо, текст урона, молния, телеграф атаки.

var kind := "ring"
var life := 0.3
var max_life := 0.3
var color := Color.WHITE
var radius := 30.0
var dir := Vector2.RIGHT
var arc := 90.0
var text := ""
var points := PackedVector2Array()
var vel := Vector2.ZERO


static func make(k: String, pos: Vector2, c: Color, t: float) -> Node2D:
	var e = load("res://scripts/effect.gd").new()
	e.kind = k
	e.position = pos
	e.color = c
	e.life = t
	e.max_life = t
	return e


func _ready() -> void:
	z_index = 20 if kind == "text" else 5
	if kind == "text":
		vel = Vector2(randf_range(-30, 30), -70)


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position += vel * delta
	vel *= 0.92
	queue_redraw()


func _draw() -> void:
	var k := clampf(life / max_life, 0.0, 1.0)
	match kind:
		"ring":
			var r := radius * (1.0 - k * 0.6)
			draw_circle(Vector2.ZERO, r, Color(color, 0.25 * k))
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(color, k), 3.0)
		"burst":
			for i in 8:
				var a := i * TAU / 8.0 + radius
				var d := (1.0 - k) * 26.0 + 4.0
				draw_circle(Vector2.RIGHT.rotated(a) * d, 3.0 * k + 1.0, Color(color, k))
		"slash":
			var half := deg_to_rad(arc) * 0.5
			var base := dir.angle()
			var prog := 1.0 - k
			var from := base - half
			var to := base - half + 2.0 * half * minf(1.0, prog * 2.5)
			draw_arc(Vector2.ZERO, radius, from, to, 24, Color(color, 0.85 * k), 10.0 * k + 2.0)
			draw_arc(Vector2.ZERO, radius * 0.75, from, to, 24, Color(1, 1, 1, 0.5 * k), 3.0)
		"text":
			var f := ThemeDB.fallback_font
			draw_string_outline(f, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 18, 4, Color(0, 0, 0, k))
			draw_string(f, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color(color, k))
		"line":
			if points.size() >= 2:
				draw_polyline(points, Color(color, k), 3.0)
				draw_polyline(points, Color(1, 1, 1, k), 1.0)
		"telegraph":
			draw_circle(Vector2.ZERO, radius, Color(color, 0.12 + 0.2 * (1.0 - k)))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(color, 0.8), 2.0)
			draw_circle(Vector2.ZERO, radius * (1.0 - k), Color(color, 0.25))
