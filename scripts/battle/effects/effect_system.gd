# 效果系统：EffectSystem 按配置分发 damage / heal / buff 效果。
class_name EffectSystem
extends RefCounted

static func apply_effects(user: Unit, target: Unit, effects: Array, game = null) -> Dictionary:
	var report := {"damage": 0, "heal": 0, "buffs": []}
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var effect_type := str(effect.get("type", ""))
		match effect_type:
			"damage":
				report["damage"] += DamageEffect.apply(
					user,
					target,
					float(effect.get("power", 1.0)),
					int(effect.get("terrain_bonus", 0)),
					game
				)
			"heal":
				report["heal"] += HealEffect.apply(target, int(effect.get("amount", 0)), game)
			"buff":
				var buff := BuffEffect.apply(target, str(effect.get("buff", "")), game)
				if buff != null:
					report["buffs"].append(buff.name)
			_:
				push_warning("未知技能效果类型: %s" % effect_type)
	return report