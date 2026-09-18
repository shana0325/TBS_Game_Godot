# 通用技能：燃血命脉 — 击杀敌人时回复自身 60% 最大生命。
extends CodeSkill


func _init() -> void:
	name = "燃血命脉"
	desc = "击杀敌人时回复自身 60% 最大生命。"
	trigger = "on_kill"
	condition = {"target_type": "self"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "生存", "击杀"]

func execute(user, targets, game, battle) -> Array:
	if not user.alive:
		return []
	var healed := user.heal(roundi(user.max_hp * 0.6), user)
	if healed > 0 and game != null and game.has_method("add_log"):
		game.add_log("燃血命脉：%s 回复 %d 点生命" % [user.get_display_name(), healed])
	return []