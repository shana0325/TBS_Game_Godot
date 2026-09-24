# 数据加载入口：统一加载单位、技能、Buff、遗物与玩家编成。
extends Node

# 编成进度保存路径（user://）：桌面与网页通用。
# 网页版 res:// 只读，进度必须写到 user://（浏览器映射为 IndexedDB）。
const ROSTER_SAVE_PATH := "user://player_roster.json"
const BASE_PLAYER_UNITS := [
	{"type": "Hero", "id": "hero_001"},
	{"type": "Warrior", "id": "warrior_001"},
	{"type": "Tank", "id": "tank_001"},
	{"type": "Archer", "id": "archer_001"},
	{"type": "Assassin", "id": "assassin_001"},
]

var units: Dictionary = {}
var skills: Dictionary = {}
var buffs: Dictionary = {}
var relics: Dictionary = {}
var tower_config: Dictionary = {}
var player_roster: Dictionary = {}

const DATA_PATHS := {
	"units": "res://data/unit/units.json",
	"skills": "res://data/skill/skills.json",
	"buffs": "res://data/buff/buffs.json",
	"relics": "res://data/relic/relics.json",
	"tower_config": "res://data/tower/tower_config.json",
	"player_roster": "res://data/player/player_roster.json",
}

func _ready() -> void:
	units = _load_json(DATA_PATHS.units)
	skills = _load_json(DATA_PATHS.skills)
	buffs = _load_json(DATA_PATHS.buffs)
	relics = _load_json(DATA_PATHS.relics)
	tower_config = _load_json(DATA_PATHS.tower_config)
	player_roster = _load_json(DATA_PATHS.player_roster)
	_merge_code_skills()

# Mod 数据与代码技能注册完成后，再校验存档中的单位与技能。
func finalize_loading() -> void:
	_sync_user_roster()
	print("GameDatabase loaded: units=%d skills=%d buffs=%d relics=%d" % [
		units.size(), skills.size(), buffs.size(), relics.size()
	])

