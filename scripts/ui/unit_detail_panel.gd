# 全屏角色资料页：左侧目录导航，中间立绘，右侧连续滚动属性、装备和技能。
class_name UnitDetailPanel
extends PanelContainer

const COMBAT_FORMULA = preload("res://scripts/core/combat_formula.gd")

var unit: Unit
var portrait: TextureRect
var portrait_panel: PanelContainer
var skill_manage_overlay: PanelContainer
var skill_manage_list: VBoxContainer
var skill_manage_title: Label
var right_panel: PanelContainer
var name_label: Label
var summary_label: Label
var content_scroll: ScrollContainer
var content_box: VBoxContainer
var section_box: VBoxContainer
var section_nodes: Dictionary = {}
var nav_buttons: Dictionary = {}
var active_section := "overview"
var stat_value_labels: Dictionary = {}
var ascension_enabled := false
var ascend_button: Button
var skill_detail_dialog: SkillDetailPopup

const SECTIONS := [["overview", "角色概览"], ["stats", "基础属性"], ["equipment", "装备"], ["skills", "技能"]]

signal ascension_requested(unit: Unit)

func _ready() -> void:
	# 资料页高于战斗操作按钮、底部单位栏和部署浮层。
	z_index = 300
	mouse_filter = Control.MOUSE_FILTER_STOP
	if content_box == null:
		_build_panel()

# ESC 或鼠标右键优先关闭技能详情，再关闭角色资料页。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var close_requested: bool = false
	if event is InputEventKey:
		close_requested = event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	elif event is InputEventMouseButton:
		close_requested = event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if not close_requested:
		return
	if skill_detail_dialog != null and skill_detail_dialog.visible:
		skill_detail_dialog.hide()
	elif skill_manage_overlay != null and skill_manage_overlay.visible:
		skill_manage_overlay.hide()
	else:
		hide()
	get_viewport().set_input_as_handled()

func _build_panel() -> void:
	custom_minimum_size = Vector2(980.0, 600.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#121526")
	style.border_color = Color("#8d749f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 14)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 54
	root_box.add_child(header)

	name_label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color("#f2d08b"))
	header.add_child(name_label)
	var close_button := Button.new()
	close_button.text = "关闭  ×"
	close_button.custom_minimum_size = Vector2(110, 42)
	close_button.pressed.connect(hide)
	header.add_child(close_button)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	root_box.add_child(columns)

	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = 166
	nav.add_theme_constant_override("separation", 10)
	columns.add_child(nav)
	for section in SECTIONS:
		var nav_button := Button.new()
		nav_button.text = str(section[1])
		nav_button.custom_minimum_size.y = 48
		nav_button.add_theme_font_size_override("font_size", 18)
		nav_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav_button.pressed.connect(_jump_to_section.bind(str(section[0])))
		nav.add_child(nav_button)
		nav_buttons[str(section[0])] = nav_button

	portrait_panel = PanelContainer.new()
	portrait_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(portrait_panel)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(portrait)
	_build_skill_manage_overlay()

	right_panel = PanelContainer.new()
	right_panel.custom_minimum_size.x = 600
	right_panel.size_flags_horizontal = Control.SIZE_FILL
	columns.add_child(right_panel)

	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 18)
	summary_label.add_theme_color_override("font_color", Color("#d8d2e5"))

	ascend_button = Button.new()
	ascend_button.custom_minimum_size = Vector2(220, 42)
	ascend_button.visible = ascension_enabled
	ascend_button.pressed.connect(_on_ascend_pressed)

	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right_panel.add_child(content_scroll)
	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 30)
	content_scroll.add_child(content_box)
	content_scroll.get_v_scroll_bar().value_changed.connect(_sync_nav_to_scroll)

func show_unit(p_unit: Unit) -> void:
	if content_box == null:
		_build_panel()
	if skill_detail_dialog != null:
		skill_detail_dialog.hide()
	if skill_manage_overlay != null:
		skill_manage_overlay.hide()
	unit = p_unit
	if unit == null:
		return
	move_to_front()
	active_section = "overview"
	_refresh_header()
	_render_all_sections()
	fit_to_viewport()
	content_scroll.scroll_vertical = 0
	_set_active_section("overview")

