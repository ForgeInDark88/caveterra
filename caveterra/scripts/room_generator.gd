extends RefCounted
## Процедурная генерация комнат пещеры (вид сбоку).
## Комната состоит из горизонтальных ярусов. Ярусы соединены ямами и люками-платформами,
## под люками стоят «лестницы» из платформ, чтобы можно было подняться обратно.
## Вход — на верхнем ярусе слева, выход (спуск глубже) — на нижнем ярусе.
## Возвращает: w, h, cells, entrance, exit, floor_spots, air_spots, decor.

const AIR := 0
const SOLID := 1
const PLATFORM := 2
const SPIKES := 3

const CHUNK_W := 14
const BAND := 9          # 8 рядов воздуха + 1 ряд пола

var rng: RandomNumberGenerator
var w := 0
var h := 0
var cells := PackedByteArray()
var bands := 0
var _reserved := {}      # Vector2i(band, x) — колонки, где нельзя ставить препятствия


func _init(random: RandomNumberGenerator) -> void:
	rng = random


func generate(kind: String) -> Dictionary:
	_reserved.clear()
	var entrance: Vector2i
	var exit: Vector2i
	if kind == "boss":
		_gen_arena()
		entrance = Vector2i(3, h - 3)
		exit = Vector2i(w - 4, h - 3)
	else:
		var cols := 3 if kind == "treasure" else rng.randi_range(5, 7)
		bands = 2 if kind == "treasure" else rng.randi_range(3, 4)
		w = cols * CHUNK_W + 2
		h = bands * BAND + 2
		_gen_bands()
		entrance = Vector2i(3, _floor_row(0) - 1)
		exit = Vector2i(w - rng.randi_range(4, 10), _floor_row(bands - 1) - 1)
		_flatten(0, entrance.x - 2, entrance.x + 3)
		_flatten(bands - 1, exit.x - 2, exit.x + 2)
		entrance.y = _surface_y(entrance.x, 0) - 1
		exit.y = _surface_y(exit.x, bands - 1) - 1

	# Точки для спавна
	var floor_spots: Array = []
	var air_spots: Array = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if _get(x, y) != AIR:
				continue
			var below := _get(x, y + 1)
			if (below == SOLID or below == PLATFORM) and _get(x, y - 1) == AIR:
				floor_spots.append(Vector2i(x, y))
			elif _get(x, y - 1) == AIR and _get(x, y + 1) == AIR and _get(x - 1, y) == AIR and _get(x + 1, y) == AIR:
				air_spots.append(Vector2i(x, y))

	var decor: Array = []
	for i in rng.randi_range(14, 26):
		var t: Vector2i = floor_spots[rng.randi_range(0, floor_spots.size() - 1)]
		if _get(t.x, t.y + 1) == SOLID:
			decor.append({"tile": t, "type": rng.randi_range(0, 2), "seed": rng.randf(), "ceiling": false})
	for i in rng.randi_range(10, 20):
		var x := rng.randi_range(1, w - 2)
		var y := rng.randi_range(1, h - 2)
		if _get(x, y) == AIR and _get(x, y - 1) == SOLID:
			decor.append({"tile": Vector2i(x, y), "type": rng.randi_range(3, 4), "seed": rng.randf(), "ceiling": true})

	return {
		"w": w, "h": h, "cells": cells, "entrance": entrance, "exit": exit,
		"floor_spots": floor_spots, "air_spots": air_spots, "decor": decor,
	}


# ------------------------------------------------------------------ ярусы
func _top_air(b: int) -> int:
	return b * BAND + 1


func _floor_row(b: int) -> int:
	return (b + 1) * BAND


func _gen_bands() -> void:
	cells = PackedByteArray()
	cells.resize(w * h)
	cells.fill(SOLID)
	for b in bands:
		for y in range(_top_air(b), _floor_row(b)):
			for x in range(1, w - 1):
				_set(x, y, AIR)

	# Неровный пол и потолок
	for b in bands:
		var x := 1
		while x < w - 1:
			var seg := rng.randi_range(3, 8)
			var r := rng.randf()
			var raise := 0 if r < 0.55 else (1 if r < 0.85 else 2)
			r = rng.randf()
			var drop := 0 if r < 0.5 else (1 if r < 0.82 else 2)
			for xx in range(x, mini(x + seg, w - 1)):
				for i in raise:
					_set(xx, _floor_row(b) - 1 - i, SOLID)
				for i in drop:
					_set(xx, _top_air(b) + i, SOLID)
			x += seg

	# Соединения между ярусами
	for b in range(bands - 1):
		var count := rng.randi_range(1, 3)
		var slots: Array = []
		for i in count:
			var lo := 4 + (w - 10) * i / count
			var hi := 4 + (w - 10) * (i + 1) / count - 4
			slots.append(rng.randi_range(lo, maxi(lo, hi)))
		for x in slots:
			_make_hole(b, x, rng.randf() < 0.55)

	# Препятствия, платформы и шипы внутри ярусов
	for b in bands:
		var x := 6
		while x < w - 6:
			var feature := rng.randf()
			var length := rng.randi_range(3, 6)
			if _is_reserved(b, x - 1, x + length + 1):
				x += 2
				continue
			var surface := _surface_y(x, b)
			var flat := true
			for xx in range(x, x + length):
				if _surface_y(xx, b) != surface:
					flat = false
			if feature < 0.25:
				# Висячая платформа
				var py := surface - rng.randi_range(3, 4)
				if py > _ceiling_y(x, b) + 1:
					for xx in range(x, x + length):
						if _get(xx, py) == AIR:
							_set(xx, py, PLATFORM)
			elif feature < 0.40 and flat:
				# Каменный выступ высотой 1-2
				var ph := rng.randi_range(1, 2)
				var pw := rng.randi_range(1, 3)
				for xx in range(x, x + pw):
					for i in ph:
						_set(xx, surface - 1 - i, SOLID)
			elif feature < 0.5 and flat and (b > 0 or x > 14):
				# Шипы
				var sw := rng.randi_range(1, 3)
				for xx in range(x, x + sw):
					if _get(xx, surface - 1) == AIR:
						_set(xx, surface - 1, SPIKES)
			x += length + rng.randi_range(2, 6)


