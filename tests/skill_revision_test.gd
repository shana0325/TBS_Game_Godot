# 技能调整回归：验证秒冷却、持续伤害、免伤、固定战吼和机制悬停。
extends Node

# 数据库加载后执行战斗规则与界面文本检查。
func _ready() -> void:
	call_deferred("_run")

# 对本轮调整的关键行为做实际结算检查。
func _run() -> void:
	if not GameDatabase.get_skill("Power Strike").is_empty():
		_fail("强力打击仍在技能库")
		return
	var battle := BattleManager.new()
	if not GameDatabase.get_skill("Oath Barrier").is_empty():
		_fail("誓约圣盾仍在技能库")
		return
	battle.grid = Grid.new(12, 8)
	var source := _unit("Warrior", "player", Vector2i(1, 1))
	var ally := _unit("Tank", "player", Vector2i(2, 1))
	var enemy := _unit("Tank", "enemy", Vector2i(4, 1))
	battle.units = [source, ally, enemy]
	for unit in battle.units:
		unit.set_battle(battle)
	_give(source, "Thorns")
	var before_reflect := enemy.hp
	SkillTriggerSystem.dispatch(battle, "on_taken_damage", {"actor": source, "target": enemy})
	if enemy.hp != before_reflect:
		_fail("荆棘不应被一般伤害事件触发")
		return
	SkillTriggerSystem.dispatch(battle, "on_be_attacked", {"actor": source, "target": enemy})
	if before_reflect - enemy.hp != CombatFormula.apply_armor(float(roundi(source.get_defense())), enemy.get_defense()):
		_fail("荆棘没有按当前护甲造成伤害")
		return
	source.skills.clear()
	EffectSystem.apply_effects(source, enemy, GameDatabase.get_skill("Miasma Wave")["effects"], null, battle)
	var default_poison := _find_status(enemy, "poison")
	if default_poison == null or float(default_poison.stacks[0].get("source_attack_percent", 0.0)) != 0.05:
		_fail("瘴气波未采用统一中毒倍率")
		return
	enemy.remove_status("poison")
	_give(source, "Guardian Aura")
	_give(source, "Battle Standard")
	SkillTriggerSystem.dispatch(battle, "on_enter_battle", {"actor": source})
	var boosted_defense := ally.get_defense()
	var boosted_attack := ally.get_attack()
	if boosted_defense <= ally.get_base_stat("defense") or boosted_attack <= ally.get_base_stat("attack"):
		_fail("战吼没有施加百分比属性")
		return
	ally.pos = Vector2i(8, 1)
	source.alive = false
	if ally.get_defense() != boosted_defense or ally.get_attack() != boosted_attack:
		_fail("战吼效果不应因移动或施加者死亡消失")
		return
	source.alive = true
	EffectSystem.apply_effects(enemy, ally, [{"type": "cleanse"}], null, battle)
	if ally.get_defense() != boosted_defense:
		_fail("清除负面状态不应移除战吼增益")
		return
	EffectSystem.apply_effects(source, source, [{"type": "aura", "range": 2,
		"stats": {"attack": 5}}], null, battle)
	ally.pos = Vector2i(2, 1)
	if ally.get_attack() <= boosted_attack:
		_fail("原有动态光环机制未保留")
		return
	ally.pos = Vector2i(8, 1)
	if ally.get_attack() != boosted_attack:
		_fail("动态光环离开范围后没有失效")
		return
	source.skills.clear()
	_give(source, "Venom Edge")
	var venom_effect: Dictionary = source.skills[0].effects[0]
	for i in range(10):
		EffectSystem.apply_effects(source, enemy, [venom_effect], null, battle)
	var poison: Buff = _find_status(enemy, "poison")
	if poison == null or poison.stacks.size() != 10:
		_fail("中毒未按次数叠层")
		return
	var hp_before := enemy.hp
	poison.tick_seconds(enemy, 1.0, null, battle)
	if poison.stacks.size() != 9 or enemy.hp >= hp_before:
		_fail("中毒每秒结算或10%层数衰减异常")
		return
	var burn_effect: Dictionary = GameDatabase.get_skill("Ember Blade")["effects"][0]
	EffectSystem.apply_effects(source, enemy, [burn_effect], null, battle)
	var burn: Buff = _find_status(enemy, "burn")
	var burn_before := enemy.hp
	burn.tick_seconds(enemy, 1.0, null, battle)
	if burn_before - enemy.hp != float(maxi(1, roundi(burn_before * 0.05))):
		_fail("灼烧没有按当前生命的5%结算")
		return
	EffectSystem.apply_effects(source, enemy, [burn_effect], null, battle)
	if burn.tick_damage != 0:
		_fail("重复施加余烬之刃不应混入固定伤害")
		return
	source.skills.clear()
	_give(source, "Emergency Veil")
	source.hp = source.max_hp * 0.3
	SkillTriggerSystem.dispatch(battle, "on_taken_damage", {"actor": source})
	if not source.is_stealthed() or source.skills[0].cooldown_seconds_remaining < 24.9:
		_fail("烟幕撤离没有进入25秒冷却")
		return
	source.remove_status("stealth")
	SkillTriggerSystem.dispatch(battle, "on_taken_damage", {"actor": source})
	if source.is_stealthed():
		_fail("烟幕撤离冷却期间重复触发")
		return
	source.skills[0].tick_seconds_cooldown(25.0)
	SkillTriggerSystem.dispatch(battle, "on_taken_damage", {"actor": source})
	if not source.is_stealthed():
		_fail("烟幕撤离冷却结束后没有重新触发")
		return
	source.skills.clear()
	_give(source, "Last Ward")
	source.hp = source.max_hp * 0.2
	SkillTriggerSystem.dispatch(battle, "on_taken_damage", {"actor": source})
	var immune_hp := source.hp
	DamageSystem.apply(enemy, source, {"raw_damage": 20, "true_damage": true}, battle)
	if source.hp != immune_hp:
		_fail("免伤没有抵挡真实伤害")
		return
	source.skills.clear()
	source.pos = Vector2i(3, 1)
	_give(source, "Crippling Order")
	source.skills[0].interval_remaining = 0.0
	var silence_hp := enemy.hp
	SkillTriggerSystem.dispatch(battle, "on_timer", {"actor": source, "target": enemy,
		"skill_filter": source.skills[0]})
	if not enemy.has_status("silence") or enemy.hp >= silence_hp:
		_fail("禁言打击没有按主动技能造成伤害并沉默")
		return
	source.remove_status("damage_immunity")
	source.skills.clear()
	_give(source, "Revive")
	_give(source, "Final Benediction")
	source.alive = false
	source.hp = 0.0
	var shield_before := ally.get_total_shield()
	SkillTriggerSystem.dispatch(battle, "on_death", {"actor": source, "target": enemy})
	if not source.alive or ally.get_total_shield() <= shield_before:
		_fail("复苏与亡语没有在同次死亡中共同触发")
		return
	var description := MechanicDescription.new()
	get_tree().root.add_child(description)
	description.set_skill_description(GameDatabase.get_skill("Venom Edge"))
	if description.get_parsed_text().begins_with("中毒：") or not "[url=poison]" in description.text:
		_fail("中毒应在正文中提供关键字链接")
		return
	description.set_skill_description(GameDatabase.get_skill("Deathrattle Backup"))
	if not "[url=deathrattle]" in description.text or not "[url=summon]" in description.text:
		_fail("亡语和召唤应同时提供关键字链接")
		return
	description.set_skill_description(GameDatabase.get_skill("Dormant Resolve"))
	if description.get_parsed_text() != "休眠（8s）：本场战斗攻击提高30、护甲提高15。":
		_fail("休眠描述格式不正确")
		return
	description.set_skill_description(GameDatabase.get_skill("Guardian Aura"))
	if not "[url=battlecry]" in description.text:
		_fail("战吼描述没有使用机制链接")
		return
	description._on_meta_hover_started("battlecry")
	await get_tree().create_timer(1.1).timeout
	if not is_instance_valid(description._tooltip_panel) or not description._tooltip_panel.visible:
		_fail("机制悬停一秒后没有显示说明")
		return
	description._on_meta_hover_ended("battlecry")
	if description._tooltip_panel.visible:
		_fail("离开机制名称后说明没有隐藏")
		return
	description.queue_free()
	var encyclopedia: Control = load("res://scripts/screens/encyclopedia_screen.gd").new()
	encyclopedia.size = Vector2(1600, 900)
	get_tree().root.add_child(encyclopedia)
	encyclopedia._select_category("skills")
	await get_tree().process_frame
	var first_entry := encyclopedia.entry_list.get_child(0) as Button
	var linked_text := first_entry.find_children("*", "MechanicDescription", true, false)
	if linked_text.size() != 1 or (linked_text[0] as MechanicDescription).size.x <= 0.0:
		_fail("技能图鉴没有绘制可悬停的机制说明")
		return
	encyclopedia.queue_free()
	print("PASS: 技能调整的战吼、持续伤害、秒冷却、免伤与机制悬停")
	get_tree().quit(0)

# 创建不带初始固有技能的测试单位。
func _unit(unit_id: String, camp: String, pos: Vector2i) -> Unit:
	var config: Dictionary = GameDatabase.get_unit(unit_id).duplicate(true)
	config.erase("innate_skill")
	config.erase("innate_skills")
	return Unit.create_from_config(unit_id, camp, pos, config)

# 给测试单位配置技能实例。
func _give(unit: Unit, skill_id: String) -> void:
	var data: Dictionary = GameDatabase.get_skill(skill_id).duplicate(true)
	data["id"] = skill_id
	unit.add_skill(Skill.from_data(data))

# 查找单位指定状态。
func _find_status(unit: Unit, status_id: String) -> Buff:
	for buff in unit.buffs:
		if buff.status == status_id:
			return buff
	return null

# 以非零退出码报告失败。
func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
