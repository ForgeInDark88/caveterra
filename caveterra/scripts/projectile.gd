extends Area2D
## Снаряд: стрела, магический шар или кость врага.

const Effect = preload("res://scripts/effect.gd")

var velocity := Vector2.ZERO
var damage := 10.0
var from_player := true
var pierce := 0
var element := ""        # "", arcane, fire, ice, lightning
var aoe := 0.0
var chain := 0
var homing := 0.0
var color := Color.WHITE
var radius := 5.0
var life := 2.0
var kind := "orb"        # arrow, orb, bone
var knockback := 120.0
var _hit: Array = []
var _done := false
var _trail: Array = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | (4 if from_player else 2)
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body_entered)
	add_to_group("player_projectiles" if from_player else "enemy_projectiles")
	if kind == "orb" and from_player:
		var light := PointLight2D.new()
		light.texture = Game.light_texture()
		light.texture_scale = 0.45
		light.color = color
		light.energy = 0.8
		add_child(light)


func _physics_process(delta: float) -> void:
	if homing > 0.0:
		var target = _nearest_enemy(320.0)
		if target != null:
			var want: Vector2 = (target.global_position - global_position).normalized() * velocity.length()
			velocity = velocity.lerp(want, clampf(homing * delta, 0.0, 1.0))
	_trail.push_front(global_position)
	if _trail.size() > 6:
		_trail.pop_back()
	global_position += velocity * delta
	rotation = velocity.angle()
	life -= delta
	if life <= 0.0:
		_impact()
	queue_redraw()


func _nearest_enemy(max_dist: float):
	var best = null
	var bd := max_dist
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if _hit.has(e):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	return best


## Отражение мечом: снаряд врага становится снарядом игрока.
func deflect(new_dir: Vector2) -> void:
	from_player = true
	velocity = new_dir * velocity.length() * 1.2
	color = Color(1.0, 0.9, 0.5)
	collision_mask = 1 | 4
	remove_from_group("enemy_projectiles")
	add_to_group("player_projectiles")
	_hit.clear()


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if body.is_in_group("walls"):
		_impact()
		return
	if _hit.has(body) or not body.has_method("take_damage"):
		return
	if from_player and not body.is_in_group("enemies"):
		return
	if not from_player and not body.is_in_group("player"):
		return
	_hit.append(body)
	if aoe > 0.0:
		_impact()
		return
	body.take_damage(damage, velocity.normalized() * knockback, element)
	if chain > 0:
		_chain_lightning(body)
	if pierce > 0:
		pierce -= 1
	else:
		_impact()


func _chain_lightning(first: Node2D) -> void:
	var pts := PackedVector2Array([first.global_position])
	var cur: Node2D = first
	var used: Array = [first]
	for i in chain:
		var best = null
		var bd := 170.0
		var enemies: Array = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			if used.has(e):
				continue
			var d: float = e.global_position.distance_to(cur.global_position)
			if d < bd:
				bd = d
				best = e
		if best == null:
			break
		used.append(best)
		_zigzag(pts, cur.global_position, best.global_position)
		best.take_damage(damage * 0.7, Vector2.ZERO, "lightning")
		cur = best
	if pts.size() > 1:
		var fx = Effect.make("line", Vector2.ZERO, color, 0.25)
		fx.points = pts
		get_parent().add_child(fx)


func _zigzag(pts: PackedVector2Array, a: Vector2, b: Vector2) -> void:
	var n := (b - a).orthogonal().normalized()
	for i in range(1, 6):
		var t := i / 6.0
		pts.append(a.lerp(b, t) + n * randf_range(-9, 9))
	pts.append(b)


func _impact() -> void:
	if _done:
		return
	_done = true
	var parent := get_parent()
	if aoe > 0.0:
		var fx = Effect.make("ring", global_position, color, 0.35)
		fx.radius = aoe
		parent.add_child(fx)
		Game.shake(4.0)
		var group := "enemies" if from_player else "player"
		var targets: Array = get_tree().get_nodes_in_group(group)
		for t in targets:
			var d: float = t.global_position.distance_to(global_position)
			if d <= aoe + 12.0:
				t.take_damage(damage, (t.global_position - global_position).normalized() * 220.0, element)
	else:
		var fx = Effect.make("burst", global_position, color, 0.25)
		fx.radius = randf() * TAU
		parent.add_child(fx)
	queue_free()


func _draw() -> void:
	# След
	for i in _trail.size():
		var p: Vector2 = _trail[i]
		var a := 0.35 * (1.0 - float(i) / _trail.size())
		draw_circle(to_local(p), radius * (1.0 - i * 0.12), Color(color, a))
	match kind:
		"arrow":
			draw_line(Vector2(-14, 0), Vector2(6, 0), Color(0.75, 0.6, 0.4), 2.5)
			draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(3, -4), Vector2(3, 4)]), Color(0.85, 0.88, 0.95))
			draw_line(Vector2(-14, 0), Vector2(-9, -4), color, 2.0)
			draw_line(Vector2(-14, 0), Vector2(-9, 4), color, 2.0)
		"bone":
			draw_line(Vector2(-7, 0), Vector2(7, 0), Color(0.9, 0.88, 0.8), 3.0)
			draw_circle(Vector2(-7, 0), 3.0, Color(0.9, 0.88, 0.8))
			draw_circle(Vector2(7, 0), 3.0, Color(0.9, 0.88, 0.8))
		_:
			draw_circle(Vector2.ZERO, radius + 3.0, Color(color, 0.35))
			draw_circle(Vector2.ZERO, radius, color)
			draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 1, 1, 0.9))
