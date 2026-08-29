# 技能详情格式化：统一生成单位信息卡、背包和成长界面使用的技能说明文本。
class_name SkillDetailFormatter
extends RefCounted

const TRIGGER_LABELS := {
	"on_battle_start": "战斗开始时", "on_turn_start": "行动开始时", "on_attack_start": "攻击前",
	"on_attack": "攻击时", "on_attack_end": "攻击结束后", "on_hit": "造成伤害后",
	"on_be_attacked": "受到攻击后", "on_taken_damage": "受到伤害后", "on_kill": "击杀敌人后",
	"on_death": "阵亡时", "on_ally_death": "友军阵亡时", "on_turn_end": "行动结束时",
	"on_round_start": "首回合开始时", "passive": "常驻被动",
}
const STAT_LABELS := {"hp": "生命", "attack": "攻击", "defense": "护甲", "move": "移动", "crit_rate": "暴击率", "crit_damage": "暴击伤害"}

static func build(skill_id: String) -> String:
	var data: Dictionary = GameDatabase.get_skill(skill_id)
	if data.is_empty():
		return "（未知技能）"
	var lines: Array[String] = []
	var name := str(data.get("name", skill_id))
	lines.append("技能：%s" % name)
	var desc := str(data.get("desc", ""))
	if not desc.is_empty():
		lines.append("技能详情：%s" % desc)
	var skill_type := "通用技能" if bool(data.get("common", false)) else "固有技能"
	var tags: Array = data.get("tags", [])
	lines.append("类型：%s   标签：%s   常规检索：%s" % [skill_type, "、".join(tags) if not tags.is_empty() else "无", "可" if bool(data.get("searchable", true)) else "不可"])
	var trigger := str(data.get("trigger", ""))
	lines.append("判断触发点：%s" % str(TRIGGER_LABELS.get(trigger, trigger if not trigger.is_empty() else "未配置")))
	var cooldown := int(data.get("cooldown", 0))
	lines.append("触发间隔：每次满足条件时判定（无冷却）" if cooldown <= 0 else "触发间隔：触发后冷却 %d 次行动" % cooldown)
	var condition: Dictionary = data.get("condition", {})
	var target_type := str(condition.get("target_type", condition.get("target", "target")))
	if target_type in ["enemy", "ally", "target", "random_enemy"]:
		lines.append("作用范围：%s 至 %s 格" % [str(data.get("min_range", 1)), str(data.get("max_range", 1))])
	lines.append("触发条件：%s" % _condition_text(condition))
	lines.append("目标：%s" % _target_text(target_type))
	lines.append("数值效果：")
	var effects: Array = data.get("effects", [])
	if effects.is_empty():
		lines.append("  · （由代码实现的自定义效果，具体数值见技能详情）" if data.get("code_script") is GDScript else "  · （无效果）")
	for effect in effects:
		if effect is Dictionary:
			lines.append("  · %s" % _effect_text(effect))
	return "\n".join(lines)

static func _target_text(target_type: String) -> String:
	return {"self": "自身", "target": "当前目标", "enemy": "射程内敌人", "ally": "射程内友军", "all_enemies": "全体敌人", "all_allies": "全体友军", "random_enemy": "随机敌人"}.get(target_type, target_type)

static func _condition_text(condition: Dictionary) -> String:
	if condition.is_empty():
		return "无额外条件"
	var parts: Array[String] = []
	for key in ["hp_percent", "target_hp_percent"]:
		if condition.has(key) and condition[key] is Dictionary:
			var label := "自身生命" if key == "hp_percent" else "目标生命"
			parts.append("%s%s" % [label, _compare_text(condition[key])])
	if condition.has("has_buff"):
		parts.append("持有状态「%s」" % str(condition["has_buff"]))
	if condition.has("target_has_buff"):
		parts.append("目标持有状态「%s」" % str(condition["target_has_buff"]))
	if condition.has("crit"):
		parts.append("本次攻击%s暴击" % ("为" if bool(condition["crit"]) else "不为"))
	return "、".join(parts) if not parts.is_empty() else "无额外条件"

static func _compare_text(rule: Dictionary) -> String:
	for key in ["lt", "lte", "gt", "gte", "eq"]:
		if not rule.has(key):
			continue
		var operators := {"lt": " < ", "lte": " ≤ ", "gt": " > ", "gte": " ≥ ", "eq": " = "}
		return "%s%d%%" % [operators[key], roundi(float(rule[key]) * 100.0)]
	return ""

static func _effect_text(effect: Dictionary) -> String:
	var effect_type := str(effect.get("type", ""))
	match effect_type:
		"damage":
			return "造成 %.1f 倍攻击伤害%s" % [float(effect.get("power", 1.0)), "（无视防御）" if bool(effect.get("ignore_defense", false)) else ""]
		"heal":
			return "恢复 %d 点生命" % int(effect.get("amount", 0))
		"shield":
			return "获得 %d 点护罩%s" % [int(effect.get("amount", 0)), _duration_text(int(effect.get("duration", 0)))]
		"shield_max_hp_percent":
			return "获得最大生命 %.0f%% 的护罩%s" % [float(effect.get("percent", 0.1)) * 100.0, _duration_text(int(effect.get("duration", 0)))]
		"buff", "dot":
			var buff_id := str(effect.get("buff", ""))
			var buff_data: Dictionary = GameDatabase.get_buff(buff_id)
			var buff_name := str(buff_data.get("name", buff_id))
			var tick := int(buff_data.get("tick_damage", 0))
			return "附加状态「%s」%s%s" % [buff_name, _duration_text(int(buff_data.get("duration", effect.get("duration", 0)))), "（每次行动 %d 点持续伤害）" % tick if tick > 0 else ""]
		"stat_mod":
			var parts: Array[String] = []
			for key in effect.get("stats", {}):
				var value := int(effect["stats"][key])
				parts.append("%s%s%d" % [str(STAT_LABELS.get(key, key)), "+" if value >= 0 else "", value])
			return "属性变化：%s%s" % ["、".join(parts), _duration_text(int(effect.get("duration", 0)))]
		"revive":
			return "复活目标（恢复 %d%% 生命上限）" % roundi(float(effect.get("hp_percent", 0.5)) * 100.0)
		"permanent_stat":
			return "永久提升%s %d（%s）" % [str(STAT_LABELS.get(str(effect.get("stat", "hp")), effect.get("stat", "hp"))), int(effect.get("amount", 1)), "全局永久" if bool(effect.get("persist", false)) else "本局永久"]
		"reflect":
			return "反射 %.0f%% 受到的伤害%s" % [float(effect.get("percent", 0.3)) * 100.0, _duration_text(int(effect.get("duration", 0)))]
		"percentage_damage":
			return "造成目标生命上限 %.0f%% 的伤害" % (float(effect.get("percent", 0.1)) * 100.0)
		"chain_damage":
			return "连锁伤害：%.1f 倍，最多连锁 %d 次" % [float(effect.get("power", 1.0)), int(effect.get("chain", 2))]
		_:
			return "类型：%s" % effect_type

static func _duration_text(duration: int) -> String:
	if duration < 0:
		return "（常驻）"
	if duration > 0:
		return "（持续 %d 次行动）" % duration
	return ""
