# 素材管理器：按单位类型与动作查询贴图。
# 动作名：stand(站立)/move(移动)/attack(攻击)/death(死亡)/skill(技能)/portrait(立绘)。
# 查找顺序：mod 素材目录（res://mods → user://mods）→ 内置 assets/units/<Type>/<action>.png
#          → 内置单文件 assets/units/<type>.png（回退，仅站立）。缺省动作回退到站立。
extends Node

const BUILTIN_DIR := "res://assets/units/"
# 获取单位战斗小人贴图。action: stand/move/attack/death/skill。
func get_unit_sprite(unit_type: String, action: String = "stand") -> Texture2D:
	var path: String = _find_sprite_path(unit_type, action)
	if path == "" and action != "stand":
		path = _find_sprite_path(unit_type, "stand")
	if path != "":
		return load(path)
	return null

# 获取单位立绘贴图。
func get_portrait(unit_type: String) -> Texture2D:
	var path: String = _find_sprite_path(unit_type, "portrait")
	if path != "":
		return load(path)
	return null

# 按查找顺序返回首个存在的贴图路径。
func _find_sprite_path(unit_type: String, action: String) -> String:
	# 1. mod 素材目录
	for root in ["res://mods", "user://mods"]:
		for mod_dir in _list_subdirs(root):
			var path: String = str(mod_dir) + "/art/units/%s/%s.png" % [unit_type, action]
			if _res_exists(path):
				return path
	# 2. 内置动作目录 assets/units/<Type>/<action>.png
	var action_dir := BUILTIN_DIR + unit_type + "/" + action + ".png"
	if _res_exists(action_dir):
		return action_dir
	# 3. 内置单文件回退（仅站立）
	if action == "stand":
		var single := BUILTIN_DIR + unit_type.to_lower() + ".png"
		if _res_exists(single):
			return single
	return ""

# 资源存在性检查：优先 ResourceLoader（兼容导出包内的导入资源重映射，
# 如网页版/PCK 中源贴图以 remap 形式存在、FileAccess 看不到），回退 FileAccess。
func _res_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(path)

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
