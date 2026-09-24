# 全局会话：跨屏幕传递当前关卡、部署单位、战斗结果与爬塔单局状态。
extends Node

const MODE_QUICK := "quick"
const MODE_TOWER := "tower"
const RUN_GROWTH_SAVE_KEY := "run_relic_state"

var mode: String = MODE_QUICK
var current_scenario: String = "battle_01"
var scenario_override: Dictionary = {}   # 非空时优先于关卡文件（爬塔分层生成用）
var deployed_units: Array = []
var deployment_units: Array = []          # 战前部署栏原始单位列表，切入战斗后继续复用
var last_winner: String = ""
var battle_stats: Array = []             # 本场战斗统计：[{name, camp, damage, heal, taken}]
var battle_speed: int = 1                # 战斗倍速设置，跨战斗保留

# --- 爬塔单局状态 ---
var tower_floor: int = 0
var tower_scenario: Dictionary = {}   # 当前层场景（部署/战斗共用）
var tower_deployed: Array = []        # 当前层玩家部署（跨层保留，便于调整）
var run_relics: Array = []            # 本局获得的遗物 id 列表
var run_relic_stacks: Dictionary = {} # 可重复遗物层数；普通遗物固定为 1 层
var run_relic_state: Dictionary = {}  # 跨模式战斗成长：继续游戏时保留，仅开始新游戏时清空
var rewarded_floor: int = 0           # 本局已发放固定战后奖励的层数
var rewarded_skill_id: String = ""     # 当前层发放的随机技能书，供结算页展示
var pending_tower_events: Array = []     # 下一层部署前依次处理的事件实例

# 自动载入玩家存档中的跨战斗成长，供主菜单“继续游戏”恢复。
func _ready() -> void:
	var saved = GameDatabase.player_roster.get(RUN_GROWTH_SAVE_KEY, {})
	if saved is Dictionary:
		run_relic_state = saved.duplicate(true)

# 选择关卡并清空旧的部署结果（快速对战模式）。
func select_scenario(scenario_id: String) -> void:
	mode = MODE_QUICK
	current_scenario = scenario_id
	scenario_override = {}
	deployed_units.clear()
	deployment_units.clear()
	last_winner = ""
	battle_stats = []

# 主菜单“开始新游戏”使用：清空运行中的关卡、遗物与跨战斗成长，但不触碰玩家角色存档。
func reset_run_state() -> void:
	end_tower_run()
	run_relic_state.clear()
	GameDatabase.player_roster.erase(RUN_GROWTH_SAVE_KEY)
	ProgressManager.save_roster()
	mode = MODE_QUICK
	current_scenario = "battle_01"

# 开始爬塔：进入第 1 层（沿用当前编成的单位作为默认部署）。
func start_tower() -> void:
	mode = MODE_TOWER
	current_scenario = "tower_floor"
	tower_floor = 1
	tower_scenario = TowerGenerator.generate_scenario(tower_floor)
	tower_deployed = TowerGenerator.auto_deploy()
	scenario_override = tower_scenario
	run_relics.clear()
	run_relic_stacks.clear()
	rewarded_floor = 0
	rewarded_skill_id = ""
	pending_tower_events.clear()
	last_winner = ""
	battle_stats = []

# 当前是否处于进行中的爬塔局。
func tower_has_active_run() -> bool:
	return mode == MODE_TOWER and tower_floor > 0

# 为当前楼层建立有序事件队列；同一事件实例跨界面切换保留候选与购买状态。
func prepare_tower_events() -> void:
	pending_tower_events.clear()
	for kind in TowerEventFactory.kinds_for_floor(tower_floor):
		var event := TowerEventFactory.create_event(str(kind), tower_floor)
		if event != null:
			pending_tower_events.append(event)
		else:
			push_warning("未知爬塔事件类型：%s" % kind)

# 读取当前待处理事件；空队列表示可以进入部署。
func get_pending_tower_event() -> TowerEvent:
	return pending_tower_events[0] as TowerEvent if not pending_tower_events.is_empty() else null

