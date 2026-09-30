# 网格渲染：绘制地板、边框，以及移动范围/攻击范围/目标范围/选中/悬停高亮。
extends Node2D

var grid: Grid
var tile_size := 64
var battle_floor: Texture2D

var move_highlight: Array = []
var attack_highlight: Array = []
var target_highlight: Array = []
var selected_cell: Vector2i = Vector2i(-1, -1)
var hover_cell: Vector2i = Vector2i(-1, -1)

func setup(p_grid: Grid, p_tile_size: int) -> void:
	grid = p_grid
	tile_size = p_tile_size
	queue_redraw()

# 战斗界面可传入独立的石质地面；部署界面仍沿用原网格显示。
func set_battle_floor(texture: Texture2D) -> void:
	battle_floor = texture
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
	var board_rect := Rect2(Vector2.ZERO, Vector2(grid.width, grid.height) * tile_size)
	if battle_floor != null:
		# 厚重的石台边缘和连续地面材质让格子成为战场而非表格。
		draw_rect(board_rect.grow(18.0), Color(0.015, 0.02, 0.045, 0.68))
		draw_rect(board_rect.grow(10.0), Color(0.17, 0.16, 0.24))
		draw_rect(board_rect.grow(9.0), Color(0.59, 0.49, 0.35, 0.82), false, 2.0)
		draw_texture_rect(battle_floor, board_rect, false)
		draw_rect(board_rect, Color(0.05, 0.065, 0.13, 0.18))
		draw_rect(board_rect, Color(0.8, 0.7, 0.52, 0.34), false, 2.0)
	var floor_color := Color(0.15, 0.16, 0.25)
	var alt_color := Color(0.19, 0.19, 0.29)
	var border_color := Color(0.38, 0.32, 0.48)
	for y in range(grid.height):
		for x in range(grid.width):
			var tile := grid.get_tile(x, y)
			var rect := Rect2(x * tile_size, y * tile_size, tile_size, tile_size)
			var base := floor_color if (x + y) % 2 == 0 else alt_color
			if not tile.passable:
				base = Color(0.09, 0.10, 0.16)
			if battle_floor != null:
				# 棋盘定位线只在近看时可见，阻挡格保持明确区分。
				draw_rect(rect, Color(0.01, 0.02, 0.05, 0.72) if not tile.passable \
					else Color(0.84, 0.77, 0.66, 0.035) if (x + y) % 2 == 0 \
					else Color(0.03, 0.02, 0.06, 0.035))
				draw_rect(rect, Color(0.84, 0.79, 0.75, 0.12), false, 1.0)
			else:
				draw_rect(rect, base)
				draw_rect(rect, border_color, false, 1.0)
	for cell in move_highlight:
		_draw_cell_overlay(cell, Color(0.25, 0.80, 0.35, 0.13))
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
