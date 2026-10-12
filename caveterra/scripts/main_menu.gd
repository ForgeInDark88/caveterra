extends Control
## Главное меню: начать игру, полноэкранный режим, управление, выход.

var _embers: Array = []
var _t := 0.0
var _fs_button: Button
var _controls: Label


func _ready() -> void:
	get_tree().paused = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in 90:
		_embers.append(_new_ember(true))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = "CAVETERRA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02))
	title.add_theme_constant_override("outline_size", 14)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Спуститесь в бесконечную пещеру. Найдите оружие. Выживите."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75))
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer)

	var play := _button(box, "Начать игру", Game.go_to_lobby)
	_fs_button = _button(box, "", _toggle_fullscreen)
	_button(box, "Управление", _toggle_controls)
	_button(box, "Выход", get_tree().quit)
	_update_fs_text()
	play.call_deferred("grab_focus")

	_controls = Label.new()
	_controls.text = "WASD / стрелки — движение\nМышь — прицел, ЛКМ — атака\nПробел / Shift — рывок (неуязвимость)\nE — открыть сундук / подобрать / войти\nQ или 1-4 — смена оружия\nEsc — пауза,  F11 — полный экран"
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.add_theme_font_size_override("font_size", 18)
	_controls.visible = false
	box.add_child(_controls)

	if Game.best_depth > 0:
		var rec := Label.new()
		rec.text = "Рекорд глубины: %d   ·   Забегов: %d" % [Game.best_depth, Game.total_runs]
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rec.add_theme_color_override("font_color", Color(0.9, 0.75, 0.5))
		box.add_child(rec)


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 54)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _toggle_fullscreen() -> void:
	Game.toggle_fullscreen()
	_update_fs_text()


func _update_fs_text() -> void:
	_fs_button.text = "Полный экран: %s" % ("ВКЛ" if Game.is_fullscreen() else "ВЫКЛ")


func _toggle_controls() -> void:
	_controls.visible = not _controls.visible


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		_update_fs_text.call_deferred()


func _new_ember(anywhere: bool) -> Dictionary:
	var vs := get_viewport_rect().size
	return {
		"pos": Vector2(randf() * vs.x, randf() * vs.y if anywhere else vs.y + 10.0),
		"vel": Vector2(randf_range(-15, 15), randf_range(-60, -20)),
		"size": randf_range(1.0, 3.5),
		"hue": randf_range(0.02, 0.1),
	}


func _process(delta: float) -> void:
	_t += delta
	for i in _embers.size():
		var e: Dictionary = _embers[i]
		e["pos"] += e["vel"] * delta + Vector2(sin(_t + i) * 8.0 * delta, 0)
		if e["pos"].y < -10.0:
			_embers[i] = _new_ember(false)
	queue_redraw()


func _draw() -> void:
	var vs := size
	# Градиентный фон пещеры
	var steps := 24
	for i in steps:
		var k := float(i) / steps
		var c := Color(0.06, 0.04, 0.05).lerp(Color(0.18, 0.08, 0.05), k)
		draw_rect(Rect2(0, vs.y * k, vs.x, vs.y / steps + 1.0), c)
	# Сталактиты
	var n := 18
	for i in n:
		var x := vs.x * (i + 0.5) / n
		var len1 := 60.0 + 70.0 * absf(sin(i * 12.9898))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 30, 0), Vector2(x + 30, 0), Vector2(x, len1)]), Color(0.03, 0.02, 0.03))
		var len2 := 40.0 + 60.0 * absf(cos(i * 7.233))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 34, vs.y), Vector2(x + 34, vs.y), Vector2(x + 10, vs.y - len2)]), Color(0.03, 0.02, 0.03))
	# Свечение снизу
	draw_circle(Vector2(vs.x * 0.5, vs.y + 120), vs.x * 0.35, Color(1.0, 0.45, 0.15, 0.08))
	for e in _embers:
		var c := Color.from_hsv(e["hue"], 0.8, 1.0, 0.7)
		draw_circle(e["pos"], e["size"], c)
		draw_circle(e["pos"], e["size"] * 2.5, Color(c, 0.15))
