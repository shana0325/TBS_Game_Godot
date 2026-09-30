# 通用技能批次测试：验证新技能注册、详情文本与关键战斗触发链。
extends Node

const NEW_SKILLS := [
	"Vanguard Challenge", "Venom Edge", "Ember Blade",
	"Winter Mark", "Crippling Order", "Emergency Veil", "Last Ward",
	"Guardian Aura", "Battle Standard", "Dormant Resolve", "Vengeful Heart",
	"Deathrattle Backup", "Timed Bulwark", "Purifying Rhythm", "War Cry Guard",
]


# 自动加载数据库就绪后执行断言。
func _ready() -> void:
	call_deferred("_run")


# 覆盖检索池、状态效果、光环、复仇、亡语和主动技能。
func _run() -> void:
	var pool: Array = GameDatabase.get_searchable_skill_ids(true)
	for skill_id in NEW_SKILLS:
		var data: Dictionary = GameDatabase.get_skill(skill_id)
		if data.is_empty() or not pool.has(skill_id):
			_fail("技能未进入通用检索池：%s" % skill_id)
			return
		var detail: String = SkillDetailFormatter.build(skill_id)
		if "类型：poison" in detail or "类型：aura" in detail or "类型：summon" in detail:
			_fail("技能详情未正确翻译：%s" % skill_id)
			return
		if skill_id in ["Venom Edge", "Ember Blade"] and "特效伤害" not in detail:
			_fail("持续伤害的类别未展示：%s" % skill_id)
			return

	var battle := BattleManager.new()
	battle.grid = Grid.new(10, 8)
	var hero := _unit("Warrior", "player", Vector2i(2, 2))
	var ally := _unit("Tank", "player", Vector2i(3, 2))
	var enemy := _unit("Warrior", "enemy", Vector2i(5, 2))
	battle.units = [hero, ally, enemy]
	for unit in battle.units:
		unit.set_battle(battle)

	_give(hero, "Vanguard Challenge")
	_give(hero, "Guardian Aura")
	SkillTriggerSystem.dispatch(battle, "on_enter_battle", {"actor": hero})
	if not hero.has_taunt() or ally.get_defense() <= ally.get_base_stat("defense"):
		_fail("入场嘲讽或战吼未生效")
		return
	hero.skills.clear()
	_give(hero, "Venom Edge")
	_give(hero, "Ember Blade")
	_give(hero, "Winter Mark")
	SkillTriggerSystem.dispatch(battle, "on_attack", {"actor": hero, "target": enemy})
	if not enemy.has_status("poison") or not enemy.has_status("burn") or not enemy.has_status("frost"):
		_fail("普攻附加状态未生效")
		return

	hero.skills.clear()
	_give(hero, "Dormant Resolve")
	SkillTriggerSystem.dispatch(battle, "on_enter_battle", {"actor": hero})
	if not hero.is_dormant():
		_fail("休眠未生效")
		return
	hero.skills.clear()
	battle.awaken_unit(hero)
	if hero.is_dormant() or hero.get_attack() < hero.get_base_stat("attack") + 30:
		_fail("休眠苏醒增益未生效")
		return

	hero.skills.clear()
	_give(hero, "Vengeful Heart")
	SkillTriggerSystem.dispatch(battle, "on_avenge", {"actor": hero})
	if hero.get_attack() != hero.get_base_stat("attack") + 30:
		_fail("复仇未按两名友军计数")
		return
	SkillTriggerSystem.dispatch(battle, "on_avenge", {"actor": hero})
	if hero.get_attack() != hero.get_base_stat("attack") + 45:
		_fail("复仇满两次未加成")
		return

	hero.skills.clear()
	_give(hero, "Timed Bulwark")
	hero.skills[0].interval_remaining = 0.0
	SkillTriggerSystem.dispatch(battle, "on_timer", {"actor": hero, "skill_filter": hero.skills[0]})
	if hero.get_total_shield() <= 0:
		_fail("定时护盾未生效")
		return

	ally.skills.clear()
	EffectSystem.apply_effects(ally, ally, [{"type": "divine_shield", "duration_seconds": 12.0}], null, battle)
	if not ally.has_status("divine_shield"):
		_fail("入场圣盾未生效")
		return
	ally.remove_status("divine_shield")
	ally.skills.clear()
	_give(ally, "Emergency Veil")
	ally.hp = ally.max_hp * 0.35
	SkillTriggerSystem.dispatch(battle, "on_taken_damage", {"actor": ally})
	if not ally.is_stealthed() or battle.can_target_enemy(enemy, ally):
		_fail("低生命潜行或目标排除未生效")
		return
	ally.remove_status("stealth")
	ally.skills.clear()
	_give(ally, "Last Ward")
	ally.hp = ally.max_hp * 0.25
	SkillTriggerSystem.dispatch(battle, "on_taken_damage", {"actor": ally})
	if not ally.has_status("damage_immunity"):
		_fail("低生命免伤未生效")
		return

	hero.skills.clear()
	_give(hero, "War Cry Guard")
	var ally_shield := ally.get_total_shield()
	SkillTriggerSystem.dispatch(battle, "on_enter_battle", {"actor": hero})
	if ally.get_total_shield() <= ally_shield:
		_fail("战吼未给友军添加护盾")
		return

	hero.skills.clear()
	_give(hero, "Purifying Rhythm")
	EffectSystem.apply_effects(enemy, hero, [{"type": "burn", "damage": 5}], null, battle)
	hero.hp -= 30
	var before_heal := hero.hp
	hero.skills[0].interval_remaining = 0.0
	SkillTriggerSystem.dispatch(battle, "on_timer", {"actor": hero, "skill_filter": hero.skills[0]})
	if hero.has_status("burn") or hero.hp <= before_heal:
		_fail("净化律动未完成净化和治疗")
		return

	hero.skills.clear()
	_give(hero, "Deathrattle Backup")
	hero.alive = false
	var before_count := battle.units.size()
	SkillTriggerSystem.dispatch(battle, "on_death", {"actor": hero})
	if battle.units.size() != before_count + 1 or not (battle.units.back() as Unit).is_summoned:
		_fail("亡语召唤未生效")
		return

	print("PASS: 16 个通用技能注册、详情与关键战斗机制")
	get_tree().quit(0)


# 创建不带固有技能的隔离单位。
func _unit(unit_type: String, camp: String, pos: Vector2i) -> Unit:
	var config: Dictionary = GameDatabase.get_unit(unit_type).duplicate(true)
	config.erase("innate_skill")
	config.erase("innate_skills")
	return Unit.create_from_config(unit_type, camp, pos, config)


# 给测试单位挂载指定技能。
func _give(unit: Unit, skill_id: String) -> void:
	var data: Dictionary = GameDatabase.get_skill(skill_id).duplicate(true)
	data["id"] = skill_id
	unit.add_skill(Skill.from_data(data))


# 报告失败并退出。
func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