# 每次显示前让资料页占用视口大部分空间，留出安全边距。
func fit_to_viewport() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var target := Vector2(maxf(320.0, vp.x - 48.0), maxf(400.0, vp.y - 48.0))
	if right_panel != null:
		right_panel.custom_minimum_size.x = minf(600.0, maxf(360.0, vp.x * 0.38))
	custom_minimum_size = target
	size = target
	position = (vp - target) / 2.0

# 战斗中只刷新动态属性，避免重新构建列表导致滚动位置跳动。
func refresh_current() -> void:
	if unit == null or not visible:
		return
	_refresh_header()
	_refresh_stat_values()

func _refresh_header() -> void:
	portrait.texture = ArtManager.get_portrait(unit.unit_type)
	name_label.text = unit.get_display_name()
	var role := str(unit.config.get("role", ""))
	var camp := "我方" if unit.camp == TurnManager.PLAYER_CAMP else "敌方"
	var tags_text := "、".join(unit.get_tags()) if not unit.get_tags().is_empty() else "无"
	summary_label.text = "%s  ·  %d星\n%s\n标签：%s" % [
		camp, unit.star, _role_text(role), tags_text
	]
	if ascend_button != null:
		ascend_button.visible = ascension_enabled
		var current_star := clampi(unit.star, 1, Unit.MAX_STARS)
		var cost := ProgressManager.get_ascension_cost(current_star)
		if current_star >= Unit.MAX_STARS:
			ascend_button.text = "已达到最高星级"
		else:
			ascend_button.text = "升星：%d → %d（消耗 %d 个道具）" % [current_star, current_star + 1, cost]
		ascend_button.disabled = not ascension_enabled or current_star >= Unit.MAX_STARS \
			or ProgressManager.get_star_item_count() < cost

# 只在部署界面开启升星入口，战斗信息卡仍保持纯查看。
func set_ascension_enabled(enabled: bool) -> void:
	ascension_enabled = enabled
	if ascend_button != null:
		if unit != null:
			_refresh_header()
		else:
			ascend_button.hide()

func _on_ascend_pressed() -> void:
	if ascension_enabled and unit != null:
		ascension_requested.emit(unit)

# 构建连续章节，使右侧滚动时无需切换互斥标签页。
func _render_all_sections() -> void:
	if summary_label.get_parent() != null:
		summary_label.get_parent().remove_child(summary_label)
	if ascend_button.get_parent() != null:
		ascend_button.get_parent().remove_child(ascend_button)
	for child in content_box.get_children():
		child.queue_free()
	section_nodes.clear()
	stat_value_labels.clear()
	_start_section("overview", "角色概览")
	section_box.add_child(summary_label)
	section_box.add_child(ascend_button)
	_start_section("stats", "基础属性")
	_render_stats()
	_start_section("equipment", "装备")
	_render_equipment()
	_start_section("skills", "技能")
	_render_skills()
	# 为最后一节保留滚动空间，使目录点击后也能把它对齐到顶部。
	var trailing_space := Control.new()
	trailing_space.custom_minimum_size.y = 740.0
	content_box.add_child(trailing_space)
	_set_active_section("overview")

