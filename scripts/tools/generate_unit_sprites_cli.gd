# 命令行入口：godot --headless --script res://scripts/tools/generate_unit_sprites_cli.gd
# 可选传参：单位 id（空格分隔），不传则生成全部。
extends SceneTree

const GENERATOR := preload("res://scripts/tools/unit_sprite_generator.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var presets := _load_presets()
	if args.size() == 0:
		_generate_all(presets)
	else:
		for arg in args:
			if presets.has(arg):
				var path: String = GENERATOR.generate_one(arg, presets[arg])
				print("generated: ", path)
			else:
				print("未知预设: ", arg)
	quit(0)

func _generate_all(presets: Dictionary) -> void:
	for unit_id in presets:
		var path: String = GENERATOR.generate_one(str(unit_id), presets[unit_id])
		print("generated: ", path)

func _load_presets() -> Dictionary:
	var file := FileAccess.open(GENERATOR.PRESET_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
