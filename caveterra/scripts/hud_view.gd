extends Control
## Отрисовка интерфейса: здоровье, мана, слоты оружия, подсказки, сообщения, полоса босса.

const WeaponDB = preload("res://scripts/weapon_db.gd")

var info_left := ""
var info_right := ""
var show_stats := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _text(pos: Vector2, s: String, size: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, pos, s, align, width, size, 5, Color(0, 0, 0, 0.85 * c.a))
	draw_string(f, pos, s, align, width, size, c)


func _bar(r: Rect2, value: float, max_value: float, c: Color, label: String) -> void:
	draw_rect(r.grow(2), Color(0, 0, 0, 0.7))
	draw_rect(r, c.darkened(0.7))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(value / max_value, 0.0, 1.0), r.size.y)), c)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(value / max_value, 0.0, 1.0), r.size.y * 0.35)), Color(1, 1, 1, 0.18))
	_text(r.position + Vector2(8, r.size.y - 4), label, 14, Color.WHITE)


func _draw() -> void:
	var vs := size
	if show_stats:
		_bar(Rect2(20, 20, 280, 20), Game.hp, Game.max_hp, Color(0.85, 0.2, 0.25), "Здоровье  %d / %d" % [ceili(Game.hp), roundi(Game.max_hp)])
		_bar(Rect2(20, 48, 220, 14), Game.mana, Game.max_mana, Color(0.25, 0.5, 1.0), "Мана  %d" % floori(Game.mana))
	if info_left != "":
		_text(Vector2(20, 88), info_left, 16, Color(0.9, 0.85, 0.75))
	if info_right != "":
		_text(Vector2(vs.x - 420, 32), info_right, 18, Color(0.95, 0.9, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 400)

	# Полоса босса
	var boss = get_tree().get_first_node_in_group("boss")
	if boss != null:
		var bw := minf(600.0, vs.x - 80.0)
		var r := Rect2((vs.x - bw) * 0.5, 70, bw, 18)
		_bar(r, boss.hp, boss.max_hp, Color(0.7, 0.25, 0.9), "")
		_text(Vector2(0, 62), boss.display_name, 20, Color(1, 0.85, 1), HORIZONTAL_ALIGNMENT_CENTER, vs.x)

	# Слоты оружия
	var slot := 64.0
	var gap := 10.0
	var total := Game.MAX_SLOTS * slot + (Game.MAX_SLOTS - 1) * gap
	var x0 := (vs.x - total) * 0.5
	var y0 := vs.y - slot - 20.0
	for i in Game.MAX_SLOTS:
		var r := Rect2(x0 + i * (slot + gap), y0, slot, slot)
		var selected := i == Game.current_slot and i < Game.inventory.size()
		draw_rect(r, Color(0.05, 0.05, 0.08, 0.8))
		if i < Game.inventory.size():
			var w: Dictionary = Game.inventory[i]
			var rc: Color = w["color"]
			draw_rect(r, Color(rc, 0.15))
			draw_rect(r, rc, false, 3.0 if selected else 1.5)
			WeaponDB.draw_icon(self, w, r.get_center(), -0.785, 1.0)
		else:
			draw_rect(r, Color(1, 1, 1, 0.15), false, 1.0)
		if selected:
			draw_rect(r.grow(4), Color(1, 1, 1, 0.8), false, 2.0)
		_text(r.position + Vector2(4, 16), str(i + 1), 13, Color(1, 1, 1, 0.7))
	var cw := Game.current_weapon()
	if not cw.is_empty():
		_text(Vector2(0, y0 - 12), WeaponDB.describe(cw), 16, cw["color"], HORIZONTAL_ALIGNMENT_CENTER, vs.x)

	# Подсказка взаимодействия
	if Game.prompt != "":
		var lines := Game.prompt.split("\n")
		for i in lines.size():
			_text(Vector2(0, y0 - 70 + i * 24), lines[i], 20, Color(1, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER, vs.x)

	# Сообщения
	for i in Game.toasts.size():
		var t: Dictionary = Game.toasts[i]
		var c: Color = t["color"]
		c.a = clampf(float(t["time"]), 0.0, 1.0)
		_text(Vector2(0, 130 + i * 30), t["text"], 22, c, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
