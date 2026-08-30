# 爬塔层级生成器：按层数生成敌人配置与玩家自动部署。
# 敌人按层数做属性倍率成长（enemy_growth_rate）与技能数量成长。
class_name TowerGenerator
extends RefCounted

const FALLBACK_SKILL_POOL := ["Power Strike", "Cleave", "Execute", "Lifesteal", "Iron Wall", "Thorns", "Fear"]
const ENEMY_SPOTS := [Vector2i(10, 1), Vector2i(10, 4), Vector2i(9, 2), Vector2i(9, 3),
	Vector2i(11, 2), Vector2i(11, 3)]
const PLAYER_SPOTS := [Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 4)]

# 生成某层的敌人列表。
static func generate_enemies(floor: int) -> Array:
	var count := mini(2 + floor / 4, 5)
	var enemies: Array = []
	for i in range(count):
		enemies.append(_make_enemy(floor, i))
	return enemies

static func _make_enemy(floor: int, index: int) -> Dictionary:
	var type := "Warrior"
	if floor >= 4:
		type = "Tank" if index % 2 == 0 else "Archer"
	# 属性成长：Multiplier = enemy_growth_rate^(floor-1)，作用于 HP/ATK/DEF（配置项可调）
	var growth := GameDatabase.get_enemy_growth_rate()
	var stat_multiplier := pow(growth, maxi(0, floor - 1))
	# 技能成长：按层段（1-10:0 / 11-20:1 / 21-30:2 / 31+:3），上限 3
	var skill_count := mini(3, int((floor - 1) / 10))
	var skills: Array = []
	var skill_pool: Array = GameDatabase.get_searchable_skill_ids(true)
	if skill_pool.is_empty():
		skill_pool = FALLBACK_SKILL_POOL
	for k in range(skill_count):
		var skill: String = str(skill_pool[(floor + k * 3 + index) % skill_pool.size()])
		if not skills.has(skill):
			skills.append(skill)
	return {
		"type": type,
		"pos": ENEMY_SPOTS[index % ENEMY_SPOTS.size()],
		"skills": skills,
		"stat_multiplier": stat_multiplier,
	}

# 生成某层完整场景配置（供部署/战斗使用）。
static func generate_scenario(floor: int) -> Dictionary:
	return {
		"name": "爬塔 · 第 %d 层" % floor,
		"width": 12,
		"height": 6,
		"floor": floor,
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
