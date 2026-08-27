# 部署屏幕：展示关卡地图与部署区，点击编成槽位后在部署区内放置单位，全部就绪后可开始战斗。
extends Control

var tile_size: int = 64

var scenario_id: String = ""
var grid: Grid
var deployment_zone: Array = []
var roster_units: Array = []
var mod_unit_types: Array = []
var selectable_units: Array = []
var placements: Dictionary = {}
var cell_to_slot: Dictionary = {}
var selected_slot: int = -1

var grid_view: Node2D
var units_layer: Node2D
var roster_panel: PanelContainer
var hint_label: Label
var roster_container: VBoxContainer
var start_button: Button
var remove_button: Button
var state_label: Label
var unit_views: Dictionary = {}
var preview_player_units: Array = []
var slot_buttons: Array = []

func _ready() -> void:
	scenario_id = GameSession.current_scenario
	var scenario := _load_scenario()
	grid = Grid.new(int(scenario.get("width", 12)), int(scenario.get("height", 6)))
	# 部署阶段同样保证战场是主区域，右侧编成栏只作为辅助面板。
	var initial_vp := get_viewport_rect().size
	tile_size = BattleLayout.compute_tile_size(grid.width, grid.height, _board_available_size(initial_vp), 0.86)
	deployment_zone = _parse_cells(scenario.get("deployment_zone", []))
	roster_units = GameDatabase.player_roster.get("units", [])
	mod_unit_types = _collect_mod_unit_types()
	_build_selectable_units()
	_build_ui(scenario)
	_prefill_placements()
	_refresh_units()
	_refresh_state()

# 收集所有可用单位类型：player_roster 的 type + mod 添加的单位 type（去重）。
func _collect_mod_unit_types() -> Array:
	var roster_types: Array = []
	for rd in roster_units:
		roster_types.append(str(rd.get("type", "")))
	var result: Array = []
	for unit_type in GameDatabase.units.keys():
		if not roster_types.has(str(unit_type)):
			result.append(str(unit_type))
	result.sort()
	return result

# 构建可选单位列表：每项 { "type", "roster_index" }。roster 单位在前，mod 单位在后。
func _build_selectable_units() -> void:
	selectable_units.clear()
	for i in roster_units.size():
		selectable_units.append({
			"type": str(roster_units[i].get("type", "Hero")),
			"roster_index": i
		})
	for unit_type in mod_unit_types:
		selectable_units.append({
			"type": unit_type,
			"roster_index": -1
		})

func _load_scenario() -> Dictionary:
	# 爬塔（或运行时覆盖）场景优先
	if not GameSession.scenario_override.is_empty():
		return GameSession.scenario_override
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

