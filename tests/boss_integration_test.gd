# Boss 集成验证：检查事件追加、Mod 技能与贴图加载，以及召唤物继承楼层倍率。
extends Node

const BOSS_BY_FLOOR := {10: "IronWarden", 20: "RiftHunter", 30: "AbyssArbiter"}
const INNATE_BY_BOSS := {
	"IronWarden": "Iron Ward",
	"RiftHunter": "Rift Volley",
	"AbyssArbiter": "Abyss Edict",
}

# 逐层创建真实事件和战斗状态，验证 Boss 不进入随机池且共用召唤技能。
func _ready() -> void:
	var ok := true
	var pool: Array = GameDatabase.get_random_pool_unit_ids()
	for floor in BOSS_BY_FLOOR:
		var boss_id: String = BOSS_BY_FLOOR[floor]
		ok = _expect(not pool.has(boss_id), "%s 意外进入随机池" % boss_id) and ok
		ok = _expect(TowerEventFactory.kinds_for_floor(floor) == ["shop", "boss"],
			"第 %d 层事件顺序错误" % floor) and ok
		var scenario := TowerGenerator.generate_scenario(floor)
		var ordinary_count: int = scenario["enemy_units"].size()
		var event := TowerEventFactory.create_event("boss", floor)
		ok = _expect(event != null and not event.can_continue(), "Boss 事件可以跳过") and ok
		if event == null:
			continue
		ok = _expect(event.choose("challenge"), "Boss 事件无法确认") and ok
		scenario = event.apply_to_scenario(scenario)
		ok = _expect(scenario["enemy_units"].size() == ordinary_count + 1,
			"Boss 未追加到原有敌军") and ok
		scenario = event.apply_to_scenario(scenario)
		ok = _expect(scenario["enemy_units"].size() == ordinary_count + 1,
			"Boss 被重复追加") and ok
		var manager := BattleManager.new("", null, [], scenario)
		manager.setup()
		var boss: Unit = null
		for unit in manager.units:
			if unit is Unit and unit.unit_type == boss_id:
				boss = unit
				break
		ok = _expect(boss != null, "%s 未生成战斗单位" % boss_id) and ok
		if boss == null:
			continue
		ok = _expect(is_equal_approx(boss.stat_multiplier, TowerGenerator.floor_stat_multiplier(floor)),
			"%s 未获得楼层倍率" % boss_id) and ok
		ok = _expect(boss.has_skill(INNATE_BY_BOSS[boss_id]) and boss.has_skill("Battlefield Summons"),
			"%s 固有技能缺失" % boss_id) and ok
		ok = _expect(ArtManager.get_unit_sprite(boss_id) != null,
			"%s 战斗小人贴图缺失" % boss_id) and ok
		manager.setup_battle()
		var before_count := manager.units.size()
		var summon_skill: Skill = null
		for skill in boss.skills:
			if skill is Skill and skill.skill_id == "Battlefield Summons":
				summon_skill = skill
				break
		if summon_skill != null:
			summon_skill.tick_interval(20.0)
			SkillTriggerSystem.dispatch(manager, SkillTriggerSystem.ON_TIMER,
				{"actor": boss, "user": boss, "skill_filter": summon_skill})
		ok = _expect(manager.units.size() == before_count + 1,
			"%s 的战场征召未生成单位" % boss_id) and ok
		if manager.units.size() > before_count:
			var summon: Unit = manager.units.back()
			ok = _expect(pool.has(summon.unit_type) and summon.camp == boss.camp
				and is_equal_approx(summon.stat_multiplier, boss.stat_multiplier),
				"%s 的召唤物类型、阵营或楼层倍率错误" % boss_id) and ok
	print("Boss 集成验证：", "通过" if ok else "失败")
	get_tree().quit(0 if ok else 1)

# 输出具体失败位置，方便定位事件、技能或资源接线问题。
func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
	return condition