# 编成进度优先读取 user://；首次运行时把内置编成种子写入 user:// 供后续保存。
func _sync_user_roster() -> void:
	if FileAccess.file_exists(ROSTER_SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_SAVE_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			player_roster = parsed
			_sanitize_user_roster()
			return
	_save_user_roster()

# 开始新游戏：从 res:// 的初始种子重建角色与背包，并覆盖当前 user:// 存档。
func start_new_game() -> bool:
	var fresh_roster := _load_json(DATA_PATHS.player_roster)
	if fresh_roster.is_empty():
		return false
	player_roster = fresh_roster
	_sanitize_user_roster()
	return _save_user_roster()

# 是否存在可继续读取的玩家存档。
func has_user_save() -> bool:
	return FileAccess.file_exists(ROSTER_SAVE_PATH)

# 清理旧版本存档中的已删除单位与技能，避免 user:// 存档覆盖当前数据设计。
func _sanitize_user_roster() -> void:
	var valid_units: Array = []
	var changed := false
	# 升星道具与技能书统一放进背包；旧版根字段只做一次迁移清理。
	if player_roster.has("star_items"):
		player_roster.erase("star_items")
		changed = true
	if not player_roster.has("inventory") or not (player_roster["inventory"] is Dictionary):
		player_roster["inventory"] = _default_inventory()
		changed = true
	else:
		var inventory: Dictionary = player_roster["inventory"]
		var old_star_items := int(inventory.get("star_items", 0))
		inventory["star_items"] = maxi(old_star_items, 0)
		changed = changed or old_star_items != int(inventory["star_items"])
		if not inventory.has("skill_books") or not (inventory["skill_books"] is Dictionary):
			inventory["skill_books"] = {}
			changed = true
		if not inventory.has("gold"):
			inventory["gold"] = 0
			changed = true
		inventory["gold"] = maxi(0, int(inventory["gold"]))
		player_roster["inventory"] = inventory
	if not player_roster.has("deployment_limit"):
		player_roster["deployment_limit"] = 4
		changed = true
	player_roster["deployment_limit"] = clampi(int(player_roster["deployment_limit"]), 1, 6)
	for raw_unit in player_roster.get("units", []):
		if typeof(raw_unit) != TYPE_DICTIONARY:
			changed = true
			continue
		var unit: Dictionary = raw_unit
		var unit_type := str(unit.get("type", ""))
		if not units.has(unit_type):
			changed = true
			continue
		if str(unit.get("id", "")).is_empty():
			unit["id"] = _default_unit_id(unit_type)
			changed = true
		var old_star := int(unit.get("star", 1))
		unit["star"] = clampi(old_star, 1, Unit.MAX_STARS)
		changed = changed or old_star != int(unit["star"])
		# 旧版经验、加点和技能点机制已经移除，载入时清掉遗留字段及其属性收益。
		for obsolete_key in ["exp", "stat_points", "skill_points", "allocated_stats"]:
			if unit.has(obsolete_key):
				unit.erase(obsolete_key)
				changed = true
		# 旧版装备系统已移除，读取旧存档时丢弃装备槽。
		if unit.has("equipment"):
			unit.erase("equipment")
			changed = true
		for list_key in ["learned_skills", "equipped_skills", "extra_skills"]:
			var old_list: Array = unit.get(list_key, [])
			var clean_list: Array = []
			for skill_id in old_list:
				var skill_data: Dictionary = skills.get(str(skill_id), {})
				var valid_skill := skills.has(str(skill_id)) and bool(skill_data.get("common", false))
				if valid_skill:
					clean_list.append(skill_id)
				else:
					changed = true
			unit[list_key] = clean_list
		var equipped: Array = unit.get("equipped_skills", [])
		var slot_limit := Unit.get_skill_slot_limit(int(unit.get("star", 1)))
		if equipped.size() > slot_limit:
			unit["equipped_skills"] = equipped.slice(0, slot_limit)
			changed = true
		valid_units.append(unit)
	# 只在旧存档完全没有有效角色时补基础队伍；出售过的角色不能自动复活。
	if valid_units.is_empty():
		for base_unit in BASE_PLAYER_UNITS:
			var base_type := str(base_unit["type"])
			if units.has(base_type):
				valid_units.append(_default_unit_entry(base_type, str(base_unit["id"])))
		changed = true
	if valid_units.size() != player_roster.get("units", []).size():
		changed = true
	player_roster["units"] = valid_units
	if changed:
		_save_user_roster()

# 旧存档缺少背包字段时补空背包，不再自动发放测试资源。
func _default_inventory() -> Dictionary:
	return {"star_items": 0, "skill_books": {}, "gold": 0}

# 构造基础角色的持久化字段，避免旧存档中的临时模板继续以空 unit_id 运行。
func _default_unit_entry(unit_type: String, unit_id: String) -> Dictionary:
	return {
		"id": unit_id,
		"type": unit_type,
		"star": 1,
		"level": 1,
		"permanent_mods": {},
		"learned_skills": [],
		"equipped_skills": [],
		"extra_skills": [],
	}

func _default_unit_id(unit_type: String) -> String:
	for base_unit in BASE_PLAYER_UNITS:
		if str(base_unit["type"]) == unit_type:
			return str(base_unit["id"])
	return "%s_001" % unit_type.to_lower()

func _save_user_roster() -> bool:
	var file := FileAccess.open(ROSTER_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(player_roster, "\t"))
		return true
	return false

# 注册代码技能（技能代码轨）：脚本提供完整元数据，战斗与界面仍统一通过 get_skill 访问。
func _merge_code_skills() -> void:
	for skill_id in SkillCodeRegistry.get_entries():
		var path: String = str(SkillCodeRegistry.get_entries()[skill_id])
		register_code_skill(str(skill_id), path)

# 注册内置或 Mod 代码技能；同 ID 的已有定义会被明确替换，避免两份元数据混用。
func register_code_skill(skill_id: String, path: String) -> bool:
	var resource: Resource = load(path)
	if not (resource is GDScript) or not (resource as GDScript).can_instantiate():
		push_error("代码技能脚本无效: %s (%s)" % [skill_id, path])
		return false
	var script := resource as GDScript
	var inst: Object = script.new()
	if not (inst is CodeSkill):
		push_error("代码技能必须继承 CodeSkill: %s" % skill_id)
		return false
	var meta: Dictionary = (inst as CodeSkill).export_meta()
	if skills.has(skill_id):
		push_warning("代码技能 %s 与已有定义重名，将只使用当前脚本元数据" % skill_id)
	meta["code_script"] = script
	skills[skill_id] = meta
	return true

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open data file: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON in data file: %s" % path)
		return {}
	return parsed

func get_unit(unit_id: String) -> Dictionary:
	return units.get(unit_id, {})

# 返回允许进入随机招募、商店和普通敌人池的单位；缺省视为可抽取。
func get_random_pool_unit_ids() -> Array:
	var result: Array = []
	for unit_id in units.keys():
		var data: Dictionary = get_unit(str(unit_id))
		if bool(data.get("random_pool_enabled", true)):
			result.append(str(unit_id))
	result.sort()
	return result

func get_skill(skill_id: String) -> Dictionary:
	return skills.get(skill_id, {})

# 获取可被随机池/常规检索发现的技能；指定获取不应调用此方法。
func get_searchable_skill_ids(common_only: bool = false, required_tags: Array = []) -> Array:
	var result: Array = []
	for skill_id in skills.keys():
		var data: Dictionary = get_skill(str(skill_id))
		if not bool(data.get("searchable", true)):
			continue
		if common_only and not bool(data.get("common", false)):
			continue
		if not _has_required_tags(data.get("tags", []), required_tags):
			continue
		result.append(str(skill_id))
	return result

# 按标签筛选技能，供后续学习界面/检索器复用。
func get_skill_ids_by_tags(required_tags: Array, common_only: bool = false, searchable_only: bool = false) -> Array:
	var result: Array = []
	for skill_id in skills.keys():
		var data: Dictionary = get_skill(str(skill_id))
		if common_only and not bool(data.get("common", false)):
			continue
		if searchable_only and not bool(data.get("searchable", true)):
			continue
		if _has_required_tags(data.get("tags", []), required_tags):
			result.append(str(skill_id))
	return result

func is_skill_searchable(skill_id: String) -> bool:
	var data := get_skill(skill_id)
	return not data.is_empty() and bool(data.get("searchable", true))

func _has_required_tags(raw_tags: Variant, required_tags: Array) -> bool:
	if required_tags.is_empty():
		return true
	if not raw_tags is Array:
		return false
	for required in required_tags:
		if not raw_tags.has(required):
			return false
	return true

func get_buff(buff_id: String) -> Dictionary:
	return buffs.get(buff_id, {})

func get_relic(relic_id: String) -> Dictionary:
	return relics.get(relic_id, {})

# 爬塔敌人属性成长率（配置项，默认 1.04；通过战斗模拟调整）。
func get_enemy_growth_rate() -> float:
	return float(tower_config.get("enemy_growth_rate", 1.04))

func get_player_units() -> Array:
	return player_roster.get("units", [])

func get_data_summary() -> String:
	return "数据已加载 | 单位:%d 技能:%d Buff:%d" % [
		units.size(), skills.size(), buffs.size()
	]
