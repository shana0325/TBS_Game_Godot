# 战斗界面（自走棋·自动战斗）：渲染网格与单位，实时驱动 BattleManager.tick，
# 播放行动动画/日志，判定胜负后进入结算。
extends Control

const ANIM_SPEED := 1.0
const MOVE_STEP_TIME := 0.18

var tile_size: int = 64
var manager: BattleManager
var unit_views: Dictionary = {}
var _tween_running: int = 0

@onready var turn_label: Label = $TurnLabel
@onready var frenzy_label: Label = $FrenzyLabel
@onready var floor_label: Label = $FloorLabel
@onready var team_status_label: Label = $TeamStatusLabel
@onready var enemy_status_label: Label = $EnemyStatusLabel
@onready var grid_view: Node2D = $BattleView/GridView
@onready var units_layer: Node2D = $BattleView/UnitsLayer
@onready var log_list: VBoxContainer = $LogPanel/Scroll/LogList
@onready var log_panel: PanelContainer = $LogPanel
@onready var victory_label: Label = $VictoryLabel

var info_panel: UnitDetailPanel
var settings_panel: PanelContainer
var pause_btn: Button
var speed_btn: Button
var log_btn: Button
var action_buttons: Array[Control] = []
var roster_panel: PanelContainer
var roster_scroll: ScrollContainer
var roster_container: HBoxContainer
var battle_unit_cards: Array[DeploymentUnitCard] = []
var battle_speed: int = 1
const SPEED_OPTIONS := [1, 2, 3]
const MAX_LOG_ENTRIES := 100
const INFO_REFRESH_INTERVAL := 0.1
var log_buffer: Array[String] = []
var info_refresh_elapsed: float = 0.0
var skill_damage_queue: Array[Dictionary] = []

func _ready() -> void:
	# 暂停时本界面保持可交互（暂停/倍速/信息面板可用）
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 日志默认隐藏；隐藏期间只保存文本，不创建日志 Label 节点。
	log_panel.visible = false
	manager = BattleManager.new(GameSession.current_scenario, self, GameSession.deployed_units, GameSession.scenario_override)
	manager.setup()
	manager.setup_battle()
	battle_speed = clampi(GameSession.battle_speed, 1, SPEED_OPTIONS.size())
	Engine.time_scale = float(SPEED_OPTIONS[battle_speed - 1])
	# 与部署场景使用同一块战场安全区，切入战斗时保持格子大小和位置不变。
	tile_size = BattleLayout.compute_tile_size(manager.grid.width, manager.grid.height, _battle_board_available_size(get_viewport_rect().size), 0.86)
	_position_battle_view()
	grid_view.setup(manager.grid, tile_size)
	for unit in manager.units:
		_create_unit_view(unit)
	_flush_skill_damage_queue()
	_build_info_panel()
	_update_turn_label()
	if GameSession.mode == GameSession.MODE_TOWER:
		add_log("＝%s＝" % GameSession.get_floor_label())
	add_log("战斗开始！地图 %dx%d，我方 %d 单位，敌方 %d 单位" % [
		manager.grid.width, manager.grid.height,
		_count_alive(TurnManager.PLAYER_CAMP), _count_alive(TurnManager.ENEMY_CAMP)
	])
	_build_settings_ui()
	_build_speed_controls()
	_build_log_toggle()
	_build_battle_roster()
	action_buttons.append(log_btn)
	_layout_overlay_controls()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and manager != null:
		tile_size = BattleLayout.compute_tile_size(manager.grid.width, manager.grid.height, _battle_board_available_size(get_viewport_rect().size), 0.86)
		grid_view.tile_size = tile_size
		for unit_view in units_layer.get_children():
			if unit_view is UnitView:
				unit_view.tile_size = tile_size
				unit_view.refresh()
		for card in battle_unit_cards:
			card.set_tile_size(tile_size)
		_position_battle_view()
		_layout_overlay_controls()

