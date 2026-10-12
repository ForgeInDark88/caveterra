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
	if mode == "entrance":
		draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.7))
		draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.9))
		return
	var c := Color(1.0, 0.3, 0.25) if locked else Color(0.45, 0.8, 1.0)
	# Арка
	draw_circle(Vector2.ZERO, 30.0, Color(0.08, 0.06, 0.08))
	draw_arc(Vector2.ZERO, 30.0, 0, TAU, 40, Color(0.4, 0.35, 0.33), 6.0)
	if locked:
		for i in 3:
			var y := -14.0 + i * 14.0
			draw_line(Vector2(-24, y), Vector2(24, y), Color(0.35, 0.25, 0.2), 4.0)
		draw_circle(Vector2.ZERO, 6.0, c)
	else:
		for i in 3:
			var r := fmod(_t * 18.0 + i * 9.0, 27.0)
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(c, 1.0 - r / 27.0), 2.0)
		draw_circle(Vector2.ZERO, 8.0, Color(c, 0.6))
