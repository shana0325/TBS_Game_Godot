# 移动范围：Pathfinder 使用 Dijkstra 计算可到达格子，并提供简单路径回溯。
class_name Pathfinder
extends RefCounted

static func get_reachable_tiles(grid: Grid, start_tile: Tile, move_points: int) -> Array:
	var result: Array = []
	if grid == null or start_tile == null or move_points < 0:
		return result
	if not start_tile.passable:
		return result
	var costs: Dictionary = {start_tile: 0}
	var queue: Array = [start_tile]
	while queue.size() > 0:
		var current = queue.pop_front()
		result.append(current)
		for neighbor in grid.get_neighbors(current):
			var new_cost: int = costs[current] + neighbor.move_cost
			if new_cost <= move_points and (not costs.has(neighbor) or new_cost < costs[neighbor]):
				costs[neighbor] = new_cost
				queue.append(neighbor)
	return result

static func find_path(grid: Grid, start_tile: Tile, goal_tile: Tile) -> Array:
	var path: Array = []
	if grid == null or start_tile == null or goal_tile == null:
		return path
	var costs: Dictionary = {start_tile: 0}
	var came_from: Dictionary = {start_tile: null}
	var queue: Array = [start_tile]
	while queue.size() > 0:
		var current = queue.pop_front()
		if current == goal_tile:
			break
		for neighbor in grid.get_neighbors(current):
			var new_cost: int = costs[current] + neighbor.move_cost
			if not costs.has(neighbor) or new_cost < costs[neighbor]:
				costs[neighbor] = new_cost
				came_from[neighbor] = current
				queue.append(neighbor)
	if not came_from.has(goal_tile):
		return path
	var cursor = goal_tile
	while cursor != null:
		path.push_front(cursor)
		cursor = came_from[cursor]
	return path