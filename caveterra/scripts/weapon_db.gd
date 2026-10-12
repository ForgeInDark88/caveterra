extends RefCounted
## База оружия: генерация случайного оружия, редкости и отрисовка иконок.

const RARITY_NAMES := ["Обычное", "Редкое", "Эпическое", "Легендарное"]
const RARITY_COLORS := [
	Color(0.80, 0.80, 0.80),
	Color(0.30, 0.65, 1.00),
	Color(0.72, 0.38, 1.00),
	Color(1.00, 0.65, 0.20),
]
const RARITY_MULT := [1.0, 1.3, 1.7, 2.3]

const TYPE_NAMES := {"sword": "Меч", "bow": "Лук", "magic": "Магия"}

const ELEMENT_COLORS := {
	"arcane": Color(0.75, 0.45, 1.0),
	"fire": Color(1.0, 0.45, 0.15),
	"ice": Color(0.55, 0.85, 1.0),
	"lightning": Color(1.0, 0.95, 0.35),
}
const ELEMENT_NAMES := {"arcane": "Тайная магия", "fire": "Огонь", "ice": "Лёд", "lightning": "Молния"}

# Варианты: базовые характеристики + имена по редкости.
const SWORDS := {
	"sword": {"damage": 20.0, "cooldown": 0.40, "reach": 64.0, "arc": 110.0, "knockback": 260.0,
		"names": ["Ржавый меч", "Стальной меч", "Рунный клинок", "Клинок Бездны"]},
	"greatsword": {"damage": 34.0, "cooldown": 0.70, "reach": 84.0, "arc": 150.0, "knockback": 420.0,
		"names": ["Тяжёлый тесак", "Двуручный меч", "Сокрушитель", "Погибель Титанов"]},
	"dagger": {"damage": 11.0, "cooldown": 0.20, "reach": 50.0, "arc": 80.0, "knockback": 120.0,
		"names": ["Кинжал", "Парные кинжалы", "Клинок Тени", "Шёпот Смерти"]},
}
const BOWS := {
	"shortbow": {"damage": 14.0, "cooldown": 0.45, "speed": 720.0, "pierce": 0, "shots": 1, "spread": 0.0,
		"names": ["Короткий лук", "Охотничий лук", "Эльфийский лук", "Лук Звездопада"]},
	"longbow": {"damage": 26.0, "cooldown": 0.80, "speed": 950.0, "pierce": 1, "shots": 1, "spread": 0.0,
		"names": ["Длинный лук", "Ясеневый лук", "Драконобой", "Небесная тетива"]},
	"crossbow": {"damage": 10.0, "cooldown": 0.65, "speed": 680.0, "pierce": 0, "shots": 3, "spread": 22.0,
		"names": ["Самострел", "Тройной арбалет", "Арбалет-веер", "Буря стрел"]},
}
const SPELLS := {
	"arcane": {"damage": 12.0, "cooldown": 0.32, "mana_cost": 6.0, "speed": 480.0, "homing": 7.0, "aoe": 0.0, "pierce": 0, "chain": 0,
		"names": ["Искра магии", "Тайная стрела", "Звёздная ладонь", "Руки Архимага"]},
	"fire": {"damage": 22.0, "cooldown": 0.60, "mana_cost": 14.0, "speed": 420.0, "homing": 0.0, "aoe": 70.0, "pierce": 0, "chain": 0,
		"names": ["Тлеющие ладони", "Огненные руки", "Пламя Феникса", "Длань Инферно"]},
	"ice": {"damage": 15.0, "cooldown": 0.42, "mana_cost": 9.0, "speed": 580.0, "homing": 0.0, "aoe": 0.0, "pierce": 1, "chain": 0,
		"names": ["Холодные пальцы", "Ледяные руки", "Морозная хватка", "Сердце Зимы"]},
	"lightning": {"damage": 16.0, "cooldown": 0.50, "mana_cost": 12.0, "speed": 820.0, "homing": 0.0, "aoe": 0.0, "pierce": 0, "chain": 2,
		"names": ["Искрящие руки", "Руки бури", "Цепная молния", "Гнев Громовержца"]},
}


static func make_starter(kind: String) -> Dictionary:
	match kind:
		"bow":
			return _build("bow", "shortbow", 0, 1.0)
		"magic":
			return _build("magic", "arcane", 0, 1.0)
		_:
			return _build("sword", "sword", 0, 1.0)


## Случайное оружие с учётом глубины. bonus сдвигает шансы к редкому.
static func random_weapon(rng: RandomNumberGenerator, depth: int, bonus: int = 0) -> Dictionary:
	var rarity := roll_rarity(rng, depth, bonus)
	var types := ["sword", "bow", "magic"]
	var t: String = types[rng.randi_range(0, 2)]
	var table: Dictionary = SWORDS if t == "sword" else (BOWS if t == "bow" else SPELLS)
	var variants: Array = table.keys()
	var variant: String = variants[rng.randi_range(0, variants.size() - 1)]
	return _build(t, variant, rarity, rng.randf_range(0.9, 1.12))


