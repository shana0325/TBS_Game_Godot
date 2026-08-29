# 部署单位预览：复用战场 UnitView 绘制小人，并提供底部栏拖拽数据。
class_name DeploymentUnitCard
extends Control

signal inspect_requested(selectable_index: int)
signal skill_book_drop_requested(selectable_index: int, skill_id: String)

var selectable_index: int = -1
var unit_type: String = ""
var roster_index: int = -1
var tile_size: int = 64
var unit_view: UnitView
var press_position := Vector2.ZERO
var drag_enabled: bool = true

static func tray_height_for_tile(p_tile_size: int) -> float:
	# 底部栏高度由卡片尺寸统一计算，部署与战斗界面共用。
	return maxf(176.0, minf(240.0, float(p_tile_size + 104)))

func setup(p_selectable_index: int, p_unit_type: String, p_roster_index: int, p_tile_size: int = 64) -> void:
	selectable_index = p_selectable_index
	unit_type = p_unit_type
	roster_index = p_roster_index
	tile_size = p_tile_size
	if get_child_count() == 0:
		_build_content()

func _ready() -> void:
	if get_child_count() == 0 and unit_type != "":
		_build_content()

func _build_content() -> void:
	custom_minimum_size = Vector2(tile_size + 16, tile_size + 52)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var config: Dictionary = GameDatabase.get_unit(unit_type)
	if config.is_empty():
		return
	var roster_data: Dictionary = {}
	var roster: Array = GameDatabase.player_roster.get("units", [])
	if roster_index >= 0 and roster_index < roster.size():
		roster_data = roster[roster_index]
	var preview_unit := Unit.create_from_config(unit_type, TurnManager.PLAYER_CAMP, Vector2i.ZERO, config, roster_data, GameDatabase)
	unit_view = UnitView.new()
	unit_view.setup(preview_unit, tile_size)
	# 底部栏空间有限，保留血条但隐藏数字，给单位名称留出完整显示空间。
	unit_view.show_hp_text = false
	add_child(unit_view)
	_update_unit_position()

func set_deployed(deployed: bool) -> void:
	# 已进入战场的单位从底部栏移除，撤回后重新出现。
	visible = not deployed

func set_drag_enabled(enabled: bool) -> void:
	# 战斗界面保留单位卡，但暂时禁止拖动。
	drag_enabled = enabled

func set_tile_size(p_tile_size: int) -> void:
	if tile_size == p_tile_size:
		return
	tile_size = p_tile_size
	custom_minimum_size = Vector2(tile_size + 16, tile_size + 52)
	if unit_view != null:
		unit_view.tile_size = tile_size
		_update_unit_position()
		unit_view.refresh()

func _update_unit_position() -> void:
	if unit_view == null:
		return
	# 下移并预留顶部安全空白，避免单位名称被底部滚动区域裁掉。
	unit_view.position = Vector2((tile_size + 16) / 2.0, tile_size / 2.0 + 20.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_position = event.position
		elif event.position.distance_to(press_position) < 8.0:
			inspect_requested.emit(selectable_index)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled:
		return null
	# 预览根节点的原点就是小人中心；Godot 会把拖拽预览原点放到鼠标位置。
	# 不再复用底部卡片的上边距，避免鼠标落在小人左上角。
	var preview := Control.new()
	preview.size = Vector2(tile_size, tile_size)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_view := UnitView.new()
	preview_view.setup(unit_view.unit, tile_size)
	preview_view.show_name = false
	preview_view.show_hp_text = false
	preview_view.position = Vector2.ZERO
	preview.add_child(preview_view)
	preview.modulate = Color(1, 1, 1, 0.82)
	set_drag_preview(preview)
	return {
		"kind": "deployment_unit",
		"selectable_index": selectable_index,
	}

# 未部署角色卡也可以作为技能书目标，便于不先上场的角色直接学习技能。
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or str(data.get("kind", "")) != "skill_book":
		return false
	if roster_index < 0:
		return false
	return ProgressManager.get_skill_book_count(str(data.get("skill_id", ""))) > 0

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		skill_book_drop_requested.emit(selectable_index, str(data.get("skill_id", "")))
