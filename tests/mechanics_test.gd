# 战斗机制验证：用真实战斗管理器检查状态计时、目标规则及伤害结算。
extends Node

# 运行关键机制回归，并用退出码报告结果。
func _ready() -> void:
	GameSession.run_relics = []
	GameSession.run_relic_stacks = {}
	var checks := [_test_status_damage(), _test_dormant(), _test_targeting(),
		_test_aura_and_frost(), _test_avenge(), _test_encyclopedia()]
	var passed := not checks.has(false)
	print("机制验证：", "通过" if passed else "失败")
	get_tree().quit(0 if passed else 1)

# 构造独立的双方战局，避免依赖存档编成。
func _battle() -> BattleManager:
	var battle := BattleManager.new("mechanics_test", null,
		[{"type": "Warrior", "pos": Vector2i(1, 1), "roster_index": -1},
		 {"type": "Tank", "pos": Vector2i(1, 2), "roster_index": -1}],
		{"width": 12, "height": 8, "enemy_units": [
			{"type": "Archer", "pos": [3, 1]}, {"type": "Assassin", "pos": [4, 2]}]})
	battle.setup()
	return battle

# 持续伤害耗掉圣盾，中毒逐秒衰减，灼烧到期后消失。
func _test_status_damage() -> bool:
	var battle := _battle()
	var source: Unit = battle.units[0]
	var target: Unit = battle.units[2]
	EffectSystem.apply_effects(source, target, [{"type": "divine_shield", "duration_seconds": 5.0},
		{"type": "poison", "damage": 7}, {"type": "poison", "damage": 7}], null, battle)
	var first_hp := target.hp
	battle._tick_statuses(1.0)
	var shield_consumed := not target.has_status("divine_shield") and is_equal_approx(target.hp, first_hp)
	battle._tick_statuses(1.0)
	var poison_expired := not target.has_status("poison") and target.hp < first_hp
	EffectSystem.apply_effects(source, target, [{"type": "burn", "damage": 4, "duration_seconds": 2.0}], null, battle)
	battle._tick_statuses(2.1)
	var ok := shield_consumed and poison_expired and not target.has_status("burn")
	EffectSystem.apply_effects(source, target, [{"type": "buff", "buff": "poison"}], null, battle)
	ok = ok and target.has_status("poison")
	if not ok:
		push_error("圣盾或持续伤害按秒结算异常：圣盾=%s 中毒=%s 灼烧=%s 生命=%s 初始=%s" % [shield_consumed, poison_expired, target.has_status("burn"), target.hp, first_hp])
	return ok

# 休眠者仍可触发受击型防御技能；低血量强制苏醒且效果仅执行一次。
func _test_dormant() -> bool:
	var battle := _battle()
	var tank: Unit = battle.units[1]
	var ally: Unit = battle.units[0]
	var enemy: Unit = battle.units[2]
	ally.hp = ally.max_hp * 0.2
	EffectSystem.apply_effects(tank, tank, [{"type": "dormant", "duration_seconds": 20.0,
		"awaken_effects": [{"type": "double_stats", "stats": ["hp", "attack", "defense"]}]}], null, battle)
	var old_max := tank.max_hp
	var old_hp := tank.hp
	battle.perform_attack(enemy, tank)
	var defensive_proc := ally.get_total_shield() > 0
	tank.hp = tank.max_hp * 0.31
	DamageSystem.apply(enemy, tank, {"raw_damage": maxi(1, roundi(tank.max_hp * 0.03)),
		"true_damage": true}, battle)
	var woken := not tank.is_dormant() and is_equal_approx(tank.max_hp, old_max * 2.0)
	battle.tick(21.0)
	var ok := defensive_proc and woken and is_equal_approx(tank.max_hp, old_max * 2.0) and old_hp > 0
	if not ok:
		push_error("休眠受击被动或提前苏醒异常")
	return ok

