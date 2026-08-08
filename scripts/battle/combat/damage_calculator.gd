# 伤害计算：只负责数值计算，不修改任何单位状态。
class_name DamageCalculator
extends RefCounted

static func calculate_damage(attacker: Unit, defender: Unit, terrain_bonus: int = 0) -> int:
	if attacker == null or defender == null:
		return 0
	var attack := attacker.get_attack()
	var defense := defender.get_defense() + terrain_bonus
	return maxi(1, attack - defense)

static func calculate_skill_damage(attacker: Unit, defender: Unit, power: float, terrain_bonus: int = 0) -> int:
	var base := calculate_damage(attacker, defender, terrain_bonus)
	return maxi(1, roundi(base * power))