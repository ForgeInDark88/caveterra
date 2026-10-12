extends Node2D
## Сетка тайлов (вид сбоку): отрисовка, коллизии стен и проходимых снизу платформ.
## 0 — воздух, 1 — камень, 2 — платформа (можно запрыгнуть снизу и спрыгнуть вниз), 3 — шипы.

const TILE := 32
const AIR := 0
const SOLID := 1
const PLATFORM := 2
const SPIKES := 3

var w := 0
var h := 0
var cells := PackedByteArray()
var floor_color := Color(0.20, 0.17, 0.16)   # цвет заднего фона пещеры
var wall_color := Color(0.33, 0.27, 0.25)
var moss_color := Color(0.30, 0.45, 0.25)
var _seed := 0


func setup(grid_w: int, grid_h: int, grid: PackedByteArray, palette_seed: int = 0) -> void:
	w = grid_w
	h = grid_h
	cells = grid
	_seed = palette_seed
	z_index = -10
	add_to_group("world_tiles")
	_build_collision()
	queue_redraw()


func get_tile(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return SOLID
	return cells[y * w + x]


func is_wall(x: int, y: int) -> bool:
	return get_tile(x, y) == SOLID


## Можно ли стоять на тайле (камень или платформа).
func is_standable(x: int, y: int) -> bool:
	var t := get_tile(x, y)
	return t == SOLID or t == PLATFORM


func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE * 0.5, t.y * TILE + TILE * 0.5)


## Точка на полу тайла (низ тайла) — сюда ставятся сундуки, двери и т.д.
func tile_floor(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE * 0.5, (t.y + 1) * TILE)


func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func pixel_size() -> Vector2:
	return Vector2(w * TILE, h * TILE)


## Высота поверхности, на которую упадёт предмет из точки p.
func ground_y_below(p: Vector2) -> float:
	var t := world_to_tile(p)
	for y in range(maxi(t.y, 0), h):
		if is_standable(t.x, y):
			return y * TILE
	return p.y


func _build_collision() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	walls.add_to_group("walls")
	add_child(walls)
	var platforms := StaticBody2D.new()
	platforms.collision_layer = 16
	platforms.collision_mask = 0
	platforms.add_to_group("platforms")
	add_child(platforms)
	# Склеиваем горизонтальные отрезки в прямоугольники.
	for y in h:
		var x := 0
		while x < w:
			var t := get_tile(x, y)
			if t != SOLID and t != PLATFORM:
				x += 1
				continue
			var start := x
			while x < w and get_tile(x, y) == t:
				x += 1
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			var cx := start * TILE + (x - start) * TILE * 0.5
			if t == SOLID:
				rect.size = Vector2((x - start) * TILE, TILE)
				shape.position = Vector2(cx, y * TILE + TILE * 0.5)
				shape.shape = rect
				walls.add_child(shape)
			else:
				rect.size = Vector2((x - start) * TILE, 10)
				shape.position = Vector2(cx, y * TILE + 5)
				shape.shape = rect
				shape.one_way_collision = true
				platforms.add_child(shape)


func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263 + _seed * 2147483) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 1000) / 1000.0


func _draw() -> void:
	# Тьма за пределами комнаты
	draw_rect(Rect2(-TILE * 30, -TILE * 30, (w + 60) * TILE, (h + 60) * TILE), Color(0.03, 0.025, 0.035))
	var back := floor_color.darkened(0.35)
	for y in h:
		for x in w:
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			var v := _hash(x, y)
			var t := get_tile(x, y)
			if t != SOLID:
				# Задняя стена пещеры
				draw_rect(r, back.lightened(v * 0.06))
				if v > 0.9:
					draw_circle(r.position + Vector2(6 + v * 18, 8 + v * 14), 3.0 + v * 3.0, back.darkened(0.25))
				elif v < 0.05:
					draw_line(r.position + Vector2(4, 22), r.position + Vector2(26, 10), back.darkened(0.3), 2.0)
			if t == SOLID:
				var edge := not is_wall(x - 1, y) or not is_wall(x + 1, y) or not is_wall(x, y - 1) or not is_wall(x, y + 1)
				if edge:
					draw_rect(r, wall_color.lightened(v * 0.1))
					draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(TILE - 6, TILE - 6)), wall_color.lightened(0.05 + v * 0.08))
					if v > 0.65:
						draw_circle(r.position + Vector2(8 + v * 14, 14 + v * 8), 2.5, wall_color.darkened(0.25))
					# Поверхность пола: мох и светлая кромка
					if not is_wall(x, y - 1):
						draw_rect(Rect2(r.position, Vector2(TILE, 5)), wall_color.lightened(0.3))
						if v > 0.35:
							draw_rect(Rect2(r.position + Vector2(0, -2), Vector2(TILE, 4)), moss_color.lightened(v * 0.2))
							for i in 3:
								var gx := 4.0 + i * 11.0 + v * 4.0
								draw_line(r.position + Vector2(gx, 0), r.position + Vector2(gx + 2, -5 - v * 4), moss_color, 1.5)
					# Потолок: тень
					if not is_wall(x, y + 1):
						draw_rect(Rect2(r.position + Vector2(0, TILE - 5), Vector2(TILE, 5)), wall_color.darkened(0.45))
				else:
					draw_rect(r, Color(0.09, 0.07, 0.075).lightened(v * 0.04))
			elif t == PLATFORM:
				var plank := Color(0.42, 0.29, 0.17)
				draw_rect(Rect2(r.position, Vector2(TILE, 9)), plank.lightened(v * 0.1))
				draw_rect(Rect2(r.position, Vector2(TILE, 2)), plank.lightened(0.3))
				draw_line(r.position + Vector2(TILE - 1, 0), r.position + Vector2(TILE - 1, 9), plank.darkened(0.4), 1.0)
				# опоры, если платформа висит
				if get_tile(x - 1, y) != PLATFORM:
					draw_line(r.position + Vector2(4, 9), r.position + Vector2(4, 16), plank.darkened(0.3), 3.0)
				if get_tile(x + 1, y) != PLATFORM:
					draw_line(r.position + Vector2(TILE - 4, 9), r.position + Vector2(TILE - 4, 16), plank.darkened(0.3), 3.0)
			elif t == SPIKES:
				for i in 4:
					var bx := r.position.x + i * 8.0
					var by := r.position.y + TILE
					draw_colored_polygon(PackedVector2Array([Vector2(bx, by), Vector2(bx + 4, by - 14 - v * 4), Vector2(bx + 8, by)]), Color(0.7, 0.68, 0.72))
					draw_line(Vector2(bx + 4, by - 14 - v * 4), Vector2(bx + 4, by - 9), Color(0.75, 0.2, 0.2), 2.0)