# 统一放置战斗中的浮层控件，避免窗口尺寸变化后遮挡战场或跑出屏幕。
func _layout_overlay_controls() -> void:
	var vp := get_viewport_rect().size
	_layout_action_buttons(vp)
	if settings_panel != null:
		settings_panel.position = Vector2(maxf(20.0, vp.x - 320.0), 52.0)
	var settings_button := get_node_or_null("SettingsButton") as Button
	if settings_button != null:
		settings_button.position = Vector2(maxf(20.0, vp.x - 108.0), 12.0)
	if log_panel != null:
		# 日志窗口悬浮在底部单位栏上方，可以遮挡单位卡片但不改变战场位置。
		var tray_y := _roster_panel_y(vp)
		log_panel.position = Vector2(24.0, maxf(104.0, tray_y - 248.0))
		log_panel.size = Vector2(minf(520.0, vp.x - 48.0), 232.0)
	_layout_roster_panel(vp)
	if info_panel != null:
		var panel_size := Vector2(minf(760.0, vp.x - 32.0), minf(440.0, vp.y - 32.0))
		info_panel.position = Vector2(maxf(16.0, (vp.x - panel_size.x) / 2.0), maxf(16.0, (vp.y - panel_size.y) / 2.0))
		info_panel.size = panel_size
		# 让最小尺寸等于目标尺寸，避免内容把信息卡撑出屏幕（与滚动区最小高度配合）
		info_panel.custom_minimum_size = panel_size

# 战斗日志：默认隐藏，可点击展开/收起。
func _build_log_toggle() -> void:
	log_panel.visible = false
	log_btn = Button.new()
	log_btn.text = "展开日志"
	log_btn.custom_minimum_size = Vector2(110, 30)
	log_btn.position = Vector2(20, 200)
	log_btn.pressed.connect(_on_log_toggled)
	add_child(log_btn)

func _on_log_toggled() -> void:
	var should_show := not log_panel.visible
	if should_show:
		_render_log_buffer()
	else:
		_clear_log_nodes()
	log_panel.visible = should_show
	if log_btn != null:
		log_btn.text = "收起日志" if should_show else "展开日志"

func _build_battle_roster() -> void:
	# 战斗中保留底部单位栏作为阵容确认区，但卡片只读、不可拖动。
	roster_panel = PanelContainer.new()
	roster_panel.name = "BattleRosterPanel"
	roster_panel.custom_minimum_size = Vector2(0, 176)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	roster_scroll = ScrollContainer.new()
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_container = HBoxContainer.new()
	roster_container.add_theme_constant_override("separation", 10)
	roster_scroll.add_child(roster_container)
	margin.add_child(roster_scroll)
	roster_panel.add_child(margin)
	add_child(roster_panel)
	var roster_source: Array = GameSession.deployment_units
	if roster_source.is_empty():
		roster_source = GameSession.deployed_units
	for i in roster_source.size():
		var entry: Dictionary = roster_source[i]
		if _is_deployed_entry(entry):
			continue
		var card := DeploymentUnitCard.new()
		card.setup(i, str(entry.get("type", "Unit")), int(entry.get("roster_index", -1)), tile_size)
		card.set_drag_enabled(false)
		card.inspect_requested.connect(_on_battle_roster_inspect.bind(entry))
		roster_container.add_child(card)
		battle_unit_cards.append(card)
	_layout_roster_panel(get_viewport_rect().size)

func _is_deployed_entry(entry: Dictionary) -> bool:
	for deployed in GameSession.deployed_units:
		if typeof(deployed) != TYPE_DICTIONARY:
			continue
		if int(deployed.get("roster_index", -1)) == int(entry.get("roster_index", -1)) \
				and str(deployed.get("type", "")) == str(entry.get("type", "")):
			return true
	return false

func _on_battle_roster_inspect(_selectable_index: int, entry: Dictionary) -> void:
	# 未上场单位没有战斗实例，用同一份编成数据生成只读信息卡。
	var unit_type := str(entry.get("type", "Unit"))
	var config: Dictionary = GameDatabase.get_unit(unit_type)
	if config.is_empty():
		return
	var roster_index := int(entry.get("roster_index", -1))
	var roster_data: Dictionary = {}
	var roster: Array = GameDatabase.player_roster.get("units", [])
	if roster_index >= 0 and roster_index < roster.size():
		roster_data = roster[roster_index]
	var unit := Unit.create_from_config(unit_type, TurnManager.PLAYER_CAMP, Vector2i.ZERO, config, roster_data, GameDatabase)
	_show_unit_info(unit)

func _roster_panel_y(vp: Vector2) -> float:
	return maxf(250.0, vp.y - _roster_panel_height() - 36.0)

