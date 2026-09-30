# 备战栏横向滚动：鼠标位于单位卡上时，普通滚轮也可浏览超出宽度的卡片。
extends ScrollContainer

# 将垂直滚轮转为横向位移，保留鼠标或触控板原生的横向滚动。
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_WHEEL_UP and event.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	var bar := get_h_scroll_bar()
	if bar.max_value <= bar.page + 1.0:
		return
	var direction := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
	scroll_horizontal += direction * roundi(92.0 * maxf(0.25, event.factor))
	accept_event()
