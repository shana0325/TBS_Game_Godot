# 战斗计时测试：验证移动与普攻独立、攻速换算和第六次普攻触发技能。
extends Node


# 数据库加载完成后运行战斗断言。
func _ready() -> void:
	call_deferred("_run")


# 在固定距离的两名单位之间检查移动、普攻和技能计数。
func _run() -> void:
	var scenario := {"width": 8, "height": 5,
		"enemy_units": [{"type": "Warrior", "pos": [4, 2]}]}
	var battle := BattleManager.new("timing", null,
		[{"type": "Warrior", "pos": Vector2i(2, 2), "roster_index": -1}], scenario)
	battle.setup()
	battle.setup_battle()
	var attacker: Unit = battle.units[0]
	var defender: Unit = battle.units[1]
	attacker.attack_timer = 0.0
	attacker.move_timer = 0.0
	defender.attack_interval = INF
	defender.move_interval = INF
	defender.attack_timer = 0.0
	defender.move_timer = 0.0
	var skill_data: Dictionary = GameDatabase.get_skill("Crippling Order").duplicate(true)
	skill_data["id"] = "Crippling Order"
	attacker.add_skill(Skill.from_data(skill_data))
	var count_buff := Buff.from_data({"name": "普攻计数状态", "duration": 2,
		"modifiers": {"defense": 1}})
	attacker.add_buff(count_buff)
	var regen := Buff.from_data({"name": "再生测试", "duration": 2,
		"tick_heal": 5, "tick_phase": "turn_start"})
	var regen_target := Unit.new()
	regen_target.max_hp = 100.0
	regen_target.hp = 50.0
	regen_target.alive = true
	regen.tick_seconds(regen_target, 0.5)
	if not is_equal_approx(regen_target.hp, 50.0):
		_fail("按秒回复在一秒前提前触发")
		return
	regen.tick_seconds(regen_target, 0.5)
	if not is_equal_approx(regen_target.hp, 55.0):
		_fail("原每回合回复没有改为每秒触发")
		return
	if not is_equal_approx(attacker.get_effective_attack_interval(), 2.0):
		_fail("初始攻击间隔并非 2 秒")
		return
	battle.tick(1.0)
	if attacker.pos != Vector2i(3, 2) or attacker.attack_count != 0 or not is_equal_approx(count_buff.seconds_left, 1.0):
		_fail("首次移动提前触发普攻，或状态未按秒推进")
		return
	battle.tick(1.0)
	if attacker.attack_count != 1 or defender.has_status("silence") or attacker.buffs.has(count_buff):
		_fail("第二秒未正常普攻，或沉默提前触发")
		return
	attacker.add_battle_stat("attack_speed", 50.0)
	if not is_equal_approx(attacker.get_effective_attack_interval(), 2.0 / 1.5):
		_fail("攻速 +50% 未正确缩短攻击间隔")
		return
	battle.tick(1.0)
	if attacker.attack_count != 1:
		_fail("攻速变化后提前普攻")
		return
	battle.tick(0.34)
	if attacker.attack_count != 2:
		_fail("攻速变化后未在约 1.33 秒普攻")
		return
	for i in 3:
		battle.tick(1.34)
	if attacker.attack_count != 5 or defender.has_status("silence"):
		_fail("前五次普攻的沉默计数不正确")
		return
	battle.tick(1.34)
	if attacker.attack_count != 6 or not defender.has_status("silence"):
		_fail("第六次普攻未施加沉默")
		return
	attacker.add_battle_stat("move", 1.0)
	if not is_equal_approx(attacker.move_interval, 1.0):
		_fail("移动力不应缩短基础移动间隔")
		return
	var movement_battle := BattleManager.new("movement", null,
		[{"type": "Warrior", "pos": Vector2i(1, 2), "roster_index": -1}],
		{"width": 9, "height": 5, "enemy_units": [{"type": "Warrior", "pos": [6, 2]}]})
	movement_battle.setup()
	movement_battle.setup_battle()
	var runner: Unit = movement_battle.units[0]
	var stationary: Unit = movement_battle.units[1]
	runner.add_battle_stat("move", 2.0)
	runner.attack_timer = 0.0
	runner.move_timer = 0.0
	stationary.attack_interval = INF
	stationary.move_interval = INF
	stationary.attack_timer = 0.0
	stationary.move_timer = 0.0
	if not movement_battle.get_move_tiles(runner).has(Vector2i(4, 2)):
		_fail("移动力 3 未允许一次移动三格")
		return
	movement_battle.tick(0.5)
	if runner.pos != Vector2i(1, 2):
		_fail("移动力 3 在一秒前就获得了移动机会")
		return
	movement_battle.tick(0.5)
	if runner.pos != Vector2i(4, 2):
		_fail("单位未在一秒后一次移动三格")
		return
	for i in 3:
		EffectSystem.apply_effects(defender, attacker, [{"type": "frost"}], null, battle)
	var frozen_pos := attacker.pos
	battle.tick(1.34)
	if attacker.attack_count != 6 or attacker.pos != frozen_pos or attacker.has_status("frozen"):
		_fail("冻结未阻止移动并跳过下一次普攻")
		return
	var cooldown_skill := Skill.new()
	cooldown_skill.name = "冷却计数测试"
	cooldown_skill.cooldown = 2
	attacker.add_skill(cooldown_skill)
	cooldown_skill.start_cooldown()
	cooldown_skill.tick_cooldown()
	if cooldown_skill.cooldown_remaining != 2:
		_fail("触发当次普攻错误地扣除了冷却")
		return
	attacker.attack_count += 1
	cooldown_skill.tick_cooldown()
	attacker.attack_count += 1
	cooldown_skill.tick_cooldown()
	if cooldown_skill.cooldown_remaining != 0:
		_fail("普攻次数冷却未正确递减")
		return
	print("PASS: 独立计时、攻速、每秒一次按移动力跨格移动、第六次普攻沉默与冻结")
	get_tree().quit(0)


# 输出断言失败原因。
func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
