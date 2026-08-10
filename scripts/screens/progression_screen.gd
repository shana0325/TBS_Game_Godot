# 成长界面：两段式——先选角色，再在 属性/技能/装备 三个子页中成长，修改写回 player_roster.json。
extends Control

enum Tab { STATS, SKILLS, EQUIP }

var roster: Array = []
var selected_index: int = 0
var current_tab: int = Tab.STATS

var role_buttons: Array = []
var tab_buttons: Array = []
var content_panel: VBoxContainer
var overview_label: Label
var overview_portrait: TextureRect
var status_label: Label

func _ready() -> void:
	roster = GameDatabase.player_roster.get("units", [])
	_build_top_bar()
	_build_tab_bar()
	content_panel = VBoxContainer.new()
	content_panel.position = Vector2(80, 200)
	content_panel.add_theme_constant_override("separation", 10)
	add_child(content_panel)
	_build_overview_panel()
	status_label = Label.new()
	status_label.position = Vector2(80, 660)
	status_label.add_theme_font_size_override("font_size", 18)
	add_child(status_label)
	_refresh()

# 右侧角色总览面板：展示装备/加点后的整体属性与已装备技能。
func _build_overview_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(700, 170)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	overview_portrait = TextureRect.new()
	overview_portrait.custom_minimum_size = Vector2(160, 160)
	overview_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overview_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(overview_portrait)
	overview_label = Label.new()
	overview_label.add_theme_font_size_override("font_size", 20)
	overview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overview_label.custom_minimum_size = Vector2(460, 280)
	box.add_child(overview_label)
	margin.add_child(box)
	panel.add_child(margin)
	add_child(panel)

func _current_unit() -> Dictionary:
	return roster[selected_index]

func _build_top_bar() -> void:
	var title := Label.new()
	title.text = "队伍编成"
	title.add_theme_font_size_override("font_size", 40)
	title.position = Vector2(60, 20)
	add_child(title)

	var back_btn := Button.new()
	back_btn.text = "返回主菜单"
	back_btn.position = Vector2(60, 70)
	back_btn.pressed.connect(_go_back)
	add_child(back_btn)

	# 角色选择按钮（横向排列）
	for i in roster.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(170, 44)
		btn.text = "%d. %s" % [i + 1, str(roster[i].get("type", "Unit"))]
		btn.pressed.connect(_on_role_selected.bind(i))
		add_child(btn)
		btn.position = Vector2(60 + i * 190, 120)
		role_buttons.append(btn)

func _build_tab_bar() -> void:
	for t in [Tab.STATS, Tab.SKILLS, Tab.EQUIP]:
		var btn := Button.new()
		btn.text = ["属性", "技能", "装备"][t]
		btn.custom_minimum_size = Vector2(120, 40)
		btn.position = Vector2(80 + t * 140, 160)
		btn.pressed.connect(_on_tab_selected.bind(t))
		add_child(btn)
		tab_buttons.append(btn)

func _on_role_selected(index: int) -> void:
	selected_index = index
	_refresh()

func _on_tab_selected(tab: int) -> void:
	current_tab = tab
	_refresh()

func _clear_content() -> void:
	for child in content_panel.get_children():
		child.queue_free()

func _refresh() -> void:
	for i in role_buttons.size():
		var btn: Button = role_buttons[i]
		if i == selected_index:
			btn.modulate = Color(1.2, 1.2, 0.5)
		else:
			btn.modulate = Color.WHITE
	for i in tab_buttons.size():
		var btn: Button = tab_buttons[i]
		if i == current_tab:
			btn.modulate = Color(0.8, 1.2, 0.9)
		else:
			btn.modulate = Color.WHITE
	_clear_content()
	var unit := _current_unit()
	var info := Label.new()
	info.text = "等级 %d  经验 %d/%d  属性点 %d  技能点 %d" % [
		int(unit.get("level", 1)), int(unit.get("exp", 0)),
		ProgressManager.required_exp_for_level(int(unit.get("level", 1))),
		int(unit.get("stat_points", 0)), int(unit.get("skill_points", 0))
	]
	info.add_theme_font_size_override("font_size", 20)
	content_panel.add_child(info)
	match current_tab:
		Tab.STATS:
			_build_stats_tab(unit)
		Tab.SKILLS:
			_build_skills_tab(unit)
		Tab.EQUIP:
			_build_equip_tab(unit)
	_refresh_overview(unit)

