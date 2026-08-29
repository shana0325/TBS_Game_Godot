# 技能触发系统：扫描单位技能，匹配战斗事件触发时机与条件，自动施放。
# 由 BattleManager 在攻击/受击/行动等事件节点调用 dispatch(trigger, user, targets, game)。
# 双轨支持：条件/目标/执行均通过 Skill 对象上的钩子分发——
# JSON 技能用基类默认实现，代码技能（CodeSkill）覆写钩子。
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
	var allow_dead_actor := trigger == ON_DEATH
	if actor == null or not (actor is Unit) or (not actor.alive and not allow_dead_actor):
		return casted
	for item in actor.skills:
		if not (item is Skill):
			continue
		var skill: Skill = item
		if skill.trigger != trigger:
			continue
		if not skill.is_ready():
			continue
		if not skill.check_condition(battle, context):
			continue
		var targets := skill.resolve_targets(battle, actor, context)
		if targets.is_empty():
			continue
		var reports: Array = skill.execute(actor, targets, battle.game)
		skill.start_cooldown()
		casted.append(skill)
		var skill_damage := 0
		for report_entry in reports:
			if typeof(report_entry) != TYPE_DICTIONARY:
				continue
			var report: Dictionary = report_entry.get("report", {})
			var damage := int(report.get("damage", 0))
			if damage <= 0:
				continue
			skill_damage += damage
			var target: Unit = report_entry.get("target")
			if battle.game != null and battle.game.has_method("record_skill_damage"):
				battle.game.record_skill_damage(actor, target, damage, skill.name)
		if battle.game != null and battle.game.has_method("add_log"):
			if skill_damage > 0:
				battle.game.add_log("%s 使用技能 %s，造成 %d 点技能伤害" % [actor.get_display_name(), skill.name, skill_damage])
			else:
				battle.game.add_log("%s 触发技能 %s" % [actor.get_display_name(), skill.name])
	return casted
