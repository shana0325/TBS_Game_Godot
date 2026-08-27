# 代码技能集中注册文件：新增代码技能时在此登记一行（技能 id -> 脚本路径）。
# GameDatabase 启动时会把这里登记的技能与 JSON 技能合并，
# 战斗（创建单位应用技能）与界面（编成/信息面板）统一可见。
class_name SkillCodeRegistry
extends RefCounted

static func get_entries() -> Dictionary:
	return {
		# 示例：技能 id（与技能名一致）-> 脚本 res:// 路径
		# "Invigorate": "res://scripts/battle/skills/code/invigorate.gd",
	}