# 地图网格：Grid 负责二维 Tile 的存储、取格子和获取上下左右可通行邻居。
class_name Grid
extends RefCounted

var width: int
var height: int
var tiles: Array = []

func _init(p_width: int = 1, p_height: int = 1) -> void:
	width = p_width
	height = p_height
	rebuild()

func rebuild() -> void:
	tiles.clear()
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(Tile.new(x, y))
		tiles.append(row)

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func get_tile(x: int, y: int) -> Tile:
	if not in_bounds(x, y):
		return null
	return tiles[y][x]

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