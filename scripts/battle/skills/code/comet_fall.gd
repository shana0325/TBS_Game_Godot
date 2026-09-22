# 通用技能：彗星溅射 — 造成技能伤害后，对该目标及其相邻 1 格内的敌人各造成 50% 攻击力特效伤害。
extends CodeSkill

# 相邻判定距离
const AOE_RADIUS := 1

func _init() -> void:
	name = "彗星溅射"
	desc = "造成技能伤害后，对该目标及其相邻 1 格内的敌人各造成 50% 攻击力的特效伤害。"
	trigger = "on_hit"
	condition = {"target_type": "target"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "攻击", "范围"]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	if battle == null:
		return []
	var t: Unit = targets[0] if targets.size() > 0 else null
	if t == null:
		return []
	if str(battle.get_active_hit().get("damage_kind", "")) != DamageSystem.SKILL:
		return []
	var out: Array = []
	for enemy in SkillKit.adjacent_enemies(battle, user, t):
		out.append({"target": enemy, "report": SkillKit.deal_effect(user, enemy, game, battle, {"atk": 0.5})})
	return out