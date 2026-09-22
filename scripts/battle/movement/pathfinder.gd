# 网格寻路：使用 Dijkstra 计算带地形消耗和单位阻挡的可达范围及最短路径。
class_name Pathfinder
extends RefCounted

# 计算移动力内可到达的格子；blocked 的坐标不可穿越，起点始终允许。
static func get_reachable_tiles(grid: Grid, start_tile: Tile, move_points: int,
		blocked: Dictionary = {}) -> Array:
	var result: Array = []
	if grid == null or start_tile == null or move_points < 0:
		return result
	if not start_tile.passable:
		return result
	var costs: Dictionary = {start_tile: 0}
	var frontier: Array = [start_tile]
	var settled: Dictionary = {}
	while not frontier.is_empty():
		var current: Tile = _pop_lowest_cost(frontier, costs)
		if settled.has(current):
			continue
		settled[current] = true
		result.append(current)
		for neighbor in grid.get_neighbors(current):
			if blocked.has(neighbor.get_position()) and neighbor != start_tile:
				continue
			var new_cost: int = costs[current] + neighbor.move_cost
			if new_cost <= move_points and (not costs.has(neighbor) or new_cost < costs[neighbor]):
				costs[neighbor] = new_cost
				frontier.append(neighbor)
	return result

# 查找起点到终点的最低移动消耗路径；blocked 中的坐标不可穿越。
static func find_path(grid: Grid, start_tile: Tile, goal_tile: Tile,
		blocked: Dictionary = {}) -> Array:
	var path: Array = []
	if grid == null or start_tile == null or goal_tile == null:
		return path
	if blocked.has(goal_tile.get_position()) and goal_tile != start_tile:
		return path
	var costs: Dictionary = {start_tile: 0}
	var came_from: Dictionary = {start_tile: null}
	var frontier: Array = [start_tile]
	var settled: Dictionary = {}
	while not frontier.is_empty():
		var current: Tile = _pop_lowest_cost(frontier, costs)
		if settled.has(current):
			continue
		settled[current] = true
		if current == goal_tile:
			break
		for neighbor in grid.get_neighbors(current):
			if blocked.has(neighbor.get_position()) and neighbor != start_tile:
				continue
			var new_cost: int = costs[current] + neighbor.move_cost
			if not costs.has(neighbor) or new_cost < costs[neighbor]:
				costs[neighbor] = new_cost
				came_from[neighbor] = current
				frontier.append(neighbor)
	if not came_from.has(goal_tile):
		return path
	var cursor = goal_tile
	while cursor != null:
		path.push_front(cursor)
		cursor = came_from[cursor]
	return path

# 从待处理节点中取当前累计消耗最低者，保证 Dijkstra 按正确顺序扩展。
static func _pop_lowest_cost(frontier: Array, costs: Dictionary) -> Tile:
	var best_index := 0
	var best_cost := int(costs.get(frontier[0], 2147483647))
	for i in range(1, frontier.size()):
		var candidate_cost := int(costs.get(frontier[i], 2147483647))
		if candidate_cost < best_cost:
			best_index = i
			best_cost = candidate_cost
	return frontier.pop_at(best_index) as Tile
