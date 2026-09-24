# 部署屏幕：展示关卡地图与底部单位栏，支持拖拽部署及战场内拖动换位。
extends Control

var tile_size: int = 64

var scenario_id: String = ""
var grid: Grid
var deployment_zone: Array = []
var roster_units: Array = []
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
var backpack_button: Button
var roster_button: Button
var population_label: Label
var roster_popup: PopupPanel
var sale_confirmation: ConfirmationDialog
var pending_sale_id: String = ""
var relic_summary_bar: HBoxContainer
var relic_detail_popup: RelicDetailPopup
var action_buttons: Array[Control] = []
var info_panel: UnitDetailPanel
var backpack_panel: BackpackPanel
var skill_replace_panel: PanelContainer
var pending_skill_book_id: String = ""
var pending_skill_unit: Dictionary = {}
var unit_views: Dictionary = {}
var slot_views: Dictionary = {}
var preview_player_units: Array = []
var unit_cards: Array[DeploymentUnitCard] = []
var dragging_slot: int = -1
var drag_start_position := Vector2.ZERO
var drag_moved := false

func _ready() -> void:
	# 根节点接收底部单位拖入战场的放置事件；具体按钮和卡片仍由子控件处理点击。
	mouse_filter = Control.MOUSE_FILTER_PASS
	scenario_id = GameSession.current_scenario
	var scenario := _load_scenario()
	grid = Grid.new(int(scenario.get("width", 12)), int(scenario.get("height", 6)))
	# 部署阶段同样保证战场是主区域，右侧编成栏只作为辅助面板。
	var initial_vp := get_viewport_rect().size
	tile_size = BattleLayout.compute_tile_size(grid.width, grid.height, _board_available_size(initial_vp), 0.86)
	deployment_zone = _parse_cells(scenario.get("deployment_zone", []))
	roster_units = GameDatabase.player_roster.get("units", [])
	_build_selectable_units()
	_build_ui(scenario)
	_prefill_placements()
	_refresh_units()
	_refresh_state()

