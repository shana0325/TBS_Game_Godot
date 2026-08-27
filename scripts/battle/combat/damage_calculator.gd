# 伤害计算：负责数值计算，不修改单位状态。
# 支持：无视防御（ignore_defense）、减伤（防护罩 reduce_percent）、暴击（crit_rate/crit_damage）。
# 返回 Dictionary：{ "damage": int, "crit": bool }。
class_name DamageCalculator
extends RefCounted

# 普攻伤害：max(1, 攻-防) → 减伤百分比 → 暴击倍率。
static func calculate_damage(attacker: Unit, defender: Unit, terrain_bonus: int = 0) -> Dictionary:
	return _calc(attacker, defender, 1.0, terrain_bonus)

# 技能伤害：普攻公式算基础，再乘 power 倍率，最后应用暴击。
static func calculate_skill_damage(attacker: Unit, defender: Unit, power: float, terrain_bonus: int = 0) -> Dictionary:
	return _calc(attacker, defender, power, terrain_bonus)

static func _calc(attacker: Unit, defender: Unit, power: float, terrain_bonus: int) -> Dictionary:
	var result := {"damage": 0, "crit": false}
	if attacker == null or defender == null:
		return result
	var attack := attacker.get_attack()
	var defense := defender.get_defense() + terrain_bonus
	# 无视防御：攻击者身上有 ignore_defense 时忽略目标防御
	if attacker.has_ignore_defense():
		defense = 0
	var damage := maxi(1, attack - defense)
	# 减伤（防护罩）：按百分比降低
	var reduce := defender.get_reduce_percent()
	if reduce > 0.0:
		damage = maxi(1, roundi(damage * (1.0 - reduce)))
	# 暴击：每次攻击/技能独立判定；暴击时最终伤害 × crit_damage 倍率
	var is_crit := roll_crit(attacker)
	if is_crit:
		damage = maxi(1, roundi(damage * (float(attacker.get_crit_damage()) / 100.0)))
	damage = maxi(1, roundi(damage * power))
	result["damage"] = damage
	result["crit"] = is_crit
	return result

# 独立判定本次攻击是否暴击（rate 为百分数，如 5 = 5%）。
static func roll_crit(attacker: Unit) -> bool:
	if attacker == null:
		return false
	return randf() * 100.0 < float(attacker.get_crit_rate())