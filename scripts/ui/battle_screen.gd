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
@onready var grid_view: Node2D = $BattleView/GridView
@onready var units_layer: Node2D = $BattleView/UnitsLayer
@onready var log_list: VBoxContainer = $LogPanel/Scroll/LogList
@onready var victory_label: Label = $VictoryLabel

var info_panel: PanelContainer
var info_label: Label
var info_portrait: TextureRect

func _ready() -> void:
	manager = BattleManager.new(GameSession.current_scenario, self, GameSession.deployed_units)
	manager.setup()
	manager.setup_battle()
	tile_size = BattleLayout.compute_tile_size(manager.grid.width, manager.grid.height, get_viewport_rect().size)
	_position_battle_view()
	grid_view.setup(manager.grid, tile_size)
	for unit in manager.units:
		_create_unit_view(unit)
	_build_info_panel()
	_update_turn_label()
	add_log("战斗开始！地图 %dx%d，我方 %d 单位，敌方 %d 单位" % [
		manager.grid.width, manager.grid.height,
		_count_alive(TurnManager.PLAYER_CAMP), _count_alive(TurnManager.ENEMY_CAMP)
	])

func _process(delta: float) -> void:
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
	info_panel.position = Vector2(24.0, 80.0)
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
	lines.append("攻击: %d   防御: %d   移动: %d" % [unit.get_attack(), unit.get_defense(), unit.get_move_points()])
	lines.append("射程: %d-%d" % [unit.get_range_min(), unit.get_range_max()])
	lines.append("行动间隔: %.1fs" % unit.turn_interval)
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
		"move", "move_attack":
			var to: Vector2i = ev.get("to")
			if unit_view != null:
				_animate_unit_move(unit_view, ev.get("from", Vector2i(-1, -1)), to)
			if action == "move_attack":
				var t2: Unit = ev.get("target")
				if t2 != null:
					_play_attack_animation(unit_view, t2)
					add_log("%s 移动后攻击 %s" % [unit.get_display_name(), t2.get_display_name()])
			else:
				add_log("%s 移动" % unit.get_display_name())
		"wait":
			pass

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

# 按路径逐格移动：从移动前位置(from_cell)到目标，逐格补间。
func _animate_unit_move(unit_view: Node2D, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if unit_view == null or not (unit_view is UnitView):
		return
	var uv := unit_view as UnitView
	if from_cell.x < 0 or to_cell == from_cell:
		return
	var path: Array = []
	var start := manager.grid.get_tile(from_cell.x, from_cell.y)
	var goal := manager.grid.get_tile(to_cell.x, to_cell.y)
	if start != null and goal != null:
		path = Pathfinder.find_path(manager.grid, start, goal)
	if path.size() <= 1:
		return
	uv.set_action("move")
	var tween := uv.animate_move(path, MOVE_STEP_TIME / ANIM_SPEED)
	tween.finished.connect(func(): uv.set_action("stand"))

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

func _check_battle_end() -> void:
	if manager.winner == "":
		return
	if manager.winner == TurnManager.PLAYER_CAMP:
		_apply_victory_rewards()
	GameSession.record_result(manager.winner)
	victory_label.visible = true
	victory_label.text = "胜利！" if manager.winner == TurnManager.PLAYER_CAMP else "失败…"
	add_log(victory_label.text)
	await get_tree().create_timer(1.5).timeout
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
	turn_label.text = manager.turn_manager.get_turn_label()
