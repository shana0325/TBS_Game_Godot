# 技能详情格式化：统一生成单位信息卡、背包和成长界面使用的技能说明文本。
class_name SkillDetailFormatter
extends RefCounted

const TRIGGER_LABELS := {
	"on_battle_start": "战斗开始时", "on_enter_battle": "战吼（入场时）", "on_turn_start": "普攻周期开始时", "on_attack_start": "攻击前",
	"on_attack_hit_before": "普攻命中前",
	"on_attack": "攻击时", "on_attack_end": "攻击结束后", "on_hit": "造成伤害后",
	"on_be_attacked": "受到攻击后", "on_taken_damage": "受到伤害后", "on_kill": "击杀敌人后",
	"on_death": "亡语（阵亡时）", "on_ally_death": "友军阵亡时", "on_avenge": "非召唤友军阵亡后", "on_target_death": "当前目标死亡时", "on_turn_end": "普攻周期结束时",
	"on_round_start": "战斗开始时", "passive": "持续生效", "on_timer": "按固定间隔自动施放",
}
const STAT_LABELS := {"hp": "生命", "attack": "攻击", "defense": "护甲", "move": "移动力", "attack_speed": "攻速加成", "crit_rate": "暴击率", "crit_damage": "暴击伤害"}

# 从技能配置生成含触发、条件与效果的完整文字说明。
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
	var trigger := str(data.get("trigger", ""))
	lines.append("类型：%s · %s   标签：%s   常规检索：%s" % [skill_type, mode_text(trigger), "、".join(tags) if not tags.is_empty() else "无", "可" if bool(data.get("searchable", true)) else "不可"])
	lines.append("判断触发点：%s" % str(TRIGGER_LABELS.get(trigger, trigger if not trigger.is_empty() else "未配置")))
	var cooldown := int(data.get("cooldown", 0))
	if trigger == "on_timer":
		lines.append("施放间隔：每 %.1f 秒自动尝试施放（受技能急速影响）" % float(data.get("interval_seconds", 0.0)))
	else:
		if float(data.get("cooldown_seconds", 0.0)) > 0.0:
			lines.append("触发间隔：触发后冷却 %.1f 秒" % float(data["cooldown_seconds"]))
		else:
			lines.append("触发间隔：每次满足条件时判定（无冷却）" if cooldown <= 0 else "触发间隔：触发后等待 %d 次普攻" % cooldown)
	var condition: Dictionary = data.get("condition", {})
	var target_type := str(condition.get("target_type", condition.get("target", "target")))
	if target_type in ["enemy", "ally", "target", "random_enemy"]:
		lines.append("作用范围：%s 至 %s 格" % [str(data.get("min_range", 1)), str(data.get("max_range", 1))])
	var extra_condition := extra_condition_text(condition)
	lines.append("触发条件：%s" % (extra_condition if not extra_condition.is_empty() else "无额外条件"))
	lines.append("目标：%s" % _target_text(target_type))
	lines.append("数值效果：")
	var effects: Array = data.get("effects", [])
	if effects.is_empty():
		lines.append("  · （由代码实现的自定义效果，具体数值见技能详情）" if data.get("code_script") is GDScript else "  · （无效果）")
	for effect in effects:
		if effect is Dictionary:
			lines.append("  · %s" % _effect_text(effect))
	return "\n".join(lines)

# 固定秒数自动施放归为主动技能，其余事件触发与常驻效果归为被动技能。
static func mode_text(trigger: String) -> String:
	return "主动技能（自动施放）" if trigger == "on_timer" else "被动技能"

# 把运行时的目标选择类型翻译为详情页文字。
static func _target_text(target_type: String) -> String:
	return {"self": "自身", "target": "当前目标", "enemy": "射程内敌人", "ally": "射程内友军", "all_enemies": "全体敌人", "all_allies": "全体其他友军", "nearby_allies": "指定范围内的其他友军", "lowest_hp_ally_with_shield_room": "护盾未满且生命比例最低的其他友军", "random_enemy": "随机敌人"}.get(target_type, target_type)

