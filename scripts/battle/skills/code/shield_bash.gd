# 通用技能：盾辉反击 — 获得护盾后，下一次普攻追加本次实际获得护盾值 15% 的技能伤害。
# 护盾信用由 unit.gain_shield / EffectSystem._apply_shield 累加到 runtime 的 shield_credit。
extends CodeSkill

const SHIELD_RATIO := 0.15

func _init() -> void:
	name = "盾辉反击"
	desc = "获得护盾后，下一次普攻追加本次实际获得护盾值 15% 的技能伤害。"
	trigger = "on_attack"
	condition = {"target_type": "target"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "防御", "攻击"]
	damage_kinds = [DamageSystem.SKILL]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	var t: Unit = targets[0] if targets.size() > 0 else null
	if t == null:
		return []
	var credit := user.runtime.stack_get("shield_credit")
	if credit <= 0:
		return []
	user.runtime.stack_set("shield_credit", 0)
	return [{"target": t, "report": SkillKit.deal_effect(user, t, game, battle, {"flat": roundi(float(credit) * SHIELD_RATIO), "damage_kind": DamageSystem.SKILL})}]
