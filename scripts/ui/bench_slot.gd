# 备战栏空位：接收单位卡拖放，并将目标格编号交给部署控制器。
class_name BenchSlot
extends PanelContainer

signal unit_dropped(selectable_index: int, slot_index: int)

var slot_index: int = -1

# 只接受可部署单位卡，其他物品拖放由原有目标处理。
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == "deployment_unit"

# 通知部署控制器把单位固定到当前空格。
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		unit_dropped.emit(int(data.get("selectable_index", -1)), slot_index)
