# 战斗系统：CombatSystem 负责普通攻击执行、事件分发和基础射程判断。
# 射程规则：单战场 10x10，距离统一用曼哈顿距离（横向+纵向）。
class_name CombatSystem
extends RefCounted

var game = null
var event_system: EventSystem = null
var grid: Grid = null
var battle_ref: WeakRef = null

# 初始化普攻执行器及其所属战斗。
func _init(p_game = null, p_event_system: EventSystem = null, p_grid: Grid = null, p_battle = null) -> void:
	game = p_game
	event_system = p_event_system
	grid = p_grid
	battle_ref = weakref(p_battle) if p_battle != null else null

# 普通攻击执行，返回 { "damage": int, "crit": bool }。
func perform_attack(attacker: Unit, defender: Unit, terrain_bonus: int = 0, final_damage_multiplier: float = 1.0) -> Dictionary:
	var result_dict := {"damage": 0, "crit": false}
	if attacker == null or defender == null or not defender.alive:
		return result_dict
	var battle = battle_ref.get_ref() if battle_ref != null else null
	var resolved := DamageSystem.apply(attacker, defender, {"damage_kind": DamageSystem.ATTACK,
		"power": 1.0, "terrain_bonus": terrain_bonus,
		"final_damage_multiplier": final_damage_multiplier, "defer_reactions": true}, battle, game)
	var damage: int = resolved.get("damage", 0)
	var crit: bool = resolved.get("crit", false)
	var result: Dictionary = resolved.get("result", {})
	if game != null and game.has_method("add_log"):
		var prefix := "暴击！" if crit else ""
		game.add_log("%s 攻击 %s%s，造成 %d 点伤害" % [attacker.get_display_name(), defender.get_display_name(), prefix, damage])
	if event_system != null:
		event_system.dispatch(BattleEvent.new(EventTypes.ON_ATTACK, attacker, defender,
			{"damage": damage, "result": result, "crit": crit, "damage_kind": DamageSystem.ATTACK}))
	result_dict["damage"] = damage
	result_dict["crit"] = crit
	result_dict["result"] = result
	result_dict["actual_damage"] = resolved.get("actual_damage", 0)
	result_dict["damage_kind"] = DamageSystem.ATTACK
	return result_dict

func is_in_range(attacker: Unit, defender: Unit) -> bool:
	if attacker == null or defender == null:
		return false
	var distance := _get_combat_distance(attacker, defender.pos)
	return distance >= attacker.get_range_min() and distance <= attacker.get_range_max()

# 计算攻击者到目标格子的战斗距离：曼哈顿距离（横向+纵向）。
func _get_combat_distance(attacker: Unit, target_pos: Vector2i) -> int:
	return Grid.manhattan_distance(attacker.pos, target_pos)
