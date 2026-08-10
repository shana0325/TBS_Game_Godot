# 敌方 AI：返回简单决策——射程内有玩家就攻击，否则朝最近目标移动最优位置。
# 若被嘲讽（has_taunt），则以嘲讽者为移动目标。
class_name EnemyAI
extends RefCounted

static func get_decision(manager: BattleManager, unit: Unit) -> Dictionary:
	if manager == null or unit == null:
		return {"action": "wait"}
	var targets := manager.get_attack_targets(unit)
	if targets.size() > 0:
		return {"action": "attack", "target": targets[0]}
	var nearest := _get_move_target(manager, unit)
	if nearest == null:
		return {"action": "wait"}
	var move_tiles := manager.get_move_tiles(unit)
	var best := unit.pos
	var best_dist := _combat_distance(manager, unit.pos, nearest.pos)
	for cell in move_tiles:
		var d := _combat_distance(manager, cell, nearest.pos)
		if d < best_dist:
			best = cell
			best_dist = d
	if best == unit.pos:
		return {"action": "wait"}
	return {"action": "move", "to": best}

# 移动目标：被嘲讽则朝嘲讽者移动；否则朝最近敌人。
static func _get_move_target(manager: BattleManager, unit: Unit) -> Unit:
	var taunt := _find_taunter(manager, unit)
	if taunt != null:
		return taunt
	return manager.get_nearest_target(unit)

# 查找嘲讽该单位的敌方单位（向 manager 查询可攻击的挑衅者）。
static func _find_taunter(manager: BattleManager, unit: Unit) -> Unit:
	for other in manager.units:
		if other is Unit and other.alive and other.camp != unit.camp:
			if _unit_has_taunt(other):
				return other
	return null

static func _unit_has_taunt(u: Unit) -> bool:
	for buff in u.buffs:
		if buff.control == "taunt":
			return true
	return false

# 战斗距离：曼哈顿距离（横向+纵向），与攻击判定一致。
static func _combat_distance(manager: BattleManager, a: Vector2i, b: Vector2i) -> int:
	return Grid.manhattan_distance(a, b)
