extends Node2D
## Сетка тайлов пещеры: отрисовка, коллизии стен и поиск пути (AStarGrid2D).

const TILE := 32

var w := 0
var h := 0
var cells := PackedByteArray()   # 0 — пол, 1 — стена
var floor_color := Color(0.20, 0.17, 0.16)
var wall_color := Color(0.33, 0.27, 0.25)
var astar := AStarGrid2D.new()
var _seed := 0


func setup(grid_w: int, grid_h: int, grid: PackedByteArray, palette_seed: int = 0) -> void:
	w = grid_w
	h = grid_h
	cells = grid
	_seed = palette_seed
	z_index = -10
	_build_collision()
	_build_astar()
	queue_redraw()


func is_wall(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return true
	return cells[y * w + x] == 1


func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE * 0.5, t.y * TILE + TILE * 0.5)


func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func pixel_size() -> Vector2:
	return Vector2(w * TILE, h * TILE)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := world_to_tile(from)
	var b := world_to_tile(to)
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return PackedVector2Array()
	if astar.is_point_solid(a) or astar.is_point_solid(b):
		return PackedVector2Array()
	return astar.get_point_path(a, b)


func _build_astar() -> void:
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(TILE, TILE)
	astar.offset = Vector2(TILE * 0.5, TILE * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in h:
		for x in w:
			if is_wall(x, y):
				astar.set_point_solid(Vector2i(x, y), true)


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("walls")
	add_child(body)
	# Склеиваем горизонтальные отрезки стен в прямоугольники.
	for y in h:
		var x := 0
		while x < w:
			if not is_wall(x, y):
				x += 1
				continue
			var start := x
			while x < w and is_wall(x, y):
				x += 1
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2((x - start) * TILE, TILE)
			shape.shape = rect
			shape.position = Vector2(start * TILE + (x - start) * TILE * 0.5, y * TILE + TILE * 0.5)
			body.add_child(shape)


func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263 + _seed * 2147483) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 1000) / 1000.0


func _draw() -> void:
	# Внешняя тьма за пределами комнаты
	draw_rect(Rect2(-TILE * 20, -TILE * 20, (w + 40) * TILE, (h + 40) * TILE), Color(0.03, 0.025, 0.035))
	for y in h:
		for x in w:
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			var v := _hash(x, y)
			if not is_wall(x, y):
				draw_rect(r, floor_color.lightened(v * 0.08).darkened(0.04))
				if v > 0.86:
					draw_circle(r.position + Vector2(8 + v * 14, 10 + v * 10), 2.0 + v * 2.0, floor_color.darkened(0.3))
				elif v < 0.06:
					draw_line(r.position + Vector2(6, 20), r.position + Vector2(22, 14), floor_color.darkened(0.35), 1.5)
			else:
				var edge := not is_wall(x - 1, y) or not is_wall(x + 1, y) or not is_wall(x, y - 1) or not is_wall(x, y + 1)
				if edge:
					draw_rect(r, wall_color.lightened(v * 0.1))
					# «верх» скалы над полом — объём
					if not is_wall(x, y + 1):
						draw_rect(Rect2(r.position + Vector2(0, TILE - 7), Vector2(TILE, 7)), wall_color.darkened(0.45))
					if not is_wall(x, y - 1):
						draw_rect(Rect2(r.position, Vector2(TILE, 4)), wall_color.lightened(0.25))
					if v > 0.7:
						draw_circle(r.position + Vector2(10 + v * 10, 12), 3.0, wall_color.darkened(0.2))
				else:
					draw_rect(r, Color(0.08, 0.065, 0.07).lightened(v * 0.04))
