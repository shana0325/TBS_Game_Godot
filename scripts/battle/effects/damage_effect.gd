# 伤害效果：DamageEffect 把技能倍率换算成实际伤害并扣除目标 HP。
class_name DamageEffect
extends RefCounted

static func apply(user: Unit, target: Unit, power: float, terrain_bonus: int = 0, game = null) -> int:
	if user == null or target == null or not target.alive:
		return 0
	var multiplier := 1.0
	if game != null and game.has_method("get_final_damage_multiplier"):
		multiplier = maxf(float(game.get_final_damage_multiplier()), 1.0)
	var damage := DamageCalculator.calculate_skill_damage(user, target, power, terrain_bonus, multiplier)
	target.take_damage(damage, game)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 对 %s 造成 %d 点伤害" % [user.get_display_name(), target.get_display_name(), damage])
	return damage
