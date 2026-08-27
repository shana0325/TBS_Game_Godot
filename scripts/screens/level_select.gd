# 选关/模式选择屏幕：爬塔模式入口 + 快速对战关卡列表（可继续扩展挑战关卡/商店/事件）。
extends Control

var scenario_ids: Array = []
var scenario_names: Dictionary = {}

func _ready() -> void:
	_scan_scenarios()
	_build_ui()

func _scan_scenarios() -> void:
	var dir := DirAccess.open("res://data/scenario")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var scenario_id := file_name.get_basename()
			scenario_ids.append(scenario_id)
			scenario_names[scenario_id] = _read_scenario_name(scenario_id)
		file_name = dir.get_next()
	dir.list_dir_end()
	scenario_ids.sort()

func _read_scenario_name(scenario_id: String) -> String:
	var path := "res://data/scenario/%s.json" % scenario_id
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return scenario_id
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return str(parsed.get("name", scenario_id))
	return scenario_id

func _build_ui() -> void:
	var title := Label.new()
	title.text = "选择模式"
	title.add_theme_font_size_override("font_size", 42)
	title.position = Vector2(80, 80)
	add_child(title)

	var back_btn := Button.new()
	back_btn.text = "返回主菜单"
	back_btn.position = Vector2(80, 40)
	back_btn.pressed.connect(_go_back)
	add_child(back_btn)

	# 爬塔模式入口（进行中的局可继续）
	var tower_btn := Button.new()
	tower_btn.text = "◆ %s" % GameSession.get_tower_entry_label()
	tower_btn.custom_minimum_size = Vector2(520, 56)
	tower_btn.position = Vector2(80, 170)
	tower_btn.pressed.connect(_on_tower_pressed)
	add_child(tower_btn)

	var divider := Label.new()
	divider.text = "—— 快速对战关卡 ——"
	divider.add_theme_font_size_override("font_size", 20)
	divider.position = Vector2(80, 250)
	add_child(divider)

	var start_y := 300
	for i in scenario_ids.size():
		var btn := Button.new()
		btn.text = "%s  (%s)" % [scenario_names[scenario_ids[i]], scenario_ids[i]]
		btn.custom_minimum_size = Vector2(420, 48)
		btn.position = Vector2(80, start_y + i * 64)
		btn.pressed.connect(_on_scenario_selected.bind(scenario_ids[i]))
		add_child(btn)

func _on_tower_pressed() -> void:
	# 新一局或继续当前局，统一进入部署（部署预填上一层出战单位）
	if not GameSession.tower_has_active_run():
		GameSession.start_tower()
	else:
		GameSession.prepare_tower_deployment()
	get_tree().change_scene_to_file("res://scenes/deployment_screen.tscn")

func _on_scenario_selected(scenario_id: String) -> void:
	GameSession.select_scenario(scenario_id)
	get_tree().change_scene_to_file("res://scenes/deployment_screen.tscn")

func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")