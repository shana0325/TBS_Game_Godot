# 部署屏幕：展示关卡地图与部署区，点击编成槽位后在部署区内放置单位，全部就绪后可开始战斗。
extends Control

const TILE_SIZE := 64

var scenario_id: String = ""
var grid: Grid
var deployment_zone: Array = []
var roster_units: Array = []
var placements: Dictionary = {}
var cell_to_slot: Dictionary = {}
var selected_slot: int = -1

var grid_view: Node2D
var units_layer: Node2D
var roster_container: VBoxContainer
var start_button: Button
var state_label: Label
var unit_views: Dictionary = {}
var preview_player_units: Array = []
var slot_buttons: Array = []

func _ready() -> void:
	scenario_id = GameSession.current_scenario
	var scenario := _load_scenario()
	grid = Grid.new()
	if int(scenario.get("side_width", 0)) > 0:
		grid.setup_dual(
			int(scenario.get("side_width", 4)),
			int(scenario.get("height", 3)),
			int(scenario.get("gap_width", 2))
		)
	else:
		grid = Grid.new(int(scenario.get("width", 10)), int(scenario.get("height", 8)))
	deployment_zone = _parse_cells(scenario.get("deployment_zone", []))
	roster_units = GameDatabase.player_roster.get("units", [])
	_build_ui(scenario)

func _load_scenario() -> Dictionary:
	var path := "res://data/scenario/%s.json" % scenario_id
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

func _parse_cells(raw: Array) -> Array:
	var result: Array = []
	for item in raw:
		result.append(Vector2i(int(item[0]), int(item[1])))
	return result

func _build_ui(scenario: Dictionary) -> void:
	var title := Label.new()
	title.text = "部署 - %s" % str(scenario.get("name", scenario_id))
	title.add_theme_font_size_override("font_size", 34)
	title.position = Vector2(20, 12)
	add_child(title)

	var back_btn := Button.new()
	back_btn.text = "返回选关"
	back_btn.position = Vector2(20, 60)
	back_btn.pressed.connect(_go_back)
	add_child(back_btn)

	# 战场视图：居中放置
	grid_view = Node2D.new()
	var board_w := grid.width * TILE_SIZE
	var board_h := grid.height * TILE_SIZE
	var vp := get_viewport_rect().size
	grid_view.position = Vector2((vp.x - board_w) / 2.0, (vp.y - board_h) / 2.0 - 60.0)
	var gv := preload("res://scripts/ui/grid_view.gd").new()
	grid_view.add_child(gv)
	grid_view.get_child(0).setup(grid, TILE_SIZE)
	add_child(grid_view)

	units_layer = Node2D.new()
	grid_view.add_child(units_layer)
	grid_view.get_child(0).set_highlights(deployment_zone, [])

	# 预览敌方单位
	for entry in scenario.get("enemy_units", []):
		var unit_type := str(entry.get("type", "Goblin"))
		var config: Dictionary = GameDatabase.get_unit(unit_type)
		if config.is_empty():
			continue
		var pos := Vector2i(int(entry.pos[0]), int(entry.pos[1]))
		var unit := Unit.create_from_config(unit_type, TurnManager.ENEMY_CAMP, pos, config)
		_create_unit_view(unit)

	# 右侧编成列表
	var roster_panel := PanelContainer.new()
	roster_panel.position = Vector2(vp.x - 230.0, 80.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	roster_container = VBoxContainer.new()
	roster_container.add_theme_constant_override("separation", 8)
	margin.add_child(roster_container)
	roster_panel.add_child(margin)
	add_child(roster_panel)
	for i in roster_units.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(190, 42)
		btn.text = "%d. %s" % [i + 1, str(roster_units[i].get("type", "Unit"))]
		btn.pressed.connect(_on_slot_clicked.bind(i))
		roster_container.add_child(btn)
		slot_buttons.append(btn)

	state_label = Label.new()
	state_label.position = Vector2(20, 110)
	state_label.add_theme_font_size_override("font_size", 22)
	add_child(state_label)

	start_button = Button.new()
	start_button.text = "开始战斗"
	start_button.custom_minimum_size = Vector2(220, 48)
	start_button.position = Vector2(20, 150)
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	add_child(start_button)

	_refresh_state()

func _create_unit_view(unit: Unit) -> void:
	var uv := preload("res://scripts/ui/unit_view.gd").new()
	uv.setup(unit, TILE_SIZE)
	units_layer.add_child(uv)
	unit_views[unit] = uv

func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var local := (grid_view as Node2D).to_local(screen_pos)
	return Vector2i(floori(local.x / TILE_SIZE), floori(local.y / TILE_SIZE))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_clicked(_screen_to_cell(event.position))

func _on_clicked(cell: Vector2i) -> void:
	if not grid.in_bounds(cell.x, cell.y):
		return
	if selected_slot < 0:
		return
	if not deployment_zone.has(cell):
		return
	_place_slot(selected_slot, cell)

func _on_slot_clicked(index: int) -> void:
	selected_slot = index
	_refresh_state()

func _place_slot(slot: int, cell: Vector2i) -> void:
	var prev_pos = placements.get(slot)
	if prev_pos != null:
		cell_to_slot.erase(prev_pos)
	var occupied = cell_to_slot.get(cell)
	if occupied != null:
		placements.erase(occupied)
	placements[slot] = cell
	cell_to_slot[cell] = slot
	_refresh_units()
	_refresh_state()

func _refresh_units() -> void:
	# 重建玩家预览单位，显示已放置位置
	for u in preview_player_units:
		units_layer.remove_child(unit_views[u])
		unit_views.erase(u)
	preview_player_units.clear()
	for slot in placements:
		var rd: Dictionary = roster_units[slot]
		var unit_type := str(rd.get("type", "Hero"))
		var config: Dictionary = GameDatabase.get_unit(unit_type)
		if config.is_empty():
			continue
		var pos: Vector2i = placements[slot]
		var unit := Unit.create_from_config(unit_type, TurnManager.PLAYER_CAMP, pos, config, rd, GameDatabase)
		preview_player_units.append(unit)
		_create_unit_view(unit)
	for child in units_layer.get_children():
		if child.has_method("refresh"):
			child.refresh()

func _refresh_state() -> void:
	var placed := placements.size()
	var total := roster_units.size()
	for i in slot_buttons.size():
		var btn: Button = slot_buttons[i]
		if placements.has(i):
			btn.text = "%d. %s  [已部署]" % [i + 1, str(roster_units[i].get("type", "Unit"))]
		else:
			btn.text = "%d. %s  [未部署]" % [i + 1, str(roster_units[i].get("type", "Unit"))]
		if i == selected_slot:
			btn.modulate = Color(1.2, 1.2, 0.5)
		else:
			btn.modulate = Color.WHITE
	if placed >= total:
		state_label.text = "已部署 %d / %d  可以开始战斗" % [placed, total]
	elif selected_slot < 0:
		state_label.text = "已部署 %d / %d  点击单位后点击蓝色区域放置" % [placed, total]
	else:
		state_label.text = "已部署 %d / %d  请将单位放入蓝色区域（可反复点击调整位置）" % [placed, total]
	start_button.disabled = placed != total

func _on_start_pressed() -> void:
	GameSession.set_deployed_positions(placements)
	get_tree().change_scene_to_file("res://scenes/battle_screen.tscn")

func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
