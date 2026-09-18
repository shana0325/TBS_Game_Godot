# 统一伤害结算：区分普攻、技能和特效伤害，并统一处理护甲、真实伤害、减伤与触发事件。
class_name DamageSystem
extends RefCounted

const ATTACK := "attack"
const SKILL := "skill"
const EFFECT := "effect"

# 结算一次伤害；配置可用 power（攻击力倍率）或 raw_damage（固定伤害）。
# true_damage/ignore_defense 只跳过护甲，目标的百分比伤害减免始终生效。
static func apply(source: Unit, target: Unit, config: Dictionary, battle = null, game = null) -> Dictionary:
	var kind := str(config.get("damage_kind", EFFECT))
	if not kind in [ATTACK, SKILL, EFFECT]:
		push_warning("未知伤害类型 %s，按特效伤害处理" % kind)
		kind = EFFECT
	var report := {"damage": 0, "actual_damage": 0, "crit": false, "result": {},
		"damage_kind": kind, "true_damage": false}
	if target == null or not target.alive:
		return report
	var is_true := bool(config.get("true_damage", config.get("ignore_defense", false)))
	if source != null and source.has_ignore_defense():
		is_true = true
	report["true_damage"] = is_true
	var damage := 0
	var crit := false
	if config.has("raw_damage"):
		damage = maxi(0, int(config["raw_damage"]))
		if damage > 0 and not is_true:
			var raw_armor := float(target.get_defense() + int(config.get("terrain_bonus", 0)))
			damage = CombatFormula.apply_armor(float(damage), raw_armor)
	else:
		if source == null:
			return report
		var calc := DamageCalculator.calculate_skill_damage(source, target,
			float(config.get("power", 1.0)), int(config.get("terrain_bonus", 0)), is_true)
		damage = int(calc.get("damage", 0))
		crit = bool(calc.get("crit", false))
	if damage <= 0:
		return report
	var multiplier := float(config.get("final_damage_multiplier", 1.0))
	if battle != null and battle.has_method("get_final_damage_multiplier"):
		multiplier = float(battle.get_final_damage_multiplier())
	elif game != null and game.has_method("get_final_damage_multiplier"):
		multiplier = float(game.get_final_damage_multiplier())
	damage = maxi(1, roundi(float(damage) * maxf(multiplier, 1.0)))
	var reduction := clampf(target.get_reduce_percent(), 0.0, 1.0)
	damage = maxi(0, roundi(float(damage) * (1.0 - reduction)))
	var result := target.take_damage(damage, game)
	var actual := int(result.get("hp_lost", 0)) + int(result.get("shield_absorbed", 0))
	if source != null:
		source.damage_dealt += int(result.get("hp_lost", 0))
	report["damage"] = damage
	report["actual_damage"] = actual
	report["crit"] = crit
	report["result"] = result
	if battle != null and actual > 0 and not bool(config.get("defer_reactions", false)):
		battle.on_damage_resolved(source, target, report)
	return report
