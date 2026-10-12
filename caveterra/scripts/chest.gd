extends Node2D
## Сундук: при открытии выпадает случайное оружие (и иногда зелье).

const Pickup = preload("res://scripts/pickup.gd")
const Effect = preload("res://scripts/effect.gd")
const WeaponDB = preload("res://scripts/weapon_db.gd")

var interact_radius := 46.0
var bonus := 0          # 0 — обычный, 1 — золотой, 2 — сундук босса
var opened := false
var _t := 0.0
var _open_anim := 0.0


func _ready() -> void:
	add_to_group("interactable")
	z_index = 1


func _process(delta: float) -> void:
	_t += delta
	if opened:
		_open_anim = minf(1.0, _open_anim + delta * 4.0)
	queue_redraw()


func get_prompt() -> String:
	return "[E] Открыть сундук" if bonus == 0 else "[E] Открыть %s" % ("золотой сундук" if bonus == 1 else "сундук Стража")


func interact(_player) -> void:
	if opened:
		return
	opened = true
	remove_from_group("interactable")
	var w := WeaponDB.random_weapon(Game.rng, Game.depth, bonus)
	var p := Pickup.new()
	p.kind = "weapon"
	p.weapon = w
	p.position = position + Vector2(0, 34)
	p.pop_from = position
	get_parent().add_child(p)
	if Game.rng.randf() < 0.4:
		var pot := Pickup.new()
		pot.kind = "potion"
		pot.position = position + Vector2(Game.rng.randf_range(-30, 30), 30)
		pot.pop_from = position
		get_parent().add_child(pot)
	var fx = Effect.make("ring", position, w["color"], 0.5)
	fx.radius = 50.0
	get_parent().add_child(fx)
	Game.toast("Выпало: %s [%s]" % [w["name"], WeaponDB.RARITY_NAMES[w["rarity"]]], w["color"])


func _draw() -> void:
	var gold := bonus > 0
	var body := Color(0.45, 0.28, 0.14)
	var trim := Color(0.95, 0.75, 0.25) if gold else Color(0.6, 0.6, 0.65)
	if not opened:
		var glow := 0.15 + 0.1 * sin(_t * 3.0)
		draw_circle(Vector2.ZERO, 30.0, Color(trim, glow))
	draw_set_transform(Vector2(0, 12), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_rect(Rect2(-18, -6, 36, 18), body)
	draw_rect(Rect2(-18, -6, 36, 18), trim, false, 2.0)
	var lid_y := -16.0 - _open_anim * 10.0
	draw_rect(Rect2(-19, lid_y, 38, 11), body.lightened(0.1))
	draw_rect(Rect2(-19, lid_y, 38, 11), trim, false, 2.0)
	draw_rect(Rect2(-3, lid_y + 7, 6, 7), trim)
	if opened and _open_anim < 1.0:
		draw_circle(Vector2(0, -8), 26.0 * _open_anim, Color(1, 0.95, 0.6, 1.0 - _open_anim))
