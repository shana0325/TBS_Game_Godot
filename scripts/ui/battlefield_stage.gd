# 部署与战斗共用的战场画面：统一背景、棋盘、顶部信息和底部阵容栏布局。
class_name BattlefieldStage
extends Control

const BATTLE_FLOOR := preload("res://assets/ui/abyss_battle_floor.png")
signal bench_move_requested(selectable_index: int, target_slot: int)

var grid: Grid
var tile_size: int = 64
var relic_scroll: ScrollContainer
var relic_button: Button
var relic_gallery: Control
var relic_gallery_grid: GridContainer
var relic_detail_popup: RelicDetailPopup

@onready var battle_view: Node2D = $BattleView
@onready var grid_view: Node2D = $BattleView/GridView
@onready var units_layer: Node2D = $BattleView/UnitsLayer
@onready var roster_panel: PanelContainer = $RosterPanel
@onready var roster_scroll: ScrollContainer = $RosterPanel/Margin/Scroll
@onready var roster_container: HBoxContainer = $RosterPanel/Margin/Scroll/Units
@onready var turn_label: Label = $TurnLabel
@onready var floor_label: Label = $FloorLabel
@onready var sub_label: Label = $SubLabel
@onready var team_label: Label = $TeamLabel
@onready var enemy_label: Label = $EnemyLabel

# 初次载入时给共享组件应用一致的战斗视觉样式。
func _ready() -> void:
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.055, 0.047, 0.085, 0.91)
	header_style.border_color = Color(0.55, 0.41, 0.29, 0.84)
	header_style.border_width_bottom = 2
	$Header.add_theme_stylebox_override("panel", header_style)
	turn_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.65))
	turn_label.add_theme_font_size_override("font_size", 23)
	floor_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.72))
	floor_label.add_theme_font_size_override("font_size", 28)
	sub_label.add_theme_color_override("font_color", Color(0.95, 0.48, 0.34))
	sub_label.add_theme_font_size_override("font_size", 17)
	team_label.add_theme_color_override("font_color", Color(0.70, 0.91, 0.80))
	enemy_label.add_theme_color_override("font_color", Color(1.0, 0.70, 0.68))
	var tray_style := StyleBoxFlat.new()
	tray_style.bg_color = Color(0.045, 0.04, 0.08, 0.88)
	tray_style.border_color = Color(0.62, 0.48, 0.31, 0.7)
	tray_style.border_width_top = 2
	tray_style.set_corner_radius_all(10)
	roster_panel.add_theme_stylebox_override("panel", tray_style)
	relic_detail_popup = RelicDetailPopup.new()
	relic_detail_popup.name = "RelicDetailPopup"
	add_child(relic_detail_popup)
	_build_relic_bar()
	_build_relic_gallery()
	_layout()

# 顶部遗物标题固定在滚动区域外，图标仍可横向滚动。
func _build_relic_bar() -> void:
	relic_button = Button.new()
	relic_button.name = "RelicListButton"
	relic_button.text = "已有遗物"
	relic_button.position = Vector2(20, 46)
	relic_button.size = Vector2(92, 36)
	relic_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	style_action_button(relic_button)
	relic_button.pressed.connect(_open_relic_gallery)
	add_child(relic_button)
	relic_scroll = ScrollContainer.new()
	relic_scroll.name = "RelicScroll"
	relic_scroll.position = Vector2(118, 44)
	relic_scroll.size = Vector2(390, 40)
	relic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	relic_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	relic_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(relic_scroll)

# 弹出的完整遗物列表与战场共用，所有图标均可继续打开详情。
func _build_relic_gallery() -> void:
	relic_gallery = Control.new()
	relic_gallery.name = "RelicGallery"
	relic_gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	relic_gallery.mouse_filter = Control.MOUSE_FILTER_STOP
	relic_gallery.z_index = 550
	relic_gallery.visible = false
	add_child(relic_gallery)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_relic_gallery_shade_input)
	relic_gallery.add_child(shade)
	var panel := PanelContainer.new()
	panel.name = "GalleryPanel"
	panel.add_theme_stylebox_override("panel", MenuStyle.frame_panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_relic_gallery_panel_input)
	relic_gallery.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "已有遗物"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#f3d79f"))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭  ×"
	close_button.custom_minimum_size = Vector2(90, 36)
	close_button.pressed.connect(_close_relic_gallery)
	header.add_child(close_button)
	var scroll := ScrollContainer.new()
	scroll.name = "GalleryScroll"
	scroll.gui_input.connect(_on_relic_gallery_panel_input)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	relic_gallery_grid = GridContainer.new()
	relic_gallery_grid.columns = 5
	relic_gallery_grid.add_theme_constant_override("h_separation", 14)
	relic_gallery_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(relic_gallery_grid)

