# 检查角色资料页的技能摘要卡片能完整容纳长描述并保留详情入口。
extends Node

# 等待界面完成排版后检查卡片边界与摘要文本。
func _ready() -> void:
	call_deferred("_run")

# 创建含较长固有技能描述的角色并验证卡片布局。
func _run() -> void:
	var config: Dictionary = GameDatabase.get_unit("Hero")
	var roster: Dictionary = GameDatabase.player_roster.get("units", [])[0].duplicate(true)
	roster["permanent_mods"] = {"hp": 28.0, "attack": 2.0}
	roster["permanent_mod_sources"] = {"Attribute Siphon": {"attack": 2.0}}
	var unit := Unit.create_from_config("Hero", TurnManager.PLAYER_CAMP, Vector2i.ZERO, config, roster, GameDatabase)
	var panel := UnitDetailPanel.new()
	get_tree().root.add_child(panel)
	panel.show_unit(unit)
	await get_tree().process_frame
	await get_tree().process_frame
	var viewport_size := get_viewport().get_visible_rect().size
	if panel.size.x > (viewport_size.x - 48.0) * 0.83 or panel.size.y > (viewport_size.y - 48.0) * 0.83:
		_fail("角色详情没有缩至原窗口的约八成")
		return
	if not get_viewport().get_visible_rect().encloses(panel.get_global_rect()):
		_fail("缩小后的角色详情超出视口")
		return
	var skills_section := panel.section_nodes.get("skills") as Control
	if skills_section == null:
		_fail("未找到技能章节")
		return
	var rows: Array[PanelContainer] = []
	for node in skills_section.find_children("*", "PanelContainer", true, false):
		var candidate := node as PanelContainer
		if candidate != null and candidate.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
			rows.append(candidate)
	if rows.is_empty():
		_fail("未找到技能摘要卡片")
		return
	var legacy_visible := false
	for label in skills_section.find_children("*", "Label", true, false):
		if (label as Label).text == "历史强化（来源未记录）":
			legacy_visible = true
	if not legacy_visible:
		_fail("旧存档无来源的永久强化未保留可见入口")
		return
	for row in rows:
		panel._set_skill_row_hover(row, true)
		await get_tree().process_frame
		var labels := row.find_children("*", "Label", true, false)
		var descriptions := row.find_children("*", "MechanicDescription", true, false)
		if labels.size() != 1 or descriptions.size() != 1:
			_fail("技能摘要文字结构异常")
			return
		var title := labels[0] as Label
		var desc := descriptions[0] as MechanicDescription
		if "标签" in title.text or "点击查看完整技能详情" in desc.text:
			_fail("技能摘要仍显示标签或多余提示")
			return
		if desc.get_global_rect().end.y > row.get_global_rect().end.y - 1.0:
			_fail("技能描述越出卡片底边")
			return
		if desc.get_global_rect().end.x > row.get_global_rect().end.x - 1.0:
			_fail("技能描述越出卡片右边")
			return
	var stats_section := panel.section_nodes.get("stats") as Control
	for label in stats_section.find_children("*", "Label", true, false):
		if (label as Label).text == "永久强化":
			_fail("基础属性里仍显示不区分来源的永久强化栏")
			return
	panel._show_skill_details("Attribute Siphon")
	await get_tree().process_frame
	if not panel.skill_detail_dialog.growth_label.visible \
			or not "攻击 +2.00" in panel.skill_detail_dialog.growth_label.text:
		_fail("属性汲取详情没有展示本技能来源的永久成长")
		return
	print("PASS: 技能摘要卡片布局和文本")
	get_tree().quit(0)

# 输出失败原因并以非零状态退出。
func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
