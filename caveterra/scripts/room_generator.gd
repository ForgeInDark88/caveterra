extends RefCounted
## Процедурная генерация комнат пещеры.
## Возвращает словарь: w, h, cells, entrance, exit, spawns, decor, style.

const STYLES := ["cavern", "pillars", "chambers", "cavern", "chambers"]

var rng: RandomNumberGenerator
var w := 0
var h := 0
var cells := PackedByteArray()


func _init(random: RandomNumberGenerator) -> void:
	rng = random


func generate(kind: String) -> Dictionary:
	var style: String
	if kind == "boss":
		style = "arena"
		w = 42
		h = 30
	elif kind == "treasure":
		style = "arena"
		w = rng.randi_range(28, 34)
		h = rng.randi_range(20, 24)
	else:
		style = STYLES[rng.randi_range(0, STYLES.size() - 1)]
		w = rng.randi_range(36, 52)
		h = rng.randi_range(24, 32)

	cells = PackedByteArray()
	cells.resize(w * h)
	cells.fill(1)

	match style:
		"cavern":
			_gen_cavern()
		"pillars":
			_gen_pillars()
		"chambers":
			_gen_chambers()
		_:
			_gen_arena(kind == "boss")

	_border()
	var entrance := Vector2i(2, rng.randi_range(4, h - 5))
	var exit := Vector2i(w - 3, rng.randi_range(4, h - 5))
	# Соединяем вход и выход с самой большой областью пещеры.
	var main_region := _largest_region()
	if not main_region.is_empty():
		_carve_tunnel(entrance, _closest_tile(main_region, entrance))
		_carve_tunnel(exit, _closest_tile(main_region, exit))
	_carve_circle(entrance, 2.5)
	_carve_circle(exit, 2.5)
	_border()

	if not _reachable(entrance).has(exit):
		_carve_tunnel(entrance, exit)
		_border()
	# Убираем недоступные островки пола.
	var reach := _reachable(entrance)
	for y in h:
		for x in w:
			if cells[y * w + x] == 0 and not reach.has(Vector2i(x, y)):
				cells[y * w + x] = 1

	var spawns: Array = []
	var near_open: Array = []
	for t in reach.keys():
		var tile: Vector2i = t
		if _open_around(tile, 1):
			near_open.append(tile)
			if tile.distance_to(entrance) > 11.0 and tile.distance_to(exit) > 3.0:
				spawns.append(tile)
	if spawns.is_empty():
		spawns = near_open.duplicate()

	var decor: Array = []
	for i in (rng.randi_range(6, 14) if not near_open.is_empty() else 0):
		var t: Vector2i = near_open[rng.randi_range(0, near_open.size() - 1)]
		decor.append({"tile": t, "type": rng.randi_range(0, 2), "seed": rng.randf()})

	return {
		"w": w, "h": h, "cells": cells, "entrance": entrance, "exit": exit,
		"spawns": spawns, "open": near_open, "decor": decor, "style": style,
	}


# ------------------------------------------------------------------ стили
func _gen_cavern() -> void:
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			cells[y * w + x] = 1 if rng.randf() < 0.44 else 0
	for i in 5:
		var next := cells.duplicate()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var n := _wall_neighbors(x, y)
				if n >= 5:
					next[y * w + x] = 1
				elif n <= 3:
					next[y * w + x] = 0
		cells = next


func _gen_pillars() -> void:
	_fill_rect(Rect2i(2, 2, w - 4, h - 4), 0)
	for i in rng.randi_range(6, 14):
		var pw := rng.randi_range(1, 3)
		var ph := rng.randi_range(1, 3)
		var px := rng.randi_range(6, w - 8)
		var py := rng.randi_range(3, h - 5)
		_fill_rect(Rect2i(px, py, pw, ph), 1)
	# Неровные края
	for i in 30:
		var t := Vector2i(rng.randi_range(2, w - 3), rng.randi_range(2, h - 3))
		if t.x < 4 or t.x > w - 5 or t.y < 4 or t.y > h - 5:
			_set_circle(t, rng.randf_range(1.0, 2.5), 1)


