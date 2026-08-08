# 战斗界面：渲染网格与单位，处理点击选择/移动/行动菜单/技能目标，并驱动 BattleManager 与敌方 AI。
extends Control

const TILE_SIZE := 64

enum State { IDLE, SELECTED, TARGETING, ENEMY_TURN, GAME_OVER }

var manager: BattleManager
var state: int = State.IDLE
var selected_unit: Unit = null
var pending_skill: Skill = null
var unit_views: Dictionary = {}

var action_panel: PanelContainer
var action_list: VBoxContainer
var attack_btn: Button
var skill_btn: Button
var wait_btn: Button
var cancel_btn: Button
var skill_panel: PanelContainer
var skill_list: VBoxContainer

@onready var turn_label: Label = $TurnLabel
@onready var end_turn_button: Button = $EndTurnButton
@onready var grid_view: Node2D = $BattleView/GridView
@onready var units_layer: Node2D = $BattleView/UnitsLayer
@onready var log_list: VBoxContainer = $LogPanel/Scroll/LogList
@onready var victory_label: Label = $VictoryLabel

var info_panel: PanelContainer
var info_label: Label

func _ready() -> void:
	manager = BattleManager.new(GameSession.current_scenario, self, GameSession.deployed_positions)
	manager.setup()
	_position_battle_view()
	grid_view.setup(manager.grid, TILE_SIZE)
	for unit in manager.units:
		_create_unit_view(unit)
	_build_action_menu()
	_build_skill_menu()
	_build_info_panel()
	_update_turn_label()
	add_log("战斗开始！地图 %dx%d，我方 %d 单位，敌方 %d 单位" % [
		manager.grid.width, manager.grid.height,
		_count_alive(TurnManager.PLAYER_CAMP), _count_alive(TurnManager.ENEMY_CAMP)
	])
	end_turn_button.pressed.connect(_on_end_turn_pressed)

