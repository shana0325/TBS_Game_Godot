# 结算屏幕：展示战斗胜负结果，可返回主菜单或再战当前关卡。
extends Control

func _ready() -> void:
	var title := Label.new()
	title.text = "胜利！" if GameSession.is_winner() else "失败…"
	title.add_theme_font_size_override("font_size", 56)
	title.position = Vector2(80, 120)
	title.size = Vector2(1120, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var retry_btn := Button.new()
	retry_btn.text = "再来一局"
	retry_btn.custom_minimum_size = Vector2(260, 48)
	retry_btn.position = Vector2(200, 260)
	retry_btn.pressed.connect(_retry)
	add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.custom_minimum_size = Vector2(260, 48)
	menu_btn.position = Vector2(200, 330)
	menu_btn.pressed.connect(_go_menu)
	add_child(menu_btn)

func _retry() -> void:
	get_tree().change_scene_to_file("res://scenes/deployment_screen.tscn")

func _go_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
