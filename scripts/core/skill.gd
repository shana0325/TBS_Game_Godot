# 技能：Skill 是技能模板，包含触发时机、条件、目标与 effect 列表，由 skills.json 创建。
# 自走棋模式下技能不手动施放，而是由 SkillTriggerSystem 在战斗事件流中自动触发。
class_name Skill
extends RefCounted

var name: String
var trigger: String = "on_attack"
var condition: Dictionary = {}
var cooldown: int = 0
var priority: int = 0
var min_range: int = 1
var max_range: int = 1
var effects: Array = []
var cooldown_remaining: int = 0

static func from_data(data: Dictionary) -> Skill:
	var skill := Skill.new()
	skill.name = str(data.get("name", data.get("id", "Skill")))
	skill.trigger = str(data.get("trigger", "on_attack"))
	skill.condition = data.get("condition", {})
	skill.cooldown = int(data.get("cooldown", 0))
	skill.priority = int(data.get("priority", 0))
	skill.min_range = int(data.get("min_range", 1))
	skill.max_range = int(data.get("max_range", 1))
	skill.effects = data.get("effects", [])
	return skill

# 判断技能当前是否可触发（不在冷却中）。
func is_ready() -> bool:
	return cooldown_remaining <= 0

# 触发后进入冷却，回合推进时由外部调用 tick_cooldown() 减少。
func start_cooldown() -> void:
	cooldown_remaining = cooldown

func tick_cooldown() -> void:
	if cooldown_remaining > 0:
		cooldown_remaining -= 1

# 执行技能：EffectSystem 对目标列表逐一应用 effect。返回结果列表。
func execute(user: Unit, targets: Array, game = null) -> Array:
	var reports: Array = []
	for target in targets:
		var r := EffectSystem.apply_effects(user, target, effects, game)
		reports.append({"target": target, "report": r})
	return reports
