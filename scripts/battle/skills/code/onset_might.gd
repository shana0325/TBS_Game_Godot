# 通用技能：骁勇累积 — 造成普攻/技能伤害叠1层（至多10），每层使普攻与技能伤害+2%（SkillKit 结算），满层时实际伤害8%转自疗。
extends CodeSkill


func _init() -> void:
	name = "骁勇累积"
	desc = "每次造成普攻或技能伤害叠 1 层（至多 10 层）；每层使自身普攻与技能伤害 +2%，满层时实际生命损失 8% 转为自身治疗。特效伤害不叠层。"
	trigger = "on_hit"
	condition = {"target_type": "self"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "攻击", "成长"]

func execute(user, targets, game, battle) -> Array:
	if battle == null or not battle.has_method("get_active_hit"):
		return []
	var rt := user.runtime
	if rt.stacked_add("onset", 1, 10) >= 10:
		var hp_lost := int(battle.get_active_hit().get("hp_lost", 0))
		var heal := roundi(float(hp_lost) * 0.08)
		if heal > 0:
			var healed := user.heal(heal, user)
			if healed > 0 and game != null and game.has_method("add_log"):
				game.add_log("骁勇累积满层：%s 回复 %d 点生命" % [user.get_display_name(), healed])
	return []