func _gen_chambers() -> void:
	var centers: Array = []
	var count := rng.randi_range(4, 7)
	for i in count:
		var c := Vector2i(
			int(lerpf(5, w - 6, (i + rng.randf_range(0.1, 0.9)) / count)),
			rng.randi_range(5, h - 6))
		centers.append(c)
		var rx := rng.randf_range(3.0, 6.5)
		var ry := rng.randf_range(3.0, 5.5)
		_carve_ellipse(c, rx, ry)
	for i in range(1, centers.size()):
		_carve_tunnel(centers[i - 1], centers[i])
	if rng.randf() < 0.6 and centers.size() > 2:
		_carve_tunnel(centers[0], centers[centers.size() - 1])


func _gen_arena(boss: bool) -> void:
	var c := Vector2i(w / 2, h / 2)
	_carve_ellipse(c, w * 0.46, h * 0.44)
	# Шероховатость края
	for i in 40:
		var a := rng.randf() * TAU
		var p := Vector2(c) + Vector2(cos(a) * w * 0.45, sin(a) * h * 0.43)
		_set_circle(Vector2i(p), rng.randf_range(1.0, 2.2), 1)
	var pillars := 4 if boss else rng.randi_range(0, 3)
	for i in pillars:
		var a := TAU * i / pillars + 0.4
		var p := Vector2(c) + Vector2(cos(a) * w * 0.25, sin(a) * h * 0.25)
		_set_circle(Vector2i(p), 1.2, 1)


# ------------------------------------------------------------------ утилиты
func _fill_rect(r: Rect2i, v: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x > 0 and y > 0 and x < w - 1 and y < h - 1:
				cells[y * w + x] = v


func _set_circle(c: Vector2i, r: float, v: int) -> void:
	var ri := ceili(r)
	for y in range(c.y - ri, c.y + ri + 1):
		for x in range(c.x - ri, c.x + ri + 1):
			if x > 0 and y > 0 and x < w - 1 and y < h - 1 and Vector2(x - c.x, y - c.y).length() <= r:
				cells[y * w + x] = v


func _carve_circle(c: Vector2i, r: float) -> void:
	_set_circle(c, r, 0)


func _carve_ellipse(c: Vector2i, rx: float, ry: float) -> void:
	for y in range(c.y - ceili(ry), c.y + ceili(ry) + 1):
		for x in range(c.x - ceili(rx), c.x + ceili(rx) + 1):
			var dx := (x - c.x) / rx
			var dy := (y - c.y) / ry
			if dx * dx + dy * dy <= 1.0 and x > 0 and y > 0 and x < w - 1 and y < h - 1:
				cells[y * w + x] = 0


## Извилистый туннель шириной ~3 тайла.
func _carve_tunnel(a: Vector2i, b: Vector2i) -> void:
	var p := Vector2(a)
	var target := Vector2(b)
	var guard := 0
	while p.distance_to(target) > 1.5 and guard < 600:
		guard += 1
		var dir := (target - p).normalized()
		dir = dir.rotated(rng.randf_range(-0.9, 0.9))
		p += dir
		p.x = clampf(p.x, 2, w - 3)
		p.y = clampf(p.y, 2, h - 3)
		_carve_circle(Vector2i(roundi(p.x), roundi(p.y)), 1.5)
	_carve_circle(b, 1.5)


func _border() -> void:
	for x in w:
		cells[x] = 1
		cells[(h - 1) * w + x] = 1
	for y in h:
		cells[y * w] = 1
		cells[y * w + w - 1] = 1


func _wall_neighbors(x: int, y: int) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= w or ny >= h or cells[ny * w + nx] == 1:
				n += 1
	return n


func _open_around(t: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := t.x + dx
			var y := t.y + dy
			if x < 0 or y < 0 or x >= w or y >= h or cells[y * w + x] == 1:
				return false
	return true


func _reachable(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array = [start]
	var i := 0
	while i < queue.size():
		var t: Vector2i = queue[i]
		i += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = t + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			if cells[n.y * w + n.x] == 1 or seen.has(n):
				continue
			seen[n] = true
			queue.append(n)
	return seen


func _largest_region() -> Array:
	var visited := {}
	var best: Array = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var t := Vector2i(x, y)
			if cells[y * w + x] == 1 or visited.has(t):
				continue
			var region := _reachable(t)
			for k in region.keys():
				visited[k] = true
			if region.size() > best.size():
				best = region.keys()
	return best


func _closest_tile(tiles: Array, to: Vector2i) -> Vector2i:
	var best: Vector2i = tiles[0]
	var bd := INF
	for t in tiles:
		var tile: Vector2i = t
		var d := Vector2(tile - to).length_squared()
		if d < bd:
			bd = d
			best = tile
	return best
