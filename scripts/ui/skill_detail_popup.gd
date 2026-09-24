# 技能详情弹窗：在角色资料页上展示图标、触发信息与完整效果。
class_name SkillDetailPopup
extends Control

const SKILL_DETAIL_FORMATTER = preload("res://scripts/ui/skill_detail_formatter.gd")

var backdrop: ColorRect
var dialog: PanelContainer
var title_label: Label
var subtitle_label: Label
var icon_rect: TextureRect
var icon_name_label: Label
var metadata_grid: GridContainer
var description_label: Label
var condition_label: Label

# 首次加入场景时构建遮罩和弹窗，后续仅更新技能数据。
func _ready() -> void:
	# 学习/遗忘列表位于立绘区的较高绘制层，详情必须盖过整页内容。
	z_index = 20
	_build_popup()
	_layout_popup()

# 随角色资料页尺寸变化维持居中和安全边距。
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and dialog != null:
		_layout_popup()

# 构建与角色资料页一致的深蓝、金色装饰层级。
func _build_popup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.015, 0.03, 0.76)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	dialog = PanelContainer.new()
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.add_theme_stylebox_override("panel", MenuStyle.frame_panel_style())
	add_child(dialog)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 24)
	dialog.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	margin.add_child(content)

	var header_frame := PanelContainer.new()
	header_frame.add_theme_stylebox_override("panel", MenuStyle.header_style())
	content.add_child(header_frame)
	var header := HBoxContainer.new()
	header_frame.add_child(header)
	var headings := VBoxContainer.new()
	headings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(headings)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 29)
	title_label.add_theme_color_override("font_color", Color("#f3d79f"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headings.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color("#b6bdc9"))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headings.add_child(subtitle_label)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(44, 42)
	close_button.add_theme_font_size_override("font_size", 28)
	close_button.pressed.connect(hide)
	header.add_child(close_button)

	var icon_row := HBoxContainer.new()
	icon_row.custom_minimum_size.y = 130
	icon_row.add_theme_constant_override("separation", 18)
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(124, 124)
	icon_row.add_child(icon_frame)
	icon_rect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_frame.add_child(icon_rect)
	icon_name_label = Label.new()
	icon_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_name_label.add_theme_font_size_override("font_size", 22)
	icon_name_label.add_theme_color_override("font_color", Color("#f3d79f"))
	icon_row.add_child(icon_name_label)

	var body_panel := PanelContainer.new()
	body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_panel.add_theme_stylebox_override("panel", MenuStyle.section_panel_style())
	content.add_child(body_panel)
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 20)
	body_margin.add_theme_constant_override("margin_right", 20)
	body_margin.add_theme_constant_override("margin_top", 18)
	body_margin.add_theme_constant_override("margin_bottom", 20)
	body_panel.add_child(body_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_margin.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	scroll.add_child(body)
	metadata_grid = GridContainer.new()
	metadata_grid.columns = 2
	metadata_grid.add_theme_constant_override("h_separation", 24)
	metadata_grid.add_theme_constant_override("v_separation", 9)
	body.add_child(metadata_grid)
	var divider := HSeparator.new()
	body.add_child(divider)
	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 19)
	description_label.add_theme_color_override("font_color", Color("#f0e8e7"))
	body.add_child(description_label)
	condition_label = Label.new()
	condition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	condition_label.add_theme_font_size_override("font_size", 17)
	condition_label.add_theme_color_override("font_color", Color("#c5c2d7"))
	body.add_child(condition_label)

# 依据真实技能数据更新弹窗，不在界面中写死技能数值。
func show_skill(skill_id: String) -> void:
	if dialog == null:
		_build_popup()
	var data: Dictionary = GameDatabase.get_skill(skill_id)
	var skill_name := str(data.get("name", skill_id))
	title_label.text = skill_name
	subtitle_label.text = "技能详情  ·  %s" % ("通用技能" if bool(data.get("common", false)) else "固有技能")
	icon_name_label.text = skill_name
	icon_rect.texture = ArtManager.get_skill_icon(skill_id, skill_name)
	for child in metadata_grid.get_children():
		metadata_grid.remove_child(child)
		child.queue_free()
	var condition: Dictionary = data.get("condition", {})
	var target_type := str(condition.get("target_type", condition.get("target", "target")))
	var trigger := str(data.get("trigger", ""))
	var trigger_text := str(SKILL_DETAIL_FORMATTER.TRIGGER_LABELS.get(trigger, trigger if not trigger.is_empty() else "未配置"))
	var cooldown := int(data.get("cooldown", 0))
	_add_metadata("触发时机", trigger_text)
	_add_metadata("作用目标", SKILL_DETAIL_FORMATTER._target_text(target_type))
	if trigger == "on_timer":
		_add_metadata("触发间隔", "每 %.1f 秒 · 受技能急速影响" % float(data.get("interval_seconds", 0.0)))
	else:
		_add_metadata("触发间隔", "无冷却" if cooldown <= 0 else "%d 次行动" % cooldown)
	_add_metadata("技能标签", "、".join(data.get("tags", [])) if not data.get("tags", []).is_empty() else "无")
	var damage_kinds := _collect_damage_kinds(data)
	if not damage_kinds.is_empty():
		_add_metadata("伤害类型", "、".join(damage_kinds))
	description_label.text = str(data.get("desc", "暂无技能说明"))
	var extra_condition := SKILL_DETAIL_FORMATTER.extra_condition_text(condition)
	condition_label.visible = not extra_condition.is_empty()
	condition_label.text = "触发条件：%s" % extra_condition if not extra_condition.is_empty() else ""
	show()
	move_to_front()
	_layout_popup()

# 汇总代码技能声明及数据效果的伤害类型；无直接伤害的技能返回空数组。
func _collect_damage_kinds(data: Dictionary) -> Array:
	var kinds: Array = []
	for kind in data.get("damage_kinds", []):
		var label := SKILL_DETAIL_FORMATTER._damage_kind_text({"damage_kind": str(kind)})
		if not kinds.has(label):
			kinds.append(label)
	for effect in data.get("effects", []):
		if not (effect is Dictionary):
			continue
		if not str(effect.get("type", "")) in ["damage", "percentage_damage", "chain_damage", "reflect"]:
			continue
		var label := SKILL_DETAIL_FORMATTER._damage_kind_text(effect)
		if kinds.has(label):
			continue
		kinds.append(label)
	return kinds

# 在信息网格中添加一项带标题的字段。
func _add_metadata(title: String, value: String) -> void:
	var field := VBoxContainer.new()
	field.custom_minimum_size.x = 250
	metadata_grid.add_child(field)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color("#ae9ec9"))
	field.add_child(heading)
	var text_label := Label.new()
	text_label.text = value
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 19)
	text_label.add_theme_color_override("font_color", Color("#f3ede7"))
	field.add_child(text_label)

# 将弹窗居中，并为较小窗口收紧尺寸。
func _layout_popup() -> void:
	if dialog == null:
		return
	var dialog_size := Vector2(minf(760.0, size.x - 48.0), minf(760.0, size.y - 48.0))
	dialog.position = (size - dialog_size) / 2.0
	dialog.size = dialog_size

# 点击弹窗外的遮罩时关闭详情。
func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide()
