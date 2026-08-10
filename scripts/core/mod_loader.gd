# Mod 加载器：扫描 mods/ 目录（res:// 与 user:// 均可），读取 mod.json 元数据，
# 把 units/skills/buffs/equipments 合并进 GameDatabase，实现"放文件夹即生效"的 mod 扩展。
# mod 目录结构：
#   mods/<mod_id>/
#     mod.json          # 必填：id/name/version/author
#     units/*.json      # 单位数据（key 为 unit_type，与 GameDatabase 合并）
#     skills/*.json     # 技能数据
#     buffs/*.json      # Buff 数据
#     equipments/*.json # 装备数据
#     art/units/<unit_type>/   # 角色素材：idle/attack/hurt/death/skill/portrait.png
extends Node

const MOD_CATEGORIES := ["units", "skills", "buffs", "equipments"]

var loaded_mods: Array = []

func _ready() -> void:
	_load_mods_from("res://mods")
	_load_mods_from("user://mods")
	for mod in loaded_mods:
		print("Mod loaded: %s v%s by %s" % [mod.get("name", mod.get("id", "?")), mod.get("version", "?"), mod.get("author", "?")])

# 扫描指定根目录下所有 mod 子目录，合并数据。
func _load_mods_from(root: String) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var mod_id := dir.get_next()
	while mod_id != "":
		if not dir.current_is_dir() and not mod_id.begins_with("."):
			mod_id = dir.get_next()
			continue
		if mod_id.begins_with("."):
			mod_id = dir.get_next()
			continue
		var mod_dir := root + "/" + mod_id
		if FileAccess.file_exists(mod_dir + "/mod.json"):
			var manifest := _load_json(mod_dir + "/mod.json")
			_merge_mod(mod_dir, manifest)
			loaded_mods.append(manifest)
		mod_id = dir.get_next()
	dir.list_dir_end()

# 合并单个 mod 的 JSON 数据到 GameDatabase。
func _merge_mod(mod_dir: String, manifest: Dictionary) -> void:
	for category in MOD_CATEGORIES:
		var data := _merge_category(mod_dir, category)
		if not data.is_empty():
			var target: Dictionary = GameDatabase.get(category)
			for key in data:
				target[key] = data[key]

func _merge_category(mod_dir: String, category: String) -> Dictionary:
	var result: Dictionary = {}
	var cat_dir := mod_dir + "/" + category
	var dir := DirAccess.open(cat_dir)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var parsed = _load_json(cat_dir + "/" + file_name)
			if typeof(parsed) == TYPE_DICTIONARY:
				for key in parsed:
					result[key] = parsed[key]
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
