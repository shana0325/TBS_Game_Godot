# 爬塔事件基类：统一事件标题、选项、可用性与选择完成状态。
class_name TowerEvent
extends RefCounted

var floor: int
var title: String = "爬塔事件"
var description: String = ""
var complete: bool = false
var multiple_purchases: bool = false
var skippable: bool = true

# 记录事件发生的楼层，子类可继续生成本次事件的固定选项。
func _init(p_floor: int) -> void:
	floor = p_floor

# 返回当前可见选项；由子类提供 id、名称、说明、价格和可用状态。
func get_options() -> Array:
	return []

# 执行玩家选择；子类应只在保存成功后标记完成。
func choose(_option_id: String) -> bool:
	return false

# 普通事件允许跳过；必经事件可禁止在完成前进入下一项。
func can_continue() -> bool:
	return complete or skippable

# 事件结束前可改写当前层战斗场景；默认保持普通层配置。
func apply_to_scenario(scenario: Dictionary) -> Dictionary:
	return scenario
