# 网格渲染：绘制地板、边框，以及移动范围/攻击范围/目标范围/选中/悬停高亮。
extends Node2D

var grid: Grid
var tile_size := 64

var move_highlight: Array = []
var attack_highlight: Array = []
var target_highlight: Array = []
var selected_cell: Vector2i = Vector2i(-1, -1)
var hover_cell: Vector2i = Vector2i(-1, -1)

func setup(p_grid: Grid, p_tile_size: int) -> void:
	grid = p_grid
	tile_size = p_tile_size
	queue_redraw()

func set_highlights(move_cells: Array, attack_cells: Array) -> void:
	move_highlight = move_cells
	attack_highlight = attack_cells
	queue_redraw()

func set_target_cells(cells: Array) -> void:
	target_highlight = cells
	queue_redraw()

func set_selected(cell: Vector2i) -> void:
	selected_cell = cell
	queue_redraw()

func set_hover(cell: Vector2i) -> void:
	hover_cell = cell
	queue_redraw()

func _draw() -> void:
	if grid == null:
		return
	var floor_color := Color(0.30, 0.32, 0.36)
	var alt_color := Color(0.34, 0.36, 0.40)
	var border_color := Color(0.16, 0.17, 0.20)
	for y in range(grid.height):
		for x in range(grid.width):
			var tile := grid.get_tile(x, y)
			var rect := Rect2(x * tile_size, y * tile_size, tile_size, tile_size)
			var base := floor_color if (x + y) % 2 == 0 else alt_color
			if not tile.passable:
				base = Color(0.20, 0.20, 0.22)
			draw_rect(rect, base)
			draw_rect(rect, border_color, false, 1.0)
	for cell in move_highlight:
		_draw_cell_overlay(cell, Color(0.25, 0.80, 0.35, 0.35))
	for cell in attack_highlight:
		_draw_cell_overlay(cell, Color(0.90, 0.30, 0.30, 0.35))
	for cell in target_highlight:
		_draw_cell_overlay(cell, Color(0.95, 0.85, 0.20, 0.40))
	if grid.in_bounds(selected_cell.x, selected_cell.y):
		_draw_cell_overlay(selected_cell, Color(0.40, 0.60, 1.00, 0.50))
	if grid.in_bounds(hover_cell.x, hover_cell.y):
		_draw_cell_overlay(hover_cell, Color(1.00, 1.00, 1.00, 0.12))

func _draw_cell_overlay(cell: Vector2i, color: Color) -> void:
	var rect := Rect2(cell.x * tile_size, cell.y * tile_size, tile_size, tile_size)
	draw_rect(rect, color)
