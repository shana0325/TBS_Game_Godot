# 通用技能：雷霆连锁 — 6秒内对同一敌人造成3次普攻或技能伤害时，追加100%攻击力特效伤害；独立冷却8秒。
extends CodeSkill


func _init() -> void:
	name = "雷霆连锁"
	desc = "6 秒内对同一敌人造成 3 次普攻或技能伤害时，追加一次 100% 攻击力的特效伤害；独立冷却 8 秒。特效伤害不计命中次数。"
	trigger = "on_hit"
	condition = {"target_type": "self"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "攻击", "爆发"]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	if battle == null:
		return []
	var t: Unit = targets[0] if targets.size() > 0 else null
	if t == null:
		return []
	var rt := user.runtime
	var now := SkillKit.now_of(battle)
	if rt.window_hit("electrocute", t, now, 6.0) >= 3 and rt.throttle_use("electrocute_cd", now, 8.0):
		return [{"target": t, "report": SkillKit.deal_effect(user, t, game, battle, {"atk": 1.0})}]
	return []