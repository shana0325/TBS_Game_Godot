# 地图网格：Grid 负责二维 Tile 的存储、取格子和获取上下左右可通行邻居。
# 支持双战场：左右两个子战场 + 中间不可通行的 gap 空区（side_width>0 时启用）。
class_name Grid
extends RefCounted

var width: int
var height: int
var tiles: Array = []
var side_width: int = 0
var gap_width: int = 0
var enemy_offset_x: int = 0

func _init(p_width: int = 1, p_height: int = 1) -> void:
	width = p_width
	height = p_height
	rebuild()

# 配置为双战场：总宽 = side_width * 2 + gap_width，中间 gap 列不可通行。
func setup_dual(p_side_width: int, p_height: int, p_gap_width: int) -> void:
	side_width = p_side_width
	gap_width = p_gap_width
	height = p_height
	enemy_offset_x = p_side_width + p_gap_width
	width = p_side_width * 2 + p_gap_width
	rebuild()

func is_dual() -> bool:
	return side_width > 0

func rebuild() -> void:
	tiles.clear()
	for y in range(height):
		var row: Array = []
		for x in range(width):
			var tile := Tile.new(x, y)
			if is_dual() and x >= side_width and x < enemy_offset_x:
				tile.passable = false
			row.append(tile)
		tiles.append(row)

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func get_tile(x: int, y: int) -> Tile:
	if not in_bounds(x, y):
		return null
	return tiles[y][x]

# 返回全局坐标所属战场：player / enemy / ""（gap 或越界）。
func get_side_for_position(x: int, y: int) -> String:
	if not is_dual() or not in_bounds(x, y):
		return ""
	if x < side_width:
		return "player"
	if x >= enemy_offset_x:
		return "enemy"
	return ""

# 跨战场逻辑列差：将敌方战场 X 减去 gap 偏移，映射到连续逻辑列（忽略 Y 轴）。
func cross_grid_distance(ax: int, tx: int) -> int:
	return absi(_to_logical_x(ax) - _to_logical_x(tx))

func _to_logical_x(x: int) -> int:
	if is_dual() and x >= enemy_offset_x:
		return x - gap_width
	return x

func set_terrain(pos: Vector2i, move_cost: int = 1, defense_bonus: int = 0, passable: bool = true) -> void:
	var tile := get_tile(pos.x, pos.y)
	if tile != null:
		tile.move_cost = move_cost
		tile.defense_bonus = defense_bonus
		tile.passable = passable

func get_neighbors(tile: Tile) -> Array:
	var neighbors: Array = []
	if tile == null:
		return neighbors
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor := get_tile(tile.x + offset.x, tile.y + offset.y)
		if neighbor != null and neighbor.passable:
			neighbors.append(neighbor)
	return neighbors