func _roster_panel_height() -> float:
	return DeploymentUnitCard.tray_height_for_tile(tile_size)

func _layout_roster_panel(vp: Vector2) -> void:
	if roster_panel == null:
		return
	roster_panel.position = Vector2(24.0, _roster_panel_y(vp))
	roster_panel.size = Vector2(maxf(320.0, vp.x - 48.0), _roster_panel_height())

# 暂停与倍速按钮（右侧操作区，位置与部署界面操作按钮一致）。
func _build_speed_controls() -> void:
	var vp := get_viewport_rect().size
	var action_x := maxf(20.0, vp.x - 244.0)
	pause_btn = Button.new()
	pause_btn.text = "暂停"
	pause_btn.custom_minimum_size = Vector2(110, 40)
	pause_btn.position = Vector2(action_x, vp.y - 64.0)
	pause_btn.pressed.connect(_on_pause_pressed)
	add_child(pause_btn)
	speed_btn = Button.new()
	speed_btn.text = "倍速 x%d" % battle_speed
	speed_btn.custom_minimum_size = Vector2(110, 40)
	speed_btn.position = Vector2(action_x, vp.y - 116.0)
	speed_btn.pressed.connect(_on_speed_pressed)
	add_child(speed_btn)
	# 操作区按“从下往上”维护，后续新增按钮追加到数组即可。
	action_buttons = [speed_btn, pause_btn]
	_layout_action_buttons(vp)

func _layout_action_buttons(vp: Vector2) -> void:
	if manager == null:
		return
	var board_right := 24.0 + manager.grid.width * tile_size
	var board_bottom := 104.0 + manager.grid.height * tile_size
	var action_x := minf(board_right + 24.0, vp.x - 244.0)
	var button_y := board_bottom - 40.0
	for button in action_buttons:
		if button == null:
			continue
		button.position = Vector2(maxf(20.0, action_x), button_y)
		button.size = Vector2(110.0, 40.0)
		button_y -= 52.0

func _on_pause_pressed() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	if pause_btn != null:
		pause_btn.text = "继续" if paused else "暂停"

func _on_speed_pressed() -> void:
	if get_tree().paused:
		return
	battle_speed = (battle_speed % SPEED_OPTIONS.size()) + 1
	GameSession.battle_speed = battle_speed
	Engine.time_scale = float(SPEED_OPTIONS[battle_speed - 1])
	if speed_btn != null:
		speed_btn.text = "倍速 x%d" % SPEED_OPTIONS[battle_speed - 1]

# 离开战斗场景时复位全局时间流速与暂停状态。
func _exit_tree() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0

# 战斗设置：右上角小型"设置"按钮 + 面板（伤害飙字开关等）。
func _build_settings_ui() -> void:
	var vp := get_viewport_rect().size
	var btn := Button.new()
	btn.name = "SettingsButton"
	btn.text = "设置"
	btn.custom_minimum_size = Vector2(88, 32)
	btn.position = Vector2(maxf(20.0, vp.x - 108.0), 12.0)
	btn.pressed.connect(_toggle_settings_panel)
	add_child(btn)

	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(maxf(20.0, vp.x - 320.0), 52.0)
	settings_panel.visible = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "战斗设置"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var dmg_check := CheckButton.new()
	dmg_check.text = "显示伤害数字"
	dmg_check.button_pressed = GameSettings.show_damage_numbers()
	dmg_check.toggled.connect(_on_damage_numbers_toggled)
	box.add_child(dmg_check)
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(100, 34)
	close_btn.pressed.connect(_toggle_settings_panel)
	box.add_child(close_btn)
	margin.add_child(box)
	settings_panel.add_child(margin)
	add_child(settings_panel)

func _toggle_settings_panel() -> void:
	if settings_panel != null:
		settings_panel.visible = not settings_panel.visible

func _on_damage_numbers_toggled(on: bool) -> void:
	GameSettings.set_damage_numbers(on)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if manager.winner != "":
		return
	var events: Array = manager.tick(delta)
	# 先启动行动动画（tween 从当前位置开始），再刷新位置，避免逻辑位置抢先造成瞬移
	for ev in events:
		_handle_event(ev)
	_refresh_units()
	if info_panel != null and info_panel.visible:
		info_refresh_elapsed += delta
		if info_refresh_elapsed >= INFO_REFRESH_INTERVAL:
			info_panel.refresh_current()
			info_refresh_elapsed = 0.0
	_update_turn_label()
	if manager.winner != "":
		_check_battle_end()

