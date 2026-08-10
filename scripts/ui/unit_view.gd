# 单位渲染：用像素贴图绘制单位，叠加阵营色框、名称、等级与血条，死亡后隐藏。
class_name UnitView
extends Node2D

var unit: Unit
var tile_size := 64
var action: String = "idle"
var sprite_texture: Texture2D = null
var is_moving: bool = false

const SPRITE_SIZE := 32.0

func setup(p_unit: Unit, p_tile_size: int) -> void:
	unit = p_unit
	tile_size = p_tile_size
	_load_sprite()
	position = _cell_to_local(unit.pos)

# 通过 ArtManager 加载动作贴图（idle 默认；mod 素材优先，回退到内置）。
func _load_sprite() -> void:
	if unit == null:
		return
	sprite_texture = ArtManager.get_unit_sprite(unit.unit_type, action)

# 切换动作贴图并重绘（attack/hurt/death/skill/idle）。
func set_action(new_action: String) -> void:
	if action == new_action:
		return
	action = new_action
	_load_sprite()
	queue_redraw()

func _cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * tile_size + tile_size / 2.0, cell.y * tile_size + tile_size / 2.0)

func refresh() -> void:
	# 移动动画进行中不强制设位置，避免打断补间
	if not is_moving:
		position = _cell_to_local(unit.pos)
	queue_redraw()

# 开始移动动画（逐格补间），动画期间逻辑位置不干扰显示位置。
func animate_move(path: Array, step_time: float) -> Tween:
	is_moving = true
	var tween := create_tween()
	var first := true
	for tile in path:
		if not (tile is Tile):
			continue
		if first:
			first = false
			continue
		tween.tween_property(self, "position", _cell_to_local(tile.get_position()), step_time)
	tween.finished.connect(func():
		is_moving = false
		position = _cell_to_local(unit.pos)
		queue_redraw()
	)
	return tween

func _draw() -> void:
	if unit == null or not unit.alive:
		return
	var half := tile_size * 0.34
	var body_rect := Rect2(-half, -half, half * 2, half * 2)
	# 阵营底色与描边，作为像素小人的背景底板
	var body_color := Color(0.25, 0.55, 0.95) if unit.camp == TurnManager.PLAYER_CAMP else Color(0.92, 0.35, 0.35)
	draw_rect(body_rect, body_color)
	draw_rect(body_rect, Color(0.10, 0.10, 0.12), false, 2.0)
	# 像素小人居中绘制，缩放适配格子
	if sprite_texture != null:
		var scale := (tile_size * 0.8) / SPRITE_SIZE
		var draw_size := Vector2(SPRITE_SIZE * scale, SPRITE_SIZE * scale)
		var draw_pos := Vector2(-draw_size.x / 2.0, -draw_size.y / 2.0 + 6.0)
		draw_texture_rect(sprite_texture, Rect2(draw_pos, draw_size), false)
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
