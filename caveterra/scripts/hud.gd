extends CanvasLayer
## Слой интерфейса + меню паузы и экран смерти.

const HudView = preload("res://scripts/hud_view.gd")

var view: HudView
var _menu: Control = null


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	view = HudView.new()
	add_child(view)


func set_info(left: String, right: String) -> void:
	view.info_left = left
	view.info_right = right


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _menu != null and _menu.name == "PauseMenu":
			resume()
		elif _menu == null:
			show_pause()
		get_viewport().set_input_as_handled()


func show_pause() -> void:
	get_tree().paused = true
	var buttons := [["Продолжить", resume]]
	if Game.run_active:
		buttons.append(["Сдаться (в лобби)", _to_lobby])
	else:
		buttons.append(["Сбросить выбор", _to_lobby])
	buttons.append(["Полноэкранный режим (F11)", Game.toggle_fullscreen])
	buttons.append(["Главное меню", _to_menu])
	_open_menu("PauseMenu", "Пауза", "", buttons)


func show_death() -> void:
	Game.end_run()
	var stats := "Глубина: %d    Убито врагов: %d    Пройдено комнат: %d\nРекорд глубины: %d" % [Game.depth, Game.kills, Game.rooms_cleared, Game.best_depth]
	_open_menu("DeathMenu", "Вы погибли", stats, [["Вернуться в лобби", _to_lobby], ["Главное меню", _to_menu]])


func resume() -> void:
	get_tree().paused = false
	if _menu != null:
		_menu.queue_free()
		_menu = null


func _to_lobby() -> void:
	Game.go_to_lobby()


func _to_menu() -> void:
	Game.go_to_main_menu()


func _open_menu(menu_name: String, title: String, subtitle: String, buttons: Array) -> void:
	if _menu != null:
		_menu.queue_free()
	var root := Control.new()
	root.name = menu_name
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)
	_menu = root

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 48)
	t.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if menu_name == "DeathMenu" else Color(1, 0.9, 0.7))
	box.add_child(t)

	if subtitle != "":
		var s := Label.new()
		s.text = subtitle
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_font_size_override("font_size", 18)
		box.add_child(s)

	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(340, 48)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(b[1])
		box.add_child(btn)
	box.get_child(box.get_child_count() - buttons.size()).call_deferred("grab_focus")
