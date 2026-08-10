# 伤害计算：负责数值计算，不修改单位状态。
# 支持：无视防御（ignore_defense）、减伤（防护罩 reduce_percent）。
class_name DamageCalculator
extends RefCounted

static func calculate_damage(attacker: Unit, defender: Unit, terrain_bonus: int = 0) -> int:
	if attacker == null or defender == null:
		return 0
	var attack := attacker.get_attack()
	var defense := defender.get_defense() + terrain_bonus
	# 无视防御：攻击者身上有 ignore_defense 时忽略目标防御
	if attacker.has_ignore_defense():
		defense = 0
	var damage := maxi(1, attack - defense)
	# 减伤（防护罩）：按百分比降低最终伤害
	var reduce := defender.get_reduce_percent()
	if reduce > 0.0:
		damage = maxi(1, roundi(damage * (1.0 - reduce)))
	return damage

static func calculate_skill_damage(attacker: Unit, defender: Unit, power: float, terrain_bonus: int = 0) -> int:
	var base := calculate_damage(attacker, defender, terrain_bonus)
	return maxi(1, roundi(base * power))
