# 验证部署开始战斗时复用战场节点，并保持棋盘坐标与阵容栏结构。
extends Node

# 在全局数据就绪后运行场景交接检查。
func _ready() -> void:
	call_deferred("_run")

# 模拟放置一名角色并开始战斗，检查视觉场景没有被替换。
func _run() -> void:
	GameSession.select_scenario("battle_01")
	var deployment: Node = load("res://scenes/deployment_screen.tscn").instantiate()
	get_tree().root.add_child(deployment)
	get_tree().current_scene = deployment
	await get_tree().process_frame
	var stage := deployment.get_node("Stage") as BattlefieldStage
	if stage == null or stage.grid == null or deployment.deployment_zone.is_empty():
		_fail("部署场景未建立共用战场")
		return
	var deployment_card := deployment.unit_cards[0] as DeploymentUnitCard
	if deployment_card == null or not deployment_card.drag_enabled:
		_fail("部署阶段未允许单位卡拖拽")
		return
	var deployed_roster_index := deployment_card.roster_index
	var deployed_bench_slot := deployment_card.bench_slot
	if stage.roster_container.alignment != BoxContainer.ALIGNMENT_BEGIN:
		_fail("备战栏没有从左侧开始排列")
		return
	var empty_slot: BenchSlot = null
	for child in stage.roster_container.get_children():
		if child is BenchSlot:
			empty_slot = child
			break
	if empty_slot != null:
		if not empty_slot._can_drop_data(Vector2.ZERO,
				{"kind": "deployment_unit", "selectable_index": 0}):
			_fail("备战栏空格未接收单位卡")
			return
		var target_slot := empty_slot.slot_index
		var original_slot := deployment_card.bench_slot
		deployment_card.bench_slot = target_slot
		stage.arrange_bench_cards(deployment.unit_cards)
		if stage.roster_container.get_child(target_slot) != deployment_card or not stage.roster_container.get_child(original_slot) is BenchSlot:
			_fail("单位卡移动后没有固定在目标备战格")
			return
		deployment_card.bench_slot = original_slot
		stage.arrange_bench_cards(deployment.unit_cards)
	stage.roster_panel.size.x = 360.0
	await get_tree().process_frame
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = stage.roster_panel.position + Vector2(70, 60)
	wheel.global_position = wheel.position
	get_viewport().push_input(wheel, true)
	await get_tree().process_frame
	if stage.roster_scroll.scroll_horizontal <= 0:
		_fail("备战栏超出可见宽度后无法用滚轮横向滚动")
		return
	stage.resize_board()
	var third_slot := stage.roster_container.get_child(2) as Control
	var third_center := third_slot.get_global_rect().get_center()
	if stage.bench_slot_at(third_center) != 2:
		_fail("从战场撤下时没有按鼠标所在的第三个备战格识别")
		return
	var board_position := stage.battle_view.position
	var cell: Vector2i = deployment.deployment_zone[0]
	var drop_position := stage.battle_view.to_global(Vector2(cell) * stage.tile_size + Vector2.ONE * stage.tile_size * 0.5)
	var drag_data := {"kind": "deployment_unit", "selectable_index": 0}
	if not deployment._can_drop_data(drop_position, drag_data):
		_fail("部署区未接收单位卡拖放")
		return
	deployment._drop_data(drop_position, drag_data)
	if not deployment.placements.has(0):
		_fail("拖放后单位未进入部署区")
		return
	if deployment_card.visible:
		_fail("已上场单位仍显示在备战栏")
		return
	var original_relics := GameSession.run_relics.duplicate()
	GameSession.run_relics = [str(GameDatabase.relics.keys()[0])]
	stage._open_relic_gallery()
	if not stage.blocks_board_input():
		GameSession.run_relics = original_relics
		_fail("已有遗物总览没有阻止棋盘输入")
		return
	var board_click := InputEventMouseButton.new()
	board_click.button_index = MOUSE_BUTTON_LEFT
	board_click.pressed = true
	board_click.position = drop_position
	board_click.global_position = drop_position
	get_viewport().push_input(board_click, true)
	await get_tree().process_frame
	if deployment.info_panel.visible or deployment.dragging_slot >= 0:
		GameSession.run_relics = original_relics
		_fail("点击遗物总览穿透到棋盘单位")
		return
	stage._open_relic_gallery()
	stage.show_relic_details(str(GameSession.run_relics[0]))
	get_viewport().push_input(board_click, true)
	await get_tree().process_frame
	if deployment.info_panel.visible or not stage.relic_detail_popup.visible:
		GameSession.run_relics = original_relics
		_fail("遗物详情打开后仍可穿透点击棋盘单位")
		return
	stage.relic_detail_popup.close_popup()
	stage._close_relic_gallery()
	deployment._on_start_pressed()
	await get_tree().process_frame
	var battle := get_tree().current_scene
	if battle == null or battle.name != "BattleScreen":
		_fail("开始战斗后未进入战斗控制器")
		return
	if battle.get_node("Stage") != stage:
		_fail("战场节点在阶段切换时被重新创建")
		return
	if stage.battle_view.position != board_position:
		_fail("棋盘在阶段切换时发生位移")
		return
	if stage.roster_container.get_child_count() != ProgressManager.MAX_ROSTER_SIZE:
		_fail("阵容栏槽位数量在阶段切换后不一致")
		return
	if not stage.roster_container.get_child(deployed_bench_slot) is BenchSlot:
		_fail("已上场单位的原备战格没有保持为空位")
		return
	var battle_card: DeploymentUnitCard = null
	for child in stage.roster_container.get_children():
		if child is DeploymentUnitCard:
			battle_card = child
			break
	if battle_card == null or battle_card.drag_enabled:
		_fail("战斗阶段仍允许单位卡拖拽")
		return
	if battle_card.roster_index == deployed_roster_index:
		_fail("已上场单位在战斗备战栏中重新出现")
		return
	stage._open_relic_gallery()
	await get_tree().process_frame
	if not stage.relic_gallery.visible or stage.relic_gallery_grid.get_child_count() != 1:
		GameSession.run_relics = original_relics
		_fail("已有遗物总览未展示当前遗物图标")
		return
	var icon_button := stage.relic_gallery_grid.get_child(0) as Button
	if icon_button == null or icon_button.icon == null:
		GameSession.run_relics = original_relics
		_fail("遗物总览的图标入口缺失")
		return
	icon_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if not stage.relic_detail_popup.visible:
		GameSession.run_relics = original_relics
		_fail("遗物总览中的图标无法打开详情")
		return
	var popup_rect := stage.relic_detail_popup.get_global_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	if not viewport_rect.encloses(popup_rect):
		GameSession.run_relics = original_relics
		_fail("遗物详情首次打开时超出屏幕：%s" % popup_rect)
		return
	var content_scroll := stage.relic_detail_popup.get_node("ContentScroll") as ScrollContainer
	var content_margin := content_scroll.get_child(0) as MarginContainer
	if content_margin.size.x < content_scroll.size.x - 8.0:
		GameSession.run_relics = original_relics
		_fail("遗物详情内容没有铺满卡片宽度：内容=%s 卡片=%s" % [content_margin.size.x, content_scroll.size.x])
		return
	# 较长说明也只能在卡片内部滚动，不得再次撑出视口。
	stage.relic_detail_popup.desc_label.text = "遗物效果说明较长时仍需保持在屏幕以内。".repeat(100)
	await get_tree().process_frame
	popup_rect = stage.relic_detail_popup.get_global_rect()
	if not viewport_rect.encloses(popup_rect):
		GameSession.run_relics = original_relics
		_fail("遗物详情长文本将卡片撑出屏幕：%s" % popup_rect)
		return
	if content_scroll == null or content_scroll.get_v_scroll_bar().max_value <= content_scroll.size.y:
		GameSession.run_relics = original_relics
		_fail("遗物详情长文本没有在卡片内部滚动")
		return
	if not stage.blocks_board_input():
		GameSession.run_relics = original_relics
		_fail("遗物详情没有阻止棋盘输入")
		return
	stage.relic_detail_popup.close_popup()
	if not stage.blocks_board_input():
		GameSession.run_relics = original_relics
		_fail("关闭详情后仍打开的遗物总览没有阻止棋盘输入")
		return
	stage._close_relic_gallery()
	if stage.blocks_board_input():
		GameSession.run_relics = original_relics
		_fail("关闭遗物弹窗后棋盘仍被阻止输入")
		return
	GameSession.run_relics = original_relics
	print("RESULT battlefield_stage_transition=PASS")
	get_tree().quit(0)

# 测试失败时输出具体原因并返回非零状态。
func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