func get_database() -> Node:
	return GameDatabase

# --- 提供给战斗系统回调的接口 ---
func add_log(text: String) -> void:
	log_buffer.append(text)
	while log_buffer.size() > MAX_LOG_ENTRIES:
		log_buffer.pop_front()
	if not log_panel.visible:
		return
	_append_log_label(text)
	while log_list.get_child_count() > MAX_LOG_ENTRIES:
		var oldest: Node = log_list.get_child(0)
		log_list.remove_child(oldest)
		oldest.queue_free()

func _append_log_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(0.92, 0.92, 0.92)
	log_list.add_child(label)

func _clear_log_nodes() -> void:
	for child in log_list.get_children():
		var node: Node = child
		log_list.remove_child(node)
		node.queue_free()

func _render_log_buffer() -> void:
	_clear_log_nodes()
	for text in log_buffer:
		_append_log_label(text)

# --- 界面搭建 ---
func _position_battle_view() -> void:
	var view: Node2D = $BattleView
	view.position = Vector2(24.0, 104.0)

func _battle_board_available_size(vp: Vector2) -> Vector2:
	return Vector2(maxf(320.0, vp.x - 48.0), maxf(260.0, vp.y - 300.0))

func _create_unit_view(unit: Unit) -> void:
	var uv := UnitView.new()
	uv.setup(unit, tile_size)
	# 战场区域只保留小人、阵营框和血条，单位详情通过点击查看。
	uv.show_name = false
	uv.show_hp_text = false
	units_layer.add_child(uv)
	unit_views[unit] = uv

# --- 单位信息面板 ---
func _build_info_panel() -> void:
	info_panel = UnitDetailPanel.new()
	info_panel.name = "UnitInfoPanel"
	info_panel.custom_minimum_size = Vector2(680.0, 420.0)
	add_child(info_panel)
	info_panel.visible = false

# 显示指定单位的属性/装备/技能/Buff 信息。
func _show_unit_info(unit: Unit) -> void:
	if unit == null or not unit.alive:
		return
	info_panel.show_unit(unit)
	info_panel.visible = true
	info_refresh_elapsed = 0.0

func _hide_unit_info() -> void:
	info_panel.visible = false

# --- 输入：点击单位查看信息 ---
func _unhandled_input(event: InputEvent) -> void:
	if manager == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var unit := _unit_at_screen_position(event.position)
		if unit != null:
			_show_unit_info(unit)
		else:
			_hide_unit_info()
# 优先按 UnitView 的实际屏幕中心命中，再回退到网格坐标，兼容窗口缩放和战场偏移。
func _unit_at_screen_position(screen_pos: Vector2) -> Unit:
	var hit_radius := maxf(20.0, tile_size * 0.5)
	var nearest: Unit = null
	var nearest_distance := INF
	for candidate in unit_views:
		if not (candidate is Unit) or not candidate.alive:
			continue
		var view := unit_views.get(candidate) as Node2D
		if view == null:
			continue
		var distance := view.get_global_transform_with_canvas().origin.distance_to(screen_pos)
		if distance <= hit_radius and distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest != null:
		return nearest
	return manager.get_unit_at(_screen_to_cell(screen_pos))

func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var local := ($BattleView as Node2D).to_local(screen_pos)
	return Vector2i(floori(local.x / tile_size), floori(local.y / tile_size))

func _cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * tile_size + tile_size / 2.0, cell.y * tile_size + tile_size / 2.0)

