# 深渊裁决者固有技能：累计普攻次数后，对目标及其邻格造成技能伤害。
extends CodeSkill

# 声明深渊裁决者的普攻后范围技能。
func _init() -> void:
	name = "终末律令"
	desc = "每第 3 次普攻后，对目标及其相邻 1 格的敌人造成 100% 攻击力的技能伤害；生命不高于 50% 时改为每第 2 次，伤害提高到 130%。"
	trigger = SkillTriggerSystem.ON_ATTACK
	condition = {"target_type": "self"}
	common = false
	searchable = false
	tags = ["固有", "攻击", "范围"]
	damage_kinds = [DamageSystem.SKILL]

# 保留本次普攻目标位置，即使普攻击杀主目标也能命中邻格敌人。
func resolve_targets(_battle, _user: Unit, context: Dictionary) -> Array:
	var target = context.get("target")
	return [target] if target is Unit else []

# 按全场累计普攻次数决定触发频率，并分别结算范围内存活敌人。
func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	if battle == null or targets.is_empty():
		return []
	var attack_count := user.runtime.bump("abyss_edict_attacks")
	var enraged := user.hp <= user.max_hp * 0.5
	var every := 2 if enraged else 3
	if attack_count % every != 0:
		return []
	var center: Vector2i = (targets[0] as Unit).pos
	var power := 1.3 if enraged else 1.0
	var reports: Array = []
	for enemy in battle.units:
		if not (enemy is Unit) or not enemy.alive or enemy.camp == user.camp:
			continue
		if Grid.manhattan_distance(enemy.pos, center) <= 1:
			reports.append({"target": enemy, "report": SkillKit.deal_effect(user, enemy, game, battle,
				{"atk": power, "damage_kind": DamageSystem.SKILL})})
	return reports
