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
@onready var floor_label: Label = $FloorLabel
@onready var team_status_label: Label = $TeamStatusLabel
@onready var enemy_status_label: Label = $EnemyStatusLabel
@onready var grid_view: Node2D = $BattleView/GridView
@onready var units_layer: Node2D = $BattleView/UnitsLayer
@onready var log_list: VBoxContainer = $LogPanel/Scroll/LogList
@onready var log_panel: PanelContainer = $LogPanel
@onready var victory_label: Label = $VictoryLabel

var info_panel: PanelContainer
var info_label: Label
var info_portrait: TextureRect
var settings_panel: PanelContainer
var pause_btn: Button
var speed_btn: Button
var log_btn: Button
var battle_speed: int = 1
const SPEED_OPTIONS := [1, 2, 3]

func _ready() -> void:
	# 暂停时本界面保持可交互（暂停/倍速/信息面板可用）
	process_mode = Node.PROCESS_MODE_ALWAYS
	manager = BattleManager.new(GameSession.current_scenario, self, GameSession.deployed_units, GameSession.scenario_override)
	manager.setup()
	manager.setup_battle()
	tile_size = BattleLayout.compute_tile_size(manager.grid.width, manager.grid.height, get_viewport_rect().size)
	_position_battle_view()
	grid_view.setup(manager.grid, tile_size)
	for unit in manager.units:
		_create_unit_view(unit)
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
	_layout_overlay_controls()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and manager != null:
		_position_battle_view()
		_layout_overlay_controls()

# 统一放置战斗中的浮层控件，避免窗口尺寸变化后遮挡战场或跑出屏幕。
func _layout_overlay_controls() -> void:
	var vp := get_viewport_rect().size
	if pause_btn != null:
		pause_btn.position = Vector2(vp.x - 260.0, vp.y - 56.0)
	if speed_btn != null:
		speed_btn.position = Vector2(vp.x - 390.0, vp.y - 56.0)
	if settings_panel != null:
		settings_panel.position = Vector2(vp.x - 320.0, vp.y - 196.0)
	var settings_button := get_node_or_null("SettingsButton") as Button
	if settings_button != null:
		settings_button.position = Vector2(vp.x - 130.0, vp.y - 56.0)
	if log_btn != null:
		log_btn.position = Vector2(20.0, vp.y - 56.0)
	if log_panel != null:
		log_panel.position = Vector2(20.0, vp.y - 300.0)
		log_panel.size = Vector2(360.0, 240.0)
	if info_panel != null:
		info_panel.position = Vector2(maxf(16.0, vp.x - 324.0), 72.0)
		info_panel.size = Vector2(300.0, minf(560.0, maxf(260.0, vp.y - 150.0)))

# 战斗日志：默认隐藏，可点击展开/收起。
func _build_log_toggle() -> void:
	log_panel.visible = false
	var vp := get_viewport_rect().size
	log_btn = Button.new()
	log_btn.text = "展开日志"
	log_btn.custom_minimum_size = Vector2(110, 30)
	log_btn.position = Vector2(20, vp.y - 300)
	log_btn.pressed.connect(_on_log_toggled)
	add_child(log_btn)

func _on_log_toggled() -> void:
	log_panel.visible = not log_panel.visible
	if log_btn != null:
		log_btn.text = "收起日志" if log_panel.visible else "展开日志"

# 暂停与倍速按钮（右下角，设置按钮左侧）。
func _build_speed_controls() -> void:
	var vp := get_viewport_rect().size
	pause_btn = Button.new()
	pause_btn.text = "暂停"
	pause_btn.custom_minimum_size = Vector2(110, 40)
	pause_btn.position = Vector2(vp.x - 260, vp.y - 56)
	pause_btn.pressed.connect(_on_pause_pressed)
	add_child(pause_btn)
	speed_btn = Button.new()
	speed_btn.text = "倍速 x%d" % battle_speed
	speed_btn.custom_minimum_size = Vector2(110, 40)
	speed_btn.position = Vector2(vp.x - 390, vp.y - 56)
	speed_btn.pressed.connect(_on_speed_pressed)
	add_child(speed_btn)

func _on_pause_pressed() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	if pause_btn != null:
		pause_btn.text = "继续" if paused else "暂停"

func _on_speed_pressed() -> void:
	if get_tree().paused:
		return
	battle_speed = (battle_speed % SPEED_OPTIONS.size()) + 1
	Engine.time_scale = float(SPEED_OPTIONS[battle_speed - 1])
	if speed_btn != null:
		speed_btn.text = "倍速 x%d" % SPEED_OPTIONS[battle_speed - 1]

# 离开战斗场景时复位全局时间流速与暂停状态。
func _exit_tree() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0

# 战斗设置：右下角"设置"按钮 + 面板（伤害飙字开关等）。
func _build_settings_ui() -> void:
	var vp := get_viewport_rect().size
	var btn := Button.new()
	btn.name = "SettingsButton"
	btn.text = "设置"
	btn.custom_minimum_size = Vector2(110, 40)
	btn.position = Vector2(vp.x - 130, vp.y - 56)
	btn.pressed.connect(_toggle_settings_panel)
	add_child(btn)

	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(vp.x - 300, vp.y - 190)
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
	_update_turn_label()
	if manager.winner != "":
		_check_battle_end()

