# 通用技能：回响节点 — 每累计施放 3 次按秒触发技能，使自身其他按秒触发技能的剩余时间减少 30%。
extends CodeSkill


func _init() -> void:
	name = "回响节点"
	desc = "每累计施放 3 次按秒触发技能，使自身其他按秒触发技能的剩余时间减少 30%。"
	trigger = "on_timer"
	interval_seconds = 5.0
	condition = {"target_type": "self"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "冷却", "加速"]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	var rt := user.runtime
	if rt.bump("transcend_row") % 3 == 0:
		SkillKit.shorten_timed_percent(user, 0.30, self)
	return []
