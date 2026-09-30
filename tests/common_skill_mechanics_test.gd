# 第二批通用技能测试：核对检索、目标选择、驱散、群体状态和召唤。
extends Node

const IDS := ["Runebreak Strike", "Triage Aegis", "Last Smoke", "Final Benediction",
	"Miasma Wave", "Winter Pulse", "Purity Oath", "Shadow Contract",
	"Venom Lock", "Counterspell Shell"]

# 等自动加载数据准备完成后再执行测试。
func _ready() -> void:
	call_deferred("_run")

# 每个关键机制都通过实际技能分发验证。
func _run() -> void:
	var pool: Array = GameDatabase.get_searchable_skill_ids(true)
	for skill_id in IDS:
		if not pool.has(skill_id) or GameDatabase.get_skill(skill_id).is_empty():
			_fail("新通用技能未进入检索池：%s" % skill_id)
			return
		if "类型：dispel" in SkillDetailFormatter.build(skill_id):
			_fail("技能详情没有翻译驱散效果：%s" % skill_id)
			return
	var battle := BattleManager.new()
	battle.grid = Grid.new(10, 8)
	var hero := _unit("Warrior", "player", Vector2i(1, 2))
	var low_ally := _unit("Tank", "player", Vector2i(2, 2))
	var other_ally := _unit("Archer", "player", Vector2i(2, 3))
	var enemy := _unit("Warrior", "enemy", Vector2i(5, 2))
	var other_enemy := _unit("Tank", "enemy", Vector2i(5, 3))
	battle.units = [hero, low_ally, other_ally, enemy, other_enemy]
	for unit in battle.units:
		unit.set_battle(battle)
	_give(hero, "Runebreak Strike")
	hero.attack_count = 4
	enemy.add_buff(Buff.from_data({"name": "增益测试", "duration_seconds": 5.0,
		"is_beneficial": true}))
	SkillTriggerSystem.dispatch(battle, "on_attack", {"actor": hero, "target": enemy})
	if Skill.unit_has_buff(enemy, "增益测试"):
		_fail("破法重击没有驱散增益")
		return
	hero.skills.clear()
	_give(hero, "Triage Aegis")
	low_ally.hp = low_ally.max_hp * 0.2
	low_ally.gain_shield(int(low_ally.get_shield_cap()), "护盾已满", -1, true)
	other_ally.hp = other_ally.max_hp * 0.5
	EffectSystem.apply_effects(enemy, other_ally, [{"type": "burn", "damage": 5}], null, battle)
	hero.skills[0].interval_remaining = 0.0
	SkillTriggerSystem.dispatch(battle, "on_timer", {"actor": hero, "skill_filter": hero.skills[0]})
	if other_ally.get_total_shield() <= 0 or other_ally.has_status("burn"):
		_fail("急救结界没有跳过护盾已满的队友并净化后续目标")
		return
	hero.skills.clear()
	_give(hero, "Miasma Wave")
	hero.skills[0].interval_remaining = 0.0
	SkillTriggerSystem.dispatch(battle, "on_timer", {"actor": hero, "skill_filter": hero.skills[0]})
	if not enemy.has_status("poison") or not other_enemy.has_status("poison"):
		_fail("瘴气波未作用于所有敌人")
		return
	hero.skills.clear()
	_give(hero, "Winter Pulse")
	hero.skills[0].interval_remaining = 0.0
	SkillTriggerSystem.dispatch(battle, "on_timer", {"actor": hero, "skill_filter": hero.skills[0]})
	if not enemy.has_status("frost") or not other_enemy.has_status("frost"):
		_fail("寒潮脉冲未作用于所有敌人")
		return
	hero.skills.clear()
	_give(hero, "Shadow Contract")
	hero.skills[0].interval_remaining = 0.0
	var before := battle.units.size()
	SkillTriggerSystem.dispatch(battle, "on_timer", {"actor": hero, "skill_filter": hero.skills[0]})
	if battle.units.size() != before + 1 or not (battle.units.back() as Unit).is_summoned:
		_fail("影卫契约没有召唤临时单位")
		return
	hero.skills.clear()
	_give(hero, "Purity Oath")
	SkillTriggerSystem.dispatch(battle, "on_enter_battle", {"actor": hero})
	EffectSystem.apply_effects(enemy, other_ally, [{"type": "poison", "damage": 5}], null, battle)
	if other_ally.has_status("poison"):
		_fail("清净誓约没有阻止中毒")
		return
	hero.skills.clear()
	_give(hero, "Venom Lock")
	SkillTriggerSystem.dispatch(battle, "on_attack", {"actor": hero, "target": enemy})
	if not enemy.has_status("silence") or hero.skills[0].cooldown_remaining != 4:
		_fail("毒蚀禁言的中毒联动或普攻冷却错误")
		return
	hero.skills.clear()
	_give(hero, "Last Smoke")
	SkillTriggerSystem.dispatch(battle, "on_ally_death", {"actor": hero, "target": low_ally})
	if not hero.is_stealthed():
		_fail("断后烟幕未在友军阵亡时生效")
		return
	hero.skills.clear()
	_give(hero, "Counterspell Shell")
	enemy.add_buff(Buff.from_data({"name": "反制增益", "duration_seconds": 5.0,
		"is_beneficial": true}))
	SkillTriggerSystem.dispatch(battle, "on_be_attacked", {"actor": hero, "target": enemy})
	if Skill.unit_has_buff(enemy, "反制增益") or not enemy.has_status("frost"):
		_fail("破咒反震没有驱散并霜冻攻击者")
		return
	hero.skills.clear()
	_give(hero, "Final Benediction")
	EffectSystem.apply_effects(enemy, other_ally, [{"type": "burn", "damage": 5}], null, battle)
	var shield_before := other_ally.get_total_shield()
	hero.alive = false
	SkillTriggerSystem.dispatch(battle, "on_death", {"actor": hero, "target": enemy})
	if other_ally.has_status("burn") or other_ally.get_total_shield() <= shield_before:
		_fail("遗愿祈福没有净化并保护其他友军")
		return
	print("PASS: 10 个新通用技能注册，驱散、智能护盾、群体状态和召唤生效")
	get_tree().quit(0)

# 创建不带固有技能的测试单位。
func _unit(unit_type: String, camp: String, pos: Vector2i) -> Unit:
	var config: Dictionary = GameDatabase.get_unit(unit_type).duplicate(true)
	config.erase("innate_skill")
	config.erase("innate_skills")
	return Unit.create_from_config(unit_type, camp, pos, config)

# 给单位添加一个指定通用技能。
func _give(unit: Unit, skill_id: String) -> void:
	var data: Dictionary = GameDatabase.get_skill(skill_id).duplicate(true)
	data["id"] = skill_id
	unit.add_skill(Skill.from_data(data))

# 报告失败原因并停止测试。
func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
