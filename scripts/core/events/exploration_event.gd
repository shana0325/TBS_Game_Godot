# 探索事件：提供免费金币或付费材料两种不同收益。
extends TowerEvent

# 说明本次探索选择。
func _init(p_floor: int) -> void:
	super(p_floor)
	title = "废墟探索"
	description = "在废墟里搜集现金，或用金币交换成更稀缺的升星材料。"

# 根据当前金币决定交换选项是否可用。
func get_options() -> Array:
	var found_gold := ProgressManager.economy_value("exploration_gold", 5)
	var star_price := ProgressManager.economy_value("exploration_star_price", 6)
	return [
		{"id": "gold", "label": "搜集遗落金币", "desc": "获得 %d 金币。" % found_gold, "enabled": not complete},
		{"id": "stars", "label": "交换升星材料", "desc": "花费 %d 金币，获得升星材料 ×3。" % star_price,
			"enabled": not complete and ProgressManager.get_gold() >= star_price},
	]

# 应用一次探索结果。
func choose(option_id: String) -> bool:
	if complete:
		return false
	var success := false
	if option_id == "gold":
		success = ProgressManager.add_gold(ProgressManager.economy_value("exploration_gold", 5))
	elif option_id == "stars":
		success = ProgressManager.purchase_supply("star_items", "", 3,
			ProgressManager.economy_value("exploration_star_price", 6))
	complete = success
	return success
