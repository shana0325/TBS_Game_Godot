# 成长逻辑：负责角色属性加点、技能学习/装备、装备更换，并写回 player_roster.json。
# 纯逻辑模块，不依赖 UI，供成长界面调用。
class_name ProgressManager
extends RefCounted

const ROSTER_PATH := "res://data/player/player_roster.json"
const VALID_SLOTS := ["weapon", "offhand", "accessory"]
const POINTABLE_STATS := ["attack", "defense", "move", "hp"]

static func required_exp_for_level(level: int) -> int:
	return maxi(100, level * 100)

# 增加经验，自动升级并发放属性点/技能点，返回 {exp_gained, levels_gained}。
static func add_exp(unit: Dictionary, amount: int) -> Dictionary:
	if amount <= 0:
		return {"exp_gained": 0, "levels_gained": 0}
	unit["exp"] = int(unit.get("exp", 0)) + amount
	var levels := 0
	while int(unit.get("exp", 0)) >= required_exp_for_level(int(unit.get("level", 1))):
		unit["exp"] = int(unit.get("exp", 0)) - required_exp_for_level(int(unit.get("level", 1)))
		unit["level"] = int(unit.get("level", 1)) + 1
		unit["stat_points"] = int(unit.get("stat_points", 0)) + 2
		unit["skill_points"] = int(unit.get("skill_points", 0)) + 1
		levels += 1
	return {"exp_gained": amount, "levels_gained": levels}

# 消耗属性点给指定属性 +amount，返回是否成功。
static func add_stat_point(unit: Dictionary, stat_name: String, amount: int = 1) -> bool:
	if amount <= 0 or not POINTABLE_STATS.has(stat_name):
		return false
	if int(unit.get("stat_points", 0)) < amount:
		return false
	unit["stat_points"] = int(unit.get("stat_points", 0)) - amount
	var allocated: Dictionary = unit.get("allocated_stats", {})
	allocated[stat_name] = int(allocated.get(stat_name, 0)) + amount
	unit["allocated_stats"] = allocated
	return true

# 消耗技能点学习新技能，返回是否成功。
static func learn_skill(unit: Dictionary, skill_id: String) -> bool:
	if skill_id.strip_edges().is_empty() or int(unit.get("skill_points", 0)) < 1:
		return false
	if _list(unit, "learned_skills").has(skill_id):
		return false
	unit["skill_points"] = int(unit.get("skill_points", 0)) - 1
	_list(unit, "learned_skills").append(skill_id)
	return true

# 将已学技能加入装备技能列表，返回是否成功。
static func equip_skill(unit: Dictionary, skill_id: String) -> bool:
	if skill_id.strip_edges().is_empty():
		return false
	var learned: Array = _list(unit, "learned_skills")
	var extra: Array = _list(unit, "extra_skills")
	if not learned.has(skill_id) and not extra.has(skill_id):
		return false
	var equipped: Array = _list(unit, "equipped_skills")
	if equipped.has(skill_id):
		return false
	equipped.append(skill_id)
	return true

# 从装备技能列表中移除技能，返回是否成功。
static func unequip_skill(unit: Dictionary, skill_id: String) -> bool:
	var equipped: Array = _list(unit, "equipped_skills")
	if not equipped.has(skill_id):
		return false
	equipped.erase(skill_id)
	return true

# 将装备放入指定槽位（校验槽位匹配），返回是否成功。
static func equip_item(unit: Dictionary, slot: String, equipment_id: String) -> bool:
	if not VALID_SLOTS.has(slot) or equipment_id.strip_edges().is_empty():
		return false
	var data: Dictionary = GameDatabase.get_equipment(equipment_id)
	if data.is_empty() or str(data.get("slot", "")) != slot:
		return false
	var equipment: Dictionary = unit.get("equipment", {})
	equipment[slot] = equipment_id
	unit["equipment"] = equipment
	return true

# 卸下指定槽位装备，返回是否成功。
static func unequip_item(unit: Dictionary, slot: String) -> bool:
	var equipment: Dictionary = unit.get("equipment", {})
	if not equipment.has(slot):
		return false
	equipment.erase(slot)
	unit["equipment"] = equipment
	return true

# 给编成角色的永久强化累加 +amount 并写回 JSON（全局永久成长）。
# stat 与单位字段一致（hp/attack/defense/move）。返回是否成功。
static func add_permanent_stat(unit_id: String, stat: String, amount: int) -> bool:
	if unit_id.strip_edges().is_empty() or amount == 0:
		return false
	for unit in GameDatabase.player_roster.get("units", []):
		if str(unit.get("id", "")) != unit_id:
			continue
		var mods: Dictionary = unit.get("permanent_mods", {})
		mods[stat] = int(mods.get(stat, 0)) + amount
		unit["permanent_mods"] = mods
		return save_roster()
	return false

# 将当前内存中的 player_roster 写回 JSON 文件。
static func save_roster() -> bool:
	var json_text := JSON.stringify(GameDatabase.player_roster, "\t")
	var file := FileAccess.open(ROSTER_PATH, FileAccess.WRITE)
	if file == null:
		push_error("无法写入编成文件: %s" % ROSTER_PATH)
		return false
	file.store_string(json_text)
	return true

static func _list(unit: Dictionary, key: String) -> Array:
	var value: Array = unit.get(key, [])
	unit[key] = value
	return value
