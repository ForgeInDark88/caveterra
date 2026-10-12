extends Node2D
## Проход: вход в комнату (декоративный), выход вглубь пещеры, вход в пещеру из лобби.

signal activated

var mode := "exit"          # entrance, exit, lobby
var locked := false
var interact_radius := 56.0
var prompt_open := "[E] Спуститься глубже"
var prompt_locked := "Проход запечатан — победите всех врагов"
var _t := 0.0
var _light: PointLight2D


func _ready() -> void:
	z_index = -1
	if mode != "entrance":
		add_to_group("interactable")
		_light = PointLight2D.new()
		_light.texture = Game.light_texture()
		_light.texture_scale = 1.4
		_light.position = Vector2(0, -30)
		add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	if _light:
		_light.color = Color(1.0, 0.3, 0.25) if locked else Color(0.45, 0.8, 1.0)
		_light.energy = 0.7 + 0.15 * sin(_t * 3.0)
	queue_redraw()


func get_prompt() -> String:
	return prompt_locked if locked else prompt_open


func interact(_player) -> void:
	if not locked:
		activated.emit()


func _draw() -> void:
	# Позиция портала — точка на полу.
	if mode == "entrance":
		# Дыра в потолке/стене, откуда пришёл герой
		draw_rect(Rect2(-22, -70, 44, 70), Color(0, 0, 0, 0.55))
		draw_arc(Vector2(0, -48), 22.0, PI, TAU, 16, Color(0.3, 0.26, 0.24), 5.0)
		return
	var c := Color(1.0, 0.3, 0.25) if locked else Color(0.45, 0.8, 1.0)
	# Шахта вниз: деревянная рама, лестница, свечение из глубины
	draw_rect(Rect2(-26, -4, 52, 12), Color(0.02, 0.02, 0.03))
	draw_rect(Rect2(-30, -64, 6, 64), Color(0.42, 0.29, 0.17))
	draw_rect(Rect2(24, -64, 6, 64), Color(0.42, 0.29, 0.17))
	draw_rect(Rect2(-34, -70, 68, 8), Color(0.5, 0.35, 0.2))
	for i in 4:
		draw_line(Vector2(-12, -4 + i * 3), Vector2(12, -4 + i * 3), Color(0.35, 0.24, 0.14), 2.0)
	if locked:
		for i in 3:
			var y := -54.0 + i * 18.0
			draw_line(Vector2(-24, y), Vector2(24, y), Color(0.35, 0.25, 0.2), 5.0)
		draw_line(Vector2(-24, -54), Vector2(24, -18), Color(0.3, 0.2, 0.15), 4.0)
		draw_circle(Vector2(0, -36), 6.0, c)
	else:
		for i in 3:
			var r := fmod(_t * 14.0 + i * 8.0, 24.0)
			draw_arc(Vector2(0, 2), r, PI, TAU, 16, Color(c, 1.0 - r / 24.0), 2.0)
		draw_rect(Rect2(-24, -64, 48, 60), Color(c, 0.08 + 0.05 * sin(_t * 3.0)))
		# стрелка вниз
		var ay := -40.0 + sin(_t * 4.0) * 5.0
		draw_colored_polygon(PackedVector2Array([Vector2(-9, ay), Vector2(9, ay), Vector2(0, ay + 12)]), Color(c, 0.9))
