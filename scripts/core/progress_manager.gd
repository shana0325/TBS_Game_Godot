# 成长逻辑：负责升星、技能书学习、技能槽装配与遗忘，并写回 player_roster.json。
# 纯逻辑模块，不依赖 UI，供成长界面调用。
class_name ProgressManager
extends RefCounted

const ROSTER_PATH := "user://player_roster.json"
const DISPLAY_STATS := ["attack", "defense", "move", "hp", "crit_rate", "crit_damage"]
const MAX_STARS := Unit.MAX_STARS
const BASE_SKILL_SLOTS := 1
const ASCENSION_SKILL_SLOT_CAP := 2
const MAX_ROSTER_SIZE := 10
const MAX_DEPLOYMENT_LIMIT := 6

# 从爬塔配置读取经济数值，缺项时使用初版默认值。
static func economy_value(key: String, fallback: int) -> int:
	var economy: Dictionary = GameDatabase.tower_config.get("economy", {})
	return maxi(0, int(economy.get(key, fallback)))

# 读取金币和上阵人口，供部署与商店共用。
static func get_gold() -> int:
	return maxi(0, int(get_inventory().get("gold", 0)))

# 增加金币并保存，供非商店事件发放货币。
static func add_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	var inventory := get_inventory()
	var old_gold := get_gold()
	inventory["gold"] = old_gold + amount
	if save_roster():
		return true
	inventory["gold"] = old_gold
	return false

# 读取当前上阵人口上限。
static func get_deployment_limit() -> int:
	return clampi(int(GameDatabase.player_roster.get("deployment_limit", 4)), 1, MAX_DEPLOYMENT_LIMIT)

# 一次保存战后固定奖励，避免奖励页重复打开时只发放其中一部分。
static func grant_battle_supplies(skill_id: String, gold: int) -> bool:
	if gold < 0 or (not skill_id.is_empty() and not bool(GameDatabase.get_skill(skill_id).get("common", false))):
		return false
	var inventory := get_inventory()
	var old_gold := get_gold()
	var books: Dictionary = inventory.get("skill_books", {})
	var old_books := books.duplicate(true)
	inventory["gold"] = old_gold + gold
	if not skill_id.is_empty():
		books[skill_id] = int(books.get(skill_id, 0)) + 1
	if save_roster():
		return true
	inventory["gold"] = old_gold
	inventory["skill_books"] = old_books
	return false

# 招募一个独立角色；同类型可重复招募，但编成最多十人。
static func recruit_unit(unit_type: String, price: int = 0) -> bool:
	if not GameDatabase.units.has(unit_type) or price < 0 or get_gold() < price:
		return false
	var roster: Array = GameDatabase.player_roster.get("units", [])
	if roster.size() >= MAX_ROSTER_SIZE:
		return false
	var original_serial := int(GameDatabase.player_roster.get("next_unit_serial", 1))
	var serial := original_serial
	var unit_id := "recruit_%d" % serial
	var known_ids: Array = roster.map(func(unit: Dictionary) -> String: return str(unit.get("id", "")))
	while known_ids.has(unit_id):
		serial += 1
		unit_id = "recruit_%d" % serial
	var inventory := get_inventory()
	var old_gold := get_gold()
	inventory["gold"] = old_gold - price
	GameDatabase.player_roster["next_unit_serial"] = serial + 1
	var recruit := {"id": unit_id, "type": unit_type, "star": 1, "level": 1,
		"permanent_mods": {}, "learned_skills": [], "equipped_skills": [], "extra_skills": []}
	roster.append(recruit)
	if save_roster():
		return true
	roster.pop_back()
	inventory["gold"] = old_gold
	GameDatabase.player_roster["next_unit_serial"] = original_serial
	return false

# 出售价格只返还金币，不折算已消耗的技能书、升星材料或永久成长。
static func get_sale_price(unit: Dictionary) -> int:
	return economy_value("sale_base_price", 8) + economy_value("sale_star_bonus", 4) * maxi(0, int(unit.get("star", 1)) - 1)

