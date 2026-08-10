# 素材管理器：按单位类型与动作查询贴图，查找顺序为 mod 素材目录（res://mods → user://mods）→ 内置 assets/units。
# 动作图命名约定：idle/attack/hurt/death/skill.png，只有 idle 时其余动作回退到 idle；立绘为 portrait.png。
extends Node

const BUILTIN_DIR := "res://assets/units/"

# 获取单位战斗小人贴图。action: idle/attack/hurt/death/skill。
func get_unit_sprite(unit_type: String, action: String = "idle") -> Texture2D:
	var path: String = _find_sprite_path(unit_type, action)
	if path == "" and action != "idle":
		path = _find_sprite_path(unit_type, "idle")
	if path != "":
		return load(path)
	return null

# 获取单位立绘贴图。
func get_portrait(unit_type: String) -> Texture2D:
	return get_unit_sprite(unit_type, "portrait")

# 按查找顺序返回首个存在的贴图路径。
func _find_sprite_path(unit_type: String, action: String) -> String:
	for root in ["res://mods", "user://mods"]:
		for mod_dir in _list_subdirs(root):
			var path: String = str(mod_dir) + "/art/units/%s/%s.png" % [unit_type, action]
			if FileAccess.file_exists(path):
				return path
	var builtin := BUILTIN_DIR + unit_type.to_lower() + ".png"
	if action == "idle" and FileAccess.file_exists(builtin):
		return builtin
	return ""

func _list_subdirs(root: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(root)
	if dir == null:
		return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			result.append(root + "/" + name)
		name = dir.get_next()
	dir.list_dir_end()
	return result
