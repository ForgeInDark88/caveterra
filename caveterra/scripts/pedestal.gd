extends Node2D
## Пьедестал в лобби: выбор стартового оружия.

const WeaponDB = preload("res://scripts/weapon_db.gd")
const Effect = preload("res://scripts/effect.gd")

const INFO := {
	"sword": ["Меч", "ближний бой, широкий взмах, отбивает снаряды"],
	"bow": ["Лук", "дальний бой, быстрые стрелы"],
	"magic": ["Магия рук", "самонаводящиеся заклинания, тратит ману"],
}

var weapon_kind := "sword"
var interact_radius := 52.0
var _weapon: Dictionary
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	_weapon = WeaponDB.make_starter(weapon_kind)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _is_selected() -> bool:
	return not Game.inventory.is_empty() and Game.inventory[0]["type"] == weapon_kind


func get_prompt() -> String:
	var info: Array = INFO[weapon_kind]
	if _is_selected():
		return "%s — выбрано" % info[0]
	return "[E] Взять: %s — %s" % [info[0], info[1]]


func interact(_player) -> void:
	if _is_selected():
		return
	Game.choose_start_weapon(weapon_kind)
	var info: Array = INFO[weapon_kind]
	Game.toast("Выбрано: %s. Вход в пещеру открыт!" % info[0], Color(0.7, 1, 0.7))
	var fx = Effect.make("ring", position, Color(1, 0.9, 0.5), 0.5)
	fx.radius = 50.0
	get_parent().add_child(fx)


func _draw() -> void:
	var sel := _is_selected()
	# постамент
	draw_rect(Rect2(-22, 4, 44, 18), Color(0.35, 0.33, 0.36))
	draw_rect(Rect2(-18, -6, 36, 12), Color(0.45, 0.43, 0.46))
	draw_rect(Rect2(-22, 4, 44, 3), Color(0.55, 0.53, 0.56))
	var glow := Color(1, 0.9, 0.5) if sel else Color(0.6, 0.7, 1.0)
	draw_circle(Vector2(0, -26), 24.0, Color(glow, 0.12 + 0.06 * sin(_t * 3.0)))
	if not sel:
		WeaponDB.draw_icon(self, _weapon, Vector2(0, -28 + sin(_t * 2.5) * 4.0), -0.785, 1.2)
	var info: Array = INFO[weapon_kind]
	var f := ThemeDB.fallback_font
	draw_string_outline(f, Vector2(-80, 44), info[0], HORIZONTAL_ALIGNMENT_CENTER, 160, 16, 4, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(-80, 44), info[0], HORIZONTAL_ALIGNMENT_CENTER, 160, 16, glow)
