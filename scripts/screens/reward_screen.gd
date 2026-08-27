# 奖励选择界面（爬塔）：胜利后展示 三选一 奖励，选择后进入下一层。
extends Control

var options: Array = []
var option_buttons: Array = []

func _ready() -> void:
	options = RewardGenerator.generate_options()
	_build_title()
	_build_summary()
	_build_options()
	_build_quit_button()

func _build_title() -> void:
	var title := Label.new()
	title.text = "%s 通关！选择奖励" % GameSession.get_floor_label()
	title.add_theme_font_size_override("font_size", 36)
	title.position = Vector2(60, 30)
	add_child(title)

func _build_summary() -> void:
	var summary := Label.new()
	var text := RewardGenerator.run_summary()
	summary.text = text if text != "" else "尚未获得遗物/祝福"
	summary.add_theme_font_size_override("font_size", 18)
	summary.position = Vector2(60, 100)
	summary.custom_minimum_size = Vector2(640, 60)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)

func _build_options() -> void:
	var x := 60
	for i in options.size():
		var panel := PanelContainer.new()
		panel.position = Vector2(x + i * 220, 220)
		panel.custom_minimum_size = Vector2(200, 260)
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
		pick_btn.custom_minimum_size = Vector2(120, 38)
		pick_btn.pressed.connect(_on_pick.bind(i))
		box.add_child(pick_btn)
		margin.add_child(box)
		panel.add_child(margin)
		add_child(panel)
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
	quit_btn.text = "结束爬塔并返回主菜单"
	quit_btn.position = Vector2(60, 520)
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