# 潜行在存在可见队友时不可被单选，全队潜行则失效；嘲讽不改技能目标。
func _test_targeting() -> bool:
	var battle := _battle()
	var attacker: Unit = battle.units[0]
	var stealth: Unit = battle.units[2]
	var other: Unit = battle.units[3]
	EffectSystem.apply_effects(stealth, stealth, [{"type": "stealth", "duration_seconds": 5.0}], null, battle)
	var hidden := not battle.can_target_enemy(attacker, stealth)
	EffectSystem.apply_effects(other, other, [{"type": "stealth", "duration_seconds": 5.0}], null, battle)
	var all_hidden := battle.can_target_enemy(attacker, stealth)
	other.remove_status("stealth")
	EffectSystem.apply_effects(other, other, [{"type": "taunt", "duration_seconds": 5.0}], null, battle)
	var skill := Skill.from_data({"condition": {"target_type": "target"}})
	var skill_ignores_taunt := skill.resolve_targets(battle, attacker, {"target": stealth}).is_empty()
	stealth.remove_status("stealth")
	skill_ignores_taunt = skill_ignores_taunt and skill.resolve_targets(battle, attacker,
		{"target": stealth}).has(stealth)
	var taunt_movement: Dictionary = EnemyAI.get_decision(battle, attacker)
	var ok := hidden and all_hidden and skill_ignores_taunt \
		and str(taunt_movement.get("action", "")) == "move"
	if not ok:
		push_error("潜行或嘲讽的选目标规则异常")
	return ok

# 光环随位置与沉默即时变化，霜冻叠满转冻结。
func _test_aura_and_frost() -> bool:
	var battle := _battle()
	var source: Unit = battle.units[0]
	var ally: Unit = battle.units[1]
	var base_attack := ally.get_attack()
	EffectSystem.apply_effects(source, source, [{"type": "aura", "range": 2,
		"stats": {"attack": 7}}], null, battle)
	var boosted := ally.get_attack() >= base_attack + 7
	EffectSystem.apply_effects(ally, source, [{"type": "silence", "duration_seconds": 2.0}], null, battle)
	var suppressed := ally.get_attack() == base_attack
	source.remove_status("silence")
	for i in 3:
		EffectSystem.apply_effects(ally, source, [{"type": "frost"}], null, battle)
	var frozen := source.has_status("frozen") and source.get_frost_stacks() == 0
	EffectSystem.apply_effects(ally, source, [{"type": "cleanse"}], null, battle)
	var ok := boosted and suppressed and frozen and not source.has_status("frozen")
	if not ok:
		push_error("光环、霜冻或净化异常")
	return ok

# 复仇仅统计非召唤友军死亡，并在达到门槛后清零。
func _test_avenge() -> bool:
	var battle := _battle()
	var avenger: Unit = battle.units[0]
	var skill := Skill.from_data({"name": "复仇测试", "trigger": "on_avenge", "avenge_count": 2,
		"condition": {"target_type": "self"}, "effects": [{"type": "heal", "amount": 10}]})
	avenger.skills.append(skill)
	var summoned: Unit = battle.units[1]
	summoned.is_summoned = true
	battle.on_damage_resolved(null, summoned, {"actual_damage": 1, "result": {"lethal": true}})
	var ignored := skill.avenge_progress == 0
	summoned.is_summoned = false
	battle.on_damage_resolved(null, summoned, {"actual_damage": 1, "result": {"lethal": true}})
	var counted := skill.avenge_progress == 1
	battle.on_damage_resolved(null, summoned, {"actual_damage": 1, "result": {"lethal": true}})
	var ok := ignored and counted and skill.avenge_progress == 0
	if not ok:
		push_error("召唤物死亡或复仇计数异常")
	return ok

# 图鉴包含本次约定的全部机制，并能读取完整中文说明。
func _test_encyclopedia() -> bool:
	var page = load("res://scripts/screens/encyclopedia_screen.gd").new()
	var entries: Dictionary = page._load_mechanics()
	page.free()
	var ok := entries.size() == 15 and entries.has("dormant") and entries.has("avenge") \
		and str(entries.get("dormant", {}).get("desc", "")).contains("防御型被动")
	if not ok:
		push_error("机制图鉴条目缺失或说明未加载")
	return ok
