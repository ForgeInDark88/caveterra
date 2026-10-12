extends Node2D
## Лобби (лагерь): выбор стартового оружия, манекен для тренировки, вход в пещеру.

const WorldTiles = preload("res://scripts/world_tiles.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Portal = preload("res://scripts/portal.gd")
const Pedestal = preload("res://scripts/pedestal.gd")
const Decor = preload("res://scripts/decor.gd")
const Hud = preload("res://scripts/hud.gd")

const W := 42
const H := 18
const FLOOR := 14

var world
var portal
var hud


func _ready() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	Game.run_active = false
	Game.hp = Game.max_hp
	Game.mana = Game.max_mana

	var canvas_mod := CanvasModulate.new()
	canvas_mod.color = Color(0.55, 0.5, 0.55)
	add_child(canvas_mod)

	# Лагерь: ровный пол, неровный потолок, пара платформ.
	var cells := PackedByteArray()
	cells.resize(W * H)
	for y in H:
		for x in W:
			var solid := x == 0 or x == W - 1 or y >= FLOOR or y <= 1
			if y == 2 and (x * 7) % 5 < 2:
				solid = true
			cells[y * W + x] = 1 if solid else 0
	for x in range(20, 26):
		cells[(FLOOR - 4) * W + x] = 2
	for x in range(27, 31):
		cells[(FLOOR - 7) * W + x] = 2

	world = WorldTiles.new()
	world.floor_color = Color(0.26, 0.21, 0.18)
	world.wall_color = Color(0.38, 0.31, 0.26)
	add_child(world)
	world.setup(W, H, cells, 7)

	var kinds := ["sword", "bow", "magic"]
	for i in kinds.size():
		var p := Pedestal.new()
		p.weapon_kind = kinds[i]
		p.position = world.tile_floor(Vector2i(9 + i * 5, FLOOR - 1)) - Vector2(0, 22)
		add_child(p)

	for t in [Vector2i(3, FLOOR - 1), Vector2i(18, FLOOR - 1), Vector2i(33, FLOOR - 1)]:
		var d := Decor.new()
		d.type = 0
		d.seed_value = randf()
		d.position = world.tile_floor(t) - Vector2(0, 6)
		add_child(d)
	for x in [6, 15, 24, 31, 38]:
		var d := Decor.new()
		d.type = 4 if x % 2 == 0 else 3
		d.seed_value = randf()
		d.position = world.tile_center(Vector2i(x, 3))
		add_child(d)

	var dummy := Enemy.new()
	dummy.setup("dummy", 1)
	dummy.position = world.tile_floor(Vector2i(26, FLOOR - 1)) - Vector2(0, 15)
	add_child(dummy)

	portal = Portal.new()
	portal.mode = "lobby"
	portal.prompt_open = "[E] Спуститься в пещеру"
	portal.prompt_locked = "Сначала выберите оружие на пьедестале"
	portal.position = world.tile_floor(Vector2i(37, FLOOR - 1))
	portal.activated.connect(Game.start_run)
	add_child(portal)

	var player := Player.new()
	player.position = world.tile_floor(Vector2i(4, FLOOR - 1)) - Vector2(0, 21)
	player.world = world
	add_child(player)
	player.set_camera_limits(world.pixel_size())

	hud = Hud.new()
	add_child(hud)
	hud.set_info("A/D — ходить · W/Пробел — прыжок · S — спрыгнуть вниз\nЛКМ — атака · Shift — рывок · E — действие · Q/1-4 — оружие · Esc — пауза",
		"Лагерь искателей\nЛучшая глубина: %d" % Game.best_depth)
	Game.toast("Выберите оружие на одном из пьедесталов", Color(1, 0.95, 0.7), 4.0)


func _process(_delta: float) -> void:
	portal.locked = Game.inventory.is_empty()


func _draw() -> void:
	var f := ThemeDB.fallback_font
	var pos: Vector2 = world.tile_center(Vector2i(14, 7)) + Vector2(-200, 0)
	draw_string(f, pos, "ВЫБЕРИТЕ ОРУЖИЕ", HORIZONTAL_ALIGNMENT_CENTER, 400, 22, Color(1, 0.9, 0.7, 0.8))
