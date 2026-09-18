# 通用技能：攻坚重锤 — 对敌方最大生命最高的一员进行普攻时，追加自身最大生命 30% 的特效伤害。
extends CodeSkill


func _init() -> void:
	name = "攻坚重锤"
	desc = "对敌方最大生命最高的一名单位进行普攻时，追加自身最大生命 30% 的特效伤害。"
	trigger = "on_attack"
	condition = {"target_type": "target"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "攻击"]

func execute(user, targets, game, battle) -> Array:
	if battle == null:
		return []
	var t: Unit = targets[0] if targets.size() > 0 else null
	if t == null:
		return []
	if t == SkillKit.max_hp_enemy(battle, user):
		return [{"target": t, "report": SkillKit.deal_effect(user, t, game, battle, {"maxhp": 0.30})}]
	return []