# 成长逻辑：负责角色属性加点、技能学习/装备、装备更换，并写回 player_roster.json。
# 纯逻辑模块，不依赖 UI，供成长界面调用。
class_name ProgressManager
extends RefCounted

const ROSTER_PATH := "user://player_roster.json"
const VALID_SLOTS := ["weapon", "offhand", "accessory"]
const POINTABLE_STATS := ["attack", "defense", "move", "hp", "crit_rate", "crit_damage"]
const MAX_STARS := Unit.MAX_STARS
const BASE_SKILL_SLOTS := 1
const ASCENSION_SKILL_SLOT_CAP := 2

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

# 当前星级对应的通用技能槽位：初始 1 格，前两次升星各增加 1 格。
static func get_skill_slot_limit(star: int) -> int:
	return BASE_SKILL_SLOTS + mini(maxi(star - 1, 0), ASCENSION_SKILL_SLOT_CAP)

# 读取背包中的升星道具数量。
static func get_star_item_count() -> int:
	var inventory: Dictionary = get_inventory()
	return maxi(0, int(inventory.get("star_items", 0)))

# 当前星级升到下一星所需的升星道具数量：1/2/4/8/16……
static func get_ascension_cost(current_star: int) -> int:
	return 1 << maxi(current_star - 1, 0)

# 读取玩家背包；背包是逻辑状态，UI 只通过本接口读取展示。
static func get_inventory() -> Dictionary:
	var inventory_variant: Variant = GameDatabase.player_roster.get("inventory", {})
	if not (inventory_variant is Dictionary):
		inventory_variant = {"star_items": 0, "skill_books": {}}
		GameDatabase.player_roster["inventory"] = inventory_variant
	var inventory: Dictionary = inventory_variant
	if not inventory.has("skill_books") or not (inventory["skill_books"] is Dictionary):
		inventory["skill_books"] = {}
	return inventory

# 消耗一个背包中的升星道具，将单位提升一星并写回存档。
static func ascend_unit(unit: Dictionary) -> bool:
	if unit.is_empty():
		return false
	var current_star := clampi(int(unit.get("star", 1)), 1, MAX_STARS)
	var inventory := get_inventory()
	var item_count := int(inventory.get("star_items", 0))
	var cost := get_ascension_cost(current_star)
	if current_star >= MAX_STARS or item_count < cost:
		return false
	unit["star"] = current_star + 1
	inventory["star_items"] = item_count - cost
	if save_roster():
		return true
	unit["star"] = current_star
	inventory["star_items"] = item_count
	return false

# 增加背包中的升星道具，供未来奖励/商店等明确来源调用。
static func add_star_items(amount: int) -> bool:
	if amount <= 0:
		return false
	var inventory := get_inventory()
	inventory["star_items"] = int(inventory.get("star_items", 0)) + amount
	return save_roster()

# 增加指定通用技能书。技能书是直接获取技能的明确手段，因此不受 searchable 限制。
static func add_skill_book(skill_id: String, amount: int = 1) -> bool:
	if skill_id.strip_edges().is_empty() or amount <= 0:
		return false
	var data: Dictionary = GameDatabase.get_skill(skill_id)
	if data.is_empty() or not bool(data.get("common", false)):
		return false
	var inventory := get_inventory()
	var books: Dictionary = inventory.get("skill_books", {})
	books[skill_id] = int(books.get(skill_id, 0)) + amount
	inventory["skill_books"] = books
	if save_roster():
		return true
	books[skill_id] = int(books.get(skill_id, 0)) - amount
	if int(books[skill_id]) <= 0:
		books.erase(skill_id)
	return false

# 读取指定技能书数量，供拖拽目标校验与背包 UI 使用。
static func get_skill_book_count(skill_id: String) -> int:
	var books: Dictionary = get_inventory().get("skill_books", {})
	return maxi(0, int(books.get(skill_id, 0)))

# 消耗一本技能书，让指定单位学会并装备技能；满槽时可替换一个已装备技能。
# 被替换技能仍保留在已学列表中，之后仍可手动重新装备。
static func use_skill_book(unit: Dictionary, skill_id: String, replaced_skill_id: String = "") -> bool:
	if unit.is_empty() or skill_id.strip_edges().is_empty():
		return false
	var data: Dictionary = GameDatabase.get_skill(skill_id)
	if data.is_empty() or not bool(data.get("common", false)):
		return false
	var learned: Array = _list(unit, "learned_skills")
	if learned.has(skill_id):
		return false
	var equipped: Array = _list(unit, "equipped_skills")
	var slot_limit := get_skill_slot_limit(int(unit.get("star", 1)))
	if replaced_skill_id.is_empty():
		if equipped.size() >= slot_limit:
			return false
	else:
		if equipped.size() < slot_limit or not equipped.has(replaced_skill_id):
			return false
	var inventory := get_inventory()
	var books: Dictionary = inventory.get("skill_books", {})
	var count := int(books.get(skill_id, 0))
	if count <= 0:
		return false
	learned.append(skill_id)
	var replacement_position := -1
	if not replaced_skill_id.is_empty():
		replacement_position = equipped.find(replaced_skill_id)
		equipped[replacement_position] = skill_id
	else:
		equipped.append(skill_id)
	books[skill_id] = count - 1
	if save_roster():
		return true
	learned.erase(skill_id)
	if replacement_position >= 0:
		equipped[replacement_position] = replaced_skill_id
	else:
		equipped.erase(skill_id)
	books[skill_id] = count
	return false

# 消耗技能点学习新技能，返回是否成功。
static func learn_skill(unit: Dictionary, skill_id: String) -> bool:
	if skill_id.strip_edges().is_empty() or int(unit.get("skill_points", 0)) < 1:
		return false
	var data: Dictionary = GameDatabase.get_skill(skill_id)
	if data.is_empty() or not bool(data.get("common", false)) or not bool(data.get("searchable", true)):
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
	var data: Dictionary = GameDatabase.get_skill(skill_id)
	if data.is_empty() or not bool(data.get("common", false)):
		return false
	var equipped: Array = _list(unit, "equipped_skills")
	if equipped.has(skill_id):
		return false
	if equipped.size() >= get_skill_slot_limit(int(unit.get("star", 1))):
		return false
	equipped.append(skill_id)
	return true

# 从装备技能列表中移除技能，返回是否成功。
static func unequip_skill(unit: Dictionary, skill_id: String) -> bool:
	var data: Dictionary = GameDatabase.get_skill(skill_id)
	if data.is_empty() or not bool(data.get("common", false)):
		return false
	var equipped: Array = _list(unit, "equipped_skills")
	if not equipped.has(skill_id):
		return false
	equipped.erase(skill_id)
	return true

# 免费获得技能（爬塔奖励用）：不消耗技能点，直接学习并装备。
static func grant_skill_free(unit: Dictionary, skill_id: String) -> bool:
	if skill_id.strip_edges().is_empty():
		return false
	var data: Dictionary = GameDatabase.get_skill(skill_id)
	if data.is_empty() or not bool(data.get("common", false)):
		return false
	var learned := _list(unit, "learned_skills")
	if not learned.has(skill_id):
		learned.append(skill_id)
	var equipped := _list(unit, "equipped_skills")
	if not equipped.has(skill_id) and equipped.size() < get_skill_slot_limit(int(unit.get("star", 1))):
		equipped.append(skill_id)
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
