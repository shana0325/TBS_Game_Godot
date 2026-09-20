# 通用技能：破军追击 — 连续3次普攻击中同一敌人后，对该目标后续普攻伤害+50%；更换目标重新计数。
extends CodeSkill


func _init() -> void:
	name = "破军追击"
	desc = "连续 3 次普攻击中同一敌人后，后续对该目标的普攻伤害 +50%；更换目标则重新计数。"
	trigger = "on_attack"
	condition = {"target_type": "target"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "攻击"]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	var t: Unit = targets[0] if targets.size() > 0 else null
	if t == null:
		return []
	var rt := user.runtime
	var tid := t.get_instance_id()
	if tid == int(rt.notes.get("triple_target", -1)):
		rt.bump("triple_count")
	else:
		rt.notes["triple_target"] = tid
		rt.stack_set("triple_count", 1)
	return []