# Buff：Buff 表示单位身上的临时状态，数据来自 buffs.json。
class_name Buff
extends RefCounted

var name: String
var duration: int
var modifiers: Dictionary = {}
var tick_damage: int = 0
var tick_heal: int = 0
var tick_phase: String = ""
var control: String = ""
var shield: int = 0
var trigger: String = ""
var counter: bool = false
var aura_range: int = 0
var heal_percent: float = 0.0
var immunity: Array = []
var reflect_percent: float = 0.0
var reduce_percent: float = 0.0
var ignore_defense: bool = false
var is_mark: bool = false
var permanent: bool = false
var conditional_hp_percent: Dictionary = {}
var raw_data: Dictionary = {}

static func from_data(data: Dictionary) -> Buff:
	var buff := Buff.new()
	buff.name = str(data.get("name", "buff"))
	buff.duration = int(data.get("duration", 1))
	buff.modifiers = data.get("modifiers", {})
	buff.tick_damage = int(data.get("tick_damage", 0))
	buff.tick_heal = int(data.get("tick_heal", 0))
	buff.tick_phase = str(data.get("tick_phase", ""))
	buff.control = str(data.get("control", ""))
	buff.shield = int(data.get("shield", 0))
	buff.trigger = str(data.get("trigger", ""))
	buff.counter = bool(data.get("counter", false))
	buff.aura_range = int(data.get("aura_range", 0))
	buff.heal_percent = float(data.get("heal_percent", 0.0))
	buff.immunity = data.get("immunity", [])
	buff.reflect_percent = float(data.get("reflect_percent", 0.0))
	buff.reduce_percent = float(data.get("reduce_percent", 0.0))
	buff.ignore_defense = bool(data.get("ignore_defense", false))
	buff.is_mark = bool(data.get("is_mark", false))
	buff.permanent = bool(data.get("permanent", false))
	buff.conditional_hp_percent = data.get("conditional_hp_percent", {})
	buff.raw_data = data
	return buff

func get_stat_modifier(stat: String) -> int:
	if not conditional_hp_percent.is_empty():
		return 0
	return int(modifiers.get(stat, 0))

func get_stat_modifier_for_unit(unit: Unit, stat: String) -> int:
	if not _condition_matches(unit):
		return 0
	return int(modifiers.get(stat, 0))

func _condition_matches(unit: Unit) -> bool:
	if conditional_hp_percent.is_empty() or unit == null:
		return true
	var ratio := float(unit.hp) / float(maxi(unit.max_hp, 1))
	return Skill.compare_num(ratio, conditional_hp_percent)

func on_turn_start(unit, game) -> void:
	if tick_phase == "turn_start":
		_apply_tick(unit, game)

func on_turn_end(unit, game) -> void:
	if tick_phase == "turn_end":
		_apply_tick(unit, game)
	if not permanent:
		duration -= 1

func on_trigger(unit, event, game) -> void:
	# 触发型 Buff 的统一入口，当前先支持吸血示例。
	# on_hit 是“造成伤害后”事件，只允许伤害来源本人触发吸血，
	# 避免受击者因同一事件错误回血。
	if trigger == "on_hit" and heal_percent > 0.0 and event != null and event.source == unit:
		var damage := int(event.data.get("damage", 0))
		var heal := roundi(damage * heal_percent)
		if heal > 0:
			unit.heal(heal, unit)
			if game != null and game.has_method("add_log"):
				game.add_log("%s 通过 %s 恢复 %d 点生命" % [unit.get_display_name(), name, heal])

func is_expired() -> bool:
	if permanent:
		return false
	return duration <= 0

func _apply_tick(unit, game) -> void:
	if tick_damage > 0:
		var damage := tick_damage
		if game != null and game.has_method("get_final_damage_multiplier"):
			damage = maxi(1, roundi(float(damage) * float(game.get_final_damage_multiplier())))
		unit.take_damage(damage, game)
		if game != null and game.has_method("add_log"):
			game.add_log("%s 受到 %s 的 %d 点持续伤害" % [unit.get_display_name(), name, damage])
	if tick_heal > 0:
		var healed: int = unit.heal(tick_heal, unit)
		if healed > 0 and game != null and game.has_method("add_log"):
			game.add_log("%s 通过 %s 恢复 %d 点生命" % [unit.get_display_name(), name, healed])
