# 单位渲染：用像素贴图绘制单位，叠加阵营色框、名称、等级与血条，死亡后隐藏。
class_name UnitView
extends Node2D

var unit: Unit
var tile_size := 64
var action: String = "stand"
var sprite_texture: Texture2D = null
var is_moving: bool = false

# 目标显示尺寸：战斗小人缩放到格子的这个比例。
const SPRITE_TARGET_RATIO := 0.72

func setup(p_unit: Unit, p_tile_size: int) -> void:
	unit = p_unit
	tile_size = p_tile_size
	_load_sprite()
	position = _cell_to_local(unit.pos)

# 通过 ArtManager 加载动作贴图（stand 默认；mod 素材优先，回退到内置）。
func _load_sprite() -> void:
	if unit == null:
		return
	sprite_texture = ArtManager.get_unit_sprite(unit.unit_type, action)

# 切换动作贴图并重绘（stand/move/attack/death/skill）。
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
	# 单位贴图填满整个格子（无纯色底板）
	if sprite_texture != null:
		var draw_rect_size := Vector2(tile_size, tile_size)
		var draw_pos := Vector2(-draw_rect_size.x / 2.0, -draw_rect_size.y / 2.0)
		# acted 时变暗
		var mod := Color(1, 1, 1, 0.6) if unit.acted else Color(1, 1, 1, 1)
		draw_texture_rect(sprite_texture, Rect2(draw_pos, draw_rect_size), false, mod)
	# 顶部名称
	var name_pos := Vector2(-tile_size / 2.0, -tile_size / 2.0 - 4.0)
	draw_string(ThemeDB.fallback_font, name_pos, unit.get_display_name(), \
		HORIZONTAL_ALIGNMENT_CENTER, tile_size, 14, Color.WHITE)
	# 底部血条
	var bar_width := tile_size - 6
	var bar_height := 6
	var bar_pos := Vector2(-bar_width / 2.0, tile_size / 2.0 - 8.0)
	var hp_ratio := float(unit.hp) / float(unit.max_hp)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.10, 0.10, 0.12))
	draw_rect(Rect2(bar_pos, Vector2(bar_width * hp_ratio, bar_height)), Color(0.25, 0.85, 0.35))
	# 护盾条：血条上方，蓝色，按剩余/初始护盾量填充
	var shield_amount := 0
	var shield_max := 0
	for buff in unit.buffs:
		if buff.shield > 0:
			shield_amount += buff.shield
			shield_max += int(buff.raw_data.get("shield", buff.shield))
	if shield_amount > 0:
		var shield_ratio := float(shield_amount) / float(maxi(shield_max, shield_amount))
		var shield_h := 4
		var shield_pos := Vector2(bar_pos.x, bar_pos.y - shield_h - 1)
		draw_rect(Rect2(shield_pos, Vector2(bar_width, shield_h)), Color(0.10, 0.13, 0.22))
		draw_rect(Rect2(shield_pos, Vector2(bar_width * shield_ratio, shield_h)), Color(0.42, 0.72, 1.00))
	draw_string(ThemeDB.fallback_font, Vector2(-40, tile_size / 2.0 + 12.0), "%d/%d" % [unit.hp, unit.max_hp], \
		HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color.WHITE)
