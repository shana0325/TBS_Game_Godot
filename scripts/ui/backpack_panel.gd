## 背包悬浮窗：以网格展示升星道具与技能书，技能书可拖拽到部署区单位。
class_name BackpackPanel
extends Control

const SKILL_DETAIL_FORMATTER = preload("res://scripts/ui/skill_detail_formatter.gd")

var dimmer: ColorRect
var popup_panel: PanelContainer
var items_grid: GridContainer
var status_label: Label

func _ready() -> void:
	# 面板自身覆盖父节点，透明遮罩负责接收“点击背包外关闭”。
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	dimmer = ColorRect.new()
	dimmer.color = Color(0.02, 0.02, 0.06, 0.42)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.gui_input.connect(_on_dimmer_gui_input)
	add_child(dimmer)
	_build_popup()
	_layout_popup()
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_popup()

func _build_popup() -> void:
	popup_panel = PanelContainer.new()
	popup_panel.name = "BackpackPopup"
	popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(popup_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	popup_panel.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)

	var title := Label.new()
	title.text = "背包"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#f2d08b"))
	root_box.add_child(title)

	var hint := Label.new()
	hint.text = "点击或悬停查看说明；将技能书拖到部署区的我方单位即可学习并装备。"
	hint.add_theme_color_override("font_color", Color("#b8b1c7"))
	root_box.add_child(hint)

	items_grid = GridContainer.new()
	items_grid.name = "BackpackItemsGrid"
	items_grid.columns = 4
	items_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_grid.add_theme_constant_override("h_separation", 10)
	items_grid.add_theme_constant_override("v_separation", 10)
	root_box.add_child(items_grid)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 42
	status_label.add_theme_color_override("font_color", Color("#f0c878"))
	root_box.add_child(status_label)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0, 38)
	close_button.pressed.connect(close)
	root_box.add_child(close_button)

func _layout_popup() -> void:
	if popup_panel == null:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var popup_size := Vector2(minf(640.0, maxf(360.0, viewport_size.x - 48.0)), minf(620.0, maxf(400.0, viewport_size.y - 48.0)))
	popup_panel.position = (viewport_size - popup_size) / 2.0
	popup_panel.size = popup_size

func refresh() -> void:
	if items_grid == null:
		return
	for child in items_grid.get_children():
		items_grid.remove_child(child)
		child.queue_free()
	var inventory: Dictionary = ProgressManager.get_inventory()
	_add_item_cell("star_item", "升星道具", "用于角色升星。当前总数量：%d" % int(inventory.get("star_items", 0)), int(inventory.get("star_items", 0)))
	var books: Dictionary = inventory.get("skill_books", {})
	var book_ids: Array = books.keys()
	book_ids.sort()
	for skill_id in book_ids:
		var count := int(books.get(skill_id, 0))
		if count <= 0:
			continue
		var skill_data: Dictionary = GameDatabase.get_skill(str(skill_id))
		if skill_data.is_empty():
			continue
		var skill_name := str(skill_data.get("name", skill_id))
		var desc := str(skill_data.get("desc", "暂无简介"))
		_add_item_cell("skill_book", skill_name, "技能书：%s\n%s" % [skill_name, desc], count, str(skill_id))

func _add_item_cell(item_kind: String, title: String, description: String, count: int, item_id: String = "") -> void:
	var cell := BackpackItemCell.new()
	cell.setup(item_kind, item_id, title, count, description)
	if item_kind == "skill_book":
		var skill_details: String = SKILL_DETAIL_FORMATTER.build(item_id)
		cell.mouse_entered.connect(_show_skill_details.bind(skill_details))
		cell.pressed.connect(_show_skill_details.bind(skill_details))
	else:
		cell.mouse_entered.connect(_show_item_details.bind(title, description))
		cell.pressed.connect(_show_item_details.bind(title, description))
	items_grid.add_child(cell)

func _show_item_details(title: String, description: String) -> void:
	if status_label != null:
		status_label.text = "%s\n%s" % [title, description]

func _show_skill_details(details: String) -> void:
	if status_label != null:
		status_label.text = details

func set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	refresh()
	visible = true

func close() -> void:
	visible = false

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
		get_viewport().set_input_as_handled()
