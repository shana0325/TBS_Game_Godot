# 游戏设置：战斗界面可调节项的持久化存储（user://settings.json，桌面与网页通用）。
class_name GameSettings
extends RefCounted

const SETTINGS_PATH := "user://settings.json"

static var _show_damage_numbers: int = -1  # -1 = 未加载

# 是否显示伤害飙字（默认开）。
static func show_damage_numbers() -> bool:
	if _show_damage_numbers < 0:
		_show_damage_numbers = 1
		if FileAccess.file_exists(SETTINGS_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
			if typeof(parsed) == TYPE_DICTIONARY:
				_show_damage_numbers = 1 if bool(parsed.get("show_damage_numbers", true)) else 0
	return _show_damage_numbers == 1

static func set_damage_numbers(on: bool) -> void:
	_show_damage_numbers = 1 if on else 0
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"show_damage_numbers": on}, "\t"))