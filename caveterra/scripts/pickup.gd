extends Node2D
## Предмет на земле: оружие (подбирается по E) или зелье здоровья (подбирается касанием).

const WeaponDB = preload("res://scripts/weapon_db.gd")
const Effect = preload("res://scripts/effect.gd")

var kind := "weapon"
var weapon: Dictionary = {}
var interact_radius := 40.0
var pop_from := Vector2.INF
var _t := 0.0
var _pop := 1.0
var _target := Vector2.ZERO


func _ready() -> void:
	z_index = 2
	_target = position
	if pop_from != Vector2.INF:
		_pop = 0.0
		position = pop_from
	if kind == "weapon":
		add_to_group("interactable")


func _process(delta: float) -> void:
	_t += delta
	if _pop < 1.0:
		_pop = minf(1.0, _pop + delta * 3.0)
		position = pop_from.lerp(_target, _pop) + Vector2(0, -sin(_pop * PI) * 30.0)
	if kind == "potion" and _pop >= 1.0:
		var p = get_tree().get_first_node_in_group("player")
		if p != null and not p.dead and p.global_position.distance_to(global_position) < 22.0 and Game.hp < Game.max_hp:
			p.heal(Game.max_hp * 0.25)
			queue_free()
	queue_redraw()


func get_prompt() -> String:
	var s := "[E] Взять: " + WeaponDB.describe(weapon)
	if Game.inventory.size() >= Game.MAX_SLOTS:
		s += "\n(заменит: %s)" % Game.current_weapon().get("name", "")
	return s


func interact(_player) -> void:
	var dropped := Game.add_weapon(weapon)
	Game.toast("Подобрано: %s" % weapon["name"], weapon["color"])
	var fx = Effect.make("ring", position, weapon["color"], 0.3)
	fx.radius = 24.0
	get_parent().add_child(fx)
	if dropped.is_empty():
		queue_free()
	else:
		weapon = dropped


func _draw() -> void:
	var bob := sin(_t * 3.0) * 3.0
	draw_set_transform(Vector2(0, 10), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if kind == "potion":
		draw_circle(Vector2(0, bob), 8.0, Color(0.85, 0.15, 0.2))
		draw_circle(Vector2(-2, bob - 2), 2.5, Color(1, 1, 1, 0.6))
		draw_rect(Rect2(-3, bob - 14, 6, 6), Color(0.7, 0.6, 0.5))
		return
	var c: Color = weapon["color"]
	draw_circle(Vector2(0, bob), 20.0, Color(c, 0.15 + 0.08 * sin(_t * 4.0)))
	# луч редкости
	if int(weapon["rarity"]) >= 2:
		draw_rect(Rect2(-2, bob - 60, 4, 60), Color(c, 0.25))
	WeaponDB.draw_icon(self, weapon, Vector2(0, bob), -0.785, 1.0)
