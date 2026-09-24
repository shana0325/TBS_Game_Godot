# 测试事件：模拟不可跳过的 Boss 预告，并将标记写入战斗场景。
extends TowerEvent

# 创建必须确认的测试事件。
func _init(p_floor: int) -> void:
	super(p_floor)
	skippable = false

# 证明同层事件能在保留普通敌军时追加 Boss。
func apply_to_scenario(scenario: Dictionary) -> Dictionary:
	scenario["test_boss_floor"] = floor
	var enemies: Array = scenario.get("enemy_units", []).duplicate()
	enemies.append({"type": "Tank", "pos": [11, 3],
		"stat_multiplier": TowerGenerator.floor_stat_multiplier(floor)})
	scenario["enemy_units"] = enemies
	return scenario