static func roll_rarity(rng: RandomNumberGenerator, depth: int, bonus: int = 0) -> int:
	var d := float(depth + bonus * 4)
	var weights := [maxf(10.0, 60.0 - d * 4.0), 30.0, 8.0 + d * 1.6, 1.0 + d * 0.8]
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return clampi(i + (1 if bonus >= 2 and i < 3 else 0), 0, 3)
	return 0


static func _build(t: String, variant: String, rarity: int, roll: float) -> Dictionary:
	var table: Dictionary = SWORDS if t == "sword" else (BOWS if t == "bow" else SPELLS)
	var base: Dictionary = table[variant]
	var names: Array = base["names"]
	var mult: float = RARITY_MULT[rarity] * roll
	var w := {
		"type": t,
		"variant": variant,
		"rarity": rarity,
		"name": names[rarity],
		"damage": snappedf(float(base["damage"]) * mult, 0.1),
		"cooldown": float(base["cooldown"]) * (1.0 - 0.05 * rarity),
		"color": RARITY_COLORS[rarity],
	}
	match t:
		"sword":
			w["reach"] = float(base["reach"]) * (1.0 + 0.05 * rarity)
			w["arc"] = float(base["arc"]) + 8.0 * rarity
			w["knockback"] = float(base["knockback"])
		"bow":
			w["speed"] = float(base["speed"])
			w["pierce"] = int(base["pierce"]) + (1 if rarity >= 3 else 0)
			w["shots"] = int(base["shots"]) + (1 if rarity >= 2 else 0)
			w["spread"] = maxf(float(base["spread"]), 10.0 if rarity >= 2 else 0.0)
		"magic":
			w["element"] = variant
			w["mana_cost"] = float(base["mana_cost"])
			w["speed"] = float(base["speed"])
			w["homing"] = float(base["homing"])
			w["aoe"] = float(base["aoe"]) * (1.0 + 0.12 * rarity)
			w["pierce"] = int(base["pierce"]) + (1 if rarity >= 2 else 0)
			w["chain"] = int(base["chain"]) + (1 if rarity >= 2 else 0)
			w["fx_color"] = ELEMENT_COLORS[variant]
	return w


static func describe(w: Dictionary) -> String:
	if w.is_empty():
		return ""
	var s := "%s [%s] · Урон %d · %.2fс" % [w["name"], RARITY_NAMES[w["rarity"]], roundi(w["damage"]), w["cooldown"]]
	match w["type"]:
		"bow":
			if int(w["shots"]) > 1:
				s += " · Стрел: %d" % w["shots"]
			if int(w["pierce"]) > 0:
				s += " · Пробитие: %d" % w["pierce"]
		"magic":
			s += " · %s · Мана %d" % [ELEMENT_NAMES[w["element"]], roundi(w["mana_cost"])]
	return s


## Рисует иконку оружия на любом CanvasItem.
static func draw_icon(ci: CanvasItem, w: Dictionary, pos: Vector2, angle: float = -0.785, s: float = 1.0) -> void:
	if w.is_empty():
		return
	var rc: Color = w["color"]
	var dir := Vector2.RIGHT.rotated(angle)
	var nrm := dir.orthogonal()
	match w["type"]:
		"sword":
			var length := 26.0 * s
			if w["variant"] == "greatsword":
				length = 32.0 * s
			elif w["variant"] == "dagger":
				length = 17.0 * s
			var hilt := pos - dir * length * 0.35
			var tip := hilt + dir * length
			ci.draw_line(hilt - dir * 7.0 * s, hilt, Color(0.45, 0.28, 0.15), 4.0 * s)
			ci.draw_line(hilt - nrm * 7.0 * s, hilt + nrm * 7.0 * s, rc.darkened(0.2), 3.0 * s)
			ci.draw_line(hilt, tip, Color(0.85, 0.88, 0.95), 4.0 * s)
			ci.draw_line(hilt, tip, rc.lightened(0.3), 1.5 * s)
		"bow":
			var pts := PackedVector2Array()
			for i in 13:
				var a := lerpf(-1.1, 1.1, i / 12.0)
				pts.append(pos + (dir * cos(a) * 0.55 + nrm * sin(a)) * 16.0 * s)
			ci.draw_polyline(pts, Color(0.55, 0.35, 0.18), 3.5 * s)
			ci.draw_polyline(pts, rc, 1.2 * s)
			ci.draw_line(pts[0], pts[pts.size() - 1], Color(0.9, 0.9, 0.85, 0.9), 1.0 * s)
			if w["variant"] == "crossbow":
				ci.draw_line(pos - dir * 12.0 * s, pos + dir * 10.0 * s, Color(0.45, 0.3, 0.2), 4.0 * s)
		"magic":
			var ec: Color = w.get("fx_color", rc)
			ci.draw_circle(pos, 13.0 * s, Color(ec, 0.18))
			ci.draw_circle(pos, 8.0 * s, Color(ec, 0.45))
			ci.draw_circle(pos, 4.5 * s, ec.lightened(0.5))
			for i in 4:
				var a := angle + i * TAU / 4.0 + Time.get_ticks_msec() / 400.0
				ci.draw_circle(pos + Vector2.RIGHT.rotated(a) * 11.0 * s, 1.8 * s, ec)
