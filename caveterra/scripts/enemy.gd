extends CharacterBody2D
## Враг. Тип задаётся через setup(): slime, bat, skeleton, spider, golem, shaman, boss, dummy.

signal died(enemy)

const Projectile = preload("res://scripts/projectile.gd")
const Effect = preload("res://scripts/effect.gd")

const TYPES := {
	"slime": {"name": "Слизень", "hp": 32.0, "speed": 80.0, "damage": 10.0, "radius": 13.0, "color": Color(0.35, 0.8, 0.35)},
	"bat": {"name": "Летучая мышь", "hp": 16.0, "speed": 165.0, "damage": 7.0, "radius": 10.0, "color": Color(0.55, 0.35, 0.7)},
	"skeleton": {"name": "Скелет-лучник", "hp": 34.0, "speed": 85.0, "damage": 9.0, "radius": 12.0, "color": Color(0.88, 0.86, 0.78)},
	"spider": {"name": "Пещерный паук", "hp": 24.0, "speed": 95.0, "damage": 11.0, "radius": 11.0, "color": Color(0.6, 0.15, 0.15)},
	"golem": {"name": "Каменный голем", "hp": 110.0, "speed": 52.0, "damage": 18.0, "radius": 15.0, "color": Color(0.5, 0.48, 0.45)},
	"shaman": {"name": "Культист", "hp": 40.0, "speed": 70.0, "damage": 12.0, "radius": 12.0, "color": Color(0.85, 0.35, 0.2)},
	"boss": {"name": "Пещерный Страж", "hp": 520.0, "speed": 75.0, "damage": 20.0, "radius": 26.0, "color": Color(0.75, 0.3, 0.9)},
	"dummy": {"name": "Манекен", "hp": 9999.0, "speed": 0.0, "damage": 0.0, "radius": 14.0, "color": Color(0.7, 0.55, 0.35)},
}

const GRAVITY := 1400.0
const MAX_FALL := 900.0

var type := "slime"
var display_name := ""
var max_hp := 30.0
var hp := 30.0
var speed := 80.0
var damage := 10.0
var radius := 12.0
var color := Color.WHITE
var is_boss := false
var flying := false

var cave = null          # ссылка на комнату (для призыва)
var world = null         # world_tiles

var _player = null
var _knock := Vector2.ZERO
var _vx := 0.0
var _fly := Vector2.ZERO
var _jump := 0.0
var _air_vx := 0.0
var _dir := 1.0
var _slow_t := 0.0
var _flash := 0.0
var _contact_cd := 0.0
var _wake := 0.8
var _t := 0.0
var _state := "idle"
var _state_t := 0.0
var _shoot_cd := 1.5
var _hop_cd := 0.5
var _los := false
var _los_t := 0.0
var _aware := false
var _home := Vector2.ZERO
var _phase := 0
var _summoned := false
var _wobble := 0.0


func setup(t: String, depth: int) -> void:
	type = t
	var d: Dictionary = TYPES[t]
	display_name = d["name"]
	var hp_mult := 1.0 + 0.18 * (depth - 1)
	var dmg_mult := 1.0 + 0.07 * (depth - 1)
	max_hp = float(d["hp"]) * (1.0 if t == "dummy" else hp_mult)
	hp = max_hp
	speed = float(d["speed"]) * randf_range(0.9, 1.1)
	damage = float(d["damage"]) * dmg_mult
	radius = d["radius"]
	color = d["color"]
	is_boss = t == "boss"
	flying = t == "bat" or t == "shaman"
	_wobble = randf() * TAU
	_shoot_cd = randf_range(1.0, 2.2)
	_dir = 1.0 if randf() < 0.5 else -1.0


func _ready() -> void:
	add_to_group("enemies")
	if is_boss:
		add_to_group("boss")
	collision_layer = 4
	collision_mask = 1 if flying else (1 | 16)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING if flying else CharacterBody2D.MOTION_MODE_GROUNDED
	up_direction = Vector2.UP
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius if is_boss else minf(radius, 14.0)
	cs.shape = c
	add_child(cs)
	_home = global_position


