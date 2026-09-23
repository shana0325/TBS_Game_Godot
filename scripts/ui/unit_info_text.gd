# 单位信息文本格式化：统一部署界面与战斗界面的属性、技能和 Buff 文本。
class_name UnitInfoText
extends RefCounted

const COMBAT_FORMULA = preload("res://scripts/core/combat_formula.gd")

static func build(unit: Unit) -> String:
	if unit == null:
		return ""
	var lines: Array = []
	lines.append("%s  Lv.%d  (%s)" % [unit.get_display_name(), unit.level, "玩家" if unit.camp == TurnManager.PLAYER_CAMP else "敌方"])
	lines.append("HP: %.2f/%.2f" % [unit.hp, unit.max_hp])
	var shield_total := unit.get_total_shield()
	var shield_cap := unit.get_shield_cap()
	lines.append("护罩: %d/%s" % [shield_total, "无上限" if shield_cap < 0 else str(shield_cap)])
	lines.append("攻击: %.2f   护甲: %.2f（%.1f%%减伤）   移动: %d" % [unit.get_attack(), unit.get_defense(), COMBAT_FORMULA.armor_reduction_percent(unit.get_defense()), unit.get_move_points()])
	lines.append("暴击率: %.2f%%   暴击伤害: %.2f%%" % [unit.get_crit_rate(), unit.get_crit_damage()])
	lines.append("射程: %d-%d" % [unit.get_range_min(), unit.get_range_max()])
	lines.append("行动间隔: %.1fs" % unit.turn_interval)
	if not unit.permanent_mods.is_empty():
		lines.append("永久强化:")
		var stat_labels := {"hp": "生命上限", "attack": "攻击", "defense": "护甲", "move": "移动",
			"crit_rate": "暴击率", "crit_damage": "暴击伤害"}
		for stat in unit.permanent_mods:
			lines.append("  %s +%.2f" % [str(stat_labels.get(stat, stat)), float(unit.permanent_mods[stat])])
	lines.append("")
	lines.append("技能:")
	if unit.skills.size() == 0:
		lines.append("  （无）")
	else:
		for skill in unit.skills:
			lines.append("  · %s" % skill.name)
	lines.append("")
	lines.append("Buff:")
	if unit.buffs.size() == 0:
		lines.append("  （无）")
	else:
		for buff in unit.buffs:
			lines.append("  · %s（剩 %d 回合）" % [buff.name, buff.duration])
	return "\n".join(lines)
