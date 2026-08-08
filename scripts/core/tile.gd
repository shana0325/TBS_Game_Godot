# 地图格子：Tile 只保存单个格子的坐标、移动消耗、防御加成和通行状态。
class_name Tile
extends RefCounted

var x: int
var y: int
var move_cost: int
var defense_bonus: int
var passable: bool

func _init(p_x: int = 0, p_y: int = 0, p_move_cost: int = 1, p_defense_bonus: int = 0, p_passable: bool = true) -> void:
	x = p_x
	y = p_y
	move_cost = p_move_cost
	defense_bonus = p_defense_bonus
	passable = p_passable

func get_position() -> Vector2i:
	return Vector2i(x, y)