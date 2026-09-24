# 补给事件：在升星材料和两本指定技能书之间选择一项。
extends TowerEvent

var books: Array = []

# 生成本次可自选的两个技能书候选。
func _init(p_floor: int) -> void:
	super(p_floor)
	title = "旅途补给"
	description = "选择升星材料，或指定领取一本通用技能书。"
	books = GameDatabase.get_searchable_skill_ids(true)
	books.shuffle()
	books = books.slice(0, 2)

# 展示固定候选，奖励领取后禁用所有选项。
func get_options() -> Array:
	var options: Array = [{"id": "stars", "label": "升星材料 ×2",
		"desc": "用于在部署阶段为角色升星。", "enabled": not complete}]
	for skill_id in books:
		var data: Dictionary = GameDatabase.get_skill(str(skill_id))
		options.append({"id": str(skill_id), "label": "技能书：%s" % str(data.get("name", skill_id)),
			"desc": str(data.get("desc", "")), "enabled": not complete})
	return options

# 发放一次选中的材料，并等待玩家继续。
func choose(option_id: String) -> bool:
	if complete:
		return false
	var success := false
	if option_id == "stars":
		success = ProgressManager.add_star_items(2)
	elif books.has(option_id):
		success = ProgressManager.add_skill_book(option_id)
	complete = success
	return success