# 只展示已拥有的角色；Mod 单位也需要先通过招募加入编成。
func _build_selectable_units() -> void:
	selectable_units.clear()
	for i in roster_units.size():
		selectable_units.append({
			"type": str(roster_units[i].get("type", "Hero")),
			"roster_index": i
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
					if placements.size() >= ProgressManager.get_deployment_limit():
						return
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
	title.add_theme_color_override("font_color", Color("#f3d99d"))
	title.position = Vector2(20, 12)
	add_child(title)
	population_label = Label.new()
	population_label.position = Vector2(480, 23)
	population_label.add_theme_font_size_override("font_size", 17)
	population_label.add_theme_color_override("font_color", Color("#e5d5ad"))
	add_child(population_label)

	# 顶部遗物栏用图标展示持有物，悬停提示名称、效果和当前成长。
	relic_summary_bar = HBoxContainer.new()
	relic_summary_bar.position = Vector2(20, 58)
	relic_summary_bar.add_theme_constant_override("separation", 7)
	add_child(relic_summary_bar)
	_refresh_relic_summary()

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
		var unit_type := str(entry.get("type", "Warrior"))
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
		card.skill_book_drop_requested.connect(_on_unit_card_skill_book_drop)
		roster_container.add_child(card)
		unit_cards.append(card)

	start_button = Button.new()
	start_button.text = "开始战斗"
	MenuStyle.apply_primary(start_button)
	start_button.custom_minimum_size = Vector2(220, 48)
	start_button.position = Vector2(20, 150)
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	add_child(start_button)
	backpack_button = Button.new()
	backpack_button.text = "背包"
	backpack_button.custom_minimum_size = Vector2(220, 48)
	backpack_button.pressed.connect(_on_backpack_pressed)
	add_child(backpack_button)
	roster_button = Button.new()
	roster_button.text = "管理队伍"
	roster_button.custom_minimum_size = Vector2(220, 48)
	roster_button.pressed.connect(_show_roster_management)
	add_child(roster_button)
	# 操作区按“从下往上”维护，后续新增按钮直接追加到数组即可。
	action_buttons = [start_button, back_button, backpack_button, roster_button]
	_build_roster_management()
	_build_info_panel()
	_build_backpack_panel()
	relic_detail_popup = RelicDetailPopup.new()
	relic_detail_popup.name = "RelicDetailPopup"
	add_child(relic_detail_popup)

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
	if relic_summary_bar != null:
		relic_summary_bar.size = Vector2(maxf(240.0, vp.x - 300.0), 48.0)
	if roster_panel != null:
		# 底部保留 24px 安全边距，保证面板和横向滚动条完整可见。
		var tray_height := _tray_height()
		# 额外保留 36px 客户区底部安全边距，避免窗口边框/任务栏裁掉面板下沿。
		roster_panel.position = Vector2(24.0, maxf(250.0, vp.y - tray_height - 36.0))
		roster_panel.size = Vector2(maxf(320.0, vp.x - 48.0), tray_height)
	_layout_action_buttons(vp)
	if info_panel != null:
		info_panel.fit_to_viewport()
	if skill_replace_panel != null and skill_replace_panel.visible:
		var replace_size := Vector2(minf(440.0, vp.x - 32.0), minf(360.0, vp.y - 32.0))
		skill_replace_panel.position = (vp - replace_size) / 2.0
		skill_replace_panel.size = replace_size

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

# 构建占据视口大部分空间的角色资料页。
func _build_info_panel() -> void:
	info_panel = UnitDetailPanel.new()
	info_panel.name = "DeploymentUnitInfoPanel"
	info_panel.ascension_requested.connect(_on_info_panel_ascension_requested)
	add_child(info_panel)
	info_panel.visible = false

# 构建背包悬浮窗；背包 UI 独立于部署逻辑，技能书拖放后再回到进度逻辑层。
func _build_backpack_panel() -> void:
	backpack_panel = BackpackPanel.new()
	backpack_panel.name = "BackpackPanel"
	add_child(backpack_panel)
	backpack_panel.visible = false

# 创建队伍管理与出售确认窗口，出售只返还金币且不会恢复成长材料。
func _build_roster_management() -> void:
	roster_popup = PopupPanel.new()
	roster_popup.title = "管理队伍"
	roster_popup.exclusive = true
	add_child(roster_popup)
	sale_confirmation = ConfirmationDialog.new()
	sale_confirmation.title = "确认出售"
	sale_confirmation.ok_button_text = "确认出售"
	sale_confirmation.confirmed.connect(_confirm_sale)
	roster_popup.add_child(sale_confirmation)

# 打开队伍列表，逐个显示星级、售价与出售操作。
func _show_roster_management() -> void:
	for child in roster_popup.get_children():
		if child == sale_confirmation:
			continue
		roster_popup.remove_child(child)
		child.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	roster_popup.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = "队伍管理 · %d/%d 人 · %d 金币" % [roster_units.size(), ProgressManager.MAX_ROSTER_SIZE, ProgressManager.get_gold()]
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("#f3d79f"))
	box.add_child(heading)
	var note := Label.new()
	note.text = "出售只获得金币；技能书、升星投入和永久成长不返还。至少保留一名角色。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	for unit in roster_units:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var name_label := Label.new()
		var unit_type := str(unit.get("type", ""))
		name_label.text = "%s · %d 星 · %s" % [
			str(GameDatabase.get_unit(unit_type).get("display_name", unit_type)),
			int(unit.get("star", 1)), str(unit.get("id", ""))]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var sell_button := Button.new()
		sell_button.text = "出售 +%d 金币" % ProgressManager.get_sale_price(unit)
		sell_button.custom_minimum_size.x = 145
		sell_button.disabled = roster_units.size() <= 1
		MenuStyle.apply_primary(sell_button)
		sell_button.pressed.connect(_request_sale.bind(str(unit.get("id", ""))))
		row.add_child(sell_button)
	roster_popup.popup_centered(Vector2i(660, 570))

# 在真正删除角色前明确展示不可返还的投入。
func _request_sale(unit_id: String) -> void:
	pending_sale_id = unit_id
	sale_confirmation.dialog_text = "出售后该角色的已学技能、升星投入和永久强化都会失去，且不会返还。确定出售吗？"
	sale_confirmation.popup_centered()

# 出售成功后修正跨层部署索引并重建部署界面。
func _confirm_sale() -> void:
	var old_index := ProgressManager.sell_unit(pending_sale_id)
	pending_sale_id = ""
	if old_index < 0:
		return
	get_tree().reload_current_scene()

func _on_backpack_pressed() -> void:
	if backpack_panel != null:
		backpack_panel.toggle()

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
	var unit := Unit.create_from_config(unit_type, TurnManager.PLAYER_CAMP, pos, config, roster_data, GameDatabase)
	RelicSystem.apply_run_bonuses_to_unit(unit)
	return unit

# 刷新部署页顶部遗物图标，悬停提示包含名称、效果和数据驱动的当前成长。
func _refresh_relic_summary() -> void:
	if relic_summary_bar == null:
		return
	for child in relic_summary_bar.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "已有遗物"
	title.custom_minimum_size = Vector2(76, 44)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#d9c6a0"))
	relic_summary_bar.add_child(title)
	if GameSession.run_relics.is_empty():
		var empty := Label.new()
		empty.text = "暂无"
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color("#8f89a8"))
		relic_summary_bar.add_child(empty)
		return
	for relic_id in GameSession.run_relics:
		var relic: Dictionary = GameDatabase.get_relic(str(relic_id))
		if relic.is_empty():
			continue
		var icon := TextureButton.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.ignore_texture_size = true
		icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_normal = ArtManager.get_relic_icon(str(relic_id))
		icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tooltip := "%s\n%s" % [str(relic.get("name", relic_id)), str(relic.get("desc", "暂无说明"))]
		var growth_lines := RelicSystem.get_growth_display_lines(str(relic_id))
		if not growth_lines.is_empty():
			tooltip += "\n\n当前成长\n" + "\n".join(growth_lines)
		icon.tooltip_text = tooltip
		icon.pressed.connect(_show_relic_details.bind(str(relic_id)))
		relic_summary_bar.add_child(icon)
		var stacks := GameSession.get_relic_stack(str(relic_id))
		if stacks > 1:
			var stack_label := Label.new()
			stack_label.text = "×%d" % stacks
			stack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			stack_label.add_theme_color_override("font_color", Color("#f2d08b"))
			relic_summary_bar.add_child(stack_label)

