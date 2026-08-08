# 主菜单占位：显示数据加载结果，验证 Godot 工程可运行。
extends Control

@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	status_label.text = GameDatabase.get_data_summary()