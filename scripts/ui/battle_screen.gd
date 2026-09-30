# 战斗界面（自走棋·自动战斗）：渲染网格与单位，实时驱动 BattleManager.tick，
# 播放行动动画，判定胜负后进入结算。
extends Control

const ANIM_SPEED := 1.0
const MOVE_STEP_TIME := 0.18

var tile_size: int = 64
var manager: BattleManager
var unit_views: Dictionary = {}
var _tween_running: int = 0

@onready var stage: BattlefieldStage = $Stage
@onready var turn_label: Label = $Stage/TurnLabel
@onready var frenzy_label: Label = $Stage/SubLabel
@onready var floor_label: Label = $Stage/FloorLabel
@onready var team_status_label: Label = $Stage/TeamLabel
@onready var enemy_status_label: Label = $Stage/EnemyLabel
@onready var grid_view: Node2D = $Stage/BattleView/GridView
@onready var units_layer: Node2D = $Stage/BattleView/UnitsLayer

var info_panel: UnitDetailPanel
var settings_panel: PanelContainer
var pause_btn: Button
var speed_btn: Button
var action_buttons: Array[Control] = []
var roster_panel: PanelContainer
var roster_scroll: ScrollContainer
var roster_container: HBoxContainer
var battle_unit_cards: Array[DeploymentUnitCard] = []
var battle_speed: int = 1
const SPEED_OPTIONS := [1, 2, 3]
const INFO_REFRESH_INTERVAL := 0.1
var info_refresh_elapsed: float = 0.0
var skill_damage_queue: Array[Dictionary] = []
var reward_overlay: Control
var reward_toggle_layer: CanvasLayer
var reward_toggle_button: Button

func _ready() -> void:
	# 暂停时本界面保持可交互（暂停/倍速/信息面板可用）
	process_mode = Node.PROCESS_MODE_ALWAYS
	manager = BattleManager.new(GameSession.current_scenario, self, GameSession.deployed_units, GameSession.scenario_override)
	manager.setup()
	manager.setup_battle()
	battle_speed = clampi(GameSession.battle_speed, 1, SPEED_OPTIONS.size())
	Engine.time_scale = float(SPEED_OPTIONS[battle_speed - 1])
	# 部署与战斗复用同一个战场节点，只替换棋子与阶段操作。
	stage.clear_contents()
	stage.configure(manager.grid)
	tile_size = stage.tile_size
	for unit in manager.units:
		_create_unit_view(unit)
	_flush_skill_damage_queue()
	_build_info_panel()
	_update_turn_label()
	_build_settings_ui()
	_build_speed_controls()
	_build_battle_roster()
	_layout_overlay_controls()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and manager != null:
		stage.resize_board()
		tile_size = stage.tile_size
		for unit_view in units_layer.get_children():
			if unit_view is UnitView:
				unit_view.tile_size = tile_size
				unit_view.refresh()
		for card in battle_unit_cards:
			card.set_tile_size(mini(tile_size, 74))
		_layout_overlay_controls()

# 统一放置战斗中的浮层控件，避免窗口尺寸变化后遮挡战场或跑出屏幕。
func _layout_overlay_controls() -> void:
	var vp := get_viewport_rect().size
	_layout_action_buttons(vp)
	if settings_panel != null:
		settings_panel.position = Vector2(maxf(20.0, vp.x - 320.0), 52.0)
	var settings_button := get_node_or_null("SettingsButton") as Button
	if settings_button != null:
		settings_button.position = Vector2(maxf(20.0, vp.x - 108.0), 27.0)
	if info_panel != null:
		info_panel.fit_to_viewport()
	if reward_toggle_button != null:
		reward_toggle_button.position = Vector2((vp.x - reward_toggle_button.size.x) / 2.0, 12.0)

func _build_battle_roster() -> void:
	# 战斗阶段只显示未上场角色，已在棋盘上的单位不占备战卡位。
	roster_panel = stage.roster_panel
	roster_scroll = stage.roster_scroll
	roster_container = stage.roster_container
	var roster_source: Array = GameSession.deployment_units
	if roster_source.is_empty():
		roster_source = GameSession.deployed_units
	if roster_source.is_empty():
		# 直接运行战斗场景时，也让底栏展示当前上场队伍。
		for i in manager.units.size():
			var battle_unit := manager.units[i] as Unit
			if battle_unit != null and battle_unit.camp == TurnManager.PLAYER_CAMP:
				roster_source.append({"type": battle_unit.unit_type, "roster_index": -1,
					"battle_unit_index": i})
	var reserve_entries: Array[Dictionary] = []
	for item in roster_source:
		var entry: Dictionary = item
		if int(entry.get("battle_unit_index", -1)) >= 0 or _deployed_unit_for_entry(entry) != null:
			continue
		reserve_entries.append(entry)
	for i in reserve_entries.size():
		var entry: Dictionary = reserve_entries[i]
		var card := DeploymentUnitCard.new()
		card.setup(i, str(entry.get("type", "Unit")), int(entry.get("roster_index", -1)), mini(tile_size, 74))
		card.bench_slot = int(entry.get("bench_slot", i))
		card.set_drag_enabled(false)
		card.inspect_requested.connect(_on_battle_roster_inspect.bind(entry))
		roster_container.add_child(card)
		battle_unit_cards.append(card)
	stage.arrange_bench_cards(battle_unit_cards)

