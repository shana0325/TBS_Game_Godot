# 技能：Skill 是技能模板，包含射程和 effect 列表，由 skills.json 创建。
class_name Skill
extends RefCounted

var name: String
var min_range: int
var max_range: int
var effects: Array = []

static func from_data(data: Dictionary) -> Skill:
	var skill := Skill.new()
	skill.name = str(data.get("name", data.get("id", "Skill")))
	skill.min_range = int(data.get("min_range", 1))
	skill.max_range = int(data.get("max_range", 1))
	skill.effects = data.get("effects", [])
	return skill

func execute(user: Unit, target: Unit, game = null) -> Dictionary:
	# 技能执行统一交给 EffectSystem，Skill 自身只保存数据和射程。
	return EffectSystem.apply_effects(user, target, effects, game)