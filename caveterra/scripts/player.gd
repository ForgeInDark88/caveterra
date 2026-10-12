extends CharacterBody2D
## Игрок: движение, рывок, атаки мечом / луком / магией, взаимодействие.

signal died

const Projectile = preload("res://scripts/projectile.gd")
const Effect = preload("res://scripts/effect.gd")
const WeaponDB = preload("res://scripts/weapon_db.gd")

const SPEED := 240.0
const ACCEL := 2200.0
const GRAVITY := 1500.0
const JUMP_VELOCITY := 680.0
const MAX_FALL := 950.0
const COYOTE := 0.1
const JUMP_BUFFER := 0.12
const DASH_SPEED := 720.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.7
const HALF_W := 10.0
const HALF_H := 20.0
const RADIUS := 12.0
const MANA_REGEN := 16.0
const PLATFORM_LAYER := 5

var attack_cd := 0.0
var dash_timer := 0.0
var dash_cd := 0.0
var dash_dir := 1.0
var invuln := 0.0
var flash := 0.0
var aim := Vector2.RIGHT
var facing := 1.0
var knock := Vector2.ZERO
var walk_t := 0.0
var swing_t := 0.0
var swing_side := 1.0
var dead := false
var camera: Camera2D
var world = null
var _coyote := 0.0
var _jump_buffer := 0.0
var _drop_t := 0.0
var _air_jumps := 0
var _land_squash := 0.0
var _run_vx := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 16
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	up_direction = Vector2.UP
	floor_snap_length = 6.0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF_W * 2.0, HALF_H * 2.0)
	cs.shape = rect
	add_child(cs)

	var light := PointLight2D.new()
	light.texture = Game.light_texture()
	light.texture_scale = 3.4
	light.energy = 1.05
	light.color = Color(1.0, 0.85, 0.65)
	add_child(light)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.35, 1.35)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.drag_vertical_enabled = true
	camera.drag_top_margin = 0.15
	camera.drag_bottom_margin = 0.15
	add_child(camera)
	camera.make_current()


func set_camera_limits(size: Vector2) -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)


func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_cd -= delta
	dash_cd -= delta
	invuln -= delta
	flash -= delta
	swing_t -= delta
	_drop_t -= delta
	_coyote -= delta
	_jump_buffer -= delta
	_land_squash = maxf(0.0, _land_squash - delta * 4.0)
	Game.mana = minf(Game.max_mana, Game.mana + MANA_REGEN * delta)

	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 2.0:
		aim = to_mouse.normalized()
	if absf(aim.x) > 0.05:
		facing = signf(aim.x)

	var dir := Input.get_axis("move_left", "move_right")
	var was_on_floor := is_on_floor()
	if was_on_floor:
		_coyote = COYOTE
		_air_jumps = 0

	# Спрыгнуть вниз сквозь платформу
	if Input.is_action_just_pressed("move_down") or (Input.is_action_pressed("move_down") and Input.is_action_just_pressed("jump")):
		_drop_t = 0.25
	set_collision_mask_value(PLATFORM_LAYER, _drop_t <= 0.0)

	if Input.is_action_just_pressed("jump") and not Input.is_action_pressed("move_down"):
		_jump_buffer = JUMP_BUFFER

	if dash_timer > 0.0:
		dash_timer -= delta
		velocity = Vector2(dash_dir * DASH_SPEED, 0.0)
		_run_vx = dash_dir * SPEED
	else:
		_run_vx = move_toward(_run_vx, dir * SPEED, ACCEL * delta)
		velocity.x = _run_vx + knock.x
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		if knock.y != 0.0:
			velocity.y = knock.y
			knock.y = 0.0
		if _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = -JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote = 0.0
			_puff(Vector2(0, HALF_H))
		# Короткий прыжок, если кнопку отпустили
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= 0.5
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0:
			dash_dir = signf(dir) if dir != 0.0 else facing
			dash_timer = DASH_TIME
			dash_cd = DASH_COOLDOWN
			invuln = maxf(invuln, DASH_TIME + 0.05)
			_puff(Vector2.ZERO)
	knock.x = move_toward(knock.x, 0.0, 1400.0 * delta)
	if dir != 0.0 and is_on_floor():
		walk_t += delta * 12.0
	move_and_slide()
	if is_on_floor() and not was_on_floor:
		_land_squash = 1.0
	if is_on_wall():
		_run_vx = 0.0

	_check_spikes()
	_handle_weapon_input()
	_handle_interaction()

	if camera:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Game.shake_strength
	queue_redraw()


