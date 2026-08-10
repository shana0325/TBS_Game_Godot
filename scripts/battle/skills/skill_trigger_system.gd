# 技能触发系统：扫描单位技能，匹配战斗事件触发时机与条件，自动施放。
# 由 BattleManager 在攻击/受击/行动等事件节点调用 dispatch(trigger, user, targets, game)。
class_name SkillTriggerSystem
extends RefCounted

# 触发时机常量（与 EventTypes 语义对应，但自走棋独立定义）
const ON_BATTLE_START := "on_battle_start"
const ON_TURN_START := "on_turn_start"
const ON_ATTACK_START := "on_attack_start"
const ON_ATTACK := "on_attack"
const ON_ATTACK_END := "on_attack_end"
const ON_HIT := "on_hit"
const ON_BE_ATTACKED := "on_be_attacked"
const ON_TAKEN_DAMAGE := "on_taken_damage"
const ON_KILL := "on_kill"
const ON_DEATH := "on_death"
const ON_ALLY_DEATH := "on_ally_death"
const ON_TURN_END := "on_turn_end"
const ON_ROUND_START := "on_round_start"
const PASSIVE := "passive"

# 分发一次触发：只检查指定单位（context.actor）中 trigger 匹配的技能，满足条件则施放。
# 受击类触发由调用方以被攻击单位为 actor 传入。
# return 本节点已施放的技能列表。
static func dispatch(battle, trigger: String, context: Dictionary) -> Array:
	var casted: Array = []
	var actor = context.get("actor")
	if actor == null or not (actor is Unit) or not actor.alive:
		return casted
	for skill in actor.skills:
		if not (skill is Skill):
			continue
		if skill.trigger != trigger:
			continue
		if not skill.is_ready():
			continue
		if not _check_condition(battle, actor, skill.condition, context):
			continue
		var targets := _resolve_targets(battle, actor, skill, context)
		if targets.is_empty():
			continue
		skill.execute(actor, targets, battle.game)
		skill.start_cooldown()
		casted.append(skill)
		if battle.game != null and battle.game.has_method("add_log"):
			battle.game.add_log("%s 触发技能 %s" % [actor.get_display_name(), skill.name])
	return casted

# 检查触发条件。当前支持基础字段，复杂组合后续扩展。
static func _check_condition(battle, unit: Unit, condition: Dictionary, context: Dictionary) -> bool:
	if condition.is_empty():
		return true
	# hp_percent
	if condition.has("hp_percent"):
		var op = condition["hp_percent"]
		var val := float(unit.hp) / float(unit.max_hp)
		if not _compare(val, op):
			return false
	if condition.has("has_buff"):
		var buff_name: String = str(condition["has_buff"])
		if not _unit_has_buff(unit, buff_name):
			return false
	if condition.has("target_has_buff"):
		var buff_name2: String = str(condition["target_has_buff"])
		var target = context.get("target")
		if target == null or not (target is Unit) or not _unit_has_buff(target, buff_name2):
			return false
	return true

static func _compare(val: float, op: Dictionary) -> bool:
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

static func _unit_has_buff(unit: Unit, buff_name: String) -> bool:
	for buff in unit.buffs:
		if buff.name == buff_name:
			return true
	return false

# 目标解析：基于技能 target 配置与 context。
# 自走棋下 target.type 支持 self / target（当前攻击目标）/ enemy / ally / all_enemies / all_allies。
static func _resolve_targets(battle, user: Unit, skill: Skill, context: Dictionary) -> Array:
	var target_type: String = str(skill.condition.get("target_type", skill.condition.get("target", "target")))
	var targets: Array = []
	match target_type:
		"self":
			targets.append(user)
		"target":
			var t = context.get("target")
			if t != null and (t is Unit) and (t as Unit).alive:
				targets.append(t)
		"enemy":
			targets = _get_all_in_range(battle, user, "enemy", skill.min_range, skill.max_range)
		"ally":
			targets = _get_all_in_range(battle, user, "ally", skill.min_range, skill.max_range)
		"all_enemies":
			targets = _all_units(battle, user, "enemy")
		"all_allies":
			targets = _all_units(battle, user, "ally")
		_:
			var t2 = context.get("target")
			if t2 != null and (t2 is Unit) and (t2 as Unit).alive:
				targets.append(t2)
	return targets

static func _get_all_in_range(battle, user: Unit, camp: String, min_r: int, max_r: int) -> Array:
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

static func _all_units(battle, user: Unit, camp: String) -> Array:
	var result: Array = []
	for unit in battle.units:
		if not (unit is Unit) or not unit.alive or unit == user:
			continue
		var is_enemy: bool = unit.camp != user.camp
		var match: bool = (camp == "enemy" and is_enemy) or (camp == "ally" and not is_enemy)
		if match:
			result.append(unit)
	return result