# 刷新右侧整体属性总览。
func _refresh_overview(unit: Dictionary) -> void:
	var portrait := ArtManager.get_portrait(str(unit.get("type", "")))
	overview_portrait.texture = portrait
	overview_portrait.visible = portrait != null
	var total := _get_total_stats(unit)
	var equipment: Dictionary = unit.get("equipment", {})
	var slot_labels := {"weapon": "武器", "offhand": "副手", "accessory": "饰品"}
	var lines: Array = []
	lines.append("%s  Lv.%d" % [str(unit.get("type", "Unit")), int(unit.get("level", 1))])
	lines.append("HP: %d" % int(total.get("hp", 0)))
	lines.append("攻击: %d   防御: %d   移动: %d" % [
		int(total.get("attack", 0)), int(total.get("defense", 0)), int(total.get("move", 0))
	])
	lines.append("")
	lines.append("装备:")
	if equipment.size() == 0:
		lines.append("  （无）")
	for slot in ProgressManager.VALID_SLOTS:
		var equip_id: String = str(equipment.get(slot, ""))
		lines.append("  %s: %s" % [slot_labels[slot], equip_id if equip_id != "" else "（空）"])
	lines.append("")
	lines.append("技能:")
	var skill_names := _get_all_skill_names(unit)
	if skill_names.size() == 0:
		lines.append("  （无）")
	for name in skill_names:
		lines.append("  · %s" % name)
	overview_label.text = "\n".join(lines)

# --- 属性子页 ---
func _build_stats_tab(unit: Dictionary) -> void:
	var config: Dictionary = GameDatabase.get_unit(str(unit.get("type", "Hero")))
	var allocated: Dictionary = unit.get("allocated_stats", {})
	var equip_mods := _get_equip_modifiers(unit)
	var labels := {"attack": "攻击", "defense": "防御", "move": "移动", "hp": "生命"}
	var base_keys := {"attack": "atk", "defense": "defense", "move": "move", "hp": "hp"}
	for stat in ProgressManager.POINTABLE_STATS:
		var base := int(config.get(base_keys[stat], 0))
		var alloc := int(allocated.get(stat, 0))
		var equip := int(equip_mods.get(stat, 0))
		var total := base + alloc + equip
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(340, 40)
		btn.text = "%s: %d  (基础%d +加点%d +装备%d)  [加点]" % [labels[stat], total, base, alloc, equip]
		btn.pressed.connect(_on_add_stat.bind(stat))
		content_panel.add_child(btn)

