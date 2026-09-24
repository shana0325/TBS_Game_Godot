# 爬塔事件界面：通用展示代码事件的选项，执行后刷新金币和状态。
extends Control

var tower_event: TowerEvent
var status_label: Label
var result_label: Label
var option_list: VBoxContainer
var continue_button: Button
var leaving: bool = false

# 读取下一层事件并建立独立的事件页面。
func _ready() -> void:
	tower_event = GameSession.get_pending_tower_event()
	if tower_event == null:
		call_deferred("_go_to_deployment")
		return
	_build_ui()
	_refresh_options()

# 构建标题、资源状态、可滚动选项和继续按钮。
func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 54)
	margin.add_theme_constant_override("margin_bottom", 54)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuStyle.frame_panel_style())
	margin.add_child(panel)
	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 32)
	panel_margin.add_theme_constant_override("margin_right", 32)
	panel_margin.add_theme_constant_override("margin_top", 26)
	panel_margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(panel_margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel_margin.add_child(layout)
	var heading := Label.new()
	heading.text = "第 %d 层 · %s" % [GameSession.tower_floor, tower_event.title]
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color("#f3d79f"))
	layout.add_child(heading)
	var description := Label.new()
	description.text = tower_event.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 19)
	layout.add_child(description)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("#c9c3dc"))
	layout.add_child(status_label)
	result_label = Label.new()
	result_label.add_theme_color_override("font_color", Color("#a9e6c4"))
	layout.add_child(result_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	option_list = VBoxContainer.new()
	option_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_list.add_theme_constant_override("separation", 10)
	scroll.add_child(option_list)
	continue_button = Button.new()
	continue_button.text = "下一个事件" if GameSession.pending_tower_events.size() > 1 else "继续部署"
	continue_button.custom_minimum_size = Vector2(180, 50)
	MenuStyle.apply_primary(continue_button)
	continue_button.pressed.connect(_go_to_deployment)
	layout.add_child(continue_button)

# 刷新选项价格、售罄和资源数量，不重新抽取事件内容。
func _refresh_options() -> void:
	continue_button.disabled = not tower_event.can_continue()
	status_label.text = "金币 %d  ·  后备队伍 %d/%d  ·  上阵人口 %d/%d  ·  升星材料 %d" % [
		ProgressManager.get_gold(), GameDatabase.get_player_units().size(), ProgressManager.MAX_ROSTER_SIZE,
		ProgressManager.get_deployment_limit(), ProgressManager.MAX_DEPLOYMENT_LIMIT,
		ProgressManager.get_star_item_count()]
	for child in option_list.get_children():
		option_list.remove_child(child)
		child.queue_free()
	for option in tower_event.get_options():
		var button := Button.new()
		var price := int(option.get("price", 0))
		var suffix := " · %d 金币" % price if price > 0 else ""
		if bool(option.get("purchased", false)):
			suffix = " · 已购买"
		button.text = "%s%s\n%s" % [str(option.get("label", "选项")), suffix, str(option.get("desc", ""))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 90
		button.disabled = not bool(option.get("enabled", true))
		MenuStyle.apply_primary(button)
		button.pressed.connect(_choose.bind(str(option.get("id", "")), str(option.get("label", ""))))
		option_list.add_child(button)

# 让事件子类完成存档事务，成功后更新页面与提示。
func _choose(option_id: String, label: String) -> void:
	if not tower_event.choose(option_id):
		result_label.text = "选择失败，请检查金币或队伍容量。"
		return
	result_label.text = "已获得：%s" % label
	_refresh_options()

# 结束当前事件；队列未清空时进入下一个事件，否则进入部署。
func _go_to_deployment() -> void:
	if leaving or (tower_event != null and not tower_event.can_continue()):
		return
	leaving = true
	GameSession.finish_tower_event()
	if GameSession.pending_tower_events.is_empty():
		get_tree().change_scene_to_file("res://scenes/deployment_screen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/tower_event_screen.tscn")
