# 奖励选择界面（爬塔）：胜利后展示可扩展数量的奖励卡片，选择后进入下一层。
extends Control

var options: Array = []
var option_buttons: Array = []
var stats_panel: PanelContainer
var stats_rows: VBoxContainer
var stats_button: Button
var options_scroll: ScrollContainer
var options_box: HBoxContainer
var stats_tab: String = "damage"
const STAT_TABS := {"damage": "伤害输出", "taken": "承伤", "heal": "治疗"}

func _ready() -> void:
	options = RewardGenerator.generate_options()
	_build_title()
	_build_summary()
	_build_stats_button()
	_build_options()
	_build_quit_button()
	_layout_screen()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_screen()

# 奖励界面只让奖励卡片占据主区域，战斗记录默认收起为一个紧凑入口。
func _layout_screen() -> void:
	var vp := get_viewport_rect().size
	if stats_button != null:
		stats_button.position = Vector2(maxf(20.0, vp.x - 180.0), 30.0)
	if options_scroll != null:
		options_scroll.position = Vector2(48.0, 190.0)
		options_scroll.size = Vector2(maxf(480.0, vp.x - 96.0), maxf(300.0, vp.y - 280.0))
	if stats_panel != null:
		stats_panel.position = Vector2(maxf(20.0, vp.x - 420.0), 88.0)
		stats_panel.size = Vector2(minf(390.0, vp.x - 40.0), maxf(300.0, vp.y - 150.0))
	var quit_button := get_node_or_null("QuitTowerButton") as Button
	if quit_button != null:
		quit_button.position = Vector2(60.0, maxf(0.0, vp.y - 58.0))

# 战斗统计：按钮点击后展开面板（伤害输出/承伤/治疗三个子页，按我方/敌方分组，长度条=本队占比）。
# 放在右侧，避免遮挡左侧的三选一奖励卡片。
func _build_stats_button() -> void:
	if GameSession.battle_stats.is_empty():
		return
	stats_button = Button.new()
	stats_button.name = "BattleStatsButton"
	stats_button.text = "战斗记录"
	stats_button.custom_minimum_size = Vector2(140, 36)
	stats_button.pressed.connect(_toggle_stats)
	add_child(stats_button)
	stats_panel = PanelContainer.new()
	stats_panel.name = "BattleStatsPanel"
	stats_panel.visible = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for key in STAT_TABS:
		var tb := Button.new()
		tb.text = STAT_TABS[key]
		tb.custom_minimum_size = Vector2(110, 32)
		tb.pressed.connect(_on_stats_tab.bind(key))
		tabs.add_child(tb)
	box.add_child(tabs)
	stats_rows = VBoxContainer.new()
	stats_rows.add_theme_constant_override("separation", 4)
	box.add_child(stats_rows)
	margin.add_child(box)
	stats_panel.add_child(margin)
	add_child(stats_panel)
	_render_stats_rows()

func _toggle_stats() -> void:
	if stats_panel == null:
		return
	stats_panel.visible = not stats_panel.visible

func _on_stats_tab(key: String) -> void:
	stats_tab = key
	_render_stats_rows()

func _render_stats_rows() -> void:
	for child in stats_rows.get_children():
		child.queue_free()
	var stat := stats_tab
	for camp in [TurnManager.PLAYER_CAMP, TurnManager.ENEMY_CAMP]:
		var members: Array = []
		var total := 0
		for s in GameSession.battle_stats:
			if str(s.camp) == camp:
				members.append(s)
				total += int(s[stat])
		if members.is_empty():
			continue
		var title := Label.new()
		title.text = "—— %s ——" % ("我方" if camp == TurnManager.PLAYER_CAMP else "敌方")
		title.add_theme_font_size_override("font_size", 16)
		stats_rows.add_child(title)
		for s in members:
			var value := int(s[stat])
			var pct := roundi(float(value) / float(maxi(total, 1)) * 100.0)
			stats_rows.add_child(_stat_row(str(s.name), value, pct))

func _stat_row(name: String, value: int, pct: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = name
	name_label.custom_minimum_size = Vector2(90, 0)
	h.add_child(name_label)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = pct
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180, 14)
	h.add_child(bar)
	var value_label := Label.new()
	value_label.text = "%d（%d%%）" % [value, pct]
	value_label.custom_minimum_size = Vector2(80, 0)
	h.add_child(value_label)
	return h

func _build_title() -> void:
	var title := Label.new()
	title.name = "RewardTitle"
	title.text = "%s 通关！选择奖励" % GameSession.get_floor_label()
	title.add_theme_font_size_override("font_size", 36)
	title.position = Vector2(60, 30)
	add_child(title)

func _build_summary() -> void:
	var summary := Label.new()
	summary.name = "RunSummary"
	var text := RewardGenerator.run_summary()
	summary.text = text if text != "" else "尚未获得遗物/祝福"
	summary.add_theme_font_size_override("font_size", 18)
	summary.position = Vector2(60, 96)
	summary.custom_minimum_size = Vector2(900, 54)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)

func _build_options() -> void:
	options_scroll = ScrollContainer.new()
	options_scroll.name = "RewardOptionsScroll"
	options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	options_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(options_scroll)
	options_box = HBoxContainer.new()
	options_box.name = "RewardOptionsBox"
	options_box.add_theme_constant_override("separation", 16)
	options_scroll.add_child(options_box)
	for i in options.size():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(210, 300)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		var name_label := Label.new()
		name_label.text = str(options[i].get("label", "?"))
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(name_label)
		var type_label := Label.new()
		type_label.text = _type_text(str(options[i].get("type", "")))
		type_label.add_theme_font_size_override("font_size", 14)
		box.add_child(type_label)
		var desc_label := Label.new()
		desc_label.text = str(options[i].get("desc", ""))
		desc_label.add_theme_font_size_override("font_size", 15)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc_label)
		var pick_btn := Button.new()
		pick_btn.text = "选择"
		pick_btn.custom_minimum_size = Vector2(160, 42)
		pick_btn.pressed.connect(_on_pick.bind(i))
		box.add_child(pick_btn)
		margin.add_child(box)
		panel.add_child(margin)
		options_box.add_child(panel)
		option_buttons.append(pick_btn)

func _type_text(t: String) -> String:
	match t:
		"skill":
			return "◆ 通用技能"
		"equipment":
			return "◆ 装备"
		"blessing":
			return "◆ 祝福"
		"relic":
			return "★ 遗物"
	return t

func _build_quit_button() -> void:
	var quit_btn := Button.new()
	quit_btn.name = "QuitTowerButton"
	quit_btn.text = "结束爬塔并返回主菜单"
	quit_btn.custom_minimum_size = Vector2(220, 40)
	quit_btn.pressed.connect(_on_quit_pressed)
	add_child(quit_btn)

func _on_pick(index: int) -> void:
	var option: Dictionary = options[index]
	RewardGenerator.apply_option(option)
	# 进入下一层的部署环节（保留上一场出战单位，可调整/换装/退出）
	GameSession.tower_floor += 1
	GameSession.tower_scenario = TowerGenerator.generate_scenario(GameSession.tower_floor)
	GameSession.prepare_tower_deployment()
	get_tree().change_scene_to_file("res://scenes/deployment_screen.tscn")

func _on_quit_pressed() -> void:
	ProgressManager.save_roster()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
