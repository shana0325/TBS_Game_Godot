# 固有技能验证：用真实战斗管理器检查四名基础角色的战斗效果。
extends Node

# 执行所有验证并以进程退出码报告结果。
func _ready() -> void:
	GameSession.run_relics = []
	GameSession.run_relic_stacks = {}
	var passed := _test_warrior() and _test_tank() and _test_archer() and _test_assassin() \
		and _test_scaled_summon()
	print("基础角色固有技能：", "通过" if passed else "失败")
	get_tree().quit(0 if passed else 1)

# 构造不依赖当前编成和存档的测试战局。
func _battle(player_types: Array, enemies: Array) -> BattleManager:
	var deployed: Array = []
	for i in player_types.size():
		deployed.append({"type": player_types[i], "pos": Vector2i(1, i + 1), "roster_index": -1})
	var battle := BattleManager.new("innate_test", null, deployed,
		{"width": 14, "height": 10, "enemy_units": enemies})
	battle.setup()
	return battle

# 战士普攻追加技能伤害并按攻击前已损生命治疗。
func _test_warrior() -> bool:
	var battle := _battle(["Warrior"], [{"type": "Tank", "pos": [2, 1]}])
	var warrior: Unit = battle.units[0]
	var enemy: Unit = battle.units[1]
	warrior.hp = warrior.max_hp * 0.5
	warrior.battle_stat_mods["crit_rate"] = -warrior.get_crit_rate()
	var old_enemy_hp := enemy.hp
	var result := battle.perform_attack(warrior, enemy)
	var extra := old_enemy_hp - enemy.hp - float(result.get("actual_damage", 0))
	var ok := warrior.has_skill("Warrior Resolve") and warrior.hp == 770.0 and extra > 0
	if not ok:
		push_error("战士固有技能未正确结算：生命=%s，附加伤害=%s" % [warrior.hp, extra])
	return ok

# 坦克被普攻后为最低当前生命友军生成自身最大生命 5% 的护盾。
func _test_tank() -> bool:
	var battle := _battle(["Tank", "Archer"], [{"type": "Warrior", "pos": [2, 1]}])
	var tank: Unit = battle.units[0]
	var ally: Unit = battle.units[1]
	var attacker: Unit = battle.units[2]
	ally.hp = 300.0
	battle.perform_attack(attacker, tank)
	var expected := roundi(tank.max_hp * 0.05)
	var ok := ally.get_total_shield() == expected
	if not ok:
		push_error("坦克固有技能护盾不符：实际=%d，预期=%d" % [ally.get_total_shield(), expected])
	return ok

# 射手能在原射程外普攻，且每格距离增加 10% 的普攻伤害。
func _test_archer() -> bool:
	var battle := _battle(["Archer"], [{"type": "Tank", "pos": [6, 1]}])
	var archer: Unit = battle.units[0]
	var enemy: Unit = battle.units[1]
	var distance := Grid.manhattan_distance(archer.pos, enemy.pos)
	var bonus := battle.get_damage_bonus_percent(archer, enemy, DamageSystem.ATTACK)
	archer.battle_stat_mods["crit_rate"] = -archer.get_crit_rate()
	var base := DamageCalculator.calculate_damage(archer, enemy)
	var result := battle.perform_attack(archer, enemy)
	var ok := archer.get_range_max() == 12 and battle.can_attack(archer, enemy) \
		and is_equal_approx(bonus, float(distance) * 0.1) \
		and int(result.get("damage", 0)) > int(base.get("damage", 0))
	if not ok:
		push_error("射手固有技能异常：射程=%d，距离=%d，加成=%s" % [archer.get_range_max(), distance, bonus])
	return ok

# 刺客锁定目标死亡后切换到最低当前生命敌人并瞬移到相邻空格。
func _test_assassin() -> bool:
	var battle := _battle(["Assassin"], [
		{"type": "Warrior", "pos": [2, 1]},
		{"type": "Tank", "pos": [7, 5]},
		{"type": "Archer", "pos": [8, 5]},
	])
	var assassin: Unit = battle.units[0]
	var first: Unit = battle.units[1]
	var weakest: Unit = battle.units[2]
	var other: Unit = battle.units[3]
	first.hp = 1.0
	weakest.hp = 400.0
	other.hp = 600.0
	battle.perform_attack(assassin, first)
	var ok := not first.alive and assassin.get_current_target() == weakest \
		and Grid.manhattan_distance(assassin.pos, weakest.pos) == 1
	if not ok:
		push_error("刺客固有技能未正确追击：锁定=%s，位置=%s" % [assassin.get_current_target(), assassin.pos])
	return ok

# 召唤单位继承召唤者的楼层倍率，并经由效果系统的真实入口生成。
func _test_scaled_summon() -> bool:
	var multiplier := TowerGenerator.floor_stat_multiplier(20)
	var battle := _battle(["Warrior"], [{"type": "Tank", "pos": [5, 5],
		"stat_multiplier": multiplier}])
	var summoner: Unit = battle.units[1]
	EffectSystem._apply_summon(summoner, {"unit_type": "Archer"}, battle)
	if battle.units.size() != 3:
		push_error("召唤效果没有生成单位")
		return false
	var summoned: Unit = battle.units[2]
	var template: Dictionary = GameDatabase.get_unit("Archer")
	var ok := summoned.camp == summoner.camp \
		and is_equal_approx(summoned.stat_multiplier, multiplier) \
		and summoned.get_base_stat("hp") == roundi(float(template["hp"]) * multiplier) \
		and is_equal_approx(summoned.hp, summoned.max_hp)
	if not ok:
		push_error("召唤单位未继承楼层倍率：倍率=%s，生命=%s" % [summoned.stat_multiplier, summoned.max_hp])
	return ok
