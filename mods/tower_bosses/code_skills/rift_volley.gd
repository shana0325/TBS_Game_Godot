# 裂空猎王固有技能：定时狙击生命比例最低的敌人，并溅射其相邻单位。
extends CodeSkill

# 声明裂空猎王的定时范围技能与技能伤害类型。
func _init() -> void:
	name = "猎弱齐射"
	desc = "每 7 秒对生命比例最低的敌人造成 120% 攻击力的技能伤害；其相邻 1 格的其他敌人受到 60% 攻击力的技能伤害。"
	trigger = SkillTriggerSystem.ON_TIMER
	interval_seconds = 7.0
	condition = {"target_type": "self"}
	common = false
	searchable = false
	tags = ["固有", "攻击", "范围"]
	damage_kinds = [DamageSystem.SKILL]

# 按当前生命比例找主目标，分别通过伤害系统结算主伤害和相邻溅射。
func execute(user: Unit, _targets: Array, game = null, battle = null) -> Array:
	if battle == null:
		return []
	var weakest: Unit = null
	var lowest_ratio := INF
	for enemy in battle.units:
		if not (enemy is Unit) or not enemy.alive or enemy.camp == user.camp:
			continue
		var ratio: float = float(enemy.hp) / maxf(float(enemy.max_hp), 1.0)
		if ratio < lowest_ratio:
			weakest = enemy
			lowest_ratio = ratio
	if weakest == null:
		return []
	var reports: Array = []
	var center := weakest.pos
	reports.append({"target": weakest, "report": SkillKit.deal_effect(user, weakest, game, battle,
		{"atk": 1.2, "damage_kind": DamageSystem.SKILL})})
	for enemy in battle.units:
		if not (enemy is Unit) or not enemy.alive or enemy == weakest or enemy.camp == user.camp:
			continue
		if Grid.manhattan_distance(enemy.pos, center) <= 1:
			reports.append({"target": enemy, "report": SkillKit.deal_effect(user, enemy, game, battle,
				{"atk": 0.6, "damage_kind": DamageSystem.SKILL})})
	return reports
