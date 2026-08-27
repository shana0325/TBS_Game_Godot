# 爬塔层级生成器：按层数生成敌人配置与玩家自动部署。
# 敌人成长以技能/组合增加为主（而非纯数值），层数越高技能越多、精英/Boss 出现。
class_name TowerGenerator
extends RefCounted

const SKILL_POOL := ["Poison Strike", "War Banner", "Counter Stance", "Concussion Blow",
	"Blood Rush", "Guard Shield"]
const ENEMY_SPOTS := [Vector2i(10, 1), Vector2i(10, 4), Vector2i(9, 2), Vector2i(9, 3),
	Vector2i(11, 2), Vector2i(11, 3)]
const PLAYER_SPOTS := [Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 4)]

# 生成某层的敌人列表。
static func generate_enemies(floor: int) -> Array:
	var is_boss := floor % 5 == 0
	var elite := floor % 3 == 0 and not is_boss
	var count := mini(2 + floor / 4, 5)
	if elite:
		count += 1
	if is_boss:
		count = mini(4 + floor / 10, 6)
	var enemies: Array = []
	for i in range(count):
		enemies.append(_make_enemy(floor, i, is_boss, elite))
	return enemies

static func _make_enemy(floor: int, index: int, is_boss: bool, elite: bool) -> Dictionary:
	var type := "Goblin"
	if floor >= 4:
		type = "Orc" if index % 2 == 0 else "Goblin"
	if is_boss:
		type = "Orc"
	# 技能成长：Boss > 精英 > 普通；层数越高越多（上限 3）
	var skill_count := 0
	if is_boss:
		skill_count = 2 + floor / 8
	elif elite:
		skill_count = 1 + floor / 10
	else:
		skill_count = 1 if floor >= 8 else 0
	skill_count = mini(skill_count, 3)
	var skills: Array = []
	for k in range(skill_count):
		var skill: String = SKILL_POOL[(floor + k * 3 + index) % SKILL_POOL.size()]
		if not skills.has(skill):
			skills.append(skill)
	return {"type": type, "pos": ENEMY_SPOTS[index % ENEMY_SPOTS.size()], "skills": skills}

# 生成某层完整场景配置（供部署/战斗使用）。
static func generate_scenario(floor: int) -> Dictionary:
	return {
		"name": "爬塔 · 第 %d 层" % floor,
		"width": 12,
		"height": 6,
		"floor": floor,
		"is_boss": floor % 5 == 0,
		"deployment_zone": _left_half_zone(),
		"enemy_units": generate_enemies(floor),
	}

# 玩家部署区：左半场全部 6 行（x0-5 × y0-5）。
static func _left_half_zone() -> Array:
	var zone: Array = []
	for y in range(6):
		for x in range(6):
			zone.append([x, y])
	return zone

# 自动部署玩家队伍：取编成前 N 个单位放到左半场固定布点。
static func auto_deploy() -> Array:
	var roster: Array = GameDatabase.player_roster.get("units", [])
	var deployed: Array = []
	var count := mini(roster.size(), PLAYER_SPOTS.size())
	for i in range(count):
		deployed.append({
			"type": str(roster[i].get("type", "Hero")),
			"roster_index": i,
			"pos": PLAYER_SPOTS[i],
		})
	return deployed