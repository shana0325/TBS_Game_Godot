# 数据加载入口：统一加载 units / skills / buffs / equipments / player_roster。
extends Node

var units: Dictionary = {}
var skills: Dictionary = {}
var buffs: Dictionary = {}
var equipments: Dictionary = {}
var player_roster: Dictionary = {}

const DATA_PATHS := {
	"units": "res://data/unit/units.json",
	"skills": "res://data/skill/skills.json",
	"buffs": "res://data/buff/buffs.json",
	"equipments": "res://data/equipment/equipments.json",
	"player_roster": "res://data/player/player_roster.json",
}

func _ready() -> void:
	units = _load_json(DATA_PATHS.units)
	skills = _load_json(DATA_PATHS.skills)
	buffs = _load_json(DATA_PATHS.buffs)
	equipments = _load_json(DATA_PATHS.equipments)
	player_roster = _load_json(DATA_PATHS.player_roster)
	print("GameDatabase loaded: units=%d skills=%d buffs=%d equipments=%d" % [
		units.size(), skills.size(), buffs.size(), equipments.size()
	])

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

func get_player_units() -> Array:
	return player_roster.get("units", [])

func get_data_summary() -> String:
	return "数据已加载 | 单位:%d 技能:%d Buff:%d 装备:%d" % [
		units.size(), skills.size(), buffs.size(), equipments.size()
	]