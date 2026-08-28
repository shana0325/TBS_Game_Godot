# 单位信息文本格式化：统一部署界面与战斗界面的属性、装备、技能和 Buff 文本。
class_name UnitInfoText
extends RefCounted

static func build(unit: Unit) -> String:
	if unit == null:
		return ""
	var lines: Array = []
	lines.append("%s  Lv.%d  (%s)" % [unit.get_display_name(), unit.level, "玩家" if unit.camp == TurnManager.PLAYER_CAMP else "敌方"])
	lines.append("HP: %d/%d" % [unit.hp, unit.max_hp])
	var shield_total := 0
	for buff in unit.buffs:
		shield_total += buff.shield
	if shield_total > 0:
		var shield_max_all := 0
		for buff in unit.buffs:
			if buff.shield > 0:
				shield_max_all += int(buff.raw_data.get("shield", buff.shield))
		lines.append("护罩: %d/%d" % [shield_total, shield_max_all])
	lines.append("攻击: %d   防御: %d   移动: %d" % [unit.get_attack(), unit.get_defense(), unit.get_move_points()])
	lines.append("暴击率: %d%%   暴击伤害: %d%%" % [unit.get_crit_rate(), unit.get_crit_damage()])
	lines.append("射程: %d-%d" % [unit.get_range_min(), unit.get_range_max()])
	lines.append("行动间隔: %.1fs" % unit.turn_interval)
	if not unit.permanent_mods.is_empty():
		lines.append("永久强化:")
		var stat_labels := {"hp": "生命上限", "attack": "攻击", "defense": "防御", "move": "移动"}
		for stat in unit.permanent_mods:
			lines.append("  %s +%d" % [str(stat_labels.get(stat, stat)), int(unit.permanent_mods[stat])])
	lines.append("")
	lines.append("装备:")
	var has_equip := false
	for slot in unit.equipment:
		lines.append("  %s: %s" % [slot, unit.equipment[slot].name])
		has_equip = true
	if not has_equip:
		lines.append("  （无）")
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
