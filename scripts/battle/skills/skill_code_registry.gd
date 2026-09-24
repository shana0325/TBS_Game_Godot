# 代码技能集中注册文件：新增代码技能时在此登记一行（技能 id -> 脚本路径）。
# GameDatabase 启动时会把这里登记的技能与 JSON 技能合并，
# 战斗（创建单位应用技能）与界面（编成/信息面板）统一可见。
class_name SkillCodeRegistry
extends RefCounted

static func get_entries() -> Dictionary:
	return {
		"Warrior Resolve": "res://scripts/battle/skills/code/warrior_resolve.gd",
		"Tank Shelter": "res://scripts/battle/skills/code/tank_shelter.gd",
		"Archer Distance": "res://scripts/battle/skills/code/archer_distance.gd",
		"Assassin Pursuit": "res://scripts/battle/skills/code/assassin_pursuit.gd",
		# 16 个通用技能的代码实现登记：key 为稳定技能 id，值指向脚本；元数据由脚本提供。
		"Triple Pursuit": "res://scripts/battle/skills/code/triple_pursuit.gd",
		"Frenzy Chain": "res://scripts/battle/skills/code/frenzy_chain.gd",
		"Onset Might": "res://scripts/battle/skills/code/onset_might.gd",
		"Blooddrain Victim": "res://scripts/battle/skills/code/blooddrain_victim.gd",
		"Calm Branch": "res://scripts/battle/skills/code/calm_branch.gd",
		"Electrocute Burst": "res://scripts/battle/skills/code/electrocute_burst.gd",
		"Blade Opening": "res://scripts/battle/skills/code/blade_opening.gd",
		"Taste Blood": "res://scripts/battle/skills/code/taste_blood.gd",
		"Comet Fall": "res://scripts/battle/skills/code/comet_fall.gd",
		"Deathfire Burn": "res://scripts/battle/skills/code/deathfire_burn.gd",
		"Transcend Row": "res://scripts/battle/skills/code/transcend_row.gd",
		"Absolute Focus": "res://scripts/battle/skills/code/absolute_focus.gd",
		"Scorch Tick": "res://scripts/battle/skills/code/scorch_tick.gd",
		"Demolish Scene": "res://scripts/battle/skills/code/demolish_scene.gd",
		"Shield Bash": "res://scripts/battle/skills/code/shield_bash.gd",
		"Second Wind": "res://scripts/battle/skills/code/second_wind.gd",
	}
