## 大型角色信息面板：参考 LC2 !ve 角色面板，统一展示立绘、属性、装备和技能。
class_name UnitDetailPanel
extends PanelContainer

const COMBAT_FORMULA = preload("res://scripts/core/combat_formula.gd")
const SKILL_DETAIL_FORMATTER = preload("res://scripts/ui/skill_detail_formatter.gd")

var unit: Unit
var portrait: TextureRect
var name_label: Label
var summary_label: Label
var content_scroll: ScrollContainer
var content_box: VBoxContainer
var tab_buttons: Array[Button] = []
var active_tab := "stats"
var ascension_enabled := false
var ascend_button: Button
var skill_detail_dialog: AcceptDialog

signal ascension_requested(unit: Unit)

func _ready() -> void:
	if content_box == null:
		_build_panel()

func _build_panel() -> void:
	custom_minimum_size = Vector2(680.0, 420.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#191827")
	style.border_color = Color("#b58a4a")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 172
	header.add_theme_constant_override("separation", 18)
	root_box.add_child(header)

	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(172, 172)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.add_child(portrait)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 6)
	header.add_child(identity)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color("#f2d08b"))
	identity.add_child(name_label)

	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 16)
	summary_label.add_theme_color_override("font_color", Color("#d8d2e5"))
	identity.add_child(summary_label)

	ascend_button = Button.new()
	ascend_button.custom_minimum_size = Vector2(220, 34)
	ascend_button.visible = ascension_enabled
	ascend_button.pressed.connect(_on_ascend_pressed)
	identity.add_child(ascend_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	root_box.add_child(tabs)
	for tab_data in [["stats", "属性"], ["equipment", "装备"], ["skills", "技能"]]:
		var button := Button.new()
		button.text = tab_data[1]
		button.custom_minimum_size = Vector2(116, 38)
		button.pressed.connect(_on_tab_pressed.bind(str(tab_data[0])))
		tabs.add_child(button)
		tab_buttons.append(button)

	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root_box.add_child(content_scroll)
	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 8)
	content_scroll.add_child(content_box)

func show_unit(p_unit: Unit) -> void:
	if content_box == null:
		_build_panel()
	unit = p_unit
	if unit == null:
		return
	active_tab = "stats"
	_refresh_header()
	_render_tab()

# 刷新当前已打开的信息卡，保留用户正在查看的标签页。
# 战斗界面只对当前打开的卡片调用，不让未查看的单位产生持续 UI 开销。
func refresh_current() -> void:
	if unit == null or not visible:
		return
	_refresh_header()
	_render_tab()

func _refresh_header() -> void:
	portrait.texture = ArtManager.get_portrait(unit.unit_type)
	name_label.text = unit.get_display_name()
	var role := str(unit.config.get("role", ""))
	var camp := "我方" if unit.camp == TurnManager.PLAYER_CAMP else "敌方"
	var tags_text := "、".join(unit.get_tags()) if not unit.get_tags().is_empty() else "无"
	summary_label.text = "%s  ·  %d星  ·  Lv.%d\n%s\n标签：%s\n通用技能槽：%d/%d" % [
		camp, unit.star, unit.level, _role_text(role), tags_text,
		unit.equipped_skill_names.size(), Unit.get_skill_slot_limit(unit.star)
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

func _on_tab_pressed(tab: String) -> void:
	active_tab = tab
	_render_tab()

func _render_tab() -> void:
	for child in content_box.get_children():
		child.queue_free()
	for button in tab_buttons:
		button.modulate = Color("#fff0c2") if button.text == _tab_title(active_tab) else Color("#b4afc4")
	match active_tab:
		"equipment":
			_render_equipment()
		"skills":
			_render_skills()
		_:
			_render_stats()

func _render_stats() -> void:
	_add_section_title("基础属性")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	var armor_percent := COMBAT_FORMULA.armor_reduction_percent(unit.get_defense())
	var values := [
		["星级", "%d / %d" % [unit.star, Unit.MAX_STARS]],
		["生命", "%d / %d" % [unit.hp, unit.max_hp]],
		["攻击", "%d" % unit.get_attack()],
		["护甲", "%d（%.1f%%减伤）" % [unit.get_defense(), armor_percent]],
		["射程", "%d - %d" % [unit.get_range_min(), unit.get_range_max()]],
		["移动", "%d 格" % unit.get_move_points()],
		["行动间隔", "%.1f 秒" % unit.turn_interval],
		["暴击", "%d%% / %d%%" % [unit.get_crit_rate(), unit.get_crit_damage()]],
		["通用技能槽", "%d / %d" % [unit.equipped_skill_names.size(), Unit.get_skill_slot_limit(unit.star)]],
		["当前状态", "存活" if unit.alive else "已阵亡"]
	]
	for item in values:
		var key := Label.new()
		key.text = str(item[0])
		key.add_theme_color_override("font_color", Color("#b9a5d8"))
		grid.add_child(key)
		var value := Label.new()
		value.text = str(item[1])
		value.add_theme_color_override("font_color", Color("#f1edf8"))
		grid.add_child(value)
	content_box.add_child(grid)
	if not unit.permanent_mods.is_empty():
		_add_section_title("永久强化")
		for stat in unit.permanent_mods:
			_add_body_label("%s  +%d" % [_stat_text(str(stat)), int(unit.permanent_mods[stat])])

func _render_equipment() -> void:
	_add_section_title("装备栏")
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
		details.add_theme_color_override("font_color", Color("#d8d2e5"))
		text_box.add_child(details)
		line.add_child(text_box)
		content_box.add_child(line)

func _render_skills() -> void:
	_add_section_title("技能")
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
		desc.add_theme_color_override("font_color", Color("#d8d2e5"))
		desc.text = "%s\n点击查看完整技能详情" % str(skill.desc)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(desc)
		row_box.add_child(text_box)
		content_box.add_child(row)

# 技能详情弹窗与背包技能书共用同一份格式化文本。
func _show_skill_details(skill_id: String) -> void:
	if skill_detail_dialog == null:
		skill_detail_dialog = AcceptDialog.new()
		skill_detail_dialog.name = "SkillDetailDialog"
		skill_detail_dialog.min_size = Vector2(620, 420)
		add_child(skill_detail_dialog)
	skill_detail_dialog.title = str(GameDatabase.get_skill(skill_id).get("name", skill_id))
	skill_detail_dialog.dialog_text = SKILL_DETAIL_FORMATTER.build(skill_id)
	skill_detail_dialog.popup_centered(Vector2(620, 420))

func _add_section_title(text: String) -> void:
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#f2d08b"))
	content_box.add_child(title)

func _add_body_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#d8d2e5"))
	content_box.add_child(label)

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

func _tab_title(tab: String) -> String:
	return {"stats": "属性", "equipment": "装备", "skills": "技能"}.get(tab, "属性")
