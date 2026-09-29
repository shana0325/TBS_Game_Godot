# SkillKit：通用技能工具库，把 16 个通用技能反复出现的形态收成可复用函数。
# 涵盖：追加特效/真实伤害、按目标/相邻扩散、最高生命目标、计时技能剩余时间缩短、
#       以及"按单位状态的被动伤害倍率"集中评估（破军追击/骁勇累积/盈血之力共用）。
class_name SkillKit
extends RefCounted

# 当前战斗秒数（限流/时间窗统一取时源）。
static func now_of(battle) -> float:
	if battle != null and battle.has_method("get_battle_time"):
		return float(battle.get_battle_time())
	return 0.0

# 追加伤害：按攻击力倍数、最大生命倍数或固定值结算，默认特效伤害；可显式指定技能伤害。
static func deal_effect(user: Unit, target: Unit, game, battle, opts: Dictionary) -> Dictionary:
	if user == null or target == null or not target.alive:
		return {"damage": 0}
	var raw := 0
	if opts.has("atk"):
		raw = roundi(user.get_attack() * float(opts["atk"]))
	elif opts.has("maxhp"):
		raw = roundi(user.max_hp * float(opts["maxhp"]))
	elif opts.has("flat"):
		raw = int(opts["flat"])
	if raw <= 0:
		return {"damage": 0}
	return DamageSystem.apply(user, target, {"damage_kind": str(opts.get("damage_kind", DamageSystem.EFFECT)),
		"raw_damage": raw, "true_damage": bool(opts.get("true", false))}, battle, game)

# 目标 + 与目标曼哈顿距离 1 的所有敌方存活单位（Comet Fall 用）。
static func adjacent_enemies(battle, user: Unit, target: Unit) -> Array:
	var result: Array = []
	if battle == null or target == null:
		return result
	for unit in battle.units:
		if unit is Unit and unit.alive and unit.camp != user.camp:
			if Grid.manhattan_distance(unit.pos, target.pos) <= 1:
				result.append(unit)
	return result

# 当前敌方最大生命最高的存活单位（Demolish Scene 用）。
static func max_hp_enemy(battle, user: Unit) -> Unit:
	var best: Unit = null
	var best_hp := -1
	for unit in battle.units:
		if unit is Unit and unit.alive and unit.camp != user.camp:
			if unit.max_hp > best_hp:
				best_hp = unit.max_hp
				best = unit
	return best

# 判断单位是否仍能获得护盾，供各种友军选目标规则共用。
static func can_receive_shield(unit: Unit) -> bool:
	if unit == null or not unit.alive:
		return false
	var shield_cap: int = unit.get_shield_cap()
	return shield_cap < 0 or unit.get_total_shield() < shield_cap

# 为可选择友军的护盾效果选目标：跳过满盾单位，可按当前生命值或生命比例排序。
# 明确指定自身的护盾效果应直接调用 gain_shield，不使用此选择函数。
static func lowest_hp_shield_ally(battle, user: Unit, exclude_self: bool = false, by_hp_ratio: bool = false) -> Unit:
	if battle == null or user == null:
		return null
	var best: Unit = null
	var best_hp := INF
	for candidate in battle.units:
		if not (candidate is Unit):
			continue
		var ally: Unit = candidate
		if ally.camp != user.camp or (exclude_self and ally == user):
			continue
		if not can_receive_shield(ally):
			continue
		var current_hp := float(ally.hp) / maxf(ally.max_hp, 1.0) if by_hp_ratio else float(ally.hp)
		if best == null or current_hp < best_hp:
			best = ally
			best_hp = current_hp
	return best

# 缩短 unit 名下所有正在等待的 on_timer 技能中剩余时间最长者的剩余时间（至少为 0）。
# 可选排除某技能（如回响节点缩短"其他"时排除自身）。
static func shorten_timed(unit: Unit, seconds: float, exclude: Skill = null) -> int:
	if unit == null or seconds <= 0.0:
		return 0
	var longest: Skill = null
	var longest_remaining := -1.0
	for skill in unit.skills:
		if not (skill is Skill) or skill.trigger != SkillTriggerSystem.ON_TIMER:
			continue
		if skill == exclude:
			continue
		if skill.interval_remaining > 0.0 and skill.interval_remaining > longest_remaining:
			longest_remaining = skill.interval_remaining
			longest = skill
	if longest == null:
		return 0
	longest.interval_remaining = maxf(0.0, longest.interval_remaining - seconds)
	return 1

# 缩短剩余时间最长者的一定比例（回响节点"减少 30%"用）。
static func shorten_timed_percent(unit: Unit, percent: float, exclude: Skill = null) -> int:
	if unit == null or percent <= 0.0:
		return 0
	var longest: Skill = null
	var longest_remaining := -1.0
	for skill in unit.skills:
		if not (skill is Skill) or skill.trigger != SkillTriggerSystem.ON_TIMER:
			continue
		if skill == exclude:
			continue
		if skill.interval_remaining > 0.0 and skill.interval_remaining > longest_remaining:
			longest_remaining = skill.interval_remaining
			longest = skill
	if longest == null:
		return 0
	longest.interval_remaining = maxf(0.0, longest.interval_remaining * (1.0 - percent))
	return 1

# 回响节点：每次自身某个"按秒触发"技能实际施放时调用，累计达到 3 次后，
# 把其他按秒触发技能中剩余时间最长者的剩余时间缩短 30%，并重置计数。
# 由 BattleManager._tick_timed_skills 在定时技能施放成功后回调。
static func register_timed_cast(unit: Unit, fired: Skill = null) -> void:
	if unit == null or not unit.has_skill("Transcend Row"):
		return
	var rt := unit.runtime
	if rt.bump("echo_count") >= 3:
		rt.stack_set("echo_count", 0)
		shorten_timed_percent(unit, 0.30, fired)

# 按单位当前状态评估"普攻/技能伤害"的被动百分比加成（技能侧；遗物侧见 RelicSystem）。
# 只在 kind != effect 时被调用。破军追击 / 骁勇累积 / 盈血之力 在此集中结算。
static func passive_damage_bonus(source: Unit, target: Unit) -> float:
	if source == null or target == null:
		return 0.0
	var bonus := 0.0
	var rt := source.runtime
	# 破军追击：满 3 层且当前目标未更换 → +50%
	if source.has_skill("Triple Pursuit"):
		if rt.stack_get("triple_count") >= 3 \
				and int(rt.notes.get("triple_target", -1)) == target.get_instance_id():
			bonus += 0.50
	# 骁勇累积：每层 +2%
	if source.has_skill("Onset Might"):
		bonus += 0.02 * float(rt.stack_get("onset"))
	# 盈血之力：生命 > 70% → +40%
	if source.has_skill("Absolute Focus"):
		if float(source.hp) / maxf(source.max_hp, 1.0) > 0.7:
			bonus += 0.40
	return bonus