func get_database() -> Node:
	return GameDatabase

# --- 提供给战斗系统回调的接口 ---
func add_log(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(0.92, 0.92, 0.92)
	log_list.add_child(label)
	while log_list.get_child_count() > 100:
		log_list.get_child(0).queue_free()

# --- 界面搭建 ---
func _position_battle_view() -> void:
	var view: Node2D = $BattleView
	var vp := get_viewport_rect().size
	view.position = BattleLayout.board_position(manager.grid.width, manager.grid.height, tile_size, vp)

func _create_unit_view(unit: Unit) -> void:
	var uv := UnitView.new()
	uv.setup(unit, tile_size)
	units_layer.add_child(uv)
	unit_views[unit] = uv

# --- 单位信息面板 ---
func _build_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.name = "UnitInfoPanel"
	info_panel.custom_minimum_size = Vector2(300.0, 0.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	info_portrait = TextureRect.new()
	info_portrait.custom_minimum_size = Vector2(140, 140)
	info_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(info_portrait)
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(250, 0)
	box.add_child(info_label)
	margin.add_child(box)
	info_panel.add_child(margin)
	add_child(info_panel)
	info_panel.visible = false

# 显示指定单位的属性/装备/技能/Buff 信息。
func _show_unit_info(unit: Unit) -> void:
	if unit == null or not unit.alive:
		return
	var portrait := ArtManager.get_portrait(unit.unit_type)
	info_portrait.texture = portrait
	info_portrait.visible = portrait != null
	var camp_text := "玩家" if unit.camp == TurnManager.PLAYER_CAMP else "敌方"
	var lines: Array = []
	lines.append("%s  Lv.%d  (%s)" % [unit.get_display_name(), unit.level, camp_text])
	lines.append("HP: %d/%d" % [unit.hp, unit.max_hp])
	var shield_total := 0
	for buff in unit.buffs:
		shield_total += buff.shield
	if shield_total > 0:
		var shield_max_all := 0
		for buff in unit.buffs:
			if buff.shield > 0:
				shield_max_all += int(buff.raw_data.get("shield", buff.shield))
		lines.append("护罩: %d/%d" % [shield_total, shield_max_all])
	lines.append("攻击: %d   防御: %d   移动: %d" % [unit.get_attack(), unit.get_defense(), unit.get_move_points()])
	lines.append("暴击率: %d%%   暴击伤害: %d%%" % [unit.get_crit_rate(), unit.get_crit_damage()])
	lines.append("射程: %d-%d" % [unit.get_range_min(), unit.get_range_max()])
	lines.append("行动间隔: %.1fs" % unit.turn_interval)
	if not unit.permanent_mods.is_empty():
		lines.append("永久强化:")
		var stat_labels := {"hp": "生命上限", "attack": "攻击", "defense": "防御", "move": "移动"}
		for stat in unit.permanent_mods:
			lines.append("  %s +%d" % [str(stat_labels.get(stat, stat)), int(unit.permanent_mods[stat])])
	lines.append("")
	lines.append("装备:")
	var has_equip := false
	for slot in unit.equipment:
		lines.append("  %s: %s" % [slot, unit.equipment[slot].name])
		has_equip = true
	if not has_equip:
		lines.append("  （无）")
	lines.append("")
	lines.append("技能:")
	if unit.skills.size() == 0:
		lines.append("  （无）")
	for skill in unit.skills:
		lines.append("  · %s" % skill.name)
	lines.append("")
	lines.append("Buff:")
	if unit.buffs.size() == 0:
		lines.append("  （无）")
	for buff in unit.buffs:
		lines.append("  · %s（剩 %d 回合）" % [buff.name, buff.duration])
	info_label.text = "\n".join(lines)
	info_panel.visible = true

func _hide_unit_info() -> void:
	info_panel.visible = false

# --- 输入：点击单位查看信息 ---
func _unhandled_input(event: InputEvent) -> void:
	if manager == null or manager.winner != "":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _screen_to_cell(event.position)
		var unit := manager.get_unit_at(cell)
		if unit != null:
			_show_unit_info(unit)
		else:
			_hide_unit_info()

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
					add_log("%s 移动后攻击 %s" % [unit.get_display_name(), t2.get_display_name()])
				_show_damage_popup(ev)
			else:
				add_log("%s 移动" % unit.get_display_name())
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
	# 战斗结束：解除暂停与倍速（保证后续场景/计时器正常）
	get_tree().paused = false
	Engine.time_scale = 1.0
	battle_speed = 1
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
		get_tree().change_scene_to_file("res://scenes/reward_screen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/result_screen.tscn")

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
	floor_label.text = GameSession.get_floor_label() if GameSession.mode == GameSession.MODE_TOWER else GameSession.current_scenario
	team_status_label.text = "我方 %d/%d" % [_count_alive(TurnManager.PLAYER_CAMP), _count_camp(TurnManager.PLAYER_CAMP)]
	enemy_status_label.text = "敌方 %d/%d" % [_count_alive(TurnManager.ENEMY_CAMP), _count_camp(TurnManager.ENEMY_CAMP)]

func _count_camp(camp: String) -> int:
	var count := 0
	for unit in manager.units:
		if unit is Unit and unit.camp == camp:
			count += 1
	return count
