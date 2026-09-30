# 通用技能：回气指环 — 造成技能伤害后缩短一个主动技能的等待时间。
extends CodeSkill


func _init() -> void:
	name = "回气指环"
	desc = "造成技能伤害后，若有主动技能正在等待自动施放，使剩余时间最长者缩短 0.3 秒（每秒至多一次）；基础施放间隔小于 1 秒的技能无法触发。"
	trigger = "on_hit"
	condition = {"target_type": "self"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "冷却", "加速"]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	if battle == null:
		return []
	var hit: Dictionary = battle.get_active_hit()
	if str(hit.get("damage_kind", "")) != DamageSystem.SKILL:
		return []
	var rt := user.runtime
	if rt.throttle_use("calm_branch", SkillKit.now_of(battle), 1.0):
		SkillKit.shorten_timed(user, 0.3)
	return []
