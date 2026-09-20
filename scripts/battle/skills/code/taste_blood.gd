# 通用技能：血腥回响 — 造成普攻或技能伤害后，回复本次实际伤害的 10%（每 8 秒至多一次）。
extends CodeSkill


func _init() -> void:
	name = "血腥回响"
	desc = "造成普攻或技能伤害后，回复本次实际伤害的 10%（每 8 秒至多一次）；特效伤害不触发。"
	trigger = "on_hit"
	condition = {"target_type": "self"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "生存", "恢复"]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	if battle == null or not battle.has_method("get_active_hit"):
		return []
	var hp_lost := int(battle.get_active_hit().get("hp_lost", 0))
	if hp_lost <= 0:
		return []
	var rt := user.runtime
	if rt.throttle_use("taste_blood", SkillKit.now_of(battle), 8.0):
		var healed := user.heal(roundi(float(hp_lost) * 0.10), user)
		if healed > 0 and game != null and game.has_method("add_log"):
			game.add_log("血腥回响：%s 回复 %d 点生命" % [user.get_display_name(), healed])
	return []