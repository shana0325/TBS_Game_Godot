# 验证嵌入战场的遗物奖励卡居中排列并展示对应遗物图标。
extends Node

# 等待自动加载数据后建立奖励界面。
func _ready() -> void:
	call_deferred("_run")

# 检查三选一布局、图标及底部选择按钮的位置。
func _run() -> void:
	var reward := load("res://scenes/reward_screen.tscn").instantiate() as Control
	reward.setup_embedded()
	get_tree().root.add_child(reward)
	await get_tree().process_frame
	await get_tree().process_frame
	var popup := reward.get_node("RewardPopupPanel") as PanelContainer
	var scroll := reward.get_node("RewardOptionsScroll") as ScrollContainer
	var cards := reward.get_node("RewardOptionsScroll/RewardOptionsBox") as HBoxContainer
	var summary := reward.get_node("RunSummary") as Label
	if popup == null or scroll == null or cards.get_child_count() != 3:
		_fail("遗物奖励卡片未正确创建")
		return
	if "尚未获得遗物" in summary.text or "遗物：" in summary.text or "\n" in summary.text:
		_fail("奖励摘要仍显示已有遗物清单或占位文字")
		return
	var popup_center := popup.get_global_rect().get_center().x
	var options_center := scroll.get_global_rect().get_center().x
	if absf(popup_center - options_center) > 2.0:
		_fail("遗物奖励卡片没有在弹窗中水平居中")
		return
	for card in cards.get_children():
		var icons := card.find_children("*", "TextureRect", true, false)
		var buttons := card.find_children("*", "Button", true, false)
		if icons.is_empty() or (icons[0] as TextureRect).texture == null or buttons.is_empty():
			_fail("遗物奖励卡片缺少图标或选择按钮")
			return
		if (buttons[0] as Button).get_global_rect().end.y < card.get_global_rect().end.y - 32.0:
			_fail("选择按钮没有靠近卡片底部")
			return
	print("PASS: 遗物奖励居中、图标与选择按钮")
	get_tree().quit(0)

# 输出布局失败原因并返回非零退出码。
func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