## Яма или люк между ярусом b и b+1 в колонке x (ширина 3).
func _make_hole(b: int, x: int, hatch: bool) -> void:
	var y0 := _floor_row(b) - 3
	var y1 := _top_air(b + 1) + 3
	for xx in range(x - 1, x + 2):
		for y in range(y0, y1):
			_set(xx, y, AIR)
		if hatch:
			_set(xx, _floor_row(b), PLATFORM)
	for xx in range(x - 4, x + 5):
		_reserved[Vector2i(b, xx)] = true
		_reserved[Vector2i(b + 1, xx)] = true
	# Лестница из платформ под люком/ямой, чтобы забраться наверх
	var lower := b + 1
	var surface := _surface_y(x, lower)
	var side := 1 if rng.randf() < 0.5 else -1
	var step1 := surface - 3
	var step2 := surface - 6
	for xx in range(x - 1 + side * 3, x + 3 + side * 3):
		if _get(xx, step1) == AIR:
			_set(xx, step1, PLATFORM)
	for xx in range(x - 2, x + 3):
		if step2 > _top_air(lower) and _get(xx, step2) == AIR:
			_set(xx, step2, PLATFORM)


func _flatten(b: int, x0: int, x1: int) -> void:
	for x in range(maxi(1, x0), mini(w - 1, x1 + 1)):
		for y in range(_top_air(b), _floor_row(b)):
			if _get(x, y) != PLATFORM:
				_set(x, y, AIR)
		_set(x, _floor_row(b), SOLID)
		_reserved[Vector2i(b, x)] = true


func _surface_y(x: int, b: int) -> int:
	# Первая клетка сверху вниз (от середины яруса), на которой можно стоять.
	for y in range(_top_air(b) + 3, h):
		var t := _get(x, y)
		if t == SOLID:
			return y
	return _floor_row(b)


func _ceiling_y(x: int, b: int) -> int:
	var y := _top_air(b)
	while y < _floor_row(b) and _get(x, y) == SOLID:
		y += 1
	return y - 1


func _is_reserved(b: int, x0: int, x1: int) -> bool:
	for x in range(x0, x1 + 1):
		if _reserved.has(Vector2i(b, x)):
			return true
	return false


# ------------------------------------------------------------------ арена босса
func _gen_arena() -> void:
	w = 48
	h = 24
	bands = 1
	cells = PackedByteArray()
	cells.resize(w * h)
	cells.fill(SOLID)
	for y in range(1, h - 2):
		for x in range(1, w - 1):
			_set(x, y, AIR)
	# Неровный потолок
	var x := 1
	while x < w - 1:
		var seg := rng.randi_range(2, 6)
		var drop := rng.randi_range(0, 3)
		for xx in range(x, mini(x + seg, w - 1)):
			for i in drop:
				_set(xx, 1 + i, SOLID)
		x += seg
	# Платформы
	var floor_y := h - 2
	for xx in range(7, 14):
		_set(xx, floor_y - 4, PLATFORM)
	for xx in range(w - 14, w - 7):
		_set(xx, floor_y - 4, PLATFORM)
	for xx in range(w / 2 - 4, w / 2 + 4):
		_set(xx, floor_y - 8, PLATFORM)
	for xx in range(3, 8):
		_set(xx, floor_y - 11, PLATFORM)
	for xx in range(w - 8, w - 3):
		_set(xx, floor_y - 11, PLATFORM)


# ------------------------------------------------------------------ утилиты
func _get(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return SOLID
	return cells[y * w + x]


func _set(x: int, y: int, v: int) -> void:
	if x <= 0 or y <= 0 or x >= w - 1 or y >= h - 1:
		return
	cells[y * w + x] = v
