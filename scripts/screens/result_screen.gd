# 结算屏幕：展示战斗胜负结果，可查看战斗统计（输出/承伤/治疗三个子页，我方/敌方两组）、返回主菜单或再战当前关卡。
extends Control

var stats_btn: Button
var stats_panel: PanelContainer
var stats_rows: VBoxContainer
var stats_tab: String = "damage"
const STAT_TABS := {"damage": "伤害输出", "taken": "承伤", "heal": "治疗"}

func _ready() -> void:
	var title := Label.new()
	title.text = "胜利！" if GameSession.is_winner() else "失败…"
	title.add_theme_font_size_override("font_size", 56)
	title.position = Vector2(80, 120)
	title.size = Vector2(1120, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var retry_btn := Button.new()
	retry_btn.text = "再来一局"
	retry_btn.custom_minimum_size = Vector2(260, 48)
	retry_btn.position = Vector2(200, 260)
	retry_btn.pressed.connect(_retry)
	add_child(retry_btn)

	if GameSession.is_winner():
		_build_rewards()

	_build_stats_button()

	var menu_btn := Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.custom_minimum_size = Vector2(260, 48)
	menu_btn.position = Vector2(200, 330)
	menu_btn.pressed.connect(_go_menu)
	add_child(menu_btn)

# 胜利时展示各单位获得的经验与升级信息。
func _build_rewards() -> void:
	var rewards_label := Label.new()
	rewards_label.add_theme_font_size_override("font_size", 22)
	rewards_label.position = Vector2(80, 200)
	rewards_label.size = Vector2(1120, 200)
	rewards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines: Array = ["—— 战斗奖励 ——"]
	for report in GameSession.victory_rewards:
		var text := "%s：+%d 经验" % [report.get("unit_type", ""), int(report.get("exp_gained", 0))]
		if int(report.get("levels_gained", 0)) > 0:
			text += "（升级到 %d 级！）" % int(report.get("level", 1))
		lines.append(text)
	rewards_label.text = "\n".join(lines)
	add_child(rewards_label)

# 战斗统计：按钮点击后展开面板（伤害输出/承伤/治疗三个子页，按我方/敌方分组，长度条=本队占比）。
func _build_stats_button() -> void:
	if GameSession.battle_stats.is_empty():
		return
	stats_btn = Button.new()
	stats_btn.text = "战斗统计"
	stats_btn.custom_minimum_size = Vector2(260, 48)
	stats_btn.position = Vector2(520, 260)
	stats_btn.pressed.connect(_toggle_stats)
	add_child(stats_btn)

	stats_panel = PanelContainer.new()
	stats_panel.position = Vector2(520, 320)
	stats_panel.visible = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for key in STAT_TABS:
		var tb := Button.new()
		tb.text = STAT_TABS[key]
		tb.custom_minimum_size = Vector2(120, 34)
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
		title.add_theme_font_size_override("font_size", 17)
		stats_rows.add_child(title)
		for s in members:
			var value := int(s[stat])
			var pct := roundi(float(value) / float(maxi(total, 1)) * 100.0)
			stats_rows.add_child(_stat_row(str(s.name), value, pct))

# 单行统计：名称 + 长度条（本队占比）+ 数值（百分比）。
func _stat_row(name: String, value: int, pct: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = name
	name_label.custom_minimum_size = Vector2(110, 0)
	h.add_child(name_label)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = pct
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 16)
	h.add_child(bar)
	var value_label := Label.new()
	value_label.text = "%d（%d%%）" % [value, pct]
	value_label.custom_minimum_size = Vector2(90, 0)
	h.add_child(value_label)
	return h

func _toggle_stats() -> void:
	if stats_panel == null:
		return
	stats_panel.visible = not stats_panel.visible
	if stats_btn != null:
		stats_btn.text = "收起统计" if stats_panel.visible else "战斗统计"

func _retry() -> void:
	get_tree().change_scene_to_file("res://scenes/deployment_screen.tscn")

func _go_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
