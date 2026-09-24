# 射手固有技能：常驻增加普攻射程，并按与目标的格距提高普攻伤害。
extends CodeSkill

# 声明供战斗触发系统和技能详情使用的元数据。
func _init() -> void:
	name = "远程压制"
	desc = "普攻射程 +10；普攻伤害按与目标的曼哈顿距离每格提高 10%。"
	trigger = SkillTriggerSystem.PASSIVE
	condition = {"target_type": "self"}
	common = false
	searchable = false
	tags = ["固有", "攻击", "远程"]

# 射程加成由 Unit.get_range_max 在攻击判定前读取。
func get_attack_range_bonus() -> int:
	return 10

# 距离增伤由统一伤害结算入口在普攻时读取。
func get_damage_bonus_percent(source: Unit, target: Unit, kind: String) -> float:
	if kind != DamageSystem.ATTACK or source == null or target == null:
		return 0.0
	return float(Grid.manhattan_distance(source.pos, target.pos)) * 0.10

# 常驻能力通过上述查询钩子生效，不产生额外结算事件。
func execute(_user: Unit, _targets: Array, _game = null, _battle = null) -> Array:
	return []
