# 代码技能基类：复杂逻辑技能通过继承本类实现，与 JSON 技能统一注册使用。
# 可选覆写（不覆写则用基类的数据驱动默认行为）：
#   - check_condition(battle, context)：触发条件（血量/护盾/任意自定义判断）
#   - resolve_targets(battle, user, context)：目标解析
#   - execute(user, targets, game)：效果执行（可调用 EffectSystem 或写任意逻辑）
# 元数据（名称/描述/触发时机/冷却/射程/common 等）在声明处或 _init 中设置，
# GameDatabase 启动时通过 export_meta() 收集，合并进全局技能表。
class_name CodeSkill
extends Skill

# 供 GameDatabase 合并注册用：导出本技能的元数据。
func export_meta() -> Dictionary:
	return {
		"name": name,
		"desc": desc,
		"trigger": trigger,
		"condition": condition,
		"cooldown": cooldown,
		"priority": priority,
		"min_range": min_range,
		"max_range": max_range,
		"effects": effects,
		"common": common,
		"tags": tags,
		"searchable": searchable,
		"once": once,
	}

# from_data 构造后回调：代码技能可在这里做初始化（读取数据中的附加字段）。
func after_from_data(data: Dictionary) -> void:
	pass
