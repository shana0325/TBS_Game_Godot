# 主菜单：提供继续游戏、开始新游戏、队伍编成与退出入口。
extends Control

@onready var status_label: Label = $StatusLabel
@onready var continue_button: Button = $ContinueButton
@onready var start_button: Button = $StartButton
@onready var roster_button: Button = $RosterButton
@onready var quit_button: Button = $QuitButton

func _ready() -> void:
	status_label.text = "自动战斗 · 战棋部署 · 爬塔冒险"
	continue_button.pressed.connect(_on_continue_pressed)
	start_button.pressed.connect(_on_start_pressed)
	roster_button.pressed.connect(_on_roster_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	quit_button.add_theme_color_override("font_color", Color(0.92, 0.48, 0.42, 1.0))
	quit_button.add_theme_color_override("font_hover_color", Color(1.0, 0.68, 0.56, 1.0))
	continue_button.disabled = not GameDatabase.has_user_save()

func _on_continue_pressed() -> void:
	# GameDatabase 已在启动时加载 user:// 存档，这里直接进入选关。
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_start_pressed() -> void:
	if not GameDatabase.start_new_game():
		status_label.text = "新游戏存档创建失败，请检查存档权限"
		return
	GameSession.reset_run_state()
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_roster_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/progression_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
