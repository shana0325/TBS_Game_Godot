# 战士固有技能：每次普攻追加按已损生命计算的技能伤害，并回复生命。
extends CodeSkill

# 声明供战斗触发系统和技能详情使用的元数据。
func _init() -> void:
	name = "浴血奋战"
	desc = "每次普攻追加自身已损生命值 10% 的技能伤害，并回复自身已损生命值的 10%。"
	trigger = SkillTriggerSystem.ON_ATTACK
	condition = {"target_type": "self"}
	common = false
	searchable = false
	tags = ["固有", "攻击", "恢复"]
	damage_kinds = [DamageSystem.SKILL]

# 使用普攻触发时的已损生命快照结算追加伤害和治疗。
func execute(user: Unit, _targets: Array, game = null, battle = null) -> Array:
	var missing := maxf(0.0, user.max_hp - user.hp)
	var reports: Array = []
	var target := user.get_current_target()
	if target != null and target.alive:
		var damage := roundi(missing * 0.1)
		if damage > 0:
			reports.append({"target": target, "report": SkillKit.deal_effect(user, target, game, battle,
				{"flat": damage, "damage_kind": DamageSystem.SKILL})})
	user.heal(roundi(missing * 0.1), user)
	return reports