# --- 事件处理 ---
func _handle_event(ev: Dictionary) -> void:
	var unit: Unit = ev.get("unit")
	if unit == null:
		return
	var action: String = ev.get("action", "")
	var unit_view: Node2D = unit_views.get(unit)
	match action:
		"attack":
			var target: Unit = ev.get("target")
			if target != null and unit_view != null:
				_play_attack_animation(unit_view, target)
				add_log("%s 攻击 %s" % [unit.get_display_name(), target.get_display_name()])
			_show_damage_popup(ev)
		"move", "move_attack":
			var to: Vector2i = ev.get("to")
			var t2: Unit = ev.get("target")
			if unit_view != null:
				if action == "move_attack" and t2 != null:
					# 移动结束后再播攻击动画（链条化），避免同一行动中攻击动画被移动吞掉
					_animate_unit_move(unit_view, ev.get("from", Vector2i(-1, -1)), to, \
						func(): _play_attack_animation(unit_view, t2))
				else:
					_animate_unit_move(unit_view, ev.get("from", Vector2i(-1, -1)), to)
			if action == "move_attack":
				if t2 != null:
					add_log("%s 攻击 %s" % [unit.get_display_name(), t2.get_display_name()])
				_show_damage_popup(ev)
		"wait":
			pass

# 伤害飙字：受击单位头上短暂显示红色数字（暴击带感叹号），可在设置中开关。
func _show_damage_popup(ev: Dictionary) -> void:
	if not GameSettings.show_damage_numbers():
		return
	var target: Unit = ev.get("target")
	var damage: int = ev.get("damage", 0)
	if target == null or damage <= 0:
		return
	var target_view: Node2D = unit_views.get(target)
	if target_view == null:
		return
	var crit: bool = ev.get("crit", false)
	var text: String = "-%d" % damage
	if crit:
		text += "!"
	_spawn_float_text(target_view.position, text, Color(1.0, 0.25, 0.2), 26 if crit else 22)

# 技能伤害飙字与普通攻击分色显示，并由技能触发系统统一上报。
func record_skill_damage(source: Unit, target: Unit, damage: int, skill_name: String) -> void:
	if target == null or damage <= 0:
		return
	var item: Dictionary = {"source": source, "target": target, "damage": damage, "skill_name": skill_name}
	skill_damage_queue.append(item)
	_flush_skill_damage_queue()

func _flush_skill_damage_queue() -> void:
	if units_layer == null:
		return
	var pending := skill_damage_queue.duplicate()
	skill_damage_queue.clear()
	for item in pending:
		var target: Unit = item.get("target")
		var target_view: Node2D = unit_views.get(target)
		if target_view == null:
			# 单位视图尚未创建时保留，待 _ready 完成后再显示。
			skill_damage_queue.append(item)
			continue
		if GameSettings.show_damage_numbers():
			_spawn_float_text(target_view.position + Vector2(22.0, 0.0), "技能 -%d" % int(item.get("damage", 0)), Color(0.86, 0.42, 1.0), 20)

