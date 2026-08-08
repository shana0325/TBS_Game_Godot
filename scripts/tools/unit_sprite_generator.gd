# 像素小人生成器：按预设 JSON 用整像素矩形拼接角色 PNG，纯 GDScript 实现。
# 用法：UnitSpriteGenerator.generate_all() 或 generate_one("orc")，输出到 res://assets/units/。
class_name UnitSpriteGenerator
extends RefCounted

const PRESET_PATH := "res://tools/unit_sprite_presets.json"
const OUTPUT_DIR := "res://assets/units/"

const BASE_DRAWERS := ["human", "goblin", "orc"]

static func generate_all() -> Array:
	var presets := _load_presets()
	var paths: Array = []
	for unit_id in presets:
		paths.append(generate_one(str(unit_id), presets[unit_id]))
	return paths

static func generate_one(unit_id: String, preset: Dictionary = {}) -> String:
	var data := preset
	if data.is_empty():
		data = _load_presets().get(unit_id, {})
	if data.is_empty():
		push_error("未知单位预设: %s" % unit_id)
		return ""
	var size := int(data.get("size", 32))
	var palette := _palette(data.get("palette", {}))
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_base(image, str(data.get("base", "human")), palette)
	for feature in data.get("features", []):
		_draw_feature(image, str(feature), palette)
	var out_dir := OUTPUT_DIR
	var dir := DirAccess.open("res://")
	if dir != null:
		dir.make_dir_recursive("assets/units")
	var path := out_dir + unit_id + ".png"
	image.save_png(path)
	return path

static func _load_presets() -> Dictionary:
	if not FileAccess.file_exists(PRESET_PATH):
		push_error("缺少预设文件: %s" % PRESET_PATH)
		return {}
	var file := FileAccess.open(PRESET_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func _palette(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in raw:
		var values: Array = raw[key]
		result[key] = Color(
			float(values[0]) / 255.0,
			float(values[1]) / 255.0,
			float(values[2]) / 255.0,
			1.0
		)
	return result

# 在 image 上以 (x, y) 左上角画一个像素矩形。
static func _rect(image: Image, color: Color, x: int, y: int, w: int, h: int) -> void:
	for yy in range(h):
		for xx in range(w):
			var px := x + xx
			var py := y + yy
			if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
				image.set_pixel(px, py, color)

static func _outline_rect(image: Image, fill: Color, outline: Color, x: int, y: int, w: int, h: int) -> void:
	_rect(image, outline, x - 1, y - 1, w + 2, h + 2)
	_rect(image, fill, x, y, w, h)

static func _draw_base(image: Image, base: String, p: Dictionary) -> void:
	if not BASE_DRAWERS.has(base):
		push_warning("未知基础模板: %s" % base)
		return
	match base:
		"human":
			_human_base(image, p)
		"goblin":
			_goblin_base(image, p)
		"orc":
			_orc_base(image, p)

static func _human_base(image: Image, p: Dictionary) -> void:
	_outline_rect(image, p.skin, p.outline, 12, 3, 8, 7)      # 头
	_outline_rect(image, p.primary, p.outline, 10, 11, 12, 10)  # 躯干
	_outline_rect(image, p.secondary, p.outline, 11, 21, 4, 8)  # 左腿
	_outline_rect(image, p.secondary, p.outline, 17, 21, 4, 8)  # 右腿
	_outline_rect(image, p.skin, p.outline, 7, 12, 3, 8)        # 左臂
	_outline_rect(image, p.skin, p.outline, 22, 12, 3, 8)       # 右臂

static func _goblin_base(image: Image, p: Dictionary) -> void:
	_outline_rect(image, p.skin, p.outline, 11, 4, 10, 7)
	_outline_rect(image, p.primary, p.outline, 9, 11, 14, 9)
	_outline_rect(image, p.secondary, p.outline, 11, 20, 4, 7)
	_outline_rect(image, p.secondary, p.outline, 17, 20, 4, 7)
	_outline_rect(image, p.skin, p.outline, 6, 12, 3, 7)
	_outline_rect(image, p.skin, p.outline, 23, 12, 3, 7)

static func _orc_base(image: Image, p: Dictionary) -> void:
	_outline_rect(image, p.skin, p.outline, 11, 3, 10, 8)
	_outline_rect(image, p.primary, p.outline, 8, 11, 16, 11)
	_outline_rect(image, p.secondary, p.outline, 11, 22, 4, 7)
	_outline_rect(image, p.secondary, p.outline, 17, 22, 4, 7)
	_outline_rect(image, p.skin, p.outline, 5, 13, 3, 8)
	_outline_rect(image, p.skin, p.outline, 24, 13, 3, 8)

static func _draw_feature(image: Image, feature: String, p: Dictionary) -> void:
	match feature:
		"cape":
			_outline_rect(image, p.accent, p.outline, 9, 12, 14, 13)
		"headband":
			_rect(image, p.accent, 12, 5, 8, 2)
		"sword":
			_outline_rect(image, p.secondary, p.outline, 23, 13, 2, 10)
			_rect(image, p.accent, 22, 20, 4, 2)
		"helmet":
			_outline_rect(image, p.secondary, p.outline, 11, 2, 10, 6)
			_rect(image, p.outline, 15, 6, 2, 3)
		"shield":
			_outline_rect(image, p.primary, p.outline, 4, 13, 5, 9)
			_rect(image, p.accent, 5, 16, 3, 2)
		"spear":
			_outline_rect(image, p.secondary, p.outline, 23, 7, 1, 18)
			_rect(image, p.accent, 22, 5, 3, 3)
		"ears":
			_outline_rect(image, p.skin, p.outline, 8, 5, 2, 4)
			_outline_rect(image, p.skin, p.outline, 22, 5, 2, 4)
		"dagger":
			_outline_rect(image, p.secondary, p.outline, 24, 15, 1, 7)
			_rect(image, p.accent, 23, 19, 3, 1)
		"tusks":
			_rect(image, p.accent, 12, 9, 2, 2)
			_rect(image, p.accent, 18, 9, 2, 2)
		"axe":
			_outline_rect(image, p.secondary, p.outline, 24, 10, 1, 14)
			_outline_rect(image, p.accent, p.outline, 22, 9, 4, 4)
		"shoulders":
			_outline_rect(image, p.accent, p.outline, 6, 10, 5, 4)
			_outline_rect(image, p.accent, p.outline, 21, 10, 5, 4)
		_:
			push_warning("未知部件: %s" % feature)
