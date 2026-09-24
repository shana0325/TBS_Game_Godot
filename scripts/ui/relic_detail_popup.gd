# 遗物详情弹窗：点击遗物图标后展示大图、名称、效果和当前成长数值。
class_name RelicDetailPopup
extends PanelContainer

var icon_rect: TextureRect
var name_label: Label
var desc_label: Label
var growth_label: Label
var input_blocker: ColorRect

# 首次进入场景时构建遮挡层与详情卡片。
func _ready() -> void:
	z_index = 600
	custom_minimum_size = Vector2(560, 520)
	add_theme_stylebox_override("panel", MenuStyle.frame_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var header_frame := PanelContainer.new()
	header_frame.add_theme_stylebox_override("panel", MenuStyle.header_style())
	box.add_child(header_frame)
	var header := HBoxContainer.new()
	header_frame.add_child(header)
	name_label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color("#f3d79f"))
	header.add_child(name_label)
	var close_hint := Label.new()
	close_hint.text = "右键/ESC关闭界面"
	close_hint.add_theme_color_override("font_color", Color("#b6bdc9"))
	header.add_child(close_hint)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(220, 220)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(icon_rect)
	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 18)
	box.add_child(desc_label)
	growth_label = Label.new()
	growth_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	growth_label.add_theme_font_size_override("font_size", 18)
	growth_label.add_theme_color_override("font_color", Color("#a9e6c4"))
	box.add_child(growth_label)
	visible = false

# 窗口尺寸变化时同步调整遮罩和详情卡位置。
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_fit_to_viewport()

# 打开指定遗物，并按视口居中显示。
func show_relic(relic_id: String) -> void:
	var relic: Dictionary = GameDatabase.get_relic(relic_id)
	if relic.is_empty():
		return
	var stacks := GameSession.get_relic_stack(relic_id)
	name_label.text = "%s ×%d" % [str(relic.get("name", relic_id)), stacks] if stacks > 1 \
		else str(relic.get("name", relic_id))
	icon_rect.texture = ArtManager.get_relic_icon(relic_id)
	desc_label.text = str(relic.get("desc", "暂无说明"))
	var growth := RelicSystem.get_growth_display_lines(relic_id)
	growth_label.visible = not growth.is_empty()
	growth_label.text = "当前成长\n%s" % "\n".join(growth)
	var vp := get_viewport_rect().size
	_ensure_input_blocker(vp)
	# 首次打开时先隐藏卡片，等待容器完成最小尺寸计算后再限制尺寸和居中。
	visible = false
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_fit_to_viewport()
	visible = true
	move_to_front()

# 根据当前视口限制详情卡尺寸并居中，避免首次布局使用未稳定的容器尺寸。
func _fit_to_viewport() -> void:
	var vp := get_viewport_rect().size
	var target := Vector2(minf(560.0, maxf(320.0, vp.x - 48.0)),
		minf(520.0, maxf(360.0, vp.y - 48.0)))
	custom_minimum_size = Vector2(minf(560.0, target.x), minf(520.0, target.y))
	size = target
	position = (vp - target) / 2.0
	if input_blocker != null:
		input_blocker.size = vp

# 创建覆盖视口的输入遮罩，防止弹窗内外的鼠标事件穿透到部署单位或按钮。
func _ensure_input_blocker(viewport_size: Vector2) -> void:
	if input_blocker == null:
		input_blocker = ColorRect.new()
		input_blocker.name = "RelicDetailInputBlocker"
		input_blocker.color = Color(0.0, 0.0, 0.0, 0.42)
		input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		input_blocker.z_index = 599
		get_parent().add_child(input_blocker)
	input_blocker.position = Vector2.ZERO
	input_blocker.size = viewport_size
	input_blocker.visible = true
	input_blocker.move_to_front()
	move_to_front()

# 关闭详情卡和配套输入遮罩。
func close_popup() -> void:
	hide()
	if input_blocker != null:
		input_blocker.hide()

# 支持 ESC 和鼠标右键关闭弹窗。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_popup()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close_popup()
		get_viewport().set_input_as_handled()
