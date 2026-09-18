# 伤害效果：DamageEffect 把技能倍率换算成实际伤害并扣除目标 HP。
class_name DamageEffect
extends RefCounted

# 通过统一伤害系统执行一段倍率伤害。
# kind 决定伤害分类：默认技能伤害(SKILL)，代码技能可传 effect/attack 表达特效或普攻语义。
static func apply(user: Unit, target: Unit, power: float, terrain_bonus: int = 0,
		game = null, battle = null, kind: String = DamageSystem.SKILL) -> int:
	if user == null or target == null or not target.alive:
		return 0
	var resolved := DamageSystem.apply(user, target, {"damage_kind": kind,
		"power": power, "terrain_bonus": terrain_bonus}, battle, game)
	var damage := int(resolved.get("damage", 0))
	if game != null and game.has_method("add_log"):
		game.add_log("%s 对 %s 造成 %d 点伤害" % [user.get_display_name(), target.get_display_name(), damage])
	return damage