# 只返回技能数据中实际配置的额外触发条件；没有时返回空字符串。
static func extra_condition_text(condition: Dictionary) -> String:
	if condition.is_empty():
		return ""
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
	if condition.has("attack_count_multiple"):
		parts.append("每完成 %d 次普攻，下一次触发" % maxi(0, int(condition["attack_count_multiple"]) - 1))
	return "、".join(parts)

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
			if effect.has("source_stat"):
				return "造成自身%s %.0f%% 的%s%s" % [STAT_LABELS.get(str(effect["source_stat"]), str(effect["source_stat"])), float(effect.get("stat_percent", 1.0)) * 100.0, _damage_kind_text(effect), _true_damage_text(effect)]
			return "造成 %.1f 倍攻击的%s%s" % [float(effect.get("power", 1.0)), _damage_kind_text(effect), _true_damage_text(effect)]
		"heal":
			return "恢复 %d 点生命" % int(effect.get("amount", 0))
		"cleanse":
			return "清除负面状态"
		"dispel":
			return "驱散目标的增益状态" if not bool(effect.get("friendly", false)) else "清除目标的负面状态"
		"immunity":
			return "免疫%s，持续 %d 秒" % ["、".join(effect.get("states", [])), int(effect.get("duration", 2))]
		"taunt":
			return "获得嘲讽，持续 %.1f 秒" % float(effect.get("duration_seconds", 6.0))
		"stealth":
			return "获得潜行，持续 %.1f 秒" % float(effect.get("duration_seconds", 6.0))
		"divine_shield":
			return "获得圣盾，持续 %.1f 秒或抵挡一次伤害" % float(effect.get("duration_seconds", 6.0))
		"damage_immunity":
			return "获得免伤，持续 %.1f 秒" % float(effect.get("duration_seconds", 6.0))
		"silence":
			return "沉默目标 %.1f 秒" % float(effect.get("duration_seconds", 6.0))
		"poison":
			return "每秒每层受到施加者攻击力 %.0f%% 的特效伤害，结算后层数衰减10%%，无叠层上限" % (float(effect.get("source_attack_percent", 0.0)) * 100.0) if effect.has("source_attack_percent") else "每秒每层受到 %d 点特效伤害，结算后层数衰减10%%，无叠层上限" % int(effect.get("damage", 5))
		"burn":
			return "灼烧 %.1f 秒，每 %.1f 秒受到当前生命 %.0f%% 的特效伤害" % [float(effect.get("duration_seconds", 6.0)), float(effect.get("tick_interval_seconds", 2.0)), float(effect["target_current_hp_percent"]) * 100.0] if effect.has("target_current_hp_percent") else "灼烧 %.1f 秒，每 %.1f 秒受到 %d 点特效伤害" % [float(effect.get("duration_seconds", 6.0)), float(effect.get("tick_interval_seconds", 2.0)), int(effect.get("damage", 5))]
		"frost":
			return "施加 %d 层霜冻，持续 %.1f 秒" % [int(effect.get("stacks", 1)), float(effect.get("duration_seconds", 5.0))]
		"aura":
			var aura_parts: Array[String] = []
			for key in effect.get("stats", {}):
				aura_parts.append("%s+%d" % [str(STAT_LABELS.get(key, key)), int(effect["stats"][key])])
			return "光环：%d 格内友军%s" % [int(effect.get("range", 2)), "、".join(aura_parts)]
		"dormant":
			var awaken_parts: Array[String] = []
			for awaken_effect in effect.get("awaken_effects", []):
				if awaken_effect is Dictionary:
					awaken_parts.append(_effect_text(awaken_effect))
			return "休眠 %.1f 秒，苏醒后%s" % [float(effect.get("duration_seconds", 20.0)), "；".join(awaken_parts)]
		"summon":
			var unit_data: Dictionary = GameDatabase.get_unit(str(effect.get("unit_type", "Warrior")))
			return "召唤一名%s" % str(unit_data.get("name", effect.get("unit_type", "Warrior")))
		"shield":
			return "获得 %d 点护罩%s" % [int(effect.get("amount", 0)), _duration_text(int(effect.get("duration", 0)))]
		"shield_max_hp_percent":
			return "获得最大生命 %.0f%% 的护罩%s" % [float(effect.get("percent", 0.1)) * 100.0, _duration_text(int(effect.get("duration", 0)))]
		"buff", "dot":
			var buff_id := str(effect.get("buff", ""))
			var buff_data: Dictionary = GameDatabase.get_buff(buff_id)
			var buff_name := str(buff_data.get("name", buff_id))
			var tick := int(buff_data.get("tick_damage", 0))
			return "附加状态「%s」%s%s" % [buff_name, _duration_text(int(buff_data.get("duration", effect.get("duration", 0)))), "（每秒 %d 点持续伤害）" % tick if tick > 0 else ""]
		"stat_mod":
			var parts: Array[String] = []
			for key in effect.get("stats", {}):
				var value := int(effect["stats"][key])
				parts.append("%s%s%d" % [str(STAT_LABELS.get(key, key)), "+" if value >= 0 else "", value])
			for key in effect.get("stats_percent", {}):
				var percent := float(effect["stats_percent"][key]) * 100.0
				parts.append("%s%s%.0f%%" % [str(STAT_LABELS.get(key, key)), "+" if percent >= 0.0 else "", percent])
			return "属性变化：%s%s" % ["、".join(parts), _duration_text(int(effect.get("duration", 0)))]
		"revive":
			return "复活目标（恢复 %d%% 生命上限）" % roundi(float(effect.get("hp_percent", 0.5)) * 100.0)
		"permanent_stat":
			return "永久提升%s %d（%s）" % [str(STAT_LABELS.get(str(effect.get("stat", "hp")), effect.get("stat", "hp"))), int(effect.get("amount", 1)), "全局永久" if bool(effect.get("persist", false)) else "本局永久"]
		"reflect":
			return "反射 %.0f%% 受到的伤害%s" % [float(effect.get("percent", 0.3)) * 100.0, _duration_text(int(effect.get("duration", 0)))]
		"percentage_damage":
			return "造成目标生命上限 %.0f%% 的%s%s" % [float(effect.get("percent", 0.1)) * 100.0, _damage_kind_text(effect), "（无视防御）" if bool(effect.get("true_damage", effect.get("ignore_defense", true))) else ""]
		"chain_damage":
			return "连锁%s：%.1f 倍，最多连锁 %d 次%s" % [_damage_kind_text(effect), float(effect.get("power", 1.0)), int(effect.get("chain", 2)), _true_damage_text(effect)]
		_:
			return "类型：%s" % effect_type

# 展示效果数据声明的伤害触发类别。
static func _damage_kind_text(effect: Dictionary) -> String:
	return {"attack": "普攻伤害", "skill": "技能伤害", "effect": "特效伤害"}.get(str(effect.get("damage_kind", "skill")), "技能伤害")

# 展示与伤害类别独立的真实伤害标记。
static func _true_damage_text(effect: Dictionary) -> String:
	return "（无视防御）" if bool(effect.get("true_damage", effect.get("ignore_defense", false))) else ""

static func _duration_text(duration: int) -> String:
	if duration < 0:
		return "（常驻）"
	if duration > 0:
		return "（持续 %d 秒）" % duration
	return ""