# 点击顶部遗物图标时打开详情弹窗。
func _show_relic_details(relic_id: String) -> void:
	if relic_detail_popup != null:
		relic_detail_popup.show_relic(relic_id)

func _on_unit_card_inspect(slot: int) -> void:
	_open_unit_info(_unit_for_slot(slot))

func _on_unit_card_skill_book_drop(slot: int, skill_id: String) -> void:
	_attempt_skill_book_drop(_unit_for_slot(slot), skill_id)

func _show_unit_info(unit: Unit) -> void:
	_open_unit_info(unit)

# 所有部署阶段点击入口统一走这里：我方单位按持久化 ID 重建，敌方沿用当前场景实例。
func _open_unit_info(unit: Unit) -> void:
	unit = _resolve_inspection_unit(unit)
	if unit == null or not unit.alive or info_panel == null:
		return
	info_panel.set_ascension_enabled(_can_ascend_unit(unit))
	info_panel.show_unit(unit)
	info_panel.visible = true
	_layout_ui()

func _resolve_inspection_unit(unit: Unit) -> Unit:
	if unit == null or unit.camp != TurnManager.PLAYER_CAMP:
		return unit
	var roster_index := _find_roster_index(unit.unit_id)
	if roster_index < 0:
		return unit
	var slot := _find_selectable_slot(roster_index)
	return _unit_for_slot(slot) if slot >= 0 else unit

func _can_ascend_unit(unit: Unit) -> bool:
	return unit != null and unit.camp == TurnManager.PLAYER_CAMP and _find_roster_index(unit.unit_id) >= 0

