# Boss 共享固有技能：每隔 20 秒召唤一名继承本层属性倍率的随机普通敌军。
extends CodeSkill

# 声明定时技能元数据，三个 Boss 共用此脚本。
func _init() -> void:
	name = "战场征召"
	desc = "每 20 秒在身旁召唤一名随机敌军。召唤物获得当前楼层的属性增益；附近无空位时本次召唤失败。"
	trigger = SkillTriggerSystem.ON_TIMER
	interval_seconds = 20.0
	condition = {"target_type": "self"}
	common = false
	searchable = false
	tags = ["固有", "召唤"]

# 从普通敌军池随机挑选单位，并通过统一召唤入口继承 Boss 的层数倍率。
func execute(user: Unit, _targets: Array, game = null, battle = null) -> Array:
	if battle == null:
		return []
	var pool: Array = GameDatabase.get_random_pool_unit_ids()
	if pool.is_empty():
		return []
	var unit_type := str(pool.pick_random())
	var summoned: Unit = battle.spawn_unit(unit_type, user.camp, user.pos, user)
	if summoned != null and game != null and game.has_method("add_log"):
		game.add_log("%s 征召了 %s" % [user.get_display_name(), summoned.get_display_name()])
	return []
