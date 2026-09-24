# Hero 固有技能“属性汲取”：普攻命中每名敌人一次，战后将偷取量的五分之一留存。
extends CodeSkill

const STATS := ["hp", "attack", "defense", "crit_rate", "crit_damage"]
const STEAL_RATE := 0.05
const KEEP_RATE := 0.20

var _stolen_targets: Dictionary = {}
var _stolen_totals: Dictionary = {}
var _settlement_connected := false

# 注册命中触发与技能说明；独立技能实例保存本场记录。
func _init() -> void:
	name = "属性汲取"
	desc = "普攻命中前，对每名敌人首次偷取其当前生命上限、攻击、护甲、暴击率和暴击伤害各 5%，持续本场战斗。战斗结束时若自身存活，将本场偷取量的 20% 永久保留。"
	trigger = SkillTriggerSystem.ON_ATTACK_HIT_BEFORE
	condition = {"target_type": "target"}
	common = false
	searchable = false
	tags = ["固有", "攻击", "成长"]

# 只接受本人已确认目标的普攻；技能和特效伤害不会偷取。
func check_condition(_battle, context: Dictionary) -> bool:
	var user = context.get("actor")
	var target = context.get("target")
	return context.get("damage_kind") == DamageSystem.ATTACK \
		and user is Unit and target is Unit and user != target \
		and user.alive and target.alive and user.camp != target.camp \
		and not _stolen_targets.has(target.get_instance_id())

# 扣血前目标仍存活，从其当前属性读取本次偷取量。
func resolve_targets(_battle, _user: Unit, context: Dictionary) -> Array:
	var target = context.get("target")
	return [target] if target is Unit else []

# 按目标当前属性精确偷取 5%，并记录本场累计值用于战后结算。
func execute(user: Unit, targets: Array, game = null, battle = null) -> Array:
	if user == null or targets.is_empty() or not (targets[0] is Unit):
		return []
	var target: Unit = targets[0]
	var target_id := target.get_instance_id()
	if _stolen_targets.has(target_id):
		return []
	_stolen_targets[target_id] = true
	for stat in STATS:
		var requested := maxf(0.0, target.max_hp if stat == "hp" else target.get_stat(stat)) * STEAL_RATE
		if is_zero_approx(requested):
			continue
		var transferred := -target.add_battle_stat(stat, -requested)
		user.add_battle_stat(stat, transferred, stat == "hp")
		_stolen_totals[stat] = float(_stolen_totals.get(stat, 0.0)) + transferred
	if not _settlement_connected and battle is BattleManager:
		var manager := battle as BattleManager
		manager.battle_finished.connect(_on_battle_finished.bind(user))
		_settlement_connected = true
	if game != null and game.has_method("add_log"):
		game.add_log("%s 从 %s 偷取了属性" % [user.get_display_name(), target.get_display_name()])
	return []

# 只在技能携带者存活且属于玩家存档时写入永久小数属性。
func _on_battle_finished(_winner_camp: String, user: Unit) -> void:
	if user == null or not user.alive or user.unit_id.is_empty() or _stolen_totals.is_empty():
		return
	var gains := {}
	for stat in _stolen_totals:
		gains[stat] = float(_stolen_totals[stat]) * KEEP_RATE
	ProgressManager.add_permanent_stats(user.unit_id, gains)