# 展开当前 Run 的完整遗物列表，并让界面阻止鼠标穿透到棋盘。
func _open_relic_gallery() -> void:
	for child in relic_gallery_grid.get_children():
		relic_gallery_grid.remove_child(child)
		child.queue_free()
	for relic_id in GameSession.run_relics:
		var id := str(relic_id)
		var relic: Dictionary = GameDatabase.get_relic(id)
		if relic.is_empty():
			continue
		var entry := Button.new()
		entry.custom_minimum_size = Vector2(126, 132)
		entry.text = "%s%s" % [str(relic.get("name", id)), " ×%d" % GameSession.get_relic_stack(id) if GameSession.get_relic_stack(id) > 1 else ""]
		entry.icon = ArtManager.get_relic_icon(id)
		entry.expand_icon = true
		entry.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry.pressed.connect(show_relic_details.bind(id))
		entry.gui_input.connect(_on_relic_gallery_panel_input)
		relic_gallery_grid.add_child(entry)
	if relic_gallery_grid.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "暂无遗物"
		relic_gallery_grid.add_child(empty)
	relic_gallery.visible = true
	_layout_relic_gallery()
	relic_gallery.move_to_front()
	relic_detail_popup.move_to_front()

# 关闭遗物总览，但不改变已打开的单件详情状态。
func _close_relic_gallery() -> void:
	relic_gallery.hide()

# 供部署和战斗控制器统一判断遗物弹窗是否占用棋盘输入。
func blocks_board_input() -> bool:
	return (relic_gallery != null and relic_gallery.visible) \
		or (relic_detail_popup != null and relic_detail_popup.visible) \
		or (relic_detail_popup != null and relic_detail_popup.input_blocker != null \
		and relic_detail_popup.input_blocker.visible)

# 点击遮罩空白处关闭总览，阻止事件继续传到下方单位。
func _on_relic_gallery_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_close_relic_gallery()
		get_viewport().set_input_as_handled()

# 总览卡片内部右键关闭，左键仍交给各图标及关闭按钮。
func _on_relic_gallery_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_close_relic_gallery()
		get_viewport().set_input_as_handled()

# ESC 或右键关闭总览；详情弹窗先处理输入，避免同时关闭两层。
func _unhandled_input(event: InputEvent) -> void:
	if relic_gallery == null or not relic_gallery.visible or relic_detail_popup.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_relic_gallery()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_close_relic_gallery()
		get_viewport().set_input_as_handled()

# 随视口变化让遗物总览居中且保持可滚动高度。
func _layout_relic_gallery() -> void:
	if relic_gallery == null:
		return
	var vp := get_viewport_rect().size
	var panel := relic_gallery.get_node("GalleryPanel") as PanelContainer
	panel.size = Vector2(minf(760.0, vp.x - 48.0), minf(570.0, vp.y - 48.0))
	panel.position = (vp - panel.size) * 0.5

# 根据关卡网格计算两阶段共用的格子尺寸并刷新棋盘。
func configure(p_grid: Grid) -> void:
	grid = p_grid
	resize_board()
	grid_view.set_battle_floor(BATTLE_FLOOR)
	grid_view.setup(grid, tile_size)

# 窗口变化时同时刷新棋盘、阵容栏和顶部信息的位置。
func resize_board() -> void:
	if grid == null:
		return
	var vp := get_viewport_rect().size
	tile_size = BattleLayout.compute_tile_size(grid.width, grid.height,
		Vector2(maxf(320.0, vp.x - 180.0), maxf(260.0, vp.y - 260.0)), 0.98)
	grid_view.tile_size = tile_size
	grid_view.queue_redraw()
	for child in roster_container.get_children():
		if child is PanelContainer:
			child.custom_minimum_size = Vector2(mini(tile_size, 74) + 16, mini(tile_size, 74) + 52)
	_layout()

# 返回当前棋盘边缘，供阶段专属操作按钮贴齐。
func board_rect() -> Rect2:
	if grid == null:
		return Rect2()
	return Rect2(battle_view.position, Vector2(grid.width, grid.height) * tile_size)

# 清空上一阶段的阵容卡和棋子，交接战场时保留节点本身。
func clear_contents() -> void:
	for child in roster_container.get_children():
		roster_container.remove_child(child)
		child.queue_free()
	for child in get_children():
		if child is DeploymentUnitCard:
			remove_child(child)
			child.queue_free()
	for child in units_layer.get_children():
		units_layer.remove_child(child)
		child.queue_free()
	grid_view.set_highlights([], [])
	grid_view.set_target_cells([])
	grid_view.set_selected(Vector2i(-1, -1))
	grid_view.set_hover(Vector2i(-1, -1))