func _physics_process(delta: float) -> void:
	_t += delta
	_flash -= delta
	_contact_cd -= delta
	_slow_t -= delta
	_hop_cd -= delta
	_knock = _knock.move_toward(Vector2.ZERO, 1100.0 * delta)
	queue_redraw()
	_vx = 0.0
	_fly = Vector2.ZERO
	if type != "dummy" and _wake <= 0.0:
		_think(delta)
	else:
		_wake -= delta
	_apply_motion(delta)

	# Контактный урон
	if _player != null and is_instance_valid(_player) and not _player.dead and _contact_cd <= 0.0 and damage > 0.0 and _wake <= 0.0:
		var dist: float = _player.global_position.distance_to(global_position)
		if dist < radius + 16.0:
			_player.take_damage(damage, Vector2(signf(_player.global_position.x - global_position.x) * 320.0, -260.0))
			_contact_cd = 0.8


func _apply_motion(delta: float) -> void:
	var slow := 0.5 if _slow_t > 0.0 else 1.0
	if flying:
		velocity = _fly * slow + _knock
	else:
		if is_on_floor():
			velocity.x = _vx * slow + _knock.x
		else:
			velocity.x = (_air_vx if _air_vx != 0.0 else _vx) * slow + _knock.x
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		if _jump != 0.0:
			velocity.y = _jump
			_jump = 0.0
	move_and_slide()
	if not flying and is_on_floor() and velocity.y >= 0.0:
		_air_vx = 0.0


