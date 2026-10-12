extends Node2D
## Лобби (лагерь): выбор стартового оружия, манекен для тренировки, вход в пещеру.

const WorldTiles = preload("res://scripts/world_tiles.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Portal = preload("res://scripts/portal.gd")
const Pedestal = preload("res://scripts/pedestal.gd")
const Decor = preload("res://scripts/decor.gd")
const Hud = preload("res://scripts/hud.gd")

const W := 30
const H := 18

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

	var cells := PackedByteArray()
	cells.resize(W * H)
	for y in H:
		for x in W:
			var wall := x <= 1 or y <= 1 or x >= W - 2 or y >= H - 2
			# неровные углы
			if (x <= 3 and y <= 3) or (x <= 3 and y >= H - 4) or (x >= W - 4 and y <= 3) or (x >= W - 4 and y >= H - 4):
				wall = wall or (x + y) % 3 == 0
			cells[y * W + x] = 1 if wall else 0
	# проход к пещере
	for y in range(7, 11):
		cells[y * W + W - 2] = 0

	world = WorldTiles.new()
	world.floor_color = Color(0.24, 0.2, 0.17)
	world.wall_color = Color(0.36, 0.3, 0.26)
	add_child(world)
	world.setup(W, H, cells, 7)

	var kinds := ["sword", "bow", "magic"]
	for i in kinds.size():
		var p := Pedestal.new()
		p.weapon_kind = kinds[i]
		p.position = world.tile_center(Vector2i(9 + i * 5, 6))
		add_child(p)

	for t in [Vector2i(3, 5), Vector2i(3, 12), Vector2i(26, 4), Vector2i(26, 13), Vector2i(14, 3)]:
		var d := Decor.new()
		d.type = 0
		d.seed_value = randf()
		d.position = world.tile_center(t)
		add_child(d)

	var dummy := Enemy.new()
	dummy.setup("dummy", 1)
	dummy.position = world.tile_center(Vector2i(14, 13))
	add_child(dummy)

	portal = Portal.new()
	portal.mode = "lobby"
	portal.prompt_open = "[E] Войти в пещеру"
	portal.prompt_locked = "Сначала выберите оружие на пьедестале"
	portal.position = world.tile_center(Vector2i(W - 3, 8)) + Vector2(16, 16)
	portal.activated.connect(Game.start_run)
	add_child(portal)

	var player := Player.new()
	player.position = world.tile_center(Vector2i(5, 9))
	add_child(player)
	player.set_camera_limits(world.pixel_size())

	hud = Hud.new()
	add_child(hud)
	hud.set_info("WASD — движение · ЛКМ — атака · Пробел — рывок\nE — взаимодействие · Q / 1-4 — смена оружия · Esc — пауза",
		"Лагерь искателей\nЛучшая глубина: %d" % Game.best_depth)
	Game.toast("Выберите оружие на одном из пьедесталов", Color(1, 0.95, 0.7), 4.0)


func _process(_delta: float) -> void:
	portal.locked = Game.inventory.is_empty()


func _draw() -> void:
	var f := ThemeDB.fallback_font
	var pos: Vector2 = world.tile_center(Vector2i(14, 3)) + Vector2(-200, 24)
	draw_string(f, pos, "ВЫБЕРИТЕ ОРУЖИЕ", HORIZONTAL_ALIGNMENT_CENTER, 400, 22, Color(1, 0.9, 0.7, 0.8))
