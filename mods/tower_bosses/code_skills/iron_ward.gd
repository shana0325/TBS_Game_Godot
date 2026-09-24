# 黑铁监军固有技能：周期性为自己及当前生命最低的友军分别施加护盾。
extends CodeSkill

# 声明黑铁监军的定时护盾技能。
func _init() -> void:
	name = "军阵庇护"
	desc = "每 8 秒为自己及当前生命值最低的另一名友军各施加自身最大生命值 8% 的护盾；没有其他友军时只保护自己。"
	trigger = SkillTriggerSystem.ON_TIMER
	interval_seconds = 8.0
	condition = {"target_type": "self"}
	common = false
	searchable = false
	tags = ["固有", "防御", "护盾"]

# 分别生成两份护盾，遵守各自目标的护盾上限。
func execute(user: Unit, _targets: Array, _game = null, battle = null) -> Array:
	if battle == null:
		return []
	var amount := roundi(user.max_hp * 0.08)
	user.gain_shield(amount, name)
	var weakest: Unit = null
	for ally in battle.units:
		if not (ally is Unit) or not ally.alive or ally == user or ally.camp != user.camp:
			continue
		if weakest == null or ally.hp < weakest.hp:
			weakest = ally
	if weakest != null:
		weakest.gain_shield(amount, name)
	return []
