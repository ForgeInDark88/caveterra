extends Node
## Глобальное состояние игры (автозагрузка "Game"): забег, инвентарь, управление, сохранения.

const WeaponDB = preload("res://scripts/weapon_db.gd")

const MAX_SLOTS := 4
const SAVE_PATH := "user://caveterra.cfg"

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const CAVE_SCENE := "res://scenes/cave.tscn"

var rng := RandomNumberGenerator.new()

# --- состояние забега ---
var inventory: Array = []
var current_slot := 0
var depth := 0
var max_hp := 100.0
var hp := 100.0
var max_mana := 100.0
var mana := 100.0
var kills := 0
var rooms_cleared := 0
var run_active := false

# --- рекорды ---
var best_depth := 0
var total_runs := 0

# --- интерфейс ---
var prompt := ""
var toasts: Array = []
var shake_strength := 0.0

var _light_texture: GradientTexture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_setup_input()
	_load()


func _process(delta: float) -> void:
	for t in toasts:
		t["time"] -= delta
	toasts = toasts.filter(func(t): return t["time"] > 0.0)
	shake_strength = move_toward(shake_strength, 0.0, 40.0 * delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()


# ---------------------------------------------------------------- управление
func _setup_input() -> void:
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("interact", [KEY_E])
	_add_keys("dash", [KEY_SPACE, KEY_SHIFT])
	_add_keys("switch_weapon", [KEY_Q])
	_add_keys("pause", [KEY_ESCAPE])
	_add_keys("toggle_fullscreen", [KEY_F11])
	for i in MAX_SLOTS:
		_add_keys("slot_%d" % (i + 1), [KEY_1 + i])
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mb)


func _add_keys(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- экран
func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func toggle_fullscreen() -> void:
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ---------------------------------------------------------------- сцены
func go_to_main_menu() -> void:
	get_tree().paused = false
	run_active = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func go_to_lobby() -> void:
	get_tree().paused = false
	run_active = false
	inventory.clear()
	current_slot = 0
	hp = max_hp
	mana = max_mana
	get_tree().change_scene_to_file(LOBBY_SCENE)


func choose_start_weapon(kind: String) -> void:
	inventory = [WeaponDB.make_starter(kind)]
	current_slot = 0


func start_run() -> void:
	if inventory.is_empty():
		return
	rng.randomize()
	depth = 1
	kills = 0
	rooms_cleared = 0
	hp = max_hp
	mana = max_mana
	run_active = true
	total_runs += 1
	_save()
	get_tree().paused = false
	get_tree().change_scene_to_file(CAVE_SCENE)


func next_room() -> void:
	rooms_cleared += 1
	depth += 1
	if depth > best_depth:
		best_depth = depth
		_save()
	get_tree().change_scene_to_file(CAVE_SCENE)


func end_run() -> void:
	run_active = false
	if depth > best_depth:
		best_depth = depth
	_save()


# ---------------------------------------------------------------- инвентарь
func current_weapon() -> Dictionary:
	if inventory.is_empty():
		return {}
	current_slot = clampi(current_slot, 0, inventory.size() - 1)
	return inventory[current_slot]


func select_slot(i: int) -> void:
	if i >= 0 and i < inventory.size():
		current_slot = i


func cycle_weapon() -> void:
	if inventory.size() > 1:
		current_slot = (current_slot + 1) % inventory.size()


## Добавляет оружие. Если слоты заняты — заменяет текущее и возвращает выброшенное.
func add_weapon(w: Dictionary) -> Dictionary:
	if inventory.size() < MAX_SLOTS:
		inventory.append(w)
		current_slot = inventory.size() - 1
		return {}
	var dropped: Dictionary = inventory[current_slot]
	inventory[current_slot] = w
	return dropped


# ---------------------------------------------------------------- эффекты/интерфейс
func toast(text: String, color: Color = Color.WHITE, time: float = 3.0) -> void:
	toasts.append({"text": text, "color": color, "time": time})
	if toasts.size() > 4:
		toasts.pop_front()


func shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)


func light_texture() -> GradientTexture2D:
	if _light_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		_light_texture = GradientTexture2D.new()
		_light_texture.gradient = g
		_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_light_texture.fill_from = Vector2(0.5, 0.5)
		_light_texture.fill_to = Vector2(1.0, 0.5)
		_light_texture.width = 256
		_light_texture.height = 256
	return _light_texture


# ---------------------------------------------------------------- сохранение
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "best_depth", best_depth)
	cfg.set_value("stats", "total_runs", total_runs)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_depth = int(cfg.get_value("stats", "best_depth", 0))
		total_runs = int(cfg.get_value("stats", "total_runs", 0))
