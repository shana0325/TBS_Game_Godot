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
	if move_tiles.is_empty():
		return {"action": "wait"}
	# 以目标为源做障碍感知的 Dijkstra，取真实路径距离最近的可走格；
	# 绕路第一步虽然曼哈顿距离变远，但真实路径距离是递减的，单位会主动绕行。
	var dists := _path_distances(manager, nearest.pos, unit.pos)
	var unreachable := 999999
	var current_dist: int = dists.get(unit.pos, unreachable)
	var best := unit.pos
	var best_dist := current_dist
	for cell in move_tiles:
		var d: int = dists.get(cell, unreachable)
		if d < best_dist:
			best = cell
			best_dist = d
	if best == unit.pos:
		# 当前格不可达（被完全堵死）但存在可达邻格时，朝可达方向走
		for cell in move_tiles:
			if dists.get(cell, unreachable) < unreachable:
				best = cell
				break
	if best == unit.pos:
		return {"action": "wait"}
	return {"action": "move", "to": best}

# 目标格的障碍感知路径距离：从 goal 出发做 Dijkstra，其他存活单位视为不可通行。
# 返回 { Vector2i: 距离 }。exclude_pos 为移动单位自身位置（不阻挡）。
static func _path_distances(manager: BattleManager, goal: Vector2i, exclude_pos: Vector2i) -> Dictionary:
	var result := {}
	var grid := manager.grid
	if grid == null:
		return result
	var start_tile := grid.get_tile(goal.x, goal.y)
	if start_tile == null:
		return result
	var blocked := {}
	for u in manager.units:
		if u is Unit and u.alive and u.pos != goal and u.pos != exclude_pos:
			blocked[u.pos] = true
	var dist := {start_tile: 0}
	var queue: Array = [start_tile]
	while queue.size() > 0:
		var current = queue.pop_front()
		result[current.get_position()] = dist[current]
		for neighbor in grid.get_neighbors(current):
			if blocked.has(neighbor.get_position()):
				continue
			if not neighbor.passable:
				continue
			var nd: int = dist[current] + neighbor.move_cost
			if not dist.has(neighbor) or nd < dist[neighbor]:
				dist[neighbor] = nd
				queue.append(neighbor)
	return result

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