# 按固定槽位重排备战卡；部署中的单位留下空位，不让其他卡自动左移。
func arrange_bench_cards(cards: Array) -> void:
	var already_arranged := roster_container.get_child_count() == ProgressManager.MAX_ROSTER_SIZE
	if already_arranged:
		for slot_index in ProgressManager.MAX_ROSTER_SIZE:
			var expected: DeploymentUnitCard = null
			for item in cards:
				var candidate := item as DeploymentUnitCard
				if candidate != null and candidate.bench_slot == slot_index and not candidate.deployed:
					expected = candidate
					break
			var current := roster_container.get_child(slot_index)
			if (expected != null and current != expected) or (expected == null and not current is BenchSlot):
				already_arranged = false
				break
	if already_arranged:
		return
	for child in roster_container.get_children():
		roster_container.remove_child(child)
		if child is BenchSlot:
			child.queue_free()
	for item in cards:
		var card := item as DeploymentUnitCard
		if card != null and card.get_parent() == self:
			remove_child(card)
	for slot_index in ProgressManager.MAX_ROSTER_SIZE:
		var card_at_slot: DeploymentUnitCard = null
		for item in cards:
			var card := item as DeploymentUnitCard
			if card != null and card.bench_slot == slot_index and not card.deployed:
				card_at_slot = card
				break
		if card_at_slot != null:
			roster_container.add_child(card_at_slot)
			continue
		var slot := BenchSlot.new()
		slot.slot_index = slot_index
		slot.custom_minimum_size = Vector2(mini(tile_size, 74) + 16, mini(tile_size, 74) + 52)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.09, 0.15, 0.52)
		style.border_color = Color(0.68, 0.57, 0.39, 0.70)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		slot.add_theme_stylebox_override("panel", style)
		slot.unit_dropped.connect(bench_move_requested.emit)
		roster_container.add_child(slot)
	for item in cards:
		var card := item as DeploymentUnitCard
		if card != null and card.deployed:
			add_child(card)

# 根据鼠标松开的位置匹配可见备战格；落在格间空隙时采用最近的格心。
func bench_slot_at(screen_position: Vector2) -> int:
	var drop_area := roster_scroll.get_global_rect().grow_individual(0.0, 20.0, 0.0, 12.0)
	if not drop_area.has_point(screen_position):
		return -1
	var nearest_slot := -1
	var nearest_distance := INF
	for i in roster_container.get_child_count():
		var child := roster_container.get_child(i) as Control
		if child == null:
			continue
		var rect := child.get_global_rect()
		if rect.has_point(screen_position):
			return i
		var distance := absf(rect.get_center().x - screen_position.x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_slot = i
	return nearest_slot

# 统一控制战场与阵容栏位置，避免开始战斗时棋盘跳动。
func _layout() -> void:
	var vp := get_viewport_rect().size
	roster_panel.position = Vector2(16.0, maxf(240.0, vp.y - tray_height() - 14.0))
	roster_panel.size = Vector2(maxf(320.0, vp.x - 32.0), tray_height())
	if grid != null:
		var board_size := Vector2(grid.width, grid.height) * tile_size
		var top := 100.0
		var bottom := roster_panel.position.y - 14.0
		battle_view.position = Vector2((vp.x - board_size.x) * 0.5,
			top + maxf(0.0, bottom - top - board_size.y) * 0.5)
	turn_label.position = Vector2(26.0, 12.0)
	turn_label.size = Vector2(350.0, 34.0)
	sub_label.position = Vector2(26.0, 51.0)
	sub_label.size = Vector2(420.0, 27.0)
	floor_label.position = Vector2(vp.x * 0.5 - 220.0, 14.0)
	floor_label.size = Vector2(440.0, 42.0)
	team_label.position = Vector2(vp.x - 350.0, 10.0)
	team_label.size = Vector2(215.0, 31.0)
	enemy_label.position = Vector2(vp.x - 350.0, 46.0)
	enemy_label.size = Vector2(215.0, 31.0)
	if relic_scroll != null:
		relic_scroll.size.x = minf(390.0, maxf(120.0, vp.x * 0.31 - 98.0))
	_layout_relic_gallery()

# 阵容栏高度跟随卡片上限，窗口大小变化时不挤压棋盘。
func tray_height() -> float:
	return float(mini(tile_size, 74) + 68)

# 阶段操作共用深色按钮样式，部署和战斗只替换按钮行为。
static func style_action_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.09, 0.16, 0.92) if state == "normal" \
			else Color(0.22, 0.17, 0.24, 0.96) if state == "hover" \
			else Color(0.31, 0.24, 0.27, 0.98)
		style.border_color = Color(0.62, 0.49, 0.35, 0.84)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.74))
	button.add_theme_font_size_override("font_size", 17)

# 两阶段的遗物图标共用同一详情弹窗。
func show_relic_details(relic_id: String) -> void:
	if relic_detail_popup != null:
		relic_detail_popup.show_relic(relic_id)
