# 通用技能：余烬引燃 — 造成技能伤害时，追加 10% 攻击力的真实特效伤害。
extends CodeSkill


func _init() -> void:
	name = "余烬引燃"
	desc = "造成技能伤害时，追加 10% 攻击力的真实特效伤害。"
	trigger = "on_hit"
	condition = {"target_type": "target"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "攻击", "灼烧"]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	if battle == null:
		return []
	var t: Unit = targets[0] if targets.size() > 0 else null
	if t == null:
		return []
	if str(battle.get_active_hit().get("damage_kind", "")) != DamageSystem.SKILL:
		return []
	return [{"target": t, "report": SkillKit.deal_effect(user, t, game, battle, {"atk": 0.10, "true": true})}]