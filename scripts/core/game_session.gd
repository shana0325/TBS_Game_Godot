# 全局会话：跨屏幕传递当前关卡、部署单位与战斗结果，避免场景切换时丢失状态。
extends Node

var current_scenario: String = "battle_01"
var deployed_units: Array = []
var last_winner: String = ""
var victory_rewards: Array = []

# 选择关卡并清空旧的部署结果。
func select_scenario(scenario_id: String) -> void:
	current_scenario = scenario_id
	deployed_units.clear()
	last_winner = ""
	victory_rewards = []

# 记录部署单位列表：每项 { "type", "pos": Vector2i, "roster_index": int }。
# roster_index >= 0 表示来自 player_roster（带成长数据），-1 表示 mod/模板单位。
func set_deployed_units(units: Array) -> void:
	deployed_units = units

func record_result(winner_camp: String) -> void:
	last_winner = winner_camp
	if winner_camp != TurnManager.PLAYER_CAMP:
		victory_rewards = []

func is_winner() -> bool:
	return last_winner == TurnManager.PLAYER_CAMP
