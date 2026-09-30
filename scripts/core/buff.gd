# Buff：Buff 表示单位身上的临时状态，数据来自 buffs.json。
class_name Buff
extends RefCounted

var name: String
var duration: int
var modifiers: Dictionary = {}
var percent_modifiers: Dictionary = {}
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
# 反射来源的伤害类别：技能反射可触发伤害联动，遗物反射默认仍为特效。
var reflect_damage_kind: String = "effect"
var reduce_percent: float = 0.0
var ignore_defense: bool = false
var is_mark: bool = false
var permanent: bool = false
var conditional_hp_percent: Dictionary = {}
var raw_data: Dictionary = {}
var status: String = ""
var seconds_left: float = -1.0
var tick_elapsed: float = 0.0
var stacks: Array = []
var source_ref: WeakRef = null

# 从状态数据创建独立实例，保留来源与持续时间。
static func from_data(data: Dictionary) -> Buff:
	var buff := Buff.new()
	buff.name = str(data.get("name", "buff"))
	buff.duration = int(data.get("duration", 1))
	buff.modifiers = data.get("modifiers", {})
	buff.percent_modifiers = data.get("percent_modifiers", {})
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
	buff.reflect_damage_kind = str(data.get("reflect_damage_kind", "effect"))
	buff.reduce_percent = float(data.get("reduce_percent", 0.0))
	buff.ignore_defense = bool(data.get("ignore_defense", false))
	buff.is_mark = bool(data.get("is_mark", false))
	buff.permanent = bool(data.get("permanent", buff.duration < 0))
	buff.conditional_hp_percent = data.get("conditional_hp_percent", {})
	buff.raw_data = data.duplicate(true)
	buff.raw_data.erase("source")
	buff.status = str(data.get("status", ""))
	buff.seconds_left = float(data.get("duration_seconds", -1.0))
	if buff.seconds_left < 0.0 and not buff.permanent and buff.duration > 0:
		buff.seconds_left = float(buff.duration)
	buff.stacks = (data.get("stacks", []) as Array).duplicate(true) if data.get("stacks", []) is Array else []
	var source: Variant = data.get("source")
	if source is Unit:
		buff.source_ref = weakref(source)
	return buff

func get_stat_modifier(stat: String) -> int:
	if not conditional_hp_percent.is_empty():
		return 0
	return int(modifiers.get(stat, 0))

func get_stat_modifier_for_unit(unit: Unit, stat: String) -> int:
	if not _condition_matches(unit):
		return 0
	return int(modifiers.get(stat, 0))

# 条件满足时返回相对基础属性的百分比增减。
func get_percent_modifier_for_unit(unit: Unit, stat: String) -> float:
	return float(percent_modifiers.get(stat, 0.0)) if _condition_matches(unit) else 0.0

func _condition_matches(unit: Unit) -> bool:
	if conditional_hp_percent.is_empty() or unit == null:
		return true
	var ratio := float(unit.hp) / maxf(unit.max_hp, 1.0)
	return Skill.compare_num(ratio, conditional_hp_percent)

# 兼容旧调用；状态效果统一由真实秒数推进。
func on_turn_start(unit, game, battle = null) -> void:
	pass

# 兼容旧调用；不再按普攻扣除状态持续时间。
func on_turn_end(unit, game, battle = null) -> void:
	pass

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
	if status == "poison":
		return stacks.is_empty()
	if _has_timed_duration():
		return seconds_left <= 0.0
	if permanent:
		return false
	return duration <= 0

# 按真实秒数推进状态；中毒每秒合并同来源伤害并衰减层数。
func tick_seconds(unit: Unit, delta: float, game = null, battle = null) -> void:
	if status == "poison":
		tick_elapsed += maxf(0.0, delta)
		while tick_elapsed >= 1.0 and not stacks.is_empty() and unit.alive:
			tick_elapsed -= 1.0
			var damage_by_source: Dictionary = {}
			for layer in stacks:
				var source = layer.get("source_ref").get_ref() if layer.get("source_ref") is WeakRef else null
				var amount := int(layer.get("damage", 0))
				if float(layer.get("source_attack_percent", 0.0)) > 0.0:
					amount = maxi(1, roundi(float(source.get_attack() if source != null else layer.get("fallback_attack", 0.0)) * float(layer["source_attack_percent"])))
				damage_by_source[source] = int(damage_by_source.get(source, 0)) + amount
			for source in damage_by_source:
				DamageSystem.apply(source, unit, {"damage_kind": DamageSystem.EFFECT,
					"raw_damage": damage_by_source[source], "true_damage": true}, battle, game)
			var decay := maxi(1, ceili(float(stacks.size()) * 0.1))
			for i in range(decay):
				stacks.pop_front()
		return
	if status == "burn" and seconds_left > 0.0:
		tick_elapsed += minf(delta, seconds_left)
		var interval := maxf(0.1, float(raw_data.get("tick_interval_seconds", 2.0)))
		while tick_elapsed >= interval and unit.alive:
			tick_elapsed -= interval
			var source = source_ref.get_ref() if source_ref != null else null
			var amount := maxi(tick_damage, roundi(unit.hp * float(raw_data.get("target_current_hp_percent", 0.0))))
			DamageSystem.apply(source, unit, {"damage_kind": DamageSystem.EFFECT,
				"raw_damage": maxi(1, amount), "true_damage": true}, battle, game)
	if tick_phase in ["turn_start", "turn_end"] and seconds_left > 0.0:
		tick_elapsed += minf(delta, seconds_left)
		while tick_elapsed >= 1.0 and unit.alive:
			tick_elapsed -= 1.0
			_apply_tick(unit, game, battle)
	if _has_timed_duration():
		seconds_left -= delta

# 判断状态是否以真实秒数到期，包括旧数据中的 duration 字段。
func _has_timed_duration() -> bool:
	return (raw_data.has("duration_seconds") and float(raw_data.get("duration_seconds", -1.0)) >= 0.0) \
		or (not permanent and duration > 0)

func _apply_tick(unit, game, battle = null) -> void:
	if tick_damage > 0:
		var damage := tick_damage
		var resolved := DamageSystem.apply(null, unit, {"damage_kind": DamageSystem.EFFECT,
			"raw_damage": damage, "true_damage": true}, battle, game)
		damage = int(resolved.get("damage", 0))
		if game != null and game.has_method("add_log"):
			game.add_log("%s 受到 %s 的 %d 点持续伤害" % [unit.get_display_name(), name, damage])
	if tick_heal > 0:
		var healed: int = unit.heal(tick_heal, unit)
		if healed > 0 and game != null and game.has_method("add_log"):
			game.add_log("%s 通过 %s 恢复 %d 点生命" % [unit.get_display_name(), name, healed])
