# 单位渲染：按阵营绘制单位方块、名称、等级与血条，死亡后隐藏。
class_name UnitView
extends Node2D

var unit: Unit
var tile_size := 64

func setup(p_unit: Unit, p_tile_size: int) -> void:
	unit = p_unit
	tile_size = p_tile_size
	position = _cell_to_local(unit.pos)

func _cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * tile_size + tile_size / 2.0, cell.y * tile_size + tile_size / 2.0)

func refresh() -> void:
	position = _cell_to_local(unit.pos)
	queue_redraw()

func _draw() -> void:
	if unit == null or not unit.alive:
		return
	var body_color := Color(0.25, 0.55, 0.95) if unit.camp == TurnManager.PLAYER_CAMP else Color(0.92, 0.35, 0.35)
	var half := tile_size * 0.34
	var body_rect := Rect2(-half, -half, half * 2, half * 2)
	draw_rect(body_rect, body_color)
	draw_rect(body_rect, Color(0.10, 0.10, 0.12), false, 2.0)
	if unit.acted:
		draw_rect(body_rect, Color(0.0, 0.0, 0.0, 0.35))
	draw_string(ThemeDB.fallback_font, Vector2(-40, -half - 8), unit.get_display_name(), \
		HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color.WHITE)
	var bar_width := tile_size - 6
	var bar_height := 6
	var bar_pos := Vector2(-bar_width / 2.0, half + 6)
	var hp_ratio := float(unit.hp) / float(unit.max_hp)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.10, 0.10, 0.12))
	draw_rect(Rect2(bar_pos, Vector2(bar_width * hp_ratio, bar_height)), Color(0.25, 0.85, 0.35))
	draw_string(ThemeDB.fallback_font, Vector2(-40, half + 26), "%d/%d" % [unit.hp, unit.max_hp], \
		HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color.WHITE)
