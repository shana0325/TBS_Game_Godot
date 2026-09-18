# 伤害系统回归检查：验证类型联动、真实伤害、全伤减免及同链防循环。
extends Node

# 构造两个固定数值的测试单位。
func _make_units() -> Array:
	var source := Unit.new()
	source.config = {"atk": 100, "crit_rate": 0, "crit_damage": 150}
	source.max_hp = 1000
	source.hp = 1000
	var target := Unit.new()
	target.camp = "enemy"
	target.config = {"defense": 100}
	target.max_hp = 1000
	target.hp = 1000
	target.pos = Vector2i(1, 0)
	return [source, target]

# 为技能联动建立最小战斗上下文。
func _make_battle(units: Array) -> BattleManager:
	var battle := BattleManager.new()
	battle.units = units
	battle.turn_manager = TurnManager.new(units)
	battle.event_system = EventSystem.new(units)
	return battle

# 运行所有断言，失败时以非零退出码结束。
func _ready() -> void:
	var pair := _make_units()
	var source: Unit = pair[0]
	var target: Unit = pair[1]
	target.add_buff(Buff.from_data({"name": "减伤", "duration": -1, "reduce_percent": 0.5}))
	var normal := DamageSystem.apply(source, target, {"damage_kind": DamageSystem.ATTACK, "power": 1.0})
	var true_hit := DamageSystem.apply(source, target, {"damage_kind": DamageSystem.ATTACK,
		"power": 1.0, "true_damage": true})
	if normal.damage != 25 or true_hit.damage != 50:
		_fail("护甲与全伤减免未按预期结算")
		return
	target.add_buff(Buff.from_data({"name": "完全减伤", "duration": -1, "reduce_percent": 0.5}))
	var blocked := DamageSystem.apply(source, target, {"damage_kind": DamageSystem.SKILL,
		"power": 1.0, "true_damage": true})
	if blocked.damage != 0 or blocked.actual_damage != 0:
		_fail("100% 减伤未能阻止真实伤害")
		return
	pair = _make_units()
	source = pair[0]
	target = pair[1]
	target.config["defense"] = 0
	var battle := _make_battle(pair)
	var proc := Skill.from_data({"name": "附带一击", "trigger": "on_hit",
		"condition": {"target_type": "target"}, "effects": [{"type": "damage",
		"damage_kind": "effect", "power": 0.5}]})
	source.skills = [proc]
	DamageSystem.apply(source, target, {"damage_kind": DamageSystem.ATTACK, "power": 1.0}, battle)
	if target.hp != 850:
		_fail("普攻附带特效伤害重复触发或没有触发")
		return
	target.hp = 1000
	DamageSystem.apply(source, target, {"damage_kind": DamageSystem.SKILL, "power": 1.0}, battle)
	if target.hp != 850:
		_fail("技能伤害没有触发附加效果")
		return
	target.hp = 1000
	DamageSystem.apply(source, target, {"damage_kind": DamageSystem.EFFECT,
		"power": 1.0}, battle)
	if target.hp != 900:
		_fail("特效伤害错误触发了附加效果")
		return
	target.hp = 1000
	var proc_skill := Skill.from_data({"name": "技能联动", "trigger": "on_hit",
		"condition": {"target_type": "target"}, "effects": [{"type": "damage",
		"damage_kind": "skill", "power": 0.5}]})
	source.skills = [proc_skill]
	DamageSystem.apply(source, target, {"damage_kind": DamageSystem.ATTACK, "power": 1.0}, battle)
	if target.hp != 850:
		_fail("同一伤害链内的技能效果发生重复触发")
		return
	target.hp = 1000
	var second_proc := Skill.from_data({"name": "第二联动", "trigger": "on_hit",
		"condition": {"target_type": "target"}, "effects": [{"type": "damage",
		"damage_kind": "skill", "power": 0.5}]})
	source.skills = [proc_skill, second_proc]
	DamageSystem.apply(source, target, {"damage_kind": DamageSystem.ATTACK, "power": 1.0}, battle)
	if target.hp != 800:
		_fail("不同技能未各触发一次，或出现了递归套娃")
		return
	var shield_pair := _make_units()
	var shield_target: Unit = shield_pair[1]
	shield_target.add_buff(Buff.from_data({"name": "护盾", "duration": -1, "shield": 20}))
	shield_target.add_buff(Buff.from_data({"name": "减伤", "duration": -1, "reduce_percent": 0.5}))
	var shield_hit := DamageSystem.apply(shield_pair[0], shield_target,
		{"damage_kind": DamageSystem.SKILL, "power": 1.0, "true_damage": true})
	if shield_hit.damage != 50 or shield_hit.result.shield_absorbed != 20 or shield_target.hp != 970:
		_fail("真实伤害的全伤减免与护盾顺序错误")
		return
	var raw_hit := DamageSystem.apply(null, shield_target,
		{"damage_kind": DamageSystem.EFFECT, "raw_damage": 20, "true_damage": true})
	if raw_hit.damage != 10 or shield_target.hp != 960:
		_fail("固定值特效伤害没有受到全伤减免")
		return
	var attack_pair := _make_units()
	var attack_target: Unit = attack_pair[1]
	attack_target.config["defense"] = 0
	attack_pair[0].skills = [proc]
	var attack_battle := _make_battle(attack_pair)
	attack_battle.grid = Grid.new(5, 5)
	attack_battle.combat_system = CombatSystem.new(null, attack_battle.event_system,
		attack_battle.grid, attack_battle)
	var attack_report := attack_battle.perform_attack(attack_pair[0], attack_target)
	if attack_report.damage != 100 or attack_target.hp != 850:
		_fail("实际普攻流程没有通过统一伤害入口触发附加效果")
		return
	print("伤害系统检查通过")
	get_tree().quit(0)

# 输出失败原因并终止测试。
func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
