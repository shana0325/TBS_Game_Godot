# 战斗系统：CombatSystem 负责普通攻击执行、事件分发和基础射程判断。
# 射程规则：同战场用 Chebyshev 距离；跨战场时忽略 Y 轴，按逻辑列差计算（对应原版双战场规则）。
class_name CombatSystem
extends RefCounted

var game = null
var event_system: EventSystem = null
var grid: Grid = null

func _init(p_game = null, p_event_system: EventSystem = null, p_grid: Grid = null) -> void:
	game = p_game
	event_system = p_event_system
	grid = p_grid

func perform_attack(attacker: Unit, defender: Unit, terrain_bonus: int = 0) -> int:
	if attacker == null or defender == null or not defender.alive:
		return 0
	var damage := DamageCalculator.calculate_damage(attacker, defender, terrain_bonus)
	var result := defender.take_damage(damage, game)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 攻击 %s，造成 %d 点伤害" % [attacker.get_display_name(), defender.get_display_name(), damage])
	if event_system != null:
		event_system.dispatch(BattleEvent.new(EventTypes.ON_ATTACK, attacker, defender, {"damage": damage, "result": result}))
		event_system.dispatch(BattleEvent.new(EventTypes.ON_HIT, attacker, defender, {"damage": damage, "result": result}))
		if result.get("lethal", false):
			event_system.dispatch(BattleEvent.new(EventTypes.ON_KILL, attacker, defender, {"damage": damage, "result": result}))
	return damage

func is_in_range(attacker: Unit, defender: Unit) -> bool:
	if attacker == null or defender == null:
		return false
	var distance := _get_combat_distance(attacker, defender.pos)
	return distance >= attacker.get_range_min() and distance <= attacker.get_range_max()

# 计算攻击者到目标格子的战斗距离：同战场 Chebyshev；跨战场逻辑列差（忽略 Y）。
func _get_combat_distance(attacker: Unit, target_pos: Vector2i) -> int:
	if grid != null and grid.is_dual():
		var attacker_side := grid.get_side_for_position(attacker.pos.x, attacker.pos.y)
		var target_side := grid.get_side_for_position(target_pos.x, target_pos.y)
		if attacker_side != "" and target_side != "" and attacker_side != target_side:
			return grid.cross_grid_distance(attacker.pos.x, target_pos.x)
	return maxi(abs(attacker.pos.x - target_pos.x), abs(attacker.pos.y - target_pos.y))