func _on_battle_roster_inspect(_selectable_index: int, entry: Dictionary) -> void:
	var battle_index := int(entry.get("battle_unit_index", -1))
	if battle_index >= 0 and battle_index < manager.units.size():
		_show_unit_info(manager.units[battle_index] as Unit)
		return
	var deployed_unit := _deployed_unit_for_entry(entry)
	if deployed_unit != null:
		_show_unit_info(deployed_unit)
		return
	# 未上场单位用编成数据生成只读信息卡。
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

# 将底部编成项映射到开局部署的实时单位，避免资料页显示静态属性。
func _deployed_unit_for_entry(entry: Dictionary) -> Unit:
	for i in GameSession.deployed_units.size():
		var deployed: Dictionary = GameSession.deployed_units[i]
		if int(deployed.get("roster_index", -1)) == int(entry.get("roster_index", -1)) \
				and str(deployed.get("type", "")) == str(entry.get("type", "")) \
				and i < manager.units.size():
			return manager.units[i] as Unit
	return null

# 暂停与倍速作为棋盘右侧的紧凑战斗控件。
func _build_speed_controls() -> void:
	var vp := get_viewport_rect().size
	var action_x := maxf(20.0, vp.x - 244.0)
	pause_btn = Button.new()
	pause_btn.text = "暂停"
	pause_btn.custom_minimum_size = Vector2(110, 40)
	pause_btn.position = Vector2(action_x, vp.y - 64.0)
	pause_btn.pressed.connect(_on_pause_pressed)
	_style_battle_button(pause_btn)
	add_child(pause_btn)
	speed_btn = Button.new()
	speed_btn.text = "倍速 x%d" % battle_speed
	speed_btn.custom_minimum_size = Vector2(110, 40)
	speed_btn.position = Vector2(action_x, vp.y - 116.0)
	speed_btn.pressed.connect(_on_speed_pressed)
	_style_battle_button(speed_btn)
	add_child(speed_btn)
	# 操作区按“从下往上”维护，后续新增按钮追加到数组即可。
	action_buttons = [speed_btn, pause_btn]
	_layout_action_buttons(vp)

func _layout_action_buttons(vp: Vector2) -> void:
	if manager == null:
		return
	var board_origin := stage.battle_view.position
	var board_right := board_origin.x + manager.grid.width * tile_size
	var board_bottom := board_origin.y + manager.grid.height * tile_size
	var action_x := minf(board_right + 22.0, vp.x - 132.0)
	var button_y := board_bottom - 44.0
	for button in action_buttons:
		if button == null:
			continue
		button.position = Vector2(maxf(20.0, action_x), button_y)
		button.size = Vector2(104.0, 42.0)
		button_y -= 50.0

# 为战斗操作提供统一的深色实体按钮和轻金色悬停反馈。
func _style_battle_button(button: Button) -> void:
	BattlefieldStage.style_action_button(button)

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
	btn.position = Vector2(maxf(20.0, vp.x - 108.0), 27.0)
	btn.pressed.connect(_toggle_settings_panel)
	_style_battle_button(btn)
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

# --- 界面搭建 ---
func _create_unit_view(unit: Unit) -> void:
	var uv := UnitView.new()
	uv.setup(unit, tile_size)
	# 战场区域只保留小人、阵营框和血条，单位详情通过点击查看。
	uv.show_name = false
	uv.show_hp_text = false
	uv.battle_style = true
	units_layer.add_child(uv)
	unit_views[unit] = uv

# --- 单位信息面板 ---
func _build_info_panel() -> void:
	info_panel = UnitDetailPanel.new()
	info_panel.name = "UnitInfoPanel"
	add_child(info_panel)
	info_panel.visible = false

