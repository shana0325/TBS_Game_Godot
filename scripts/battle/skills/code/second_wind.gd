# 通用技能：残喘气血 — 受到普攻或技能伤害、实际扣除生命后，回复当前已损生命的 6%（每 8 秒至多一次）。
extends CodeSkill


func _init() -> void:
	name = "残喘气血"
	desc = "受到普攻或技能伤害、实际扣除生命后，回复当前已损生命的 6%（每 8 秒至多一次）。特效伤害不触发治疗。"
	trigger = "on_taken_damage"
	condition = {"target_type": "self"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "生存", "恢复"]

func execute(user, targets, game, battle) -> Array:
	if battle == null or not battle.has_method("get_active_hit"):
		return []
	if int(battle.get_active_hit().get("hp_lost", 0)) <= 0:
		return []
	var rt := user.runtime
	if rt.throttle_use("second_wind", SkillKit.now_of(battle), 8.0):
		var missing := user.max_hp - user.hp
		var healed := user.heal(roundi(float(missing) * 0.06), user)
		if healed > 0 and game != null and game.has_method("add_log"):
			game.add_log("残喘气血：%s 回复 %d 点生命" % [user.get_display_name(), healed])
	return []