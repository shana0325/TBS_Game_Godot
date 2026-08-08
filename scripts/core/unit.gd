# 战斗单位：Unit 组合基础配置、运行时状态、技能、Buff 和装备。
class_name Unit
extends RefCounted

var unit_id: String = ""
var display_name: String = "Unit"
var unit_type: String = ""
var camp: String = "player"
var team_id: int = 0
var pos: Vector2i = Vector2i.ZERO
var config: Dictionary = {}
var level: int = 1
var exp: int = 0
var hp: int = 0
var max_hp: int = 0
var acted: bool = false
var alive: bool = true
var allocated_stats: Dictionary = {}
var skills: Array = []
var buffs: Array = []
var equipment: Dictionary = {}
var equipped_skill_names: Array = []
var learned_skill_names: Array = []

static func create_from_config(
	unit_type: String,
	camp: String,
	spawn_pos: Vector2i,
	config_data: Dictionary,
	roster_data: Dictionary = {},
	game_db = null
) -> Unit:
	var unit := Unit.new()
	unit.unit_type = unit_type
	unit.display_name = unit_type
	unit.camp = camp
	unit.pos = spawn_pos
	unit.config = config_data
	unit.level = int(roster_data.get("level", 1))
	unit.exp = int(roster_data.get("exp", 0))
	unit.allocated_stats = roster_data.get("allocated_stats", {})
	unit.learned_skill_names = roster_data.get("learned_skills", [])
	unit.equipped_skill_names = roster_data.get("equipped_skills", [])
	unit.max_hp = unit.get_base_stat("hp")
	unit.hp = unit.max_hp
	unit._apply_equipment_data(roster_data.get("equipment", {}), game_db)
	unit.apply_skills(game_db)
	return unit

func get_base_stat(stat: String) -> int:
	var key := stat
	if stat == "attack":
		key = "atk"
	return int(config.get(key, 0)) + int(allocated_stats.get(stat, 0))

func get_stat(stat: String) -> int:
	var value := get_base_stat(stat)
	for slot in equipment:
		var equip: Equipment = equipment[slot]
		value += int(equip.modifiers.get(stat, 0))
	for buff in buffs:
		value += buff.get_stat_modifier(stat)
	return value

func get_attack() -> int:
	return get_stat("attack")

func get_defense() -> int:
	return get_stat("defense")

func get_move_points() -> int:
	return get_stat("move")

func get_range_min() -> int:
	return int(config.get("range_min", 1))

func get_range_max() -> int:
	return int(config.get("range_max", 1))

func get_display_name() -> String:
	return display_name

func is_dead() -> bool:
	return not alive

func move_to(new_pos: Vector2i) -> void:
	pos = new_pos

func take_damage(amount: int, game = null) -> Dictionary:
	var result := {
		"damage": maxi(0, amount),
		"shield_absorbed": 0,
		"hp_lost": 0,
		"lethal": false
	}
	if not alive or amount <= 0:
		return result
	var remaining := amount
	var shield_absorbed := 0
	for buff in buffs.duplicate():
		if buff.shield > 0 and remaining > 0:
			var absorbed := mini(buff.shield, remaining)
			buff.shield -= absorbed
			shield_absorbed += absorbed
			remaining -= absorbed
	var hp_lost := mini(remaining, hp)
	hp -= hp_lost
	result["shield_absorbed"] = shield_absorbed
	result["hp_lost"] = hp_lost
	if hp <= 0:
		hp = 0
		alive = false
		result["lethal"] = true
	return result

func heal(amount: int) -> int:
	if not alive or amount <= 0:
		return 0
	var old_hp := hp
	hp = mini(max_hp, hp + amount)
	return hp - old_hp

func add_buff(buff: Buff) -> void:
	if buff != null:
		buffs.append(buff)

func tick_turn_start(game = null) -> void:
	for buff in buffs.duplicate():
		buff.on_turn_start(self, game)

func tick_turn_end(game = null) -> void:
	for buff in buffs.duplicate():
		buff.on_turn_end(self, game)
	remove_expired_buffs()

func remove_expired_buffs() -> void:
	for buff in buffs.duplicate():
		if buff.is_expired():
			buffs.erase(buff)

func is_stunned() -> bool:
	return _has_control("stun")

func is_silenced() -> bool:
	return _has_control("silence")

func has_counter() -> bool:
	for buff in buffs:
		if buff.counter:
			return true
	return false

func add_skill(skill: Skill) -> void:
	if skill != null and not has_skill(skill.name):
		skills.append(skill)

func has_skill(skill_name: String) -> bool:
	for skill in skills:
		if skill.name == skill_name:
			return true
	return false

func apply_skills(game_db = null) -> void:
	var db = game_db
	if db == null:
		db = GameDatabase
	var skill_names: Array = config.get("skills", [])
	skill_names.append_array(equipped_skill_names)
	skill_names.append_array(learned_skill_names)
	for slot in equipment:
		var equip: Equipment = equipment[slot]
		skill_names.append_array(equip.granted_skills)
	for skill_name in skill_names:
		var data: Dictionary = db.get_skill(str(skill_name))
		if not data.is_empty():
			add_skill(Skill.from_data(data))

func _apply_equipment_data(equipment_map: Dictionary, game_db = null) -> void:
	var db = game_db
	if db == null:
		db = GameDatabase
	equipment.clear()
	for slot in equipment_map:
		var equipment_id := str(equipment_map[slot])
		var data: Dictionary = db.get_equipment(equipment_id)
		if not data.is_empty():
			equipment[slot] = Equipment.from_data(equipment_id, data)

func _has_control(control_type: String) -> bool:
	for buff in buffs:
		if buff.control == control_type:
			return true
	return false