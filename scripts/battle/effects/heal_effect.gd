# 治疗效果：HealEffect 恢复目标 HP，并返回实际治疗量。
class_name HealEffect
extends RefCounted

static func apply(target: Unit, amount: int, game = null) -> int:
	if target == null or amount <= 0:
		return 0
	var healed := target.heal(amount)
	if healed > 0 and game != null and game.has_method("add_log"):
		game.add_log("%s 恢复 %d 点生命" % [target.get_display_name(), healed])
	return healed