# 爬塔：预填上一层的出战单位（未调整过部署时即默认编成放置）。
func _prefill_placements() -> void:
	if GameSession.mode != GameSession.MODE_TOWER or GameSession.tower_deployed.is_empty():
		return
	for entry in GameSession.tower_deployed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
		if pos.x < 0:
			continue
		var ridx := int(entry.get("roster_index", -1))
		for i in selectable_units.size():
			if int(selectable_units[i].get("roster_index", -1)) == ridx \
					and str(selectable_units[i].get("type", "")) == str(entry.get("type", "")):
				if not placements.has(i) and deployment_zone.has(pos):
					placements[i] = pos
					cell_to_slot[pos] = i
				break

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

	if GameSession.mode == GameSession.MODE_TOWER:
		hint_label = Label.new()
		hint_label.text = "爬塔：胜利选完奖励会回到部署，可调整后继续（或返回选关挑战其他模式）"
		hint_label.add_theme_font_size_override("font_size", 15)
		hint_label.custom_minimum_size = Vector2(900, 30)
		add_child(hint_label)

	# 战场视图：中央左侧放置，底部操作区和右侧编成栏不覆盖地图。
	grid_view = Node2D.new()
	var vp := get_viewport_rect().size
	grid_view.position = _board_position(vp)
	var gv := preload("res://scripts/ui/grid_view.gd").new()
	grid_view.add_child(gv)
	grid_view.get_child(0).setup(grid, tile_size)
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
	roster_panel = PanelContainer.new()
	roster_panel.position = Vector2(vp.x - 230.0, 80.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	roster_container = VBoxContainer.new()
	roster_container.add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(210, 480)
	scroll.add_child(roster_container)
	margin.add_child(scroll)
	roster_panel.add_child(margin)
	add_child(roster_panel)
	for i in selectable_units.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(190, 42)
		var label: String = str(selectable_units[i].get("type", "Unit"))
		var is_mod: bool = int(selectable_units[i].get("roster_index", -1)) < 0
		btn.text = "%d. %s%s" % [i + 1, label, "  [MOD]" if is_mod else ""]
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

	remove_button = Button.new()
	remove_button.text = "撤回选中单位"
	remove_button.custom_minimum_size = Vector2(220, 40)
	remove_button.position = Vector2(20, 206)
	remove_button.disabled = true
	remove_button.pressed.connect(_on_remove_pressed)
	add_child(remove_button)

	_refresh_state()
	_layout_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and grid != null:
		var vp := get_viewport_rect().size
		tile_size = BattleLayout.compute_tile_size(grid.width, grid.height, _board_available_size(vp), 0.86)
		grid_view.position = _board_position(vp)
		grid_view.get_child(0).setup(grid, tile_size)
		for child in units_layer.get_children():
			if child is UnitView:
				child.tile_size = tile_size
				child.refresh()
		_layout_ui()
		_refresh_units()

# 窗口尺寸变化时重排部署辅助控件，保证主战场和按钮都留在可视区域。
func _layout_ui() -> void:
	var vp := get_viewport_rect().size
	if roster_panel != null:
		roster_panel.position = Vector2(maxf(16.0, vp.x - 230.0), 80.0)
	if state_label != null:
		state_label.position = Vector2(20.0, vp.y - 124.0)
	if start_button != null:
		start_button.position = Vector2(20.0, vp.y - 76.0)
	if remove_button != null:
		remove_button.position = Vector2(260.0, vp.y - 76.0)
	if hint_label != null:
		hint_label.position = Vector2(20.0, vp.y - 34.0)

# 为右侧编成栏和底部操作区预留空间，避免地图与文字互相覆盖。
func _board_position(_vp: Vector2) -> Vector2:
	return Vector2(24.0, 104.0)

func _board_available_size(vp: Vector2) -> Vector2:
	return Vector2(maxf(320.0, vp.x - 280.0), maxf(360.0, vp.y - 150.0))

func _create_unit_view(unit: Unit) -> void:
	var uv := preload("res://scripts/ui/unit_view.gd").new()
	uv.setup(unit, tile_size)
	units_layer.add_child(uv)
	unit_views[unit] = uv

func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var local := (grid_view as Node2D).to_local(screen_pos)
	return Vector2i(floori(local.x / tile_size), floori(local.y / tile_size))

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
	if not placements.has(selected_slot) and placements.size() >= deployment_zone.size():
		state_label.text = "部署区已满，先移除已部署单位"
		return
	_place_slot(selected_slot, cell)

func _on_slot_clicked(index: int) -> void:
	selected_slot = index
	_refresh_state()

func _on_remove_pressed() -> void:
	if selected_slot < 0 or not placements.has(selected_slot):
		return
	var old_cell: Vector2i = placements[selected_slot]
	placements.erase(selected_slot)
	cell_to_slot.erase(old_cell)
	_refresh_units()
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
		var unit_type := str(selectable_units[slot].get("type", "Hero"))
		var config: Dictionary = GameDatabase.get_unit(unit_type)
		if config.is_empty():
			continue
		var pos: Vector2i = placements[slot]
		var rd: Dictionary = {}
		var index := int(selectable_units[slot].get("roster_index", -1))
		if index >= 0 and index < roster_units.size():
			rd = roster_units[index]
		var unit := Unit.create_from_config(unit_type, TurnManager.PLAYER_CAMP, pos, config, rd, GameDatabase)
		preview_player_units.append(unit)
		_create_unit_view(unit)
	for child in units_layer.get_children():
		if child.has_method("refresh"):
			child.refresh()

func _refresh_state() -> void:
	var placed := placements.size()
	var total := selectable_units.size()
	var zone_size := deployment_zone.size()
	for i in slot_buttons.size():
		var btn: Button = slot_buttons[i]
		if placements.has(i):
			btn.text = "%d. %s  [已部署]" % [i + 1, str(selectable_units[i].get("type", "Unit"))]
		else:
			btn.text = "%d. %s  [未部署]" % [i + 1, str(selectable_units[i].get("type", "Unit"))]
		if i == selected_slot:
			btn.modulate = Color(1.2, 1.2, 0.5)
		else:
			btn.modulate = Color.WHITE
	if placed == 0:
		state_label.text = "请选择单位部署到蓝色区域（至少 1 个，最多 %d 个）" % zone_size
	elif selected_slot < 0:
		state_label.text = "已部署 %d 个  点击单位后点击蓝色区域调整位置" % placed
	else:
		state_label.text = "已部署 %d 个  请将单位放入蓝色区域（可反复点击调整位置）" % placed
	start_button.disabled = placed == 0
	remove_button.disabled = selected_slot < 0 or not placements.has(selected_slot)

func _on_start_pressed() -> void:
	var deployed: Array = []
	for slot in placements:
		deployed.append({
			"type": str(selectable_units[slot].get("type", "Hero")),
			"roster_index": int(selectable_units[slot].get("roster_index", -1)),
			"pos": placements[slot]
		})
	if GameSession.mode == GameSession.MODE_TOWER:
		GameSession.start_tower_battle(deployed)
	else:
		GameSession.set_deployed_units(deployed)
	get_tree().change_scene_to_file("res://scenes/battle_screen.tscn")

func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
