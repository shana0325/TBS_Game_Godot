# 数据加载入口：统一加载 units / skills / buffs / equipments / relics / player_roster。
extends Node

# 编成进度保存路径（user://）：桌面与网页通用。
# 网页版 res:// 只读，进度必须写到 user://（浏览器映射为 IndexedDB）。
const ROSTER_SAVE_PATH := "user://player_roster.json"

var units: Dictionary = {}
var skills: Dictionary = {}
var buffs: Dictionary = {}
var equipments: Dictionary = {}
var relics: Dictionary = {}
var player_roster: Dictionary = {}

const DATA_PATHS := {
	"units": "res://data/unit/units.json",
	"skills": "res://data/skill/skills.json",
	"buffs": "res://data/buff/buffs.json",
	"equipments": "res://data/equipment/equipments.json",
	"relics": "res://data/relic/relics.json",
	"player_roster": "res://data/player/player_roster.json",
}

func _ready() -> void:
	units = _load_json(DATA_PATHS.units)
	skills = _load_json(DATA_PATHS.skills)
	buffs = _load_json(DATA_PATHS.buffs)
	equipments = _load_json(DATA_PATHS.equipments)
	relics = _load_json(DATA_PATHS.relics)
	player_roster = _load_json(DATA_PATHS.player_roster)
	_merge_code_skills()
	_sync_user_roster()
	print("GameDatabase loaded: units=%d skills=%d buffs=%d equipments=%d relics=%d" % [
		units.size(), skills.size(), buffs.size(), equipments.size(), relics.size()
	])

# 编成进度优先读取 user://；首次运行时把内置编成种子写入 user:// 供后续保存。
func _sync_user_roster() -> void:
	if FileAccess.file_exists(ROSTER_SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_SAVE_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			player_roster = parsed
			return
	var file := FileAccess.open(ROSTER_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(player_roster, "\t"))

# 合并代码技能（技能代码轨）：把注册文件中的技能并入全局技能表，
# 战斗与界面统一通过 get_skill 访问，与 JSON 技能无差别。
func _merge_code_skills() -> void:
	for skill_id in SkillCodeRegistry.get_entries():
		var path: String = str(SkillCodeRegistry.get_entries()[skill_id])
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			push_error("代码技能脚本无效: %s (%s)" % [skill_id, path])
			continue
		var inst: Object = script.new()
		if not (inst is CodeSkill):
			push_error("代码技能必须继承 CodeSkill: %s" % skill_id)
			continue
		var meta: Dictionary = (inst as CodeSkill).export_meta()
		meta["code_script"] = script
		skills[skill_id] = meta

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

func get_skill(skill_id: String) -> Dictionary:
	return skills.get(skill_id, {})

func get_buff(buff_id: String) -> Dictionary:
	return buffs.get(buff_id, {})

func get_equipment(equipment_id: String) -> Dictionary:
	return equipments.get(equipment_id, {})

func get_relic(relic_id: String) -> Dictionary:
	return relics.get(relic_id, {})

func get_player_units() -> Array:
	return player_roster.get("units", [])

func get_data_summary() -> String:
	return "数据已加载 | 单位:%d 技能:%d Buff:%d 装备:%d" % [
		units.size(), skills.size(), buffs.size(), equipments.size()
	]