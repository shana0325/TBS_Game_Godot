# 招募事件：从三名候选单位中免费选择一名加入后备阵容。
extends TowerEvent

var candidates: Array = []

# 固定本次候选，反复刷新界面不会重抽。
func _init(p_floor: int) -> void:
	super(p_floor)
	title = "旅途招募"
	description = "选择一名新同伴加入队伍。已拥有的单位类型也可以再次招募。"
	candidates = GameDatabase.get_random_pool_unit_ids()
	candidates.shuffle()
	candidates = candidates.slice(0, 3)

# 根据后备阵容容量更新候选可用状态。
func get_options() -> Array:
	var options: Array = []
	for unit_type in candidates:
		var data: Dictionary = GameDatabase.get_unit(str(unit_type))
		options.append({"id": str(unit_type),
			"label": str(data.get("display_name", unit_type)),
			"desc": "加入一名 1 星角色；可在下一场部署。",
			"enabled": not complete and GameDatabase.get_player_units().size() < ProgressManager.MAX_ROSTER_SIZE})
	return options

# 只允许从固定候选中招募一次。
func choose(option_id: String) -> bool:
	if complete or not candidates.has(option_id) or not ProgressManager.recruit_unit(option_id):
		return false
	complete = true
	return true