# --- 提供给战斗系统回调的接口 ---
func add_log(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(0.92, 0.92, 0.92)
	log_list.add_child(label)
	while log_list.get_child_count() > 100:
		log_list.get_child(0).queue_free()

func get_database() -> Node:
	return GameDatabase

# --- 界面搭建 ---
func _position_battle_view() -> void:
	var view: Node2D = $BattleView
	var board_w := manager.grid.width * TILE_SIZE
	var board_h := manager.grid.height * TILE_SIZE
	var vp := get_viewport_rect().size
	view.position = Vector2((vp.x - board_w) / 2.0, (vp.y - board_h) / 2.0 - 10.0)

func _create_unit_view(unit: Unit) -> void:
	var uv := UnitView.new()
	uv.setup(unit, TILE_SIZE)
	units_layer.add_child(uv)
	unit_views[unit] = uv

func _make_menu_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(170, 36)
	return btn

func _build_action_menu() -> void:
	action_panel = PanelContainer.new()
	action_panel.name = "ActionMenu"
	action_panel.position = Vector2(get_viewport_rect().size.x - 210.0, 150.0)
	action_list = VBoxContainer.new()
	attack_btn = _make_menu_button("攻击")
	skill_btn = _make_menu_button("技能")
	wait_btn = _make_menu_button("待机")
	cancel_btn = _make_menu_button("取消")
	action_list.add_child(attack_btn)
	action_list.add_child(skill_btn)
	action_list.add_child(wait_btn)
	action_list.add_child(cancel_btn)
	action_panel.add_child(action_list)
	add_child(action_panel)
	attack_btn.pressed.connect(_on_attack_pressed)
	skill_btn.pressed.connect(_on_skill_pressed)
	wait_btn.pressed.connect(_on_wait_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	action_panel.visible = false

func _build_skill_menu() -> void:
	skill_panel = PanelContainer.new()
	skill_panel.name = "SkillMenu"
	skill_panel.position = Vector2(get_viewport_rect().size.x - 210.0, 150.0)
	skill_list = VBoxContainer.new()
	skill_panel.add_child(skill_list)
	add_child(skill_panel)
	skill_panel.visible = false

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
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(250, 0)
	margin.add_child(info_label)
	info_panel.add_child(margin)
	add_child(info_panel)
	info_panel.visible = false

# 显示指定单位的属性/装备/技能/Buff 信息。
func _show_unit_info(unit: Unit) -> void:
	if unit == null or not unit.alive:
		return
	var camp_text := "玩家" if unit.camp == TurnManager.PLAYER_CAMP else "敌方"
	var lines: Array = []
	lines.append("%s  Lv.%d  (%s)" % [unit.get_display_name(), unit.level, camp_text])
	lines.append("HP: %d/%d" % [unit.hp, unit.max_hp])
	lines.append("攻击: %d   防御: %d   移动: %d" % [unit.get_attack(), unit.get_defense(), unit.get_move_points()])
	lines.append("射程: %d-%d" % [unit.get_range_min(), unit.get_range_max()])
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

func _populate_skill_menu() -> void:
	for child in skill_list.get_children():
		child.queue_free()
	for skill in selected_unit.skills:
		var btn := _make_menu_button(skill.name)
		btn.pressed.connect(_on_skill_clicked.bind(skill))
		skill_list.add_child(btn)

func _show_action_menu(visible_flag: bool) -> void:
	action_panel.visible = visible_flag

func _show_skill_menu(visible_flag: bool) -> void:
	skill_panel.visible = visible_flag

# --- 输入 ---
func _unhandled_input(event: InputEvent) -> void:
	if state == State.ENEMY_TURN or state == State.GAME_OVER:
		return
	if event is InputEventMouseMotion:
		grid_view.set_hover(_screen_to_cell(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cell_clicked(_screen_to_cell(event.position))

func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var local := ($BattleView as Node2D).to_local(screen_pos)
	return Vector2i(floori(local.x / TILE_SIZE), floori(local.y / TILE_SIZE))

func _cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)

func _on_cell_clicked(cell: Vector2i) -> void:
	match state:
		State.IDLE:
			var unit := manager.get_unit_at(cell)
			if unit != null:
				_show_unit_info(unit)
				if unit.camp == TurnManager.PLAYER_CAMP and not unit.acted and not unit.is_stunned():
					_select_unit(unit)
				elif unit.camp == TurnManager.PLAYER_CAMP and unit.acted:
					add_log("%s 本回合已行动" % unit.get_display_name())
			else:
				_hide_unit_info()
		State.SELECTED:
			var target := manager.get_unit_at(cell)
			if target == selected_unit:
				_deselect()
				return
			if target != null:
				_show_unit_info(target)
				if target.camp == TurnManager.PLAYER_CAMP and not target.acted:
					_select_unit(target)
				return
			if manager.get_move_tiles(selected_unit).has(cell):
				_move_selected_to(cell)
			else:
				_deselect()
				_hide_unit_info()
		State.TARGETING:
			var target := manager.get_unit_at(cell)
			if pending_skill != null:
				if manager.can_cast_skill(selected_unit, pending_skill, target):
					_do_skill(selected_unit, pending_skill, target)
				else:
					_cancel_targeting()
			else:
				if manager.can_attack(selected_unit, target):
					_do_attack(selected_unit, target)
				else:
					_cancel_targeting()

# --- 选择与行动 ---
func _select_unit(unit: Unit) -> void:
	selected_unit = unit
	state = State.SELECTED
	grid_view.set_selected(unit.pos)
	grid_view.set_highlights(manager.get_move_tiles(unit), [])
	grid_view.set_target_cells([])
	_update_action_buttons()
	_show_action_menu(true)
	_show_skill_menu(false)

func _deselect() -> void:
	selected_unit = null
	pending_skill = null
	state = State.IDLE
	grid_view.set_selected(Vector2i(-1, -1))
	grid_view.set_highlights([], [])
	grid_view.set_target_cells([])
	_show_action_menu(false)
	_show_skill_menu(false)
	_hide_unit_info()

func _update_action_buttons() -> void:
	if selected_unit == null:
		return
	attack_btn.disabled = manager.get_attack_targets(selected_unit).is_empty()
	skill_btn.disabled = selected_unit.is_silenced() or selected_unit.skills.is_empty()

func _move_selected_to(cell: Vector2i) -> void:
	_show_action_menu(false)
	grid_view.set_highlights([], [])
	var unit_view := unit_views.get(selected_unit) as Node2D
	manager.move_unit(selected_unit, cell)
	if unit_view != null:
		await _animate_unit_move(unit_view, cell)
	_refresh_units()
	grid_view.set_selected(cell)
	_update_action_buttons()
	_show_action_menu(true)

func _animate_unit_move(unit_view: Node2D, to_cell: Vector2i) -> void:
	var target_pos := _cell_to_local(to_cell)
	var tween := create_tween()
	tween.tween_property(unit_view, "position", target_pos, 0.25)
	await tween.finished
	unit_view.refresh()

func _on_attack_pressed() -> void:
	if selected_unit == null or state != State.SELECTED:
		return
	pending_skill = null
	state = State.TARGETING
	_show_action_menu(false)
	grid_view.set_highlights([], [])
	var cells: Array = []
	for target in manager.get_attack_targets(selected_unit):
		cells.append(target.pos)
	grid_view.set_target_cells(cells)
	add_log("选择攻击目标（黄色高亮）")

func _on_skill_pressed() -> void:
	if selected_unit == null or state != State.SELECTED:
		return
	_show_action_menu(false)
	_populate_skill_menu()
	_show_skill_menu(true)

func _on_skill_clicked(skill: Skill) -> void:
	_show_skill_menu(false)
	pending_skill = skill
	state = State.TARGETING
	grid_view.set_highlights([], [])
	var cells: Array = []
	for target in manager.get_skill_targets(selected_unit, skill):
		cells.append(target.pos)
	grid_view.set_target_cells(cells)
	add_log("选择 %s 的目标（黄色高亮）" % skill.name)

func _cancel_targeting() -> void:
	pending_skill = null
	state = State.SELECTED
	grid_view.set_target_cells([])
	grid_view.set_highlights(manager.get_move_tiles(selected_unit), [])
	_update_action_buttons()
	_show_action_menu(true)
	add_log("取消选择目标")

func _do_attack(attacker: Unit, defender: Unit) -> void:
	manager.perform_attack(attacker, defender)
	_seal_action()

func _do_skill(user: Unit, skill: Skill, target: Unit) -> void:
	manager.cast_skill(user, skill, target)
	_seal_action()

func _on_wait_pressed() -> void:
	if selected_unit == null:
		return
	manager.wait(selected_unit)
	add_log("%s 待机" % selected_unit.get_display_name())
	_seal_action()

func _on_cancel_pressed() -> void:
	_deselect()

func _seal_action() -> void:
	_refresh_units()
	_clear_selection()
	_check_battle_end()

func _clear_selection() -> void:
	selected_unit = null
	pending_skill = null
	state = State.IDLE
	grid_view.set_selected(Vector2i(-1, -1))
	grid_view.set_highlights([], [])
	grid_view.set_target_cells([])
	_show_action_menu(false)
	_show_skill_menu(false)

# --- 回合与敌方 AI ---
func _on_end_turn_pressed() -> void:
	if state == State.ENEMY_TURN or state == State.GAME_OVER:
		return
	if state != State.IDLE:
		_clear_selection()
	_start_enemy_turn()

func _start_enemy_turn() -> void:
	state = State.ENEMY_TURN
	_clear_selection()
	end_turn_button.disabled = true
	manager.next_turn()
	_update_turn_label()
	add_log("敌方回合")
	await _run_enemy_ai()
	if manager.winner == "":
		manager.next_turn()
		_update_turn_label()
		add_log("玩家回合")
		state = State.IDLE
		end_turn_button.disabled = false
		_refresh_units()
	else:
		_check_battle_end()

func _run_enemy_ai() -> void:
	for unit in manager.units:
		if not (unit is Unit) or not unit.alive or unit.camp != TurnManager.ENEMY_CAMP or unit.acted:
			continue
		if unit.is_stunned():
			manager.wait(unit)
			await _tick_delay()
			continue
		var decision := EnemyAI.get_decision(manager, unit)
		match decision.action:
			"move":
				var to: Vector2i = decision.to
				var unit_view := unit_views.get(unit) as Node2D
				manager.move_unit(unit, to)
				if unit_view != null:
					await _animate_unit_move(unit_view, to)
				_refresh_units()
				var targets := manager.get_attack_targets(unit)
				if targets.size() > 0:
					manager.perform_attack(unit, targets[0])
					_refresh_units()
			"attack":
				var target: Unit = decision.target
				manager.perform_attack(unit, target)
				_refresh_units()
			_:
				pass
		manager.wait(unit)
		await _tick_delay()
		if manager.winner != "":
			break

func _tick_delay() -> void:
	await get_tree().create_timer(0.25).timeout

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
	state = State.GAME_OVER
	end_turn_button.disabled = true
	_show_action_menu(false)
	_show_skill_menu(false)
	if manager.winner == TurnManager.PLAYER_CAMP:
		_apply_victory_rewards()
	GameSession.record_result(manager.winner)
	victory_label.visible = true
	victory_label.text = "胜利！" if manager.winner == TurnManager.PLAYER_CAMP else "失败…"
	add_log(victory_label.text)
	await get_tree().create_timer(1.2).timeout
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
	var camp := "玩家" if manager.turn_manager.current_camp == TurnManager.PLAYER_CAMP else "敌方"
	turn_label.text = "回合 %d - %s" % [manager.turn_manager.turn_number, camp]
