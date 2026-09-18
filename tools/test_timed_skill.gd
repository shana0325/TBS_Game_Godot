# 定时技能回归检查：验证秒数触发不依赖单位行动，旧技能冷却不受影响。
extends Node

# 创建最小战斗并检查首次施放、重复施放和旧冷却状态。
func _ready() -> void:
	var actor := Unit.new()
	actor.max_hp = 100
	actor.hp = 50
	actor.turn_interval = 100.0
	var enemy := Unit.new()
	enemy.camp = "enemy"
	enemy.max_hp = 100
	enemy.hp = 50
	enemy.pos = Vector2i(4, 0)
	enemy.turn_interval = 100.0
	var timed := Skill.from_data({
		"name": "测试治疗", "trigger": "on_timer", "interval_seconds": 1.0,
		"condition": {"target_type": "self"}, "effects": [{"type": "heal", "amount": 10}]
	})
	var old := Skill.from_data({"name": "旧技能", "trigger": "on_attack", "cooldown": 2})
	old.cooldown_remaining = 2
	var targeted := Skill.from_data({
		"name": "测试目标", "trigger": "on_timer", "interval_seconds": 1.0,
		"condition": {"target_type": "target"}, "min_range": 1, "max_range": 1,
		"effects": [{"type": "heal", "amount": 10}]
	})
	actor.skills = [timed, targeted, old]
	var battle := BattleManager.new()
	battle.units = [actor, enemy]
	battle.turn_manager = TurnManager.new(battle.units)
	battle.tick(0.5)
	if actor.hp != 50:
		push_error("定时技能过早施放")
		get_tree().quit(1)
		return
	battle.tick(0.5)
	if actor.hp != 60 or actor.turn_timer >= actor.turn_interval:
		push_error("定时技能没有独立于行动施放")
		get_tree().quit(1)
		return
	battle.tick(1.0)
	if actor.hp != 70 or enemy.hp != 50 or old.cooldown_remaining != 2:
		push_error("定时技能重复施放或旧技能冷却异常")
		get_tree().quit(1)
		return
	enemy.pos = Vector2i(1, 0)
	battle.tick(0.1)
	if enemy.hp != 60 or actor.turn_timer >= actor.turn_interval:
		push_error("目标出现后，已就绪的定时技能没有立即施放")
		get_tree().quit(1)
		return
	print("定时技能检查通过")
	get_tree().quit(0)
