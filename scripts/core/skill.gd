# 技能：Skill 是技能模板，包含触发时机、条件、目标与 effect 列表。
# 双轨制：
#  - JSON 轨：数据来自 skills.json，由 SkillTriggerSystem 的数据驱动逻辑自动触发。
#  - 代码轨：继承 CodeSkill 并覆写 check_condition / resolve_targets / execute 实现复杂逻辑。
class_name Skill
extends RefCounted

var name: String
var skill_id: String = ""
var desc: String = ""
var trigger: String = "on_attack"
var condition: Dictionary = {}
var cooldown: int = 0
var priority: int = 0
var min_range: int = 1
var max_range: int = 1
var effects: Array = []
var cooldown_remaining: int = 0
var common: bool = false
var tags: Array = []
var searchable: bool = true
var code_script: GDScript = null
var once: bool = false
var triggered: bool = false

static func from_data(data: Dictionary) -> Skill:
	var skill: Skill
	if data.get("code_script") is GDScript:
		skill = (data["code_script"] as GDScript).new() as Skill
		if skill == null:
			skill = Skill.new()
		skill.code_script = data["code_script"]
	else:
		skill = Skill.new()
	skill.skill_id = str(data.get("id", data.get("name", "Skill")))
	skill.name = str(data.get("name", data.get("id", "Skill")))
	skill.desc = str(data.get("desc", ""))
	skill.trigger = str(data.get("trigger", "on_attack"))
	skill.condition = data.get("condition", {})
	skill.cooldown = int(data.get("cooldown", 0))
	skill.priority = int(data.get("priority", 0))
	skill.min_range = int(data.get("min_range", 1))
	skill.max_range = int(data.get("max_range", 1))
	skill.effects = data.get("effects", [])
	skill.common = bool(data.get("common", false))
	skill.tags = _string_array(data.get("tags", []))
	skill.searchable = bool(data.get("searchable", true))
	skill.once = bool(data.get("once", false))
	if skill is CodeSkill:
		(skill as CodeSkill).after_from_data(data)
	return skill

static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	return result

# 判断技能当前是否可触发（不在冷却中）。
func is_ready() -> bool:
	return cooldown_remaining <= 0 and not (once and triggered)

# 触发后进入冷却，回合推进时由外部调用 tick_cooldown() 减少。
func start_cooldown() -> void:
	cooldown_remaining = cooldown
	if once:
		triggered = true

func tick_cooldown() -> void:
	if cooldown_remaining > 0:
		cooldown_remaining -= 1

# --- 可覆写钩子：触发条件 ---
# 默认按 JSON condition 字典判断；代码技能可完全覆写（血量/护盾/任意自定义）。
func check_condition(battle, context: Dictionary) -> bool:
	if condition.is_empty():
		return true
	if condition.has("hp_percent"):
		var op = condition["hp_percent"]
		var val := float(get_self_hp_percent(context))
		if not compare_num(val, op):
			return false
	if condition.has("has_buff"):
		var buff_name: String = str(condition["has_buff"])
		if not unit_has_buff(context.get("actor"), buff_name):
			return false
	if condition.has("target_has_buff"):
		var buff_name2: String = str(condition["target_has_buff"])
		var target = context.get("target")
		if target == null or not (target is Unit) or not unit_has_buff(target, buff_name2):
			return false
	if condition.has("target_hp_percent"):
		var target_hp: Variant = context.get("target")
		if target_hp == null or not (target_hp is Unit):
			return false
		var target_ratio := float((target_hp as Unit).hp) / float(maxi((target_hp as Unit).max_hp, 1))
		if not compare_num(target_ratio, condition["target_hp_percent"]):
			return false
	if condition.has("crit") and bool(condition.get("crit", false)) != bool(context.get("crit", false)):
		return false
	return true

# 默认按 condition.target_type 解析目标；代码技能可覆写。
func resolve_targets(battle, user: Unit, context: Dictionary) -> Array:
	var target_type: String = str(condition.get("target_type", condition.get("target", "target")))
	var targets: Array = []
	match target_type:
		"self":
			targets.append(user)
		"target":
			var t = context.get("target")
			if t != null and (t is Unit) and (t as Unit).alive:
				targets.append(t)
		"enemy":
			targets = units_in_range(battle, user, "enemy", min_range, max_range)
		"ally":
			targets = units_in_range(battle, user, "ally", min_range, max_range)
		"all_enemies":
			targets = all_units(battle, user, "enemy")
		"all_allies":
			targets = all_units(battle, user, "ally")
		_:
			var t2 = context.get("target")
			if t2 != null and (t2 is Unit) and (t2 as Unit).alive:
				targets.append(t2)
	return targets

# 执行技能：默认对目标列表逐一应用 effect 列表；代码技能可覆写。
func execute(user: Unit, targets: Array, game = null) -> Array:
	var reports: Array = []
	for target in targets:
		var r := EffectSystem.apply_effects(user, target, effects, game)
		reports.append({"target": target, "report": r})
	return reports

# 条件参考值：自身血量比例（默认用 actor，代码技能的 check_condition 可自行取用）。
func get_self_hp_percent(context: Dictionary) -> float:
	var actor = context.get("actor")
	if actor != null and (actor is Unit):
		return float((actor as Unit).hp) / float(maxi((actor as Unit).max_hp, 1))
	return 1.0

# 数值比较（lt/lte/gt/gte/eq）。
static func compare_num(val: float, op: Dictionary) -> bool:
	var lt = op.get("lt")
	var lte = op.get("lte")
	var gt = op.get("gt")
	var gte = op.get("gte")
	var eq = op.get("eq")
	if lt != null and not (val < float(lt)):
		return false
	if lte != null and not (val <= float(lte)):
		return false
	if gt != null and not (val > float(gt)):
		return false
	if gte != null and not (val >= float(gte)):
		return false
	if eq != null and not is_equal_approx(val, float(eq)):
		return false
	return true

static func unit_has_buff(unit, buff_name: String) -> bool:
	if unit == null:
		return false
	for buff in (unit as Unit).buffs:
		if buff.name == buff_name:
			return true
	return false

# 指定阵营、射程内的存活单位（供默认目标解析使用）。
static func units_in_range(battle, user: Unit, camp: String, min_r: int, max_r: int) -> Array:
	var result: Array = []
	for unit in battle.units:
		if not (unit is Unit) or not unit.alive or unit == user:
			continue
		var is_enemy: bool = unit.camp != user.camp
		var match: bool = (camp == "enemy" and is_enemy) or (camp == "ally" and not is_enemy)
		if not match:
			continue
		var d := Grid.manhattan_distance(user.pos, unit.pos)
		if d >= min_r and d <= max_r:
			result.append(unit)
	return result

# 全体阵营存活单位（供默认目标解析使用）。
static func all_units(battle, user: Unit, camp: String) -> Array:
	var result: Array = []
	for unit in battle.units:
		if not (unit is Unit) or not unit.alive or unit == user:
			continue
		var is_enemy: bool = unit.camp != user.camp
		var match: bool = (camp == "enemy" and is_enemy) or (camp == "ally" and not is_enemy)
		if match:
			result.append(unit)
	return result
