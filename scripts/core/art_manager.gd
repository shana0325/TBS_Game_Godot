# 素材管理器：按单位类型、动作和技能名称查询游戏贴图。
# 动作名：stand(站立)/move(移动)/attack(攻击)/death(死亡)/skill(技能)/portrait(立绘)。
# 查找顺序：mod 素材目录（res://mods → user://mods）→ 内置 assets/units/<Type>/<action>.png
#          → 内置单文件 assets/units/<type>.png（回退，仅站立）。缺省动作回退到站立。
extends Node

const BUILTIN_DIR := "res://assets/units/"
const SKILL_ICON_DIR := "res://assets/skills/"
var _skill_icon_files: Array[String] = []

# 技能名到图标文件名关键词的映射。关键词直接对应素材文件名，不依赖图片内容检查。
const SKILL_ICON_HINTS := {
	"Power Strike": ["staff_strike", "club_attack", "axe"],
	"Cleave": ["shadow_swords", "swords", "sword", "axe"],
	"Execute": ["gutt", "death", "dead", "sword"],
	"Lifesteal": ["heal", "healing", "blood", "life"],
	"Iron Wall": ["shield", "armor", "guard"],
	"Toughness": ["shield", "armor", "guard"],
	"Revive": ["heal", "light", "life", "phoenix"],
	"Sharp": ["arrow", "sword", "crit", "blade"],
	"Lethal": ["death", "gutt", "sword", "blade"],
	"Thorns": ["venom", "poison", "thorn"],
	"Fear": ["shadow", "dark", "fear", "moon"],
	"强力打击": ["staff_strike", "club_attack", "axe"],
	"连斩": ["shadow_swords", "swords", "sword", "axe"],
	"斩杀": ["gutt", "death", "dead", "sword"],
	"吸血": ["heal", "healing", "blood", "life"],
	"铁壁": ["shield", "armor", "guard"],
	"坚韧": ["shield", "armor", "guard"],
	"复苏": ["heal", "light", "life", "phoenix"],
	"锐利": ["arrow", "sword", "crit", "blade"],
	"致命": ["death", "gutt", "sword", "blade"],
	"荆棘": ["venom", "poison", "thorn"],
	"破胆": ["shadow", "dark", "fear", "moon"]
}
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
	if path == "":
		path = _find_sprite_path(unit_type, "stand")
	if path != "":
		return load(path)
	return null

# 获取技能图标。先按技能 ID 的专用关键词匹配，再按技能名称匹配，最后使用稳定的通用图标。
func get_skill_icon(skill_id: String, skill_name: String = "") -> Texture2D:
	var path := _find_skill_icon_path(skill_id, skill_name)
	if path != "":
		return load(path)
	return null

func _find_skill_icon_path(skill_id: String, skill_name: String) -> String:
	var files := _get_skill_icon_files()
	if files.is_empty():
		return ""
	var hints: Array = SKILL_ICON_HINTS.get(skill_id, [])
	if hints.is_empty():
		hints = SKILL_ICON_HINTS.get(skill_name, [])
	var search_text := _normalize_icon_text("%s %s" % [skill_id, skill_name])
	for hint in hints:
		var hint_text := _normalize_icon_text(str(hint))
		for file_name in files:
			if _normalize_icon_text(file_name).find(hint_text) >= 0:
				return SKILL_ICON_DIR + file_name
	for token in search_text.replace("_", " ").split(" "):
		if token.length() < 3:
			continue
		for file_name in files:
			if _normalize_icon_text(file_name).find(token) >= 0:
				return SKILL_ICON_DIR + file_name
	# 没有语义关键词时也使用素材，保证技能卡不会退回纯文字。
	var fallback_index := absi(hash(search_text)) % files.size()
	return SKILL_ICON_DIR + files[fallback_index]

func _get_skill_icon_files() -> Array[String]:
	if not _skill_icon_files.is_empty():
		return _skill_icon_files
	var dir := DirAccess.open(SKILL_ICON_DIR)
	if dir == null:
		return _skill_icon_files
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
			_skill_icon_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	_skill_icon_files.sort()
	return _skill_icon_files

func _normalize_icon_text(value: String) -> String:
	return value.to_lower().replace("-", "_").replace(" ", "_")

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