func _find_roster_index(unit_id: String) -> int:
	if unit_id.strip_edges().is_empty():
		return -1
	for i in roster_units.size():
		if str(roster_units[i].get("id", "")) == unit_id:
			return i
	return -1

func _find_selectable_slot(roster_index: int) -> int:
	for i in selectable_units.size():
		if int(selectable_units[i].get("roster_index", -1)) == roster_index:
			return i
	return -1

func _on_info_panel_ascension_requested(unit: Unit) -> void:
	var roster_index := _find_roster_index(unit.unit_id if unit != null else "")
	if roster_index < 0:
		return
	var roster_unit: Dictionary = roster_units[roster_index]
	if not ProgressManager.ascend_unit(roster_unit):
		return
	_refresh_units()
	var slot := _find_selectable_slot(roster_index)
	if slot >= 0:
		_show_unit_info(_unit_for_slot(slot))
	_refresh_state()

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
	if (roster_popup != null and roster_popup.visible) or (sale_confirmation != null and sale_confirmation.visible):
		return
	# 背包打开时由其遮罩独占鼠标，避免点击弹窗内容误触发战场拖动。
	if backpack_panel != null and backpack_panel.visible:
		return
	# 技能替换弹窗打开时同样暂停部署输入，只允许弹窗按钮处理操作。
	if skill_replace_panel != null and skill_replace_panel.visible:
		return
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
				_open_unit_info(clicked_unit)
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
				_open_unit_info(_unit_for_slot(clicked_slot))
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
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if str(data.get("kind", "")) == "skill_book":
		var target_unit := _unit_for_drop_position(at_position)
		return target_unit != null and target_unit.camp == TurnManager.PLAYER_CAMP \
			and _find_roster_index(target_unit.unit_id) >= 0 \
			and ProgressManager.get_skill_book_count(str(data.get("skill_id", ""))) > 0
	if str(data.get("kind", "")) != "deployment_unit":
		return false
	var cell := _screen_to_cell(at_position)
	if not grid.in_bounds(cell.x, cell.y) or not deployment_zone.has(cell):
		return false
	var slot := int(data.get("selectable_index", -1))
	return slot >= 0 and slot < selectable_units.size() and not placements.has(slot) \
		and cell_to_slot.get(cell, null) == null and placements.size() < ProgressManager.get_deployment_limit()

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == "skill_book":
		if _can_drop_data(at_position, data):
			_attempt_skill_book_drop(_unit_for_drop_position(at_position), str(data.get("skill_id", "")))
		get_viewport().set_input_as_handled()
		return
	if not _can_drop_data(at_position, data):
		return
	var slot := int(data.get("selectable_index", -1))
	_place_slot(slot, _screen_to_cell(at_position))
	selected_slot = slot

# 技能书拖到战场时按部署槽位重建持久化单位，避免使用旧的临时预览实例。
func _unit_for_drop_position(screen_position: Vector2) -> Unit:
	var cell := _screen_to_cell(screen_position)
	var slot_variant = cell_to_slot.get(cell, null)
	if slot_variant != null:
		return _unit_for_slot(int(slot_variant))
	return _unit_at_cell(cell)

func _attempt_skill_book_drop(unit: Unit, skill_id: String) -> void:
	if unit == null or skill_id.is_empty():
		return
	var roster_index := _find_roster_index(unit.unit_id)
	if roster_index < 0:
		# 兼容旧的运行时部署数据：基础角色类型唯一时仍解析回持久化角色。
		for i in roster_units.size():
			if str(roster_units[i].get("type", "")) == unit.unit_type:
				roster_index = i
				break
	if roster_index < 0:
		return
	var roster_unit: Dictionary = roster_units[roster_index]
	if roster_unit.get("learned_skills", []).has(skill_id):
		if backpack_panel != null:
			backpack_panel.set_status("该角色已经学会这项技能。")
		return
	var equipped: Array = roster_unit.get("equipped_skills", [])
	var slot_limit := Unit.get_skill_slot_limit(int(roster_unit.get("star", 1)))
	if equipped.size() >= slot_limit:
		_open_skill_replace_popup(roster_unit, skill_id)
		return
	if ProgressManager.use_skill_book(roster_unit, skill_id):
		_finish_skill_book_learning(roster_index, skill_id)
	elif backpack_panel != null:
		backpack_panel.set_status("技能学习失败：该技能可能已学会、技能槽已满或技能书数量不足。")

