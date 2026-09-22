# 通用技能：灼魂焚身 — 技能伤害命中后给目标施加灼烧：持续其接下来 3 次行动，每次行动开始受到施放者攻击力 8% 特效伤害，第三次翻倍。
extends CodeSkill

const BURN_ID := "灼魂焚身"
const BURN_HITS := 3
const BURN_ATK := 0.08

func _init() -> void:
	name = "灼魂焚身"
	desc = "技能伤害命中后给目标施加灼烧，持续其接下来的 3 次行动；每次行动开始时受到施放者攻击力 8% 的特效伤害，第三次伤害翻倍。持续伤害不再触发造成伤害类效果。"
	trigger = "on_hit"
	condition = {"target_type": "target"}
	common = true
	searchable = true
	cooldown = 0
	min_range = 1
	max_range = 2
	tags = ["通用", "减益", "持续伤害"]

func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	if battle == null:
		return []
	var t: Unit = targets[0] if targets.size() > 0 else null
	if t == null or not t.alive:
		return []
	if str(battle.get_active_hit().get("damage_kind", "")) != DamageSystem.SKILL:
		return []
	# 已存在同类灼烧则刷新到满次数，否则新挂 DotBuff。
	for buff in t.buffs:
		if buff is DotBuff and (buff as DotBuff).base_name == BURN_ID:
			(buff as DotBuff).hits_remaining = BURN_HITS
			(buff as DotBuff).caster = user
			return []
	var dot := DotBuff.new()
	dot.name = BURN_ID
	dot.base_name = BURN_ID
	dot.caster = user
	dot.atk_percent = BURN_ATK
	dot.hits_remaining = BURN_HITS
	dot.final_double = true
	t.add_buff(dot)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 被施加 %s（%d 次行动）" % [t.get_display_name(), BURN_ID, BURN_HITS])
	return []