# 显示指定单位的属性、技能和 Buff 信息。
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
	if manager == null or (stage != null and stage.blocks_board_input()):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if info_panel != null and info_panel.visible and info_panel.get_global_rect().has_point(event.position):
			return
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
	var local := stage.battle_view.to_local(screen_pos)
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
			if action == "move_attack" and t2 != null:
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
		var blocked := manager.get_occupied_cells(uv.unit)
		# 逻辑移动已完成，当前单位位于终点；动画回放时起点和终点都必须可用。
		blocked.erase(from_cell)
		blocked.erase(to_cell)
		path = Pathfinder.find_path(manager.grid, start, goal, blocked)
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
	# 定时召唤会在战斗开始后追加单位，首次刷新时为其建立可见小人。
	for unit in manager.units:
		if unit is Unit and not unit_views.has(unit):
			_create_unit_view(unit)
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

# 战斗结束后立即进入结算或展开遗物奖励，不再插入通关横幅和等待。
func _check_battle_end() -> void:
	if manager.winner == "":
		return
	# 战斗结束：解除暂停与时间缩放，倍速设置本身保留到下一场战斗。
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameSession.record_result(manager.winner)
	GameSession.battle_stats = _collect_battle_stats()
	var is_tower_win: bool = GameSession.mode == GameSession.MODE_TOWER and manager.winner == TurnManager.PLAYER_CAMP
	if GameSession.mode == GameSession.MODE_TOWER and not is_tower_win:
		# 塔模式失败：结束本局
		GameSession.end_tower_run()
	if is_tower_win:
		_show_reward_overlay()
	else:
		get_tree().change_scene_to_file("res://scenes/result_screen.tscn")

func _show_reward_overlay() -> void:
	# 爬塔胜利时在当前战斗场景上方展开奖励弹窗，战场不会跳转或缩放。
	reward_overlay = preload("res://scripts/screens/reward_screen.gd").new()
	reward_overlay.setup_embedded()
	reward_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(reward_overlay)
	_build_reward_toggle_button()

# 在独立画布层创建奖励开关，避免被奖励遮罩或战斗控件拦截。
func _build_reward_toggle_button() -> void:
	if reward_toggle_layer != null:
		reward_toggle_layer.queue_free()
	reward_toggle_layer = CanvasLayer.new()
	reward_toggle_layer.name = "RewardToggleLayer"
	reward_toggle_layer.layer = 100
	add_child(reward_toggle_layer)
	reward_toggle_button = Button.new()
	reward_toggle_button.name = "RewardToggleButton"
	reward_toggle_button.text = "隐藏奖励"
	reward_toggle_button.custom_minimum_size = Vector2(136, 36)
	reward_toggle_button.size = Vector2(136, 36)
	reward_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_toggle_button.process_mode = Node.PROCESS_MODE_ALWAYS
	reward_toggle_button.pressed.connect(_on_reward_toggle_pressed)
	reward_toggle_layer.add_child(reward_toggle_button)
	_layout_overlay_controls()

# 切换奖励弹窗，并同步按钮文字。
func _on_reward_toggle_pressed() -> void:
	if reward_overlay == null or not is_instance_valid(reward_overlay):
		return
	var showing := bool(reward_overlay.call("toggle_embedded_rewards"))
	reward_toggle_button.text = "隐藏奖励" if showing else "展开奖励"

func _update_turn_label() -> void:
	if manager == null or manager.turn_manager == null:
		return
	var seconds := floori(manager.turn_manager.battle_time)
	turn_label.text = "交战  %02d:%02d" % [seconds / 60, seconds % 60]
	var frenzy_percent := manager.get_final_damage_bonus_percent()
	frenzy_label.visible = frenzy_percent > 0.0
	if stage.relic_scroll != null:
		stage.relic_scroll.visible = true
		stage.relic_button.visible = true
	if frenzy_percent > 0.0:
		frenzy_label.position.x = stage.relic_scroll.position.x + stage.relic_scroll.size.x + 16.0
		frenzy_label.text = "狂暴 · 双方伤害 +%d%%" % int(frenzy_percent)
	floor_label.text = GameSession.get_floor_label() if GameSession.mode == GameSession.MODE_TOWER else manager.scenario_name
	team_status_label.text = "我方 %d/%d" % [_count_alive(TurnManager.PLAYER_CAMP), _count_camp(TurnManager.PLAYER_CAMP)]
	enemy_status_label.text = "敌方 %d/%d" % [_count_alive(TurnManager.ENEMY_CAMP), _count_camp(TurnManager.ENEMY_CAMP)]

func _count_camp(camp: String) -> int:
	var count := 0
	for unit in manager.units:
		if unit is Unit and unit.camp == camp:
			count += 1
	return count