func _think(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	if _player.dead:
		return
	_los_t -= delta
	if _los_t <= 0.0:
		_los_t = 0.25
		_los = _has_los(_player.global_position)
	var dist := _to_player().length()
	if not _aware and (dist < 140.0 or (_los and dist < 460.0)):
		_aware = true
	_state_t -= delta
	match type:
		"slime":
			_ai_slime()
		"bat":
			_ai_bat()
		"skeleton":
			_ai_skeleton(delta)
		"shaman":
			_ai_shaman(delta)
		"spider":
			_ai_spider()
		"golem":
			_ai_golem()
		"boss":
			_ai_boss(delta)


# ------------------------------------------------------------------ помощники
func _to_player() -> Vector2:
	return _player.global_position - global_position


func _ground_ahead(d: float) -> bool:
	if world == null:
		return true
	var foot: Vector2 = global_position + Vector2(d * (radius + 6.0), radius + 8.0)
	var t: Vector2i = world.world_to_tile(foot)
	return world.is_standable(t.x, t.y) and world.get_tile(t.x, t.y - 1) != 3


func _blocked(d: float) -> bool:
	return is_on_wall() and get_wall_normal().x * d < 0.0


func _patrol(spd: float) -> void:
	if is_on_floor() and (not _ground_ahead(_dir) or _blocked(_dir)):
		_dir = -_dir
	_vx = _dir * spd


## Идти к игроку. Не прыгает с обрыва, если игрок не ниже.
func _chase(spd: float, can_jump: bool) -> void:
	var to := _to_player()
	if absf(to.x) < 6.0:
		return
	_dir = signf(to.x)
	if is_on_floor():
		if _blocked(_dir):
			if can_jump:
				_jump = -560.0
				_air_vx = _dir * spd
			else:
				return
		elif not _ground_ahead(_dir) and to.y < 40.0:
			if can_jump and to.y < -40.0:
				_jump = -600.0
				_air_vx = _dir * spd * 1.3
			return
	_vx = _dir * spd


# ------------------------------------------------------------------ ИИ
func _ai_slime() -> void:
	# Прыжками в сторону игрока
	if is_on_floor() and _hop_cd <= 0.0:
		var d := _dir
		if _aware:
			d = signf(_to_player().x)
		elif not _ground_ahead(_dir) or _blocked(_dir):
			_dir = -_dir
			d = _dir
		_dir = d
		_jump = -430.0 if _aware else -300.0
		_air_vx = d * speed * (1.8 if _aware else 1.0)
		_hop_cd = randf_range(0.7, 1.1)


func _ai_bat() -> void:
	var to := _to_player()
	if _aware and (_los or to.length() < 200.0):
		var side := Vector2(0, sin(_t * 5.0 + _wobble) * 0.8)
		_fly = (to.normalized() + side).normalized() * speed
	else:
		var target := _home + Vector2(cos(_t * 0.8 + _wobble) * 60.0, sin(_t * 1.3) * 25.0)
		_fly = (target - global_position).limit_length(1.0) * speed * 0.5
		if _aware:
			_fly = to.normalized() * speed * 0.7


func _ai_skeleton(delta: float) -> void:
	var to := _to_player()
	var dist := to.length()
	if not _aware:
		_patrol(speed * 0.5)
		return
	_dir = signf(to.x) if to.x != 0.0 else _dir
	if dist < 140.0 and _ground_ahead(-_dir):
		_vx = -_dir * speed
	elif dist > 330.0 or not _los:
		_chase(speed, true)
	_shoot_cd -= delta
	if _shoot_cd <= 0.0 and _los and dist < 460.0:
		_shoot_cd = 1.8 * randf_range(0.85, 1.2)
		_fire(to.normalized(), 360.0, "bone", Color(0.9, 0.88, 0.8))


func _ai_shaman(delta: float) -> void:
	var to := _to_player()
	if not _aware:
		_fly = (_home + Vector2(sin(_t + _wobble) * 40.0, 0) - global_position).limit_length(1.0) * speed * 0.5
		return
	var want: Vector2 = _player.global_position + Vector2(-signf(to.x) * 230.0, -110.0 + sin(_t) * 30.0)
	_fly = (want - global_position).limit_length(60.0) / 60.0 * speed
	_shoot_cd -= delta
	if _shoot_cd <= 0.0 and _los and to.length() < 480.0:
		_shoot_cd = 2.4 * randf_range(0.85, 1.2)
		for i in 3:
			_fire(to.normalized().rotated((i - 1) * 0.22), 300.0, "orb", Color(1.0, 0.45, 0.15))


func _ai_spider() -> void:
	var to := _to_player()
	match _state:
		"lunge":
			if is_on_floor() and _state_t < 0.3:
				_state = "recover"
				_state_t = 0.5
		"recover":
			if _state_t <= 0.0:
				_state = "idle"
		_:
			if not _aware:
				_patrol(speed * 0.6)
				return
			_chase(speed, true)
			if _los and to.length() < 230.0 and is_on_floor() and _state_t <= -1.0:
				_state = "lunge"
				_state_t = 0.6
				_dir = signf(to.x)
				_jump = -380.0 + clampf(to.y, -200.0, 0.0)
				_air_vx = _dir * 360.0


func _ai_golem() -> void:
	var to := _to_player()
	match _state:
		"windup":
			if _state_t <= 0.0:
				_slam(95.0, damage * 1.2)
				_state = "idle"
				_state_t = 2.2
		_:
			if not _aware:
				_patrol(speed * 0.6)
				return
			_chase(speed, false)
			if to.length() < 85.0 and _state_t <= 0.0:
				_state = "windup"
				_state_t = 0.65
				_telegraph(global_position, 95.0, 0.65)


func _ai_boss(delta: float) -> void:
	var to := _to_player()
	if not _summoned and hp < max_hp * 0.5:
		_summoned = true
		Game.toast("Страж призывает подмогу!", Color(1, 0.5, 0.5))
		if cave != null:
			for i in 3:
				cave.call_deferred("spawn_enemy", ["slime", "bat", "spider"][i], global_position + Vector2((i - 1) * 90.0, -30.0))
	match _state:
		"burst":
			_shoot_cd -= delta
			if _shoot_cd <= 0.0:
				_shoot_cd = 0.45
				_phase += 1
				var n := 12 if hp > max_hp * 0.5 else 18
				for i in n:
					var a := PI + PI * float(i) / (n - 1) + (0.08 if _phase % 2 == 0 else 0.0)
					_fire(Vector2.RIGHT.rotated(a), 240.0, "orb", Color(0.8, 0.4, 1.0))
			if _state_t <= 0.0:
				_state = "chase"
				_state_t = 2.2
		"windup":
			if _state_t <= 0.0:
				_state = "leap"
				_state_t = 2.0
				_jump = -820.0
				_air_vx = clampf(to.x * 1.1, -420.0, 420.0)
		"leap":
			if is_on_floor() and _state_t < 1.8:
				Game.shake(10.0)
				_slam(110.0, damage)
				for s in [-1.0, 1.0]:
					_fire(Vector2(s, 0), 320.0, "orb", Color(1.0, 0.5, 0.3), Vector2(0, radius - 8.0))
				_state = "chase"
				_state_t = 2.0
		_:
			_chase(speed, true)
			if _state_t <= 0.0 and is_on_floor():
				if randf() < 0.45:
					_state = "burst"
					_state_t = 1.4
					_shoot_cd = 0.2
				else:
					_state = "windup"
					_state_t = 0.55
					_telegraph(_player.global_position, 60.0, 0.9)


func _fire(dir: Vector2, spd: float, kind: String, c: Color, offset: Vector2 = Vector2.ZERO) -> void:
	var p := Projectile.new()
	p.from_player = false
	p.kind = kind
	p.damage = damage * 0.9
	p.velocity = dir * spd
	p.color = c
	p.radius = 5.0
	p.life = 3.0
	p.global_position = global_position + offset + dir * (radius + 4.0)
	get_parent().call_deferred("add_child", p)


func _slam(r: float, dmg: float) -> void:
	var fx = Effect.make("ring", global_position, color.lightened(0.3), 0.4)
	fx.radius = r
	get_parent().add_child(fx)
	Game.shake(5.0)
	if _player != null and _player.global_position.distance_to(global_position) <= r + 12.0:
		_player.take_damage(dmg, (_player.global_position - global_position).normalized() * 420.0)


func _telegraph(pos: Vector2, r: float, t: float) -> void:
	var fx = Effect.make("telegraph", pos, Color(1, 0.25, 0.2), t)
	fx.radius = r
	get_parent().add_child(fx)


func _has_los(target: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, target, 1)
	return space.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ урон
func take_damage(amount: float, kb: Vector2 = Vector2.ZERO, element: String = "", crit: bool = false) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_flash = 0.12
	_wake = minf(_wake, 0.1)
	var kb_mult := 0.15 if is_boss else (0.4 if type == "golem" else 1.0)
	_knock.x += kb.x * kb_mult
	if flying:
		_knock.y += kb.y * kb_mult
	elif is_on_floor() and kb != Vector2.ZERO:
		_jump = -140.0 * kb_mult
	_aware = true
	if element == "ice":
		_slow_t = 2.5
	var fx = Effect.make("text", global_position + Vector2(randf_range(-8, 8), -radius - 6), Color(1, 0.9, 0.3) if crit else Color.WHITE, 0.7)
	fx.text = str(roundi(amount)) + ("!" if crit else "")
	get_parent().add_child(fx)
	if type == "dummy":
		if hp <= 0.0:
			hp = max_hp
		return
	if hp <= 0.0:
		_die()


func _die() -> void:
	Game.kills += 1
	var fx = Effect.make("ring", global_position, color, 0.45)
	fx.radius = radius * 2.5
	get_parent().add_child(fx)
	var b = Effect.make("burst", global_position, color, 0.4)
	b.radius = randf() * TAU
	get_parent().add_child(b)
	if is_boss:
		Game.shake(14.0)
	died.emit(self)
	queue_free()


# ------------------------------------------------------------------ отрисовка
func _draw() -> void:
	var c := color
	if _flash > 0.0:
		c = Color(1, 1, 1)
	elif _slow_t > 0.0:
		c = c.lerp(Color(0.55, 0.85, 1.0), 0.5)
	var r := radius
	draw_set_transform(Vector2(0, r * 0.85), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var look := Vector2.RIGHT
	if _player != null and is_instance_valid(_player):
		look = (_player.global_position - global_position).normalized()
	match type:
		"slime":
			var sq := 0.85 if not is_on_floor() else 1.0 + 0.06 * sin(_t * 6.0)
			draw_set_transform(Vector2.ZERO, 0, Vector2(sq, 2.0 - sq))
			draw_circle(Vector2(0, 2), r, c.darkened(0.25))
			draw_circle(Vector2(0, 0), r - 2.0, c)
			draw_circle(Vector2(-4, -4), 3.0, Color(1, 1, 1, 0.5))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			_eyes(look, 4.0, -1.0, Color.BLACK)
		"bat":
			var flap := sin(_t * 18.0) * 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(-r - 8, -6 + flap), Vector2(-r, 4)]), c.darkened(0.3))
			draw_colored_polygon(PackedVector2Array([Vector2(3, 0), Vector2(r + 8, -6 + flap), Vector2(r, 4)]), c.darkened(0.3))
			draw_circle(Vector2.ZERO, r * 0.7, c)
			_eyes(look, 3.0, -1.0, Color(1, 0.3, 0.3))
		"skeleton", "shaman":
			draw_circle(Vector2(0, 2), r, c.darkened(0.4) if type == "skeleton" else Color(0.35, 0.1, 0.12))
			draw_circle(Vector2(0, -6), r * 0.65, c)
			_eyes(look, 3.0, -7.0, Color(1, 0.5, 0.1) if type == "shaman" else Color.BLACK)
			if type == "shaman":
				draw_circle(look * 14.0 + Vector2(0, -2), 4.0 + sin(_t * 8.0), Color(1.0, 0.55, 0.2))
			else:
				draw_arc(look * 10.0, 10.0, look.angle() - 1.1, look.angle() + 1.1, 10, Color(0.6, 0.45, 0.3), 2.5)
		"spider":
			for i in 4:
				var a := 0.5 + i * 0.35 + sin(_t * 14.0 + i) * 0.12
				draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * (r + 8), c.darkened(0.4), 2.0)
				draw_line(Vector2.ZERO, Vector2(-cos(a), sin(a)) * (r + 8), c.darkened(0.4), 2.0)
			draw_circle(Vector2.ZERO, r, c)
			draw_circle(Vector2(0, -r * 0.6), r * 0.55, c.darkened(0.2))
			_eyes(look, 2.5, -r * 0.6, Color(1, 0.9, 0.2))
		"golem":
			var big := r * 1.5
			draw_rect(Rect2(-big, -big, big * 2.0, big * 2.0), c.darkened(0.3))
			draw_rect(Rect2(-big + 3, -big + 3, big * 2.0 - 6, big * 2.0 - 6), c)
			draw_line(Vector2(-8, -6), Vector2(4, 10), c.darkened(0.45), 2.0)
			_eyes(look, 3.5, -6.0, Color(0.4, 0.9, 1.0))
			if _state == "windup":
				draw_arc(Vector2.ZERO, big + 6.0, 0, TAU, 24, Color(1, 0.3, 0.2, 0.8), 2.0)
		"boss":
			for i in 6:
				var a := _t * 0.8 + i * TAU / 6.0
				draw_circle(Vector2.RIGHT.rotated(a) * (r + 10.0), 5.0, Color(0.9, 0.5, 1.0, 0.7))
			draw_circle(Vector2.ZERO, r + 4.0, c.darkened(0.5))
			draw_circle(Vector2.ZERO, r, c)
			draw_circle(Vector2(0, -4), r * 0.55, c.lightened(0.25))
			_eyes(look, 5.0, -6.0, Color(1, 0.95, 0.4))
			if _state == "windup" or _state == "burst":
				draw_arc(Vector2.ZERO, r + 14.0, 0, TAU, 32, Color(1, 0.3, 0.3, 0.9), 3.0)
		"dummy":
			draw_line(Vector2(0, 14), Vector2(0, -14), Color(0.4, 0.28, 0.15), 4.0)
			draw_line(Vector2(-14, -4), Vector2(14, -4), Color(0.4, 0.28, 0.15), 4.0)
			draw_circle(Vector2(0, -2), 10.0, c)
			draw_circle(Vector2(0, -16), 7.0, c.lightened(0.15))
			draw_circle(Vector2(0, -2), 5.0, Color(0.8, 0.2, 0.2))
			draw_circle(Vector2(0, -2), 2.0, Color(1, 1, 1))
	# полоска здоровья
	if hp < max_hp and not is_boss and type != "dummy":
		var bw := r * 2.2
		draw_rect(Rect2(-bw * 0.5, -r - 14.0, bw, 4.0), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-bw * 0.5, -r - 14.0, bw * clampf(hp / max_hp, 0.0, 1.0), 4.0), Color(0.9, 0.2, 0.2))


func _eyes(look: Vector2, size: float, y: float, c: Color) -> void:
	var off := look * 2.0
	draw_circle(Vector2(-size - 1.0, y) + off, size * 0.6, c)
	draw_circle(Vector2(size + 1.0, y) + off, size * 0.6, c)