func _puff(off: Vector2) -> void:
	var fx = Effect.make("ring", global_position + off, Color(0.85, 0.85, 0.9), 0.22)
	fx.radius = 14.0
	get_parent().add_child(fx)


func _check_spikes() -> void:
	if world == null or invuln > 0.0:
		return
	var t: Vector2i = world.world_to_tile(global_position + Vector2(0, HALF_H - 4))
	if world.get_tile(t.x, t.y) == 3:  # шипы
		take_damage(12.0, Vector2(0, -520))


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
	knock.x += kb.x
	knock.y = minf(kb.y, -180.0) if kb != Vector2.ZERO else 0.0
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
	var blink := invuln > 0.0 and int(Time.get_ticks_msec() / 60) % 2 == 0
	var a := 0.45 if blink else 1.0
	var cloak := Color(0.22, 0.45, 0.75, a)
	var skin := Color(0.95, 0.8, 0.65, a)
	if flash > 0.0:
		cloak = Color(1, 1, 1, a)
	var sq := _land_squash * 0.25
	draw_set_transform(Vector2(0, HALF_H * sq), 0, Vector2(1.0 + sq, 1.0 - sq))
	var moving := is_on_floor() and absf(velocity.x) > 20.0
	var step := sin(walk_t) * 5.0 if moving else 0.0
	var air := not is_on_floor()
	# ноги
	var legc := Color(0.25, 0.2, 0.18, a)
	if air:
		draw_line(Vector2(-4, 8), Vector2(-6, 18), legc, 4.0)
		draw_line(Vector2(4, 8), Vector2(7, 15), legc, 4.0)
	else:
		draw_line(Vector2(-4, 8), Vector2(-4 + step, HALF_H), legc, 4.0)
		draw_line(Vector2(4, 8), Vector2(4 - step, HALF_H), legc, 4.0)
	# тело и плащ
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -6), Vector2(9, -6), Vector2(11, 10), Vector2(-11, 10)]), cloak)
	draw_colored_polygon(PackedVector2Array([Vector2(-9 * facing, -6), Vector2(-15 * facing, 12 + step * 0.3), Vector2(-6 * facing, 10)]), cloak.darkened(0.3))
	draw_rect(Rect2(-9, 2, 18, 3), Color(0.45, 0.3, 0.15, a))
	# голова и капюшон
	draw_circle(Vector2(0, -13), 8.0, cloak.darkened(0.15))
	draw_circle(Vector2(2.0 * facing, -12), 6.0, skin)
	draw_circle(Vector2(4.5 * facing, -13), 1.5, Color(0.1, 0.1, 0.1, a))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	var w := Game.current_weapon()
	if w.is_empty():
		return
	var ang := aim.angle()
	var hand := aim * 12.0 + Vector2(0, -2)
	if w["type"] == "sword":
		var swing_off := 0.0
		if swing_t > 0.0:
			swing_off = swing_side * (swing_t / 0.18 - 0.5) * 2.2
		ang += swing_off
		hand = Vector2.RIGHT.rotated(ang) * 12.0 + Vector2(0, -2)
		WeaponDB.draw_icon(self, w, hand + Vector2.RIGHT.rotated(ang) * 8.0, ang, 0.9)
	elif w["type"] == "bow":
		WeaponDB.draw_icon(self, w, hand + aim * (2.0 - maxf(swing_t, 0.0) * 30.0), ang, 0.9)
	else:
		WeaponDB.draw_icon(self, w, hand + aim * 4.0, ang, 0.75 + maxf(swing_t, 0.0) * 3.0)
		WeaponDB.draw_icon(self, w, Vector2(-6 * facing, 2), ang, 0.4)
