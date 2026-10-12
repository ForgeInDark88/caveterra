extends CharacterBody2D
## Игрок: движение, рывок, атаки мечом / луком / магией, взаимодействие.

signal died

const Projectile = preload("res://scripts/projectile.gd")
const Effect = preload("res://scripts/effect.gd")
const WeaponDB = preload("res://scripts/weapon_db.gd")

const SPEED := 230.0
const DASH_SPEED := 680.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.75
const RADIUS := 12.0
const MANA_REGEN := 16.0

var attack_cd := 0.0
var dash_timer := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.RIGHT
var invuln := 0.0
var flash := 0.0
var aim := Vector2.RIGHT
var knock := Vector2.ZERO
var walk_t := 0.0
var swing_t := 0.0
var swing_side := 1.0
var dead := false
var camera: Camera2D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS
	cs.shape = c
	add_child(cs)

	var light := PointLight2D.new()
	light.texture = Game.light_texture()
	light.texture_scale = 3.2
	light.energy = 1.05
	light.color = Color(1.0, 0.85, 0.65)
	add_child(light)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.25, 1.25)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()


func set_camera_limits(size: Vector2) -> void:
	camera.limit_left = -64
	camera.limit_top = -64
	camera.limit_right = int(size.x) + 64
	camera.limit_bottom = int(size.y) + 64


func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_cd -= delta
	dash_cd -= delta
	invuln -= delta
	flash -= delta
	swing_t -= delta
	Game.mana = minf(Game.max_mana, Game.mana + MANA_REGEN * delta)

	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 2.0:
		aim = to_mouse.normalized()

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dash_timer > 0.0:
		dash_timer -= delta
		velocity = dash_dir * DASH_SPEED
	else:
		velocity = input * SPEED + knock
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0:
			dash_dir = input if input != Vector2.ZERO else aim
			dash_timer = DASH_TIME
			dash_cd = DASH_COOLDOWN
			invuln = maxf(invuln, DASH_TIME + 0.05)
			var fx = Effect.make("ring", global_position, Color(0.8, 0.9, 1.0), 0.25)
			fx.radius = 18.0
			get_parent().add_child(fx)
	knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	if input != Vector2.ZERO:
		walk_t += delta * 10.0
	move_and_slide()

	_handle_weapon_input()
	_handle_interaction()

	if camera:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Game.shake_strength
	queue_redraw()


func _handle_weapon_input() -> void:
	if Input.is_action_just_pressed("switch_weapon"):
		Game.cycle_weapon()
	for i in Game.MAX_SLOTS:
		if Input.is_action_just_pressed("slot_%d" % (i + 1)):
			Game.select_slot(i)
	if Input.is_action_pressed("attack") and attack_cd <= 0.0:
		_attack()


func _handle_interaction() -> void:
	var best = null
	var bd := INF
	var items: Array = get_tree().get_nodes_in_group("interactable")
	for n in items:
		var d: float = n.global_position.distance_to(global_position)
		if d < float(n.interact_radius) and d < bd:
			bd = d
			best = n
	Game.prompt = best.get_prompt() if best != null else ""
	if best != null and Input.is_action_just_pressed("interact"):
		best.interact(self)


# ------------------------------------------------------------------ атаки
func _attack() -> void:
	var w := Game.current_weapon()
	if w.is_empty():
		return
	match w["type"]:
		"sword":
			_swing(w)
		"bow":
			_shoot(w)
		"magic":
			var cost: float = w["mana_cost"]
			if Game.mana < cost:
				attack_cd = 0.15
				return
			Game.mana -= cost
			_cast(w)
	attack_cd = float(w["cooldown"])


func _roll_damage(base: float) -> Array:
	if randf() < 0.1:
		return [base * 2.0, true]
	return [base * randf_range(0.9, 1.1), false]


func _swing(w: Dictionary) -> void:
	swing_t = 0.18
	swing_side = -swing_side
	var reach: float = w["reach"]
	var arc: float = w["arc"]
	var fx = Effect.make("slash", global_position, w["color"], 0.18)
	fx.dir = aim
	fx.radius = reach * 0.8
	fx.arc = arc
	get_parent().add_child(fx)
	var hit_any := false
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		var to: Vector2 = e.global_position - global_position
		var dist := to.length()
		if dist > reach + float(e.radius):
			continue
		if dist > 6.0 and absf(aim.angle_to(to)) > deg_to_rad(arc) * 0.5:
			continue
		var roll := _roll_damage(float(w["damage"]))
		e.take_damage(roll[0], to.normalized() * float(w["knockback"]), "", roll[1])
		hit_any = true
	# Мечом можно отбивать вражеские снаряды.
	var shots: Array = get_tree().get_nodes_in_group("enemy_projectiles")
	for p in shots:
		var to: Vector2 = p.global_position - global_position
		if to.length() < reach + 6.0 and absf(aim.angle_to(to)) < deg_to_rad(arc) * 0.5:
			p.deflect(aim)
	if hit_any:
		Game.shake(3.0)


