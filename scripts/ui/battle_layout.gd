# 战斗布局：根据战场行列数与视口尺寸计算格子大小，让战场尽量填满可用空间。
class_name BattleLayout
extends RefCounted

# 计算格子边长（像素）。留出上下 HUD 空间。
static func compute_tile_size(cols: int, rows: int, viewport: Vector2, margin: float = 0.82) -> int:
	if cols <= 0 or rows <= 0:
		return 64
	var avail_w := viewport.x * margin
	var avail_h := viewport.y * margin
	var tile := mini(int(avail_w / cols), int(avail_h / rows))
	return maxi(32, tile)

# 计算战场在视口中的偏移（居中）。
static func board_position(cols: int, rows: int, tile_size: int, viewport: Vector2) -> Vector2:
	var board_w := cols * tile_size
	var board_h := rows * tile_size
	return Vector2((viewport.x - board_w) / 2.0, (viewport.y - board_h) / 2.0 - 10.0)