func _finish_skill_book_learning(roster_index: int, skill_id: String, replaced_skill_id: String = "") -> void:
	var skill_name := str(GameDatabase.get_skill(skill_id).get("name", skill_id))
	if backpack_panel != null:
		backpack_panel.refresh()
		backpack_panel.set_status("已学习：%s" % skill_name)
	_refresh_units()
	var slot := _find_selectable_slot(roster_index)
	if info_panel != null and info_panel.visible and slot >= 0:
		_show_unit_info(_unit_for_slot(slot))

func _open_skill_replace_popup(unit: Dictionary, skill_id: String) -> void:
	_close_skill_replace_popup()
	pending_skill_unit = unit
	pending_skill_book_id = skill_id
	skill_replace_panel = PanelContainer.new()
	skill_replace_panel.name = "SkillReplacePopup"
	skill_replace_panel.z_index = 220
	skill_replace_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	skill_replace_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "通用技能槽已满"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var skill_name := str(GameDatabase.get_skill(skill_id).get("name", skill_id))
	var hint := Label.new()
	hint.text = "选择要替换的技能以学习：%s" % skill_name
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	for equipped_id in unit.get("equipped_skills", []):
		var replace_button := Button.new()
		replace_button.text = "替换：%s" % str(GameDatabase.get_skill(str(equipped_id)).get("name", equipped_id))
		replace_button.custom_minimum_size.y = 40
		replace_button.pressed.connect(_on_skill_replace_selected.bind(str(equipped_id)))
		box.add_child(replace_button)
	var cancel_button := Button.new()
	cancel_button.text = "取消（不消耗技能书）"
	cancel_button.custom_minimum_size.y = 38
	cancel_button.pressed.connect(_close_skill_replace_popup)
	box.add_child(cancel_button)
	add_child(skill_replace_panel)
	skill_replace_panel.visible = true
	_layout_ui()

func _on_skill_replace_selected(replaced_skill_id: String) -> void:
	var roster_index := _find_roster_index(str(pending_skill_unit.get("id", "")))
	var skill_id := pending_skill_book_id
	if roster_index >= 0 and ProgressManager.use_skill_book(pending_skill_unit, skill_id, replaced_skill_id):
		_close_skill_replace_popup()
		_finish_skill_book_learning(roster_index, skill_id, replaced_skill_id)

func _close_skill_replace_popup() -> void:
	if skill_replace_panel != null:
		skill_replace_panel.queue_free()
		skill_replace_panel = null
	pending_skill_unit = {}
	pending_skill_book_id = ""

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
	if not placements.has(slot) and placements.size() >= ProgressManager.get_deployment_limit():
		_refresh_state()
		return
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
		var unit := _unit_for_slot(slot)
		if unit == null:
			continue
		preview_player_units.append(unit)
		_create_unit_view(unit)
		slot_views[slot] = unit_views[unit]
	for child in units_layer.get_children():
		if child.has_method("refresh"):
			child.refresh()

func _refresh_state() -> void:
	var placed := placements.size()
	if population_label != null:
		population_label.text = "上阵 %d/%d  ·  后备 %d/%d  ·  金币 %d" % [
			placed, ProgressManager.get_deployment_limit(), roster_units.size(),
			ProgressManager.MAX_ROSTER_SIZE, ProgressManager.get_gold()]
	for i in unit_cards.size():
		unit_cards[i].set_deployed(placements.has(i))
		unit_cards[i].modulate = Color(1.15, 1.15, 0.85) if i == selected_slot else Color.WHITE
	start_button.disabled = placed == 0 or placed > ProgressManager.get_deployment_limit()

func _on_start_pressed() -> void:
	if placements.is_empty() or placements.size() > ProgressManager.get_deployment_limit():
		return
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