# 完成当前事件，应用场景改动，再进入队列下一项。
func finish_tower_event() -> void:
	if not pending_tower_events.is_empty():
		var event: TowerEvent = pending_tower_events[0]
		var updated := event.apply_to_scenario(tower_scenario.duplicate(true))
		if not updated.is_empty():
			tower_scenario = updated
			scenario_override = tower_scenario
		pending_tower_events.pop_front()

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
	deployment_units.clear()
	last_winner = ""

# 从部署开始战斗：记录部署并保证场景就绪。
func start_tower_battle(deployed: Array) -> void:
	# 深拷贝阵容与坐标，奖励进入下一层时继续沿用本层最终编成。
	tower_deployed = deployed.duplicate(true)
	deployed_units = tower_deployed.duplicate(true)
	scenario_override = tower_scenario
	last_winner = ""

# 结束爬塔局（失败或主动结束）：清空爬塔状态，跨模式成长继续保留。
func end_tower_run() -> void:
	mode = MODE_QUICK
	current_scenario = "battle_01"
	tower_floor = 0
	tower_scenario = {}
	tower_deployed = []
	deployment_units.clear()
	scenario_override = {}
	run_relics.clear()
	run_relic_stacks.clear()
	rewarded_floor = 0
	rewarded_skill_id = ""
	pending_tower_events.clear()
	last_winner = ""
	battle_stats = []

func get_floor_label() -> String:
	return "爬塔 第 %d 层" % tower_floor

# 每层胜利固定发放一本随机通用技能书和六金币；重复打开结算页不会重复领取。
func claim_tower_clear_supplies() -> Dictionary:
	if not tower_has_active_run() or not is_winner():
		return {}
	var gold := ProgressManager.economy_value("gold_per_win", 6)
	if rewarded_floor == tower_floor:
		return {"skill_id": rewarded_skill_id, "gold": gold}
	var pool := GameDatabase.get_searchable_skill_ids(true)
	var skill_id := str(pool.pick_random()) if not pool.is_empty() else ""
	if not ProgressManager.grant_battle_supplies(skill_id, gold):
		return {}
	rewarded_floor = tower_floor
	rewarded_skill_id = skill_id
	return {"skill_id": skill_id, "gold": gold}

# 出售编成角色后修正本层保存的出战索引，避免下层指向错误单位。
func on_roster_unit_sold(old_index: int) -> void:
	for list in [tower_deployed, deployed_units]:
		for i in range(list.size() - 1, -1, -1):
			var entry: Dictionary = list[i]
			var index := int(entry.get("roster_index", -1))
			if index == old_index:
				list.remove_at(i)
			elif index > old_index:
				entry["roster_index"] = index - 1

# 获取遗物当前层数，兼容直接写入 run_relics 的旧代码与测试。
func get_relic_stack(relic_id: String) -> int:
	if not run_relics.has(relic_id):
		return 0
	return maxi(1, int(run_relic_stacks.get(relic_id, 1)))

# 获得遗物：首次写入唯一列表，可重复遗物再次获得时只增加层数。
func add_run_relic(relic_id: String) -> bool:
	var relic: Dictionary = GameDatabase.get_relic(relic_id)
	if relic.is_empty():
		return false
	var current := get_relic_stack(relic_id)
	if current <= 0:
		run_relics.append(relic_id)
		run_relic_stacks[relic_id] = 1
		return true
	if not bool(relic.get("repeatable", false)):
		return false
	var max_stacks := int(relic.get("max_stacks", 0))
	if max_stacks > 0 and current >= max_stacks:
		return false
	run_relic_stacks[relic_id] = current + 1
	return true

# 记录部署单位列表：每项 { "type", "pos": Vector2i, "roster_index": int }。
func set_deployed_units(units: Array) -> void:
	deployed_units = units

func record_result(winner_camp: String) -> void:
	last_winner = winner_camp
	_save_run_growth()

# 把跨战斗成长写入现有玩家存档；快速战斗、爬塔和后续模式共用。
func _save_run_growth() -> void:
	GameDatabase.player_roster[RUN_GROWTH_SAVE_KEY] = run_relic_state.duplicate(true)
	if not ProgressManager.save_roster():
		push_warning("跨战斗成长保存失败")

func is_winner() -> bool:
	return last_winner == TurnManager.PLAYER_CAMP
