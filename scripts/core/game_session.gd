# 全局会话：跨屏幕传递当前关卡、部署位置与战斗结果，避免场景切换时丢失状态。
extends Node

var current_scenario: String = "battle_01"
var deployed_positions: Dictionary = {}
var last_winner: String = ""
var victory_rewards: Array = []

# 选择关卡并清空旧的部署结果。
func select_scenario(scenario_id: String) -> void:
	current_scenario = scenario_id
	deployed_positions.clear()
	last_winner = ""
	victory_rewards = []

# 记录 roster_index -> 部署坐标，供战斗生成玩家单位时使用。
func set_deployed_positions(positions: Dictionary) -> void:
	deployed_positions = positions

func record_result(winner_camp: String) -> void:
	last_winner = winner_camp
	if winner_camp != TurnManager.PLAYER_CAMP:
		victory_rewards = []

func is_winner() -> bool:
	return last_winner == TurnManager.PLAYER_CAMP