# 汇总角色装备提供的属性修正。
func _get_equip_modifiers(unit: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	var equipment: Dictionary = unit.get("equipment", {})
	for slot in ProgressManager.VALID_SLOTS:
		var equip_id: String = str(equipment.get(slot, ""))
		if equip_id == "":
			continue
		var data: Dictionary = GameDatabase.get_equipment(equip_id)
		for key in data.get("modifiers", {}):
			totals[key] = int(totals.get(key, 0)) + int(data["modifiers"][key])
	return totals

# 计算角色整体属性（基础+加点+装备）。
func _get_total_stats(unit: Dictionary) -> Dictionary:
	var config: Dictionary = GameDatabase.get_unit(str(unit.get("type", "Hero")))
	var allocated: Dictionary = unit.get("allocated_stats", {})
	var equip_mods := _get_equip_modifiers(unit)
	var base_keys := {"attack": "atk", "defense": "defense", "move": "move", "hp": "hp"}
	var result: Dictionary = {}
	for stat in ProgressManager.POINTABLE_STATS:
		result[stat] = int(config.get(base_keys[stat], 0)) \
			+ int(allocated.get(stat, 0)) + int(equip_mods.get(stat, 0))
	return result

# 收集角色当前所有技能名（模板+已学+已装备+装备授予）。
func _get_all_skill_names(unit: Dictionary) -> Array:
	var names: Array = []
	var config: Dictionary = GameDatabase.get_unit(str(unit.get("type", "Hero")))
	for s in config.get("skills", []):
		names.append(str(s))
	for s in unit.get("learned_skills", []):
		names.append(str(s))
	for s in unit.get("equipped_skills", []):
		names.append(str(s))
	for slot in ProgressManager.VALID_SLOTS:
		var equip_id: String = str(unit.get("equipment", {}).get(slot, ""))
		if equip_id == "":
			continue
		var data: Dictionary = GameDatabase.get_equipment(equip_id)
		for s in data.get("granted_skills", []):
			names.append(str(s))
	return names

func _on_add_stat(stat: String) -> void:
	if ProgressManager.add_stat_point(_current_unit(), stat):
		_refresh()
		status_label.text = "已为属性 %s +1" % stat
	else:
		status_label.text = "属性点不足"

# --- 技能子页 ---
func _build_skills_tab(unit: Dictionary) -> void:
	var learned: Array = unit.get("learned_skills", [])
	var equipped: Array = unit.get("equipped_skills", [])
	for skill_id in GameDatabase.skills.keys():
		var data: Dictionary = GameDatabase.get_skill(skill_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(560, 40)
		var status := ""
		if equipped.has(skill_id):
			status = "  已装备"
		elif learned.has(skill_id):
			status = "  已学习(未装备)"
		else:
			status = "  未学习"
		btn.text = "%s%s" % [str(data.get("name", skill_id)), status]
		btn.pressed.connect(_on_skill_action.bind(skill_id))
		content_panel.add_child(btn)

func _on_skill_action(skill_id: String) -> void:
	var unit := _current_unit()
	var learned: Array = unit.get("learned_skills", [])
	var equipped: Array = unit.get("equipped_skills", [])
	if equipped.has(skill_id):
		ProgressManager.unequip_skill(unit, skill_id)
		status_label.text = "已卸下技能 %s" % skill_id
	elif learned.has(skill_id):
		ProgressManager.equip_skill(unit, skill_id)
		status_label.text = "已装备技能 %s" % skill_id
	else:
		if ProgressManager.learn_skill(unit, skill_id):
			ProgressManager.equip_skill(unit, skill_id)
			status_label.text = "已学习并装备技能 %s" % skill_id
		else:
			status_label.text = "技能点不足或无法学习"
	_refresh()

# --- 装备子页 ---
func _build_equip_tab(unit: Dictionary) -> void:
	var equipment: Dictionary = unit.get("equipment", {})
	var slot_labels := {"weapon": "武器", "offhand": "副手", "accessory": "饰品"}
	for slot in ProgressManager.VALID_SLOTS:
		var equip_id: String = str(equipment.get(slot, ""))
		var label := Label.new()
		label.text = "%s: %s" % [slot_labels[slot], equip_id if equip_id != "" else "（空）"]
		label.add_theme_font_size_override("font_size", 18)
		content_panel.add_child(label)
		if equip_id != "":
			var unequip_btn := Button.new()
			unequip_btn.text = "卸下"
			unequip_btn.custom_minimum_size = Vector2(120, 34)
			unequip_btn.pressed.connect(_on_unequip.bind(slot))
			content_panel.add_child(unequip_btn)
	for equip_id in GameDatabase.equipments.keys():
		var data: Dictionary = GameDatabase.get_equipment(equip_id)
		var slot := str(data.get("slot", ""))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(420, 38)
		var modifiers_text := _format_modifiers(data.get("modifiers", {}))
		btn.text = "装备 %s（%s%s）" % [str(data.get("name", equip_id)), slot_labels.get(slot, slot), modifiers_text]
		btn.pressed.connect(_on_equip.bind(slot, equip_id))
		content_panel.add_child(btn)

func _format_modifiers(modifiers: Dictionary) -> String:
	var parts: Array = []
	for key in modifiers:
		parts.append("%s+%d" % [key, int(modifiers[key])])
	return " " + ",".join(parts) if parts.size() > 0 else ""

func _on_equip(slot: String, equip_id: String) -> void:
	if ProgressManager.equip_item(_current_unit(), slot, equip_id):
		_refresh()
		status_label.text = "已装备 %s" % equip_id
	else:
		status_label.text = "装备失败：槽位不匹配"

func _on_unequip(slot: String) -> void:
	if ProgressManager.unequip_item(_current_unit(), slot):
		_refresh()
		status_label.text = "已卸下 %s" % slot
	else:
		status_label.text = "该槽位为空"

func _go_back() -> void:
	ProgressManager.save_roster()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
