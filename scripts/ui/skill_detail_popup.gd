# 技能详情弹窗：在角色资料页上展示触发信息与完整效果。
class_name SkillDetailPopup
extends Control

const SKILL_DETAIL_FORMATTER = preload("res://scripts/ui/skill_detail_formatter.gd")

var backdrop: ColorRect
var dialog: PanelContainer
var title_label: Label
var subtitle_label: Label
var metadata_grid: GridContainer
var description_label: MechanicDescription
var condition_label: Label
var growth_label: Label

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
	description_label = MechanicDescription.new()
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.add_theme_font_size_override("font_size", 19)
	description_label.add_theme_color_override("font_color", Color("#f0e8e7"))
	body.add_child(description_label)
	condition_label = Label.new()
	condition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	condition_label.add_theme_font_size_override("font_size", 17)
	condition_label.add_theme_color_override("font_color", Color("#c5c2d7"))
	body.add_child(condition_label)
	growth_label = Label.new()
	growth_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	growth_label.add_theme_font_size_override("font_size", 18)
	growth_label.add_theme_color_override("font_color", Color("#a9e6c4"))
	body.add_child(growth_label)

# 依据真实技能数据更新弹窗，不在界面中写死技能数值。
func show_skill(skill_id: String, p_unit: Unit = null) -> void:
	if dialog == null:
		_build_popup()
	var data: Dictionary = GameDatabase.get_skill(skill_id)
	var skill_name := str(data.get("name", skill_id))
	title_label.text = skill_name
	var trigger := str(data.get("trigger", ""))
	subtitle_label.text = "技能详情  ·  %s  ·  %s" % ["通用技能" if bool(data.get("common", false)) else "固有技能", SKILL_DETAIL_FORMATTER.mode_text(trigger)]
	for child in metadata_grid.get_children():
		metadata_grid.remove_child(child)
		child.queue_free()
	var condition: Dictionary = data.get("condition", {})
	var target_type := str(condition.get("target_type", condition.get("target", "target")))
	var trigger_text := str(SKILL_DETAIL_FORMATTER.TRIGGER_LABELS.get(trigger, trigger if not trigger.is_empty() else "未配置"))
	var cooldown := int(data.get("cooldown", 0))
	_add_metadata("触发时机", trigger_text)
	_add_metadata("作用目标", SKILL_DETAIL_FORMATTER._target_text(target_type))
	if trigger == "on_timer":
		_add_metadata("施放间隔", "每 %.1f 秒 · 受技能急速影响" % float(data.get("interval_seconds", 0.0)))
	else:
		if float(data.get("cooldown_seconds", 0.0)) > 0.0:
			_add_metadata("触发间隔", "冷却 %.1f 秒" % float(data["cooldown_seconds"]))
		else:
			_add_metadata("触发间隔", "无冷却" if cooldown <= 0 else "等待 %d 次普攻" % cooldown)
	_add_metadata("技能标签", "、".join(data.get("tags", [])) if not data.get("tags", []).is_empty() else "无")
	var damage_kinds := _collect_damage_kinds(data)
	if not damage_kinds.is_empty():
		_add_metadata("伤害类型", "、".join(damage_kinds))
	description_label.set_skill_description(data)
	var extra_condition := SKILL_DETAIL_FORMATTER.extra_condition_text(condition)
	condition_label.visible = not extra_condition.is_empty()
	condition_label.text = "触发条件：%s" % extra_condition if not extra_condition.is_empty() else ""
	var source_mods: Dictionary = p_unit.permanent_mod_sources.get(skill_id, {}) if p_unit != null else {}
	growth_label.visible = not source_mods.is_empty()
	if not source_mods.is_empty():
		var lines: Array[String] = []
		for stat in source_mods:
			var stat_name := str({"hp": "生命上限", "attack": "攻击", "defense": "护甲",
				"attack_speed": "攻速加成", "crit_rate": "暴击率", "crit_damage": "暴击伤害"}.get(stat, stat))
			lines.append("%s +%.2f" % [stat_name, float(source_mods[stat])])
		growth_label.text = "本技能累计永久获得：\n%s" % "\n".join(lines)
	show()
	move_to_front()
	_layout_popup()

# 汇总代码技能声明及数据效果的伤害类型，包含中毒和灼烧的持续特效伤害。
func _collect_damage_kinds(data: Dictionary) -> Array:
	var kinds: Array = []
	for kind in data.get("damage_kinds", []):
		var label := SKILL_DETAIL_FORMATTER._damage_kind_text({"damage_kind": str(kind)})
		if not kinds.has(label):
			kinds.append(label)
	for effect in data.get("effects", []):
		if not (effect is Dictionary):
			continue
		if not str(effect.get("type", "")) in ["damage", "percentage_damage", "chain_damage", "reflect", "poison", "burn"]:
			continue
		var label := "特效伤害" if str(effect.get("type", "")) in ["poison", "burn"] else SKILL_DETAIL_FORMATTER._damage_kind_text(effect)
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
	var dialog_size := Vector2(minf(760.0, size.x - 48.0), minf(640.0, size.y - 48.0))
	dialog.position = (size - dialog_size) / 2.0
	dialog.size = dialog_size

# 点击弹窗外的遮罩时关闭详情。
func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide()