# 创建可被左侧目录定位的右侧章节。
func _start_section(section_id: String, heading: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_child(panel)
	section_nodes[section_id] = panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	section_box = VBoxContainer.new()
	section_box.add_theme_constant_override("separation", 12)
	margin.add_child(section_box)
	_add_section_title(heading)

# 点击目录时将对应章节滚动到右侧内容区顶部。
func _jump_to_section(section_id: String) -> void:
	var target := section_nodes.get(section_id) as Control
	if target == null:
		return
	content_scroll.scroll_vertical = roundi(target.position.y)
	_set_active_section(section_id)

# 根据右侧滚动位置更新左侧目录高亮。
func _sync_nav_to_scroll(_value: float) -> void:
	if section_nodes.is_empty():
		return
	var last_section := section_nodes.get("skills") as Control
	if last_section == null or last_section.position.y <= 0.0:
		return
	var selected := "overview"
	for section in SECTIONS:
		var key := str(section[0])
		var node := section_nodes.get(key) as Control
		if node != null and node.position.y <= content_scroll.scroll_vertical + 80.0:
			selected = key
	_set_active_section(selected)

# 集中更新目录选中态，避免重复设置所有按钮样式。
func _set_active_section(section_id: String) -> void:
	active_section = section_id
	for key in nav_buttons:
		var button := nav_buttons[key] as Button
		button.modulate = Color("#f6d998") if key == section_id else Color("#a9a8bd")

func _render_stats() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	for item in _stat_rows():
		var key := Label.new()
		key.text = str(item[0])
		key.add_theme_font_size_override("font_size", 18)
		key.add_theme_color_override("font_color", Color("#b9a5d8"))
		grid.add_child(key)
		var value := Label.new()
		value.text = str(item[1])
		value.add_theme_font_size_override("font_size", 18)
		value.add_theme_color_override("font_color", Color("#f1edf8"))
		grid.add_child(value)
		stat_value_labels[str(item[0])] = value
	section_box.add_child(grid)
	if not unit.permanent_mods.is_empty():
		_add_section_title("永久强化")
		for stat in unit.permanent_mods:
			_add_body_label("%s  +%d" % [_stat_text(str(stat)), int(unit.permanent_mods[stat])])

# 汇总当前单位的动态属性，供首次渲染与战斗中刷新共用。
func _stat_rows() -> Array:
	var armor_percent := COMBAT_FORMULA.armor_reduction_percent(unit.get_defense())
	var shield_cap := unit.get_shield_cap()
	var shield_text := "%d / %s" % [unit.get_total_shield(), "无上限" if shield_cap < 0 else str(shield_cap)]
	return [
		["星级", "%d / %d" % [unit.star, Unit.MAX_STARS]],
		["生命", "%d / %d" % [unit.hp, unit.max_hp]],
		["护盾", shield_text],
		["攻击", "%d" % unit.get_attack()],
		["护甲", "%d（%.1f%%减伤）" % [unit.get_defense(), armor_percent]],
		["射程", "%d - %d" % [unit.get_range_min(), unit.get_range_max()]],
		["移动", "%d 格" % unit.get_move_points()],
		["行动间隔", "%.1f 秒" % unit.turn_interval],
		["暴击", "%d%% / %d%%" % [unit.get_crit_rate(), unit.get_crit_damage()]],
		["通用技能槽", "%d / %d" % [unit.equipped_skill_names.size(), Unit.get_skill_slot_limit(unit.star)]],
		["当前状态", "存活" if unit.alive else "已阵亡"]
	]

# 更新已存在的数值标签，不触碰滚动容器中的节点结构。
func _refresh_stat_values() -> void:
	for item in _stat_rows():
		var value := stat_value_labels.get(str(item[0])) as Label
		if value != null:
			value.text = str(item[1])

func _render_equipment() -> void:
	if unit.equipment.is_empty():
		_add_body_label("暂无装备")
		return
	for slot in unit.equipment:
		var equipment: Equipment = unit.equipment[slot]
		var line := HBoxContainer.new()
		line.custom_minimum_size.y = 54
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(42, 42)
		icon.color = Color("#6b4e8e")
		line.add_child(icon)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.text = "%s  ·  %s" % [_slot_text(str(slot)), equipment.name]
		title.add_theme_color_override("font_color", Color("#f2d08b"))
		text_box.add_child(title)
		var details := Label.new()
		details.text = _modifier_text(equipment.modifiers)
		details.add_theme_font_size_override("font_size", 17)
		details.add_theme_color_override("font_color", Color("#d8d2e5"))
		text_box.add_child(details)
		line.add_child(text_box)
		section_box.add_child(line)

func _render_skills() -> void:
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	var learn_button := Button.new()
	learn_button.text = "学习"
	learn_button.custom_minimum_size = Vector2(110, 38)
	learn_button.disabled = _find_roster_unit().is_empty()
	learn_button.pressed.connect(_show_skill_manage.bind("learn"))
	actions.add_child(learn_button)
	var forget_button := Button.new()
	forget_button.text = "遗忘"
	forget_button.custom_minimum_size = Vector2(110, 38)
	forget_button.disabled = _find_roster_unit().is_empty()
	forget_button.pressed.connect(_show_skill_manage.bind("forget"))
	actions.add_child(forget_button)
	section_box.add_child(actions)
	if unit.skills.is_empty():
		_add_body_label("暂无技能")
		return
	for skill in unit.skills:
		var skill_id := str(skill.skill_id) if not str(skill.skill_id).is_empty() else str(skill.name)
		var row := Button.new()
		row.flat = true
		row.custom_minimum_size = Vector2(0, 82)
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.pressed.connect(_show_skill_details.bind(skill_id))
		var row_box := HBoxContainer.new()
		row_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row_box.add_theme_constant_override("separation", 12)
		row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(row_box)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(58, 58)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = ArtManager.get_skill_icon("", str(skill.name))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_box.add_child(icon)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := Label.new()
		var skill_type := "通用" if skill.common else "固有"
		var skill_tags := "、".join(skill.tags) if not skill.tags.is_empty() else "无"
		title.text = "%s  ·  %s  ·  标签：%s" % [str(skill.name), skill_type, skill_tags]
		title.add_theme_color_override("font_color", Color("#f2d08b"))
		title.add_theme_font_size_override("font_size", 17)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(title)
		var desc := Label.new()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 17)
		desc.add_theme_color_override("font_color", Color("#d8d2e5"))
		desc.text = "%s\n点击查看完整技能详情" % str(skill.desc)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(desc)
		row_box.add_child(text_box)
		section_box.add_child(row)

# 在立绘区域上方构建技能学习/遗忘列表，内容可独立滚动。
func _build_skill_manage_overlay() -> void:
	skill_manage_overlay = PanelContainer.new()
	skill_manage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_manage_overlay.visible = false
	skill_manage_overlay.z_index = 5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.12, 0.97)
	style.border_color = Color("#8d749f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	skill_manage_overlay.add_theme_stylebox_override("panel", style)
	portrait_panel.add_child(skill_manage_overlay)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	skill_manage_overlay.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	skill_manage_title = Label.new()
	skill_manage_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_manage_title.add_theme_font_size_override("font_size", 22)
	skill_manage_title.add_theme_color_override("font_color", Color("#f2d08b"))
	header.add_child(skill_manage_title)
	var close := Button.new()
	close.text = "关闭 ×"
	close.pressed.connect(skill_manage_overlay.hide)
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	skill_manage_list = VBoxContainer.new()
	skill_manage_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_manage_list.add_theme_constant_override("separation", 8)
	scroll.add_child(skill_manage_list)

# 展开符合条件的技能列表：学习只显示有技能书且有空槽的未学技能，遗忘只显示已学技能。
func _show_skill_manage(mode: String) -> void:
	var roster_unit := _find_roster_unit()
	if roster_unit.is_empty():
		return
	for child in skill_manage_list.get_children():
		child.queue_free()
	skill_manage_title.text = "选择要学习的技能" if mode == "learn" else "选择要遗忘的技能"
	var skill_ids: Array = []
	var skill_slots_full := false
	if mode == "learn":
		var equipped: Array = roster_unit.get("equipped_skills", [])
		skill_slots_full = equipped.size() >= ProgressManager.get_skill_slot_limit(int(roster_unit.get("star", 1)))
		if not skill_slots_full:
			for skill_id in ProgressManager.get_inventory().get("skill_books", {}).keys():
				var data: Dictionary = GameDatabase.get_skill(str(skill_id))
				if ProgressManager.get_skill_book_count(str(skill_id)) > 0 \
						and bool(data.get("common", false)) \
						and not roster_unit.get("learned_skills", []).has(str(skill_id)):
					skill_ids.append(str(skill_id))
	else:
		skill_ids.assign(roster_unit.get("learned_skills", []))
	if skill_ids.is_empty():
		var empty := Label.new()
		if mode == "learn" and skill_slots_full:
			empty.text = "通用技能槽已满，请先遗忘一个通用技能后再学习。"
		else:
			empty.text = "当前没有可学习的技能书。" if mode == "learn" else "当前角色没有已学习技能。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		skill_manage_list.add_child(empty)
	for skill_id in skill_ids:
		_add_skill_manage_row(str(skill_id), mode)
	skill_manage_overlay.visible = true
	skill_manage_overlay.move_to_front()

# 添加技能选择行，统一显示图标、名称和简介。
func _add_skill_manage_row(skill_id: String, mode: String) -> void:
	var data: Dictionary = GameDatabase.get_skill(skill_id)
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 86)
	row.pressed.connect(_apply_skill_manage.bind(skill_id, mode))
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ArtManager.get_skill_icon(skill_id, str(data.get("name", skill_id)))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.text = "%s%s" % [str(data.get("name", skill_id)),
		"  ×%d" % ProgressManager.get_skill_book_count(skill_id) if mode == "learn" else ""]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#f2d08b"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title)
	var desc := Label.new()
	desc.text = str(data.get("desc", "暂无说明"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(desc)
	line.add_child(text_box)
	skill_manage_list.add_child(row)

# 执行技能书学习或遗忘，并同步当前详情实例与右侧技能列表。
func _apply_skill_manage(skill_id: String, mode: String) -> void:
	var roster_unit := _find_roster_unit()
	if roster_unit.is_empty():
		return
	var changed := ProgressManager.use_skill_book(roster_unit, skill_id) if mode == "learn" \
		else ProgressManager.forget_skill(roster_unit, skill_id)
	if not changed:
		return
	unit.learned_skill_names = roster_unit.get("learned_skills", []).duplicate()
	unit.equipped_skill_names = roster_unit.get("equipped_skills", []).duplicate()
	unit.skills.clear()
	unit.apply_skills(GameDatabase)
	_render_all_sections()
	# 容器需要一帧重新计算章节位置；提前跳转会读到 y=0，导致右侧回到顶部。
	await get_tree().process_frame
	if not visible or unit == null:
		return
	_jump_to_section("skills")
	_show_skill_manage(mode)

# 根据当前详情单位的持久化 id 查找玩家编成数据；敌方和模组临时单位不允许修改技能。
func _find_roster_unit() -> Dictionary:
	if unit == null or unit.unit_id.is_empty() or unit.camp != TurnManager.PLAYER_CAMP:
		return {}
	for roster_unit in GameDatabase.player_roster.get("units", []):
		if str(roster_unit.get("id", "")) == unit.unit_id:
			return roster_unit
	return {}

# 点击技能时打开带遮罩、图标和数据摘要的详情弹窗。
func _show_skill_details(skill_id: String) -> void:
	if skill_detail_dialog == null:
		skill_detail_dialog = SkillDetailPopup.new()
		skill_detail_dialog.name = "SkillDetailDialog"
		add_child(skill_detail_dialog)
	skill_detail_dialog.show_skill(skill_id)

func _add_section_title(text: String) -> void:
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#f2d08b"))
	section_box.add_child(title)

func _add_body_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("#d8d2e5"))
	section_box.add_child(label)

func _role_text(role: String) -> String:
	return {
		"warrior": "战士",
		"tank": "坦克",
		"archer": "射手",
		"assassin": "刺客",
		"support": "辅助"
	}.get(role, role if role != "" else "作战单位")

func _stat_text(stat: String) -> String:
	return {"hp": "生命上限", "attack": "攻击", "defense": "护甲", "move": "移动"}.get(stat, stat)

func _slot_text(slot: String) -> String:
	return {"weapon": "武器", "offhand": "副手", "accessory": "饰品"}.get(slot, slot)

func _modifier_text(modifiers: Dictionary) -> String:
	if modifiers.is_empty():
		return "无属性修正"
	var parts: Array[String] = []
	for key in modifiers:
		parts.append("%s %+d" % [_stat_text(str(key)), int(modifiers[key])])
	return "，".join(parts)
