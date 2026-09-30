# 技能机制说明：将正文中的机制关键字链接到图鉴，触发整段效果的机制显示在开头。
class_name MechanicDescription
extends RichTextLabel

var _hovered_mechanic := ""
var _hover_serial := 0
var _tooltip_layer: CanvasLayer
var _tooltip_panel: PanelContainer
var _tooltip_label: Label

# 初始化描述的自动换行与悬停链接。
func _ready() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	meta_hover_started.connect(_on_meta_hover_started)
	meta_hover_ended.connect(_on_meta_hover_ended)
	meta_clicked.connect(_on_meta_clicked)

# 根据触发条件添加前缀，并为正文中所有机制关键字添加悬停说明。
func set_skill_description(data: Dictionary) -> void:
	bbcode_enabled = true
	_hover_serial += 1
	_hide_tooltip()
	var raw := str(data.get("desc", "暂无技能说明"))
	var mechanic_id := _find_mechanic(data)
	if mechanic_id.is_empty():
		text = _link_keywords(raw)
		return
	var info := _mechanic_data(mechanic_id)
	if info.is_empty():
		text = _link_keywords(raw)
		return
	var title := str(info.get("name", ""))
	# 配置已有机制前缀时先去掉，避免界面重复显示同一个名称。
	for prefix in [title + "：", title + ":"]:
		if raw.begins_with(prefix):
			raw = raw.trim_prefix(prefix)
			break
	if mechanic_id == "avenge":
		title += "（%d）" % int(data.get("avenge_count", 1))
	elif mechanic_id == "dormant":
		for effect in data.get("effects", []):
			if effect is Dictionary and str(effect.get("type", "")) == "dormant":
				var seconds := float(effect.get("duration_seconds", 0.0))
				title += "（%ds）" % roundi(seconds) if is_equal_approx(seconds, float(roundi(seconds))) else "（%.1fs）" % seconds
				break
	elif mechanic_id == "battlecry":
		for prefix in ["开战时", "战斗开始时", "入场时", "入场后"]:
			if raw.begins_with(prefix):
				raw = raw.trim_prefix(prefix)
				break
	elif mechanic_id == "deathrattle" and raw.begins_with("阵亡时"):
		raw = raw.trim_prefix("阵亡时")
	text = _link_keywords(title + "：" + raw)

# 一次匹配原始文本中的关键字，避免链接嵌套，并支持同段多个机制。
func _link_keywords(raw: String) -> String:
	var file := FileAccess.open("res://data/mechanics.json", FileAccess.READ)
	if file == null:
		return raw
	var rules: Dictionary = JSON.parse_string(file.get_as_text())
	var names: Dictionary = {}
	for mechanic_id in rules:
		names[str(rules[mechanic_id].get("name", ""))] = mechanic_id
	var regex := RegEx.new()
	regex.compile("|".join(names.keys()))
	var result := ""
	var cursor := 0
	for found in regex.search_all(raw):
		var keyword := found.get_string()
		result += raw.substr(cursor, found.get_start() - cursor)
		result += "[url=%s][color=#f3d79f]%s[/color][/url]" % [names[keyword], keyword]
		cursor = found.get_end()
	return result + raw.substr(cursor)

# 离开界面时销毁悬浮说明，避免覆盖其他弹窗。
func _exit_tree() -> void:
	_hide_tooltip()
	if is_instance_valid(_tooltip_layer):
		_tooltip_layer.queue_free()

# 仅把负责触发整段效果的机制作为前缀，状态效果留在正文中。
func _find_mechanic(data: Dictionary) -> String:
	for effect in data.get("effects", []):
		if effect is Dictionary and str(effect.get("type", "")) == "dormant":
			return "dormant"
	match str(data.get("trigger", "")):
		"on_enter_battle": return "battlecry"
		"on_death": return "deathrattle"
		"on_avenge": return "avenge"
	return ""

# 读取图鉴中的单条机制说明。
func _mechanic_data(mechanic_id: String) -> Dictionary:
	var file := FileAccess.open("res://data/mechanics.json", FileAccess.READ)
	if file == null:
		return {}
	var all_data: Variant = JSON.parse_string(file.get_as_text())
	return all_data.get(mechanic_id, {}) if all_data is Dictionary else {}

# 悬停一秒后显示规则，移动到别处即取消待显示任务。
func _on_meta_hover_started(meta: Variant) -> void:
	_hovered_mechanic = str(meta)
	_hover_serial += 1
	var serial := _hover_serial
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree() and serial == _hover_serial and _hovered_mechanic == str(meta):
		_show_tooltip(str(meta))

# 离开机制链接后隐藏规则。
func _on_meta_hover_ended(_meta: Variant) -> void:
	_hovered_mechanic = ""
	_hover_serial += 1
	_hide_tooltip()

# 点击机制名称时立即显示对应图鉴规则。
func _on_meta_clicked(meta: Variant) -> void:
	accept_event()
	_show_tooltip(str(meta))

# 在最高层显示说明，并限制在游戏视口内。
func _show_tooltip(mechanic_id: String) -> void:
	var info := _mechanic_data(mechanic_id)
	if info.is_empty():
		return
	if not is_instance_valid(_tooltip_layer):
		_tooltip_layer = CanvasLayer.new()
		_tooltip_layer.layer = 120
		get_tree().root.add_child(_tooltip_layer)
		_tooltip_panel = PanelContainer.new()
		_tooltip_panel.custom_minimum_size.x = 330
		_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tooltip_panel.add_theme_stylebox_override("panel", MenuStyle.section_panel_style())
		_tooltip_layer.add_child(_tooltip_panel)
		_tooltip_label = Label.new()
		_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tooltip_label.custom_minimum_size.x = 310
		_tooltip_label.add_theme_font_size_override("font_size", 16)
		_tooltip_panel.add_child(_tooltip_label)
	_tooltip_label.text = "%s\n%s" % [str(info.get("name", "")), str(info.get("desc", ""))]
	_tooltip_panel.visible = true
	var viewport_size := get_viewport_rect().size
	_tooltip_panel.custom_minimum_size.x = minf(330.0, maxf(180.0, viewport_size.x - 16.0))
	_tooltip_label.custom_minimum_size.x = _tooltip_panel.custom_minimum_size.x - 20.0
	_tooltip_panel.reset_size()
	var desired := get_viewport().get_mouse_position() + Vector2(16, 20)
	_tooltip_panel.position = Vector2(clampf(desired.x, 8.0, maxf(8.0, viewport_size.x - _tooltip_panel.size.x - 8.0)),
		clampf(desired.y, 8.0, maxf(8.0, viewport_size.y - _tooltip_panel.size.y - 8.0)))

# 隐藏当前机制说明。
func _hide_tooltip() -> void:
	if is_instance_valid(_tooltip_panel):
		_tooltip_panel.visible = false
