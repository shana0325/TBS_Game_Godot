# 主菜单：显示数据加载结果，提供开始游戏（进入选关/模式选择）、队伍编成与退出入口。
extends Control

@onready var status_label: Label = $StatusLabel
@onready var start_button: Button = $StartButton
@onready var roster_button: Button = $RosterButton
@onready var quit_button: Button = $QuitButton

func _ready() -> void:
	status_label.text = GameDatabase.get_data_summary()
	start_button.pressed.connect(_on_start_pressed)
	roster_button.pressed.connect(_on_roster_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_roster_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/progression_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()