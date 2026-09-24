# 通用技能：疾风电涌 — 每次普攻击中叠1层（至多5），满层后下一次普攻追加50%攻击力真实技能伤害并清层。
extends CodeSkill


func _init() -> void:
	name = "疾风电涌"
	desc = "每次普攻击中叠 1 层（至多 5 层）；满层后的下一次普攻追加 50% 攻击力的真实技能伤害并清层。"
	trigger = "on_attack"
	condition = {"target_type": "target"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "攻击", "连击"]
	damage_kinds = [DamageSystem.SKILL]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	var t: Unit = targets[0] if targets.size() > 0 else null
	if t == null:
		return []
	var rt := user.runtime
	if bool(rt.notes.get("frenzy_charged", false)):
		rt.notes["frenzy_charged"] = false
		rt.stack_set("frenzy", 0)
		return [{"target": t, "report": SkillKit.deal_effect(user, t, game, battle, {"atk": 0.5, "true": true, "damage_kind": DamageSystem.SKILL})}]
	if rt.stacked_add("frenzy", 1, 5) >= 5:
		rt.notes["frenzy_charged"] = true
	return []
