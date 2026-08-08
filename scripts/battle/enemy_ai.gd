# 敌方 AI：返回简单决策——射程内有玩家就攻击，否则朝最近的玩家移动一格范围内最优位置。
class_name EnemyAI
extends RefCounted

static func get_decision(manager: BattleManager, unit: Unit) -> Dictionary:
	if manager == null or unit == null:
		return {"action": "wait"}
	var targets := manager.get_attack_targets(unit)
	if targets.size() > 0:
		return {"action": "attack", "target": targets[0]}
	var nearest := manager.get_nearest_target(unit)
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

# 跨战场距离：同战场 Chebyshev；跨战场逻辑列差（忽略 Y），与攻击判定一致。
static func _combat_distance(manager: BattleManager, a: Vector2i, b: Vector2i) -> int:
	var grid: Grid = manager.grid
	if grid != null and grid.is_dual():
		var a_side := grid.get_side_for_position(a.x, a.y)
		var b_side := grid.get_side_for_position(b.x, b.y)
		if a_side != "" and b_side != "" and a_side != b_side:
			return grid.cross_grid_distance(a.x, b.x)
	return maxi(abs(a.x - b.x), abs(a.y - b.y))
