# 通用技能：破阵序斩 — 每场战斗对每个不同敌方单位，自身前3次对其普攻追加25%攻击力真实特效伤害。
extends CodeSkill


func _init() -> void:
	name = "破阵序斩"
	desc = "每场战斗对每个不同的敌方单位，自身前 3 次对其普攻追加 25% 攻击力的真实特效伤害。"
	trigger = "on_attack"
	condition = {"target_type": "target"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "攻击"]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	var t: Unit = targets[0] if targets.size() > 0 else null
	if t == null:
		return []
	if user.runtime.per_target_bump("blade_opening", t) <= 3:
		return [{"target": t, "report": SkillKit.deal_effect(user, t, game, battle, {"atk": 0.25, "true": true})}]
	return []