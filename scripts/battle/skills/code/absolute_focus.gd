# 通用技能：盈血之力 — 当前生命高于 70% 时，普攻和技能伤害 +40%（由 SkillKit.passive_damage_bonus 结算）。
extends CodeSkill


func _init() -> void:
	name = "盈血之力"
	desc = "当前生命高于 70% 时，普攻和技能伤害 +40%。"
	trigger = "passive"
	condition = {"target_type": "self"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "攻击"]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	return []