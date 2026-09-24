# 图鉴页面：按分类列出数据库中的全部技能与遗物，并复用已有详情弹窗。
extends Control

const CATEGORIES := [
	{"id": "skills", "label": "技能图鉴"},
	{"id": "relics", "label": "遗物图鉴"},
]

var category_buttons: Dictionary = {}
var content_title: Label
var content_hint: Label
var entry_list: VBoxContainer
var skill_popup: SkillDetailPopup
var relic_popup: RelicDetailPopup

# 创建固定布局与分类入口，初次进入时等待玩家选择图鉴。
func _ready() -> void:
	_build_layout()
	skill_popup = SkillDetailPopup.new()
	skill_popup.visible = false
	add_child(skill_popup)
	relic_popup = RelicDetailPopup.new()
	relic_popup.visible = false
	add_child(relic_popup)

# 构建无装饰的图鉴主框架，分类导航与条目列表彼此独立。
func _build_layout() -> void:
	var page_margin := MarginContainer.new()
	page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_margin.add_theme_constant_override("margin_left", 40)
	page_margin.add_theme_constant_override("margin_right", 40)
	page_margin.add_theme_constant_override("margin_top", 36)
	page_margin.add_theme_constant_override("margin_bottom", 36)
	add_child(page_margin)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", MenuStyle.frame_panel_style())
	page_margin.add_child(frame)
	var frame_margin := MarginContainer.new()
	frame_margin.add_theme_constant_override("margin_left", 22)
	frame_margin.add_theme_constant_override("margin_right", 22)
	frame_margin.add_theme_constant_override("margin_top", 18)
	frame_margin.add_theme_constant_override("margin_bottom", 18)
	frame.add_child(frame_margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	frame_margin.add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 66
	page.add_child(header)
	var title := Label.new()
	title.text = "图鉴"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f3d79f"))
	header.add_child(title)
	var back_button := Button.new()
	back_button.text = "返回主菜单"
	back_button.custom_minimum_size = Vector2(144, 44)
	MenuStyle.apply_primary(back_button)
	back_button.pressed.connect(_go_back)
	header.add_child(back_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	page.add_child(body)
	var navigation := PanelContainer.new()
	navigation.custom_minimum_size.x = 220
	navigation.add_theme_stylebox_override("panel", MenuStyle.section_panel_style())
	body.add_child(navigation)
	var nav_box := VBoxContainer.new()
	nav_box.add_theme_constant_override("separation", 8)
	navigation.add_child(nav_box)
	var nav_title := Label.new()
	nav_title.text = "分类"
	nav_title.add_theme_font_size_override("font_size", 20)
	nav_title.add_theme_color_override("font_color", Color("#f3d79f"))
	nav_box.add_child(nav_title)
	for category in CATEGORIES:
		var category_id: String = category["id"]
		var button := Button.new()
		button.text = category["label"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 52
		MenuStyle.apply_navigation(button, false)
		button.pressed.connect(_select_category.bind(category_id))
		nav_box.add_child(button)
		category_buttons[category_id] = button

	var content := PanelContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_stylebox_override("panel", MenuStyle.section_panel_style())
	body.add_child(content)
	var content_box := VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 10)
	content.add_child(content_box)
	content_title = Label.new()
	content_title.text = "选择图鉴分类"
	content_title.add_theme_font_size_override("font_size", 25)
	content_title.add_theme_color_override("font_color", Color("#f3d79f"))
	content_box.add_child(content_title)
	content_hint = Label.new()
	content_hint.text = "从左侧选择技能图鉴或遗物图鉴。"
	content_hint.add_theme_color_override("font_color", Color("#b6bdc9"))
	content_box.add_child(content_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_box.add_child(scroll)
	entry_list = VBoxContainer.new()
	entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_list.add_theme_constant_override("separation", 8)
	scroll.add_child(entry_list)

# 切换图鉴分类，并从当前数据库生成无拥有状态过滤的完整列表。
func _select_category(category_id: String) -> void:
	for id in category_buttons:
		MenuStyle.apply_navigation(category_buttons[id], id == category_id)
	for child in entry_list.get_children():
		entry_list.remove_child(child)
		child.queue_free()
	var source: Dictionary = GameDatabase.skills if category_id == "skills" else GameDatabase.relics
	var ids := source.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str(source[a].get("name", a)) < str(source[b].get("name", b)))
	content_title.text = "技能图鉴" if category_id == "skills" else "遗物图鉴"
	content_hint.text = "共 %d 项 · 点击条目查看详情" % ids.size()
	for entry_id in ids:
		_add_entry(category_id, str(entry_id), source[entry_id])

# 为一项技能或遗物创建可点击的图标、名称和效果摘要。
func _add_entry(category_id: String, entry_id: String, data: Dictionary) -> void:
	var entry := Button.new()
	var entry_name := str(data.get("name", entry_id))
	var description := str(data.get("desc", "暂无说明")).replace("\n", " ")
	if description.length() > 110:
		description = description.substr(0, 110) + "…"
	entry.text = "%s\n%s" % [entry_name, description]
	entry.icon = ArtManager.get_skill_icon(entry_id, entry_name) if category_id == "skills" else ArtManager.get_relic_icon(entry_id)
	entry.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.custom_minimum_size.y = 90
	entry.add_theme_constant_override("icon_max_width", 64)
	MenuStyle.apply_primary(entry)
	entry.pressed.connect(_open_entry.bind(category_id, entry_id))
	entry_list.add_child(entry)

# 打开与角色资料页一致的技能或遗物详情。
func _open_entry(category_id: String, entry_id: String) -> void:
	if category_id == "skills":
		skill_popup.show_skill(entry_id)
	else:
		relic_popup.show_relic(entry_id)

# 返回主菜单，不变更存档或战斗状态。
func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# 用 ESC 或右键关闭技能详情；没有弹窗时 ESC 返回主菜单。
func _unhandled_input(event: InputEvent) -> void:
	var close_key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	var close_mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if not close_key and not close_mouse:
		return
	if skill_popup != null and skill_popup.visible:
		skill_popup.hide()
	elif close_key:
		_go_back()
	get_viewport().set_input_as_handled()