# 生成一个向上飘动并淡出的文字。
func _spawn_float_text(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.position = pos + Vector2(-20, -tile_size / 2.0 - 6)
	units_layer.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 26.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _play_attack_animation(unit_view: Node2D, target: Unit) -> void:
	# 攻击动画：单位朝目标方向冲刺 + 回位，速度更快但仍可见
	if not (unit_view is UnitView):
		return
	var uv := unit_view as UnitView
	if uv.is_moving:
		return
	var target_view: Node2D = unit_views.get(target)
	if target_view == null:
		return
	var from := uv.position
	var to := target_view.position
	var dir := (to - from).normalized() * 14.0
	uv.is_moving = true
	uv.set_action("attack")
	var tween := uv.create_tween()
	tween.tween_property(uv, "position", from + dir, 0.1 / ANIM_SPEED)
	tween.tween_property(uv, "position", from, 0.14 / ANIM_SPEED)
	tween.finished.connect(func():
		uv.is_moving = false
		uv.set_action("stand")
		uv.refresh()
	)

# 按路径逐格移动：从移动前位置(from_cell)到目标，逐格补间；
# 移动补间结束后执行 follow_up（如连接攻击动画），无实际位移时直接执行 follow_up。
func _animate_unit_move(unit_view: Node2D, from_cell: Vector2i, to_cell: Vector2i, follow_up: Callable = Callable()) -> void:
	if unit_view == null or not (unit_view is UnitView):
		return
	var uv := unit_view as UnitView
	if from_cell.x < 0 or to_cell == from_cell:
		if follow_up.is_valid():
			follow_up.call()
		return
	var path: Array = []
	var start := manager.grid.get_tile(from_cell.x, from_cell.y)
	var goal := manager.grid.get_tile(to_cell.x, to_cell.y)
	if start != null and goal != null:
		path = Pathfinder.find_path(manager.grid, start, goal)
	if path.size() <= 1:
		if follow_up.is_valid():
			follow_up.call()
		return
	uv.set_action("move")
	var tween := uv.animate_move(path, MOVE_STEP_TIME / ANIM_SPEED)
	tween.finished.connect(func():
		uv.set_action("stand")
		if follow_up.is_valid():
			follow_up.call()
	)

# --- 刷新与结果 ---
func _refresh_units() -> void:
	for child in units_layer.get_children():
		if child.has_method("refresh"):
			child.refresh()

func _count_alive(camp: String) -> int:
	var count := 0
	for unit in manager.units:
		if unit is Unit and unit.alive and unit.camp == camp:
			count += 1
	return count

# 汇总本场战斗各单位统计（伤害/治疗/承伤），供结算与奖励界面展示。
func _collect_battle_stats() -> Array:
	var stats: Array = []
	for unit in manager.units:
		if not (unit is Unit):
			continue
		stats.append({
			"name": unit.get_display_name(),
			"camp": unit.camp,
			"damage": unit.damage_dealt,
			"heal": unit.healing_done,
			"taken": unit.damage_taken,
		})
	return stats

func _check_battle_end() -> void:
	if manager.winner == "":
		return
	# 战斗结束：解除暂停与时间缩放，倍速设置本身保留到下一场战斗。
	get_tree().paused = false
	Engine.time_scale = 1.0
	if manager.winner == TurnManager.PLAYER_CAMP:
		_apply_victory_rewards()
	GameSession.record_result(manager.winner)
	GameSession.battle_stats = _collect_battle_stats()
	var is_tower_win: bool = GameSession.mode == GameSession.MODE_TOWER and manager.winner == TurnManager.PLAYER_CAMP
	if GameSession.mode == GameSession.MODE_TOWER and not is_tower_win:
		# 塔模式失败：结束本局
		GameSession.end_tower_run()
	victory_label.visible = true
	victory_label.text = ("%s 通关！" % GameSession.get_floor_label()) if is_tower_win \
		else ("胜利！" if manager.winner == TurnManager.PLAYER_CAMP else "失败…")
	add_log(victory_label.text)
	await get_tree().create_timer(1.5).timeout
	if is_tower_win:
		_show_reward_overlay()
	else:
		get_tree().change_scene_to_file("res://scenes/result_screen.tscn")

func _show_reward_overlay() -> void:
	# 爬塔胜利时在当前战斗场景上方展开奖励弹窗，战场不会跳转或缩放。
	var reward_overlay := preload("res://scripts/screens/reward_screen.gd").new()
	reward_overlay.setup_embedded()
	reward_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(reward_overlay)

# 胜利后发放经验并写回 roster，记录经验/升级到日志与结算摘要。
func _apply_victory_rewards() -> void:
	var reports: Array = manager.grant_victory_exp(100)
	GameSession.victory_rewards = reports
	for report in reports:
		var label: String = report.get("unit_type", "")
		add_log("%s 获得 %d 经验" % [label, int(report.get("exp_gained", 0))])
		if int(report.get("levels_gained", 0)) > 0:
			add_log("%s 升级到 %d 级！" % [label, int(report.get("level", 1))])

func _update_turn_label() -> void:
	if manager == null or manager.turn_manager == null:
		return
	var text: String = manager.turn_manager.get_turn_label()
	turn_label.text = text
	var frenzy_percent := manager.get_final_damage_bonus_percent()
	frenzy_label.visible = frenzy_percent > 0.0
	if frenzy_percent > 0.0:
		frenzy_label.text = "双方受到最终伤害增加%d%%" % int(frenzy_percent)
	floor_label.text = GameSession.get_floor_label() if GameSession.mode == GameSession.MODE_TOWER else GameSession.current_scenario
	team_status_label.text = "我方 %d/%d" % [_count_alive(TurnManager.PLAYER_CAMP), _count_camp(TurnManager.PLAYER_CAMP)]
	enemy_status_label.text = "敌方 %d/%d" % [_count_alive(TurnManager.ENEMY_CAMP), _count_camp(TurnManager.ENEMY_CAMP)]

func _count_camp(camp: String) -> int:
	var count := 0
	for unit in manager.units:
		if unit is Unit and unit.camp == camp:
			count += 1
	return count
