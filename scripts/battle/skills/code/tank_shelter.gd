# 坦克固有技能：每次受到普攻后，为仍有护盾容量且当前生命最低的友方单位施加护盾。
extends CodeSkill

# 声明供战斗触发系统和技能详情使用的元数据。
func _init() -> void:
	name = "守护本能"
	desc = "受到普攻时，为当前生命值最低且护盾未满的我方单位添加自身最大生命值 5% 的护盾；护盾遵守目标的护盾上限。"
	trigger = SkillTriggerSystem.ON_BE_ATTACKED
	condition = {"target_type": "self"}
	common = false
	searchable = false
	tags = ["固有", "防御", "护盾"]

# 在受击后通过共用规则选取仍有护盾容量的最低生命友军，坦克自己也可成为目标。
func execute(user: Unit, _targets: Array, _game = null, battle = null) -> Array:
	if battle == null:
		return []
	var weakest := SkillKit.lowest_hp_shield_ally(battle, user)
	if weakest != null:
		weakest.gain_shield(roundi(user.max_hp * 0.05), name)
	return []
