# 全局会话：跨屏幕传递当前关卡、部署单位、战斗结果与爬塔单局状态。
extends Node

const MODE_QUICK := "quick"
const MODE_TOWER := "tower"

var mode: String = MODE_QUICK
var current_scenario: String = "battle_01"
var scenario_override: Dictionary = {}   # 非空时优先于关卡文件（爬塔分层生成用）
var deployed_units: Array = []
var last_winner: String = ""
var victory_rewards: Array = []

# --- 爬塔单局状态 ---
var tower_floor: int = 0
var tower_scenario: Dictionary = {}   # 当前层场景（部署/战斗共用）
var tower_deployed: Array = []        # 当前层玩家部署（跨层保留，便于调整）
var run_relics: Array = []            # 本局获得的遗物 id 列表
var run_blessings: Array = []         # 本局祝福列表：[{ "name", "effects": [...] }]

# 选择关卡并清空旧的部署结果（快速对战模式）。
func select_scenario(scenario_id: String) -> void:
	mode = MODE_QUICK
	current_scenario = scenario_id
	scenario_override = {}
	deployed_units.clear()
	last_winner = ""
	victory_rewards = []

# 开始爬塔：进入第 1 层（沿用当前编成的单位作为默认部署）。
func start_tower() -> void:
	mode = MODE_TOWER
	current_scenario = "tower_floor"
	tower_floor = 1
	tower_scenario = TowerGenerator.generate_scenario(tower_floor)
	tower_deployed = TowerGenerator.auto_deploy()
	scenario_override = tower_scenario
	run_relics.clear()
	run_blessings.clear()
	last_winner = ""
	victory_rewards = []

# 当前是否处于进行中的爬塔局。
func tower_has_active_run() -> bool:
	return mode == MODE_TOWER and tower_floor > 0

# 选关入口按钮文案：继续或新一局。
func get_tower_entry_label() -> String:
	if tower_has_active_run():
		return "爬塔模式（继续 · 第 %d 层）" % tower_floor
	return "爬塔模式（新一局）"

# 爬塔进入部署前：把当前层场景放到 scenario_override，供部署/战斗使用。
func prepare_tower_deployment() -> void:
	current_scenario = "tower_floor"
	scenario_override = tower_scenario
	deployed_units.clear()
	last_winner = ""
	victory_rewards = []

# 从部署开始战斗：记录部署并保证场景就绪。
func start_tower_battle(deployed: Array) -> void:
	tower_deployed = deployed
	deployed_units = deployed
	scenario_override = tower_scenario
	last_winner = ""
	victory_rewards = []

# 结束爬塔局（失败或主动结束）：清空单局状态。
func end_tower_run() -> void:
	mode = MODE_QUICK
	current_scenario = "battle_01"
	tower_floor = 0
	tower_scenario = {}
	tower_deployed = []
	scenario_override = {}
	run_relics.clear()
	run_blessings.clear()
	last_winner = ""
	victory_rewards = []

func get_floor_label() -> String:
	return "爬塔 第 %d 层" % tower_floor

# 记录部署单位列表：每项 { "type", "pos": Vector2i, "roster_index": int }。
func set_deployed_units(units: Array) -> void:
	deployed_units = units

func record_result(winner_camp: String) -> void:
	last_winner = winner_camp
	if winner_camp != TurnManager.PLAYER_CAMP:
		victory_rewards = []

func is_winner() -> bool:
	return last_winner == TurnManager.PLAYER_CAMP