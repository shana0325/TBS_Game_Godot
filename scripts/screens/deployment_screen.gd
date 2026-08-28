# 部署屏幕：展示关卡地图与底部单位栏，支持拖拽部署及战场内拖动换位。
extends Control

const UNIT_INFO_TEXT = preload("res://scripts/ui/unit_info_text.gd")

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
var roster_container: HBoxContainer
var roster_scroll: ScrollContainer
var back_button: Button
var start_button: Button
var action_buttons: Array[Control] = []
var info_panel: PanelContainer
var info_label: Label
var info_portrait: TextureRect
var unit_views: Dictionary = {}
var slot_views: Dictionary = {}
var preview_player_units: Array = []
var unit_cards: Array[DeploymentUnitCard] = []
var dragging_slot: int = -1
var drag_start_position := Vector2.ZERO
var drag_moved := false

func _ready() -> void:
	# 根节点作为战场拖放目标，同时让底部卡片正常接收鼠标事件。
	mouse_filter = Control.MOUSE_FILTER_PASS
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

	back_button = Button.new()
	back_button.text = "返回选关"
	back_button.custom_minimum_size = Vector2(220, 48)
	back_button.pressed.connect(_go_back)
	add_child(back_button)

	# 战场视图：与战斗场景共用坐标和格子尺寸，进入战斗时不产生放大跳变。
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

	# 底部横向单位栏：单位卡片可直接拖到战场部署，名称由 UnitView 绘制。
	roster_panel = PanelContainer.new()
	roster_panel.custom_minimum_size = Vector2(0, 176)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	roster_scroll = ScrollContainer.new()
	roster_scroll.name = "DeploymentUnitScroll"
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_container = HBoxContainer.new()
	roster_container.add_theme_constant_override("separation", 10)
	roster_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.add_child(roster_container)
	margin.add_child(roster_scroll)
	roster_panel.add_child(margin)
	add_child(roster_panel)
	for i in selectable_units.size():
		var card := DeploymentUnitCard.new()
		card.setup(i, str(selectable_units[i].get("type", "Unit")), int(selectable_units[i].get("roster_index", -1)), tile_size)
		card.inspect_requested.connect(_on_unit_card_inspect)
		roster_container.add_child(card)
		unit_cards.append(card)

	start_button = Button.new()
	start_button.text = "开始战斗"
	start_button.custom_minimum_size = Vector2(220, 48)
	start_button.position = Vector2(20, 150)
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	add_child(start_button)
	# 操作区按“从下往上”维护，后续新增按钮直接追加到数组即可。
	action_buttons = [start_button, back_button]
	_build_info_panel()

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
		for card in unit_cards:
			card.set_tile_size(tile_size)
		_layout_ui()
		_refresh_units()

# 窗口尺寸变化时重排部署辅助控件，保证主战场、按钮和底部单位栏都留在可视区域。
func _layout_ui() -> void:
	var vp := get_viewport_rect().size
	if roster_panel != null:
		# 底部保留 24px 安全边距，保证面板和横向滚动条完整可见。
		var tray_height := _tray_height()
		# 额外保留 36px 客户区底部安全边距，避免窗口边框/任务栏裁掉面板下沿。
		roster_panel.position = Vector2(24.0, maxf(250.0, vp.y - tray_height - 36.0))
		roster_panel.size = Vector2(maxf(320.0, vp.x - 48.0), tray_height)
	_layout_action_buttons(vp)
	if info_panel != null:
		info_panel.position = Vector2(maxf(20.0, vp.x - 400.0), 112.0)
		info_panel.size = Vector2(minf(376.0, maxf(320.0, vp.x - 40.0)), maxf(260.0, vp.y - _tray_height() - 136.0))

# 为右侧操作区和底部单位栏预留空间，避免地图与文字互相覆盖。
func _board_position(_vp: Vector2) -> Vector2:
	return Vector2(24.0, 104.0)

func _board_available_size(vp: Vector2) -> Vector2:
	return Vector2(maxf(320.0, vp.x - 48.0), maxf(260.0, vp.y - 300.0))

# 右侧操作区与战场同高，按钮从区域底部向上排列，不会落到战场下方。
func _layout_action_buttons(vp: Vector2) -> void:
	if grid == null:
		return
	var board_right := _board_position(vp).x + grid.width * tile_size
	var board_bottom := _board_position(vp).y + grid.height * tile_size
	var action_x := minf(board_right + 24.0, vp.x - 244.0)
	var button_y := board_bottom - 48.0
	for button in action_buttons:
		if button == null:
			continue
		button.position = Vector2(maxf(20.0, action_x), button_y)
		button.size = Vector2(220.0, 48.0)
		button_y -= 60.0

func _tray_height() -> float:
	return DeploymentUnitCard.tray_height_for_tile(tile_size)

# 构建悬浮单位信息卡，内容过长时在卡片内部滚动。
func _build_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.name = "DeploymentUnitInfoPanel"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "单位信息"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	info_portrait = TextureRect.new()
	info_portrait.custom_minimum_size = Vector2(140, 140)
	info_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(info_portrait)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(330, 0)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(info_label)
	box.add_child(scroll)
	margin.add_child(box)
	info_panel.add_child(margin)
	add_child(info_panel)
	info_panel.visible = false

func _unit_for_slot(slot: int) -> Unit:
	if slot < 0 or slot >= selectable_units.size():
		return null
	var unit_type := str(selectable_units[slot].get("type", "Hero"))
	var config: Dictionary = GameDatabase.get_unit(unit_type)
	if config.is_empty():
		return null
	var roster_data: Dictionary = {}
	var roster_index := int(selectable_units[slot].get("roster_index", -1))
	if roster_index >= 0 and roster_index < roster_units.size():
		roster_data = roster_units[roster_index]
	var pos: Vector2i = placements.get(slot, Vector2i.ZERO)
	return Unit.create_from_config(unit_type, TurnManager.PLAYER_CAMP, pos, config, roster_data, GameDatabase)