# 出售指定角色并返回其旧编成索引；失败返回 -1。
static func sell_unit(unit_id: String) -> int:
	var roster: Array = GameDatabase.player_roster.get("units", [])
	if roster.size() <= 1:
		return -1
	for index in roster.size():
		var unit: Dictionary = roster[index]
		if str(unit.get("id", "")) != unit_id:
			continue
		var inventory := get_inventory()
		var old_gold := get_gold()
		var old_growth := GameSession.run_relic_state.duplicate(true)
		var growth_units: Dictionary = GameSession.run_relic_state.get("units", {})
		growth_units.erase(unit_id)
		GameSession.run_relic_state["units"] = growth_units
		GameDatabase.player_roster[GameSession.RUN_GROWTH_SAVE_KEY] = GameSession.run_relic_state.duplicate(true)
		inventory["gold"] = old_gold + get_sale_price(unit)
		roster.remove_at(index)
		if save_roster():
			GameSession.on_roster_unit_sold(index)
			return index
		roster.insert(index, unit)
		inventory["gold"] = old_gold
		GameSession.run_relic_state = old_growth
		GameDatabase.player_roster[GameSession.RUN_GROWTH_SAVE_KEY] = old_growth.duplicate(true)
		return -1
	return -1

# 商店购买技能书或升星材料，统一扣费并保存背包。
static func purchase_supply(kind: String, item_id: String, amount: int, price: int) -> bool:
	if amount <= 0 or price < 0 or get_gold() < price:
		return false
	if kind == "skill_book" and not bool(GameDatabase.get_skill(item_id).get("common", false)):
		return false
	if kind != "skill_book" and kind != "star_items":
		return false
	var inventory := get_inventory()
	var old_gold := get_gold()
	var old_stars := int(inventory.get("star_items", 0))
	var old_books: Dictionary = (inventory.get("skill_books", {}) as Dictionary).duplicate(true)
	inventory["gold"] = old_gold - price
	if kind == "star_items":
		inventory["star_items"] = old_stars + amount
	else:
		var books: Dictionary = inventory["skill_books"]
		books[item_id] = int(books.get(item_id, 0)) + amount
	if save_roster():
		return true
	inventory["gold"] = old_gold
	inventory["star_items"] = old_stars
	inventory["skill_books"] = old_books
	return false

# 商店购买一个上阵人口位，最多六位。
static func purchase_deployment_limit(price: int) -> bool:
	if price < 0 or get_gold() < price or get_deployment_limit() >= MAX_DEPLOYMENT_LIMIT:
		return false
	var inventory := get_inventory()
	var old_gold := get_gold()
	var old_limit := get_deployment_limit()
	inventory["gold"] = old_gold - price
	GameDatabase.player_roster["deployment_limit"] = old_limit + 1
	if save_roster():
		return true
	inventory["gold"] = old_gold
	GameDatabase.player_roster["deployment_limit"] = old_limit
	return false

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

# 遗忘一个已学通用技能，同时从装备槽移除；技能书不会返还。
static func forget_skill(unit: Dictionary, skill_id: String) -> bool:
	if unit.is_empty() or skill_id.strip_edges().is_empty():
		return false
	var learned: Array = _list(unit, "learned_skills")
	if not learned.has(skill_id):
		return false
	var equipped: Array = _list(unit, "equipped_skills")
	var was_equipped := equipped.has(skill_id)
	learned.erase(skill_id)
	equipped.erase(skill_id)
	if save_roster():
		return true
	learned.append(skill_id)
	if was_equipped:
		equipped.append(skill_id)
	return false

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

# 给编成角色的永久强化累加小数数值并写回存档。
static func add_permanent_stat(unit_id: String, stat: String, amount: float) -> bool:
	return add_permanent_stats(unit_id, {stat: amount})

# 一次写入多个属性，避免技能在战后为每个属性分别保存存档。
static func add_permanent_stats(unit_id: String, amounts: Dictionary) -> bool:
	if unit_id.strip_edges().is_empty() or amounts.is_empty():
		return false
	for unit in GameDatabase.player_roster.get("units", []):
		if str(unit.get("id", "")) != unit_id:
			continue
		var mods: Dictionary = unit.get("permanent_mods", {})
		for stat in amounts:
			var amount := float(amounts[stat])
			if not is_zero_approx(amount):
				mods[stat] = float(mods.get(stat, 0.0)) + amount
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