func _shoot(w: Dictionary) -> void:
	swing_t = 0.12
	var shots := int(w["shots"])
	var spread := deg_to_rad(float(w["spread"]))
	for i in shots:
		var a := 0.0
		if shots > 1:
			a = lerpf(-spread * 0.5, spread * 0.5, float(i) / (shots - 1))
		var roll := _roll_damage(float(w["damage"]))
		var p := Projectile.new()
		p.kind = "arrow"
		p.from_player = true
		p.damage = roll[0]
		p.velocity = aim.rotated(a) * float(w["speed"])
		p.pierce = int(w["pierce"])
		p.color = w["color"]
		p.radius = 4.0
		p.life = 1.4
		p.knockback = 140.0
		p.global_position = global_position + aim * 16.0
		get_parent().add_child(p)


func _cast(w: Dictionary) -> void:
	swing_t = 0.12
	var roll := _roll_damage(float(w["damage"]))
	var p := Projectile.new()
	p.kind = "orb"
	p.from_player = true
	p.damage = roll[0]
	p.element = w["element"]
	p.velocity = aim * float(w["speed"])
	p.pierce = int(w["pierce"])
	p.aoe = float(w["aoe"])
	p.chain = int(w["chain"])
	p.homing = float(w["homing"])
	p.color = w["fx_color"]
	p.radius = 6.0 if p.aoe > 0.0 else 5.0
	p.life = 1.6
	p.global_position = global_position + aim * 18.0
	get_parent().add_child(p)


# ------------------------------------------------------------------ урон
func take_damage(amount: float, kb: Vector2 = Vector2.ZERO, _element: String = "", _crit: bool = false) -> void:
	if dead or invuln > 0.0:
		return
	Game.hp -= amount
	invuln = 0.6
	flash = 0.2
	knock += kb
	Game.shake(7.0)
	var fx = Effect.make("text", global_position + Vector2(0, -20), Color(1, 0.3, 0.3), 0.8)
	fx.text = str(roundi(amount))
	get_parent().add_child(fx)
	if Game.hp <= 0.0:
		Game.hp = 0.0
		dead = true
		var boom = Effect.make("ring", global_position, Color(1, 0.2, 0.2), 0.6)
		boom.radius = 60.0
		get_parent().add_child(boom)
		visible = false
		died.emit()


func heal(amount: float) -> void:
	Game.hp = minf(Game.max_hp, Game.hp + amount)
	var fx = Effect.make("text", global_position + Vector2(0, -20), Color(0.4, 1, 0.5), 0.8)
	fx.text = "+%d" % roundi(amount)
	get_parent().add_child(fx)


# ------------------------------------------------------------------ отрисовка
func _draw() -> void:
	var bob := sin(walk_t) * 1.5
	var blink := invuln > 0.0 and int(Time.get_ticks_msec() / 60) % 2 == 0
	var body_col := Color(0.25, 0.55, 0.85)
	if flash > 0.0:
		body_col = Color(1, 1, 1)
	if blink:
		body_col.a = 0.45
	# тень
	draw_set_transform(Vector2(0, 12), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# плащ и тело
	draw_circle(Vector2(0, bob), RADIUS, body_col.darkened(0.35))
	draw_circle(Vector2(0, bob - 2), RADIUS - 2.0, body_col)
	# голова
	draw_circle(Vector2(0, bob - 10), 7.0, Color(0.95, 0.8, 0.65, body_col.a))
	draw_circle(Vector2(0, bob - 10) + aim * 3.0, 1.6, Color(0.1, 0.1, 0.1, body_col.a))

	var w := Game.current_weapon()
	if w.is_empty():
		return
	var ang := aim.angle()
	var hand := aim * 14.0 + Vector2(0, bob)
	if w["type"] == "sword":
		var swing_off := 0.0
		if swing_t > 0.0:
			swing_off = swing_side * (swing_t / 0.18 - 0.5) * 2.2
		ang += swing_off
		hand = Vector2.RIGHT.rotated(ang) * 14.0 + Vector2(0, bob)
		WeaponDB.draw_icon(self, w, hand + Vector2.RIGHT.rotated(ang) * 8.0, ang, 0.9)
	elif w["type"] == "bow":
		WeaponDB.draw_icon(self, w, hand + aim * (2.0 - maxf(swing_t, 0.0) * 30.0), ang, 0.9)
	else:
		WeaponDB.draw_icon(self, w, hand + aim * 4.0, ang, 0.75 + maxf(swing_t, 0.0) * 3.0)
		WeaponDB.draw_icon(self, w, hand.rotated(0.9) * 0.8, ang, 0.45)