func _on_unit_card_inspect(slot: int) -> void:
	_show_unit_info(_unit_for_slot(slot))

func _show_unit_info(unit: Unit) -> void:
	if unit == null or not unit.alive or info_panel == null:
		return
	var portrait := ArtManager.get_portrait(unit.unit_type)
	info_portrait.texture = portrait
	info_portrait.visible = portrait != null
	info_label.text = UNIT_INFO_TEXT.build(unit)
	info_panel.visible = true
	_layout_ui()

func _hide_unit_info() -> void:
	if info_panel != null:
		info_panel.visible = false

func _create_unit_view(unit: Unit) -> void:
	var uv := preload("res://scripts/ui/unit_view.gd").new()
	uv.setup(unit, tile_size)
	# 战场区域只保留小人、阵营框和血条，避免文字干扰格子阅读。
	uv.show_name = false
	uv.show_hp_text = false
	units_layer.add_child(uv)
	unit_views[unit] = uv

func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var local := (grid_view as Node2D).to_local(screen_pos)
	return Vector2i(floori(local.x / tile_size), floori(local.y / tile_size))

func _unit_at_cell(cell: Vector2i) -> Unit:
	# 部署阶段同时查询我方预览单位和敌方预览单位，保持与战斗点击逻辑一致。
	for candidate in unit_views.keys():
		if candidate is Unit and candidate.alive and candidate.pos == cell:
			return candidate
	return null

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if info_panel != null and info_panel.visible and info_panel.get_global_rect().has_point(event.position):
			return
		var cell := _screen_to_cell(event.position)
		var slot_variant = cell_to_slot.get(cell, null)
		if slot_variant != null:
			dragging_slot = int(slot_variant)
			selected_slot = dragging_slot
			drag_start_position = event.position
			drag_moved = false
			var dragged_view: UnitView = slot_views.get(dragging_slot)
			if dragged_view != null:
				dragged_view.z_index = 100
			_refresh_state()
			get_viewport().set_input_as_handled()
		else:
			var clicked_unit := _unit_at_cell(cell)
			if clicked_unit != null:
				# 敌方单位也可以查看，但不进入部署拖动流程。
				_show_unit_info(clicked_unit)
				get_viewport().set_input_as_handled()
			else:
				# 点击信息卡外的空白区域自动收起信息卡。
				_hide_unit_info()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dragging_slot >= 0:
			var clicked_slot := dragging_slot
			if not drag_moved:
				dragging_slot = -1
				grid_view.get_child(0).set_hover(Vector2i(-1, -1))
				var clicked_view: UnitView = slot_views.get(clicked_slot)
				if clicked_view != null:
					clicked_view.z_index = 0
				_show_unit_info(_unit_for_slot(clicked_slot))
				_refresh_state()
			else:
				_finish_battlefield_drag(_screen_to_cell(event.position))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging_slot >= 0:
		if event.position.distance_to(drag_start_position) >= 8.0:
			drag_moved = true
		if not drag_moved:
			return
		var dragged_view: UnitView = slot_views.get(dragging_slot)
		if dragged_view != null:
			dragged_view.position = grid_view.to_local(event.position)
		grid_view.get_child(0).set_hover(_screen_to_cell(event.position))
		get_viewport().set_input_as_handled()

# 底部单位卡片拖入根节点时，只有部署区内的空格可以接收。
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or str(data.get("kind", "")) != "deployment_unit":
		return false
	var cell := _screen_to_cell(at_position)
	if not grid.in_bounds(cell.x, cell.y) or not deployment_zone.has(cell):
		return false
	var slot := int(data.get("selectable_index", -1))
	return slot >= 0 and slot < selectable_units.size() and not placements.has(slot) and cell_to_slot.get(cell, null) == null

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var slot := int(data.get("selectable_index", -1))
	_place_slot(slot, _screen_to_cell(at_position))
	selected_slot = slot

func _finish_battlefield_drag(cell: Vector2i) -> void:
	var slot := dragging_slot
	dragging_slot = -1
	grid_view.get_child(0).set_hover(Vector2i(-1, -1))
	var dragged_view: UnitView = slot_views.get(slot)
	if dragged_view != null:
		dragged_view.z_index = 0
	if slot < 0 or not placements.has(slot):
		_refresh_units()
		return
	var occupied = cell_to_slot.get(cell, null)
	if not grid.in_bounds(cell.x, cell.y) or not deployment_zone.has(cell):
		_withdraw_slot(slot)
		selected_slot = -1
		_refresh_state()
		return
	if occupied != null and int(occupied) != slot:
		_refresh_units()
		_refresh_state()
		return
	_place_slot(slot, cell)

func _withdraw_slot(slot: int) -> void:
	if not placements.has(slot):
		return
	var old_cell: Vector2i = placements[slot]
	placements.erase(slot)
	cell_to_slot.erase(old_cell)
	_refresh_units()

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
	slot_views.clear()
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
		slot_views[slot] = unit_views[unit]
	for child in units_layer.get_children():
		if child.has_method("refresh"):
			child.refresh()

func _refresh_state() -> void:
	var placed := placements.size()
	for i in unit_cards.size():
		unit_cards[i].set_deployed(placements.has(i))
		unit_cards[i].modulate = Color(1.15, 1.15, 0.85) if i == selected_slot else Color.WHITE
	start_button.disabled = placed == 0

func _on_start_pressed() -> void:
	var deployed: Array = []
	# 保存部署前的完整单位栏，战斗场景直接按同一份数据复用。
	GameSession.deployment_units = selectable_units.duplicate(true)
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
