extends Node2D
## Комната пещеры: случайная генерация уровня, врагов, сундуков и выхода.

const WorldTiles = preload("res://scripts/world_tiles.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Chest = preload("res://scripts/chest.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Portal = preload("res://scripts/portal.gd")
const Decor = preload("res://scripts/decor.gd")
const Hud = preload("res://scripts/hud.gd")

const KIND_NAMES := {"combat": "Логово", "treasure": "Сокровищница", "boss": "Логово Стража"}
const PALETTES := [
	[Color(0.20, 0.17, 0.16), Color(0.33, 0.27, 0.25)],   # бурая
	[Color(0.14, 0.17, 0.20), Color(0.24, 0.29, 0.34)],   # синеватая
	[Color(0.15, 0.19, 0.14), Color(0.26, 0.32, 0.24)],   # мшистая
	[Color(0.21, 0.14, 0.17), Color(0.36, 0.22, 0.27)],   # багровая
]

var world
var player
var hud
var exit_portal
var kind := "combat"
var data: Dictionary
var alive := 0
var cleared := false
var _spawn_tiles: Array = []


func _ready() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	var rng := Game.rng
	kind = _pick_kind(rng)
	var gen := RoomGenerator.new(rng)
	data = gen.generate(kind)

	var canvas_mod := CanvasModulate.new()
	canvas_mod.color = Color(0.42, 0.40, 0.48)
	add_child(canvas_mod)

	world = WorldTiles.new()
	var pal: Array = PALETTES[(Game.depth - 1) / 3 % PALETTES.size()]
	world.floor_color = pal[0]
	world.wall_color = pal[1]
	add_child(world)
	world.setup(data["w"], data["h"], data["cells"], rng.randi())

	for d in data["decor"]:
		var dec := Decor.new()
		dec.type = d["type"]
		dec.seed_value = d["seed"]
		dec.position = world.tile_center(d["tile"])
		add_child(dec)

	# Вход (откуда пришли) и выход
	var entrance_mark := Portal.new()
	entrance_mark.mode = "entrance"
	entrance_mark.position = world.tile_center(data["entrance"]) + Vector2(-40, 0)
	add_child(entrance_mark)

	exit_portal = Portal.new()
	exit_portal.mode = "exit"
	exit_portal.locked = true
	exit_portal.position = world.tile_center(data["exit"])
	exit_portal.activated.connect(_on_exit)
	add_child(exit_portal)

	player = Player.new()
	player.position = world.tile_center(data["entrance"])
	player.died.connect(_on_player_died)
	add_child(player)
	player.set_camera_limits(world.pixel_size())

	hud = Hud.new()
	add_child(hud)

	_spawn_tiles = data["spawns"].duplicate()
	_spawn_tiles.shuffle()
	_populate(rng)
	_update_info()
	Game.toast("Глубина %d — %s" % [Game.depth, KIND_NAMES[kind]], Color(1, 0.9, 0.7), 2.5)


func _pick_kind(rng: RandomNumberGenerator) -> String:
	if Game.depth % 5 == 0:
		return "boss"
	if Game.depth > 1 and rng.randf() < 0.15:
		return "treasure"
	return "combat"


func _take_spawn_tile() -> Vector2i:
	if _spawn_tiles.is_empty():
		_spawn_tiles = data["open"].duplicate()
		_spawn_tiles.shuffle()
	return _spawn_tiles.pop_back()


func _populate(rng: RandomNumberGenerator) -> void:
	var depth := Game.depth
	match kind:
		"boss":
			var center: Vector2 = world.pixel_size() * 0.5
			spawn_enemy("boss", center + Vector2(80, 0))
			Game.toast("Пещерный Страж пробудился!", Color(1, 0.4, 0.8), 3.0)
		"treasure":
			_spawn_chest(1)
			if rng.randf() < 0.5:
				_spawn_chest(0)
			for i in rng.randi_range(0, 2):
				spawn_enemy(_random_enemy_type(rng, depth), world.tile_center(_take_spawn_tile()))
		_:
			var count := mini(3 + int(depth * 0.9) + rng.randi_range(0, 2), 16)
			for i in count:
				spawn_enemy(_random_enemy_type(rng, depth), world.tile_center(_take_spawn_tile()))
			if rng.randf() < 0.35:
				_spawn_chest(0)
	if alive == 0:
		_on_room_cleared()


func _random_enemy_type(rng: RandomNumberGenerator, depth: int) -> String:
	var table := {"slime": 30.0, "bat": 22.0, "skeleton": 16.0}
	if depth >= 2:
		table["spider"] = 16.0
	if depth >= 3:
		table["golem"] = 6.0 + depth
	if depth >= 4:
		table["shaman"] = 6.0 + depth
	var total := 0.0
	for k in table:
		total += float(table[k])
	var r := rng.randf() * total
	for k in table:
		r -= float(table[k])
		if r <= 0.0:
			return k
	return "slime"


func spawn_enemy(t: String, pos: Vector2) -> void:
	var e := Enemy.new()
	e.setup(t, Game.depth)
	e.position = pos
	e.cave = self
	e.world = world
	e.died.connect(_on_enemy_died)
	add_child(e)
	alive += 1
	if cleared:
		cleared = false
		exit_portal.locked = true
	_update_info()


func _spawn_chest(bonus: int) -> void:
	var c := Chest.new()
	c.bonus = bonus
	c.position = world.tile_center(_take_spawn_tile())
	add_child(c)


func _on_enemy_died(e) -> void:
	alive -= 1
	if Game.rng.randf() < (0.12 if not e.is_boss else 1.0):
		var p := Pickup.new()
		p.kind = "potion"
		p.position = e.global_position
		call_deferred("add_child", p)
	if e.is_boss:
		var c := Chest.new()
		c.bonus = 2
		c.position = e.global_position
		call_deferred("add_child", c)
		Game.toast("Страж повержен!", Color(1, 0.85, 0.3), 3.5)
	_update_info()
	if alive <= 0:
		_on_room_cleared()


func _on_room_cleared() -> void:
	if cleared:
		return
	cleared = true
	exit_portal.locked = false
	if kind != "treasure":
		Game.toast("Комната зачищена! Проход открыт →", Color(0.6, 1, 0.6))
		if player != null and not player.dead:
			player.heal(Game.max_hp * 0.1)
	_update_info()


func _on_exit() -> void:
	Game.next_room()


func _on_player_died() -> void:
	hud.show_death()


func _update_info() -> void:
	if hud == null:
		return
	var right := "Глубина %d · %s" % [Game.depth, KIND_NAMES[kind]]
	if alive > 0:
		right += "\nВрагов осталось: %d" % alive
	else:
		right += "\nПроход открыт"
	hud.set_info("Рекорд: %d   Убито: %d" % [Game.best_depth, Game.kills], right)
