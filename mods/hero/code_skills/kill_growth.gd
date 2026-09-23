# Hero 固有技能“以战养战”：击杀后永久提高生命上限并同步当前生命。
extends CodeSkill

# 设置技能触发、目标和展示信息；击杀后的具体效果在 execute 中执行。
func _init() -> void:
	name = "以战养战"
	desc = "每击杀一名敌人，生命值上限永久 +1（当前生命同步 +1）"
	trigger = "on_kill"
	condition = {"target_type": "self"}
	common = false
	searchable = false
	tags = ["固有", "成长"]

# 经代码技能入口调用统一效果系统，沿用原有成长和存档规则。
func execute(user: Unit, _targets: Array, game = null, battle = null) -> Array:
	if user == null or not user.alive:
		return []
	EffectSystem.apply_effects(user, user, [
		{"type": "permanent_stat", "stat": "hp", "amount": 1, "persist": true}
	], game, battle)
	return []
