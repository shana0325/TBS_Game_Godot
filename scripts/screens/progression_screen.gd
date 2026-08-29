# 成长界面：两段式——先选角色，再在 属性/技能/装备 三个子页中成长，修改写回 player_roster.json。
extends Control

const COMBAT_FORMULA = preload("res://scripts/core/combat_formula.gd")
const SKILL_DETAIL_FORMATTER = preload("res://scripts/ui/skill_detail_formatter.gd")

enum Tab { STATS, SKILLS, EQUIP }

var roster: Array = []
var selected_index: int = 0
var current_tab: int = Tab.STATS

var role_buttons: Array = []
var tab_buttons: Array = []
var role_scroll: ScrollContainer
var role_box: HBoxContainer
var tab_bar: HBoxContainer
var content_scroll: ScrollContainer
var content_panel: VBoxContainer
var overview_panel: PanelContainer
var overview_scroll: ScrollContainer
var overview_box: VBoxContainer
var overview_label: Label
var overview_portrait: TextureRect
var status_label: Label
var start_button: Button
var selected_skill: String = ""
var selected_skill_tag: String = ""

# 触发时机中文标签（与 skill_trigger_system.gd 的常量对应）
const SKILL_TRIGGER_LABELS := {
	"on_battle_start": "战斗开始时", "on_turn_start": "行动开始时", "on_attack_start": "攻击前",
	"on_attack": "攻击时", "on_attack_end": "攻击结束后", "on_hit": "造成伤害后",
	"on_be_attacked": "受到攻击后", "on_taken_damage": "受到伤害后", "on_kill": "击杀敌人后",
	"on_death": "阵亡时", "on_ally_death": "友军阵亡时", "on_turn_end": "行动结束时",
	"on_round_start": "首回合开始时", "passive": "常驻被动",
}
const SKILL_STAT_LABELS := {"hp": "生命", "attack": "攻击", "defense": "防御", "move": "移动"}

func _ready() -> void:
	roster = GameDatabase.player_roster.get("units", [])
	_build_top_bar()
	_build_tab_bar()
	content_scroll = ScrollContainer.new()
	content_scroll.name = "ContentScroll"
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(content_scroll)
	content_panel = VBoxContainer.new()
	content_panel.name = "ContentPanel"
	content_panel.custom_minimum_size = Vector2(580, 0)
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_constant_override("separation", 10)
	content_scroll.add_child(content_panel)
	_build_overview_panel()
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	add_child(status_label)
	_layout_screen()
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_screen()

# 响应窗口尺寸变化：左右内容独立滚动，顶部按钮用容器排布避免互相覆盖。
func _layout_screen() -> void:
	var vp := get_viewport_rect().size
	var right_x := minf(maxf(650.0, vp.x * 0.58), maxf(650.0, vp.x - 360.0))
	if start_button != null:
		start_button.position = Vector2(maxf(60.0, vp.x - 280.0), 70.0)
	if role_scroll != null:
		role_scroll.position = Vector2(60.0, 120.0)
		role_scroll.size = Vector2(maxf(360.0, vp.x - 120.0), 42.0)
	if tab_bar != null:
		tab_bar.position = Vector2(60.0, 174.0)
		tab_bar.size = Vector2(minf(440.0, maxf(360.0, vp.x - 120.0)), 42.0)
	if content_scroll != null:
		content_scroll.position = Vector2(60.0, 226.0)
		content_scroll.size = Vector2(maxf(360.0, right_x - 90.0), maxf(260.0, vp.y - 286.0))
		content_panel.custom_minimum_size.x = maxf(340.0, content_scroll.size.x - 18.0)
	if overview_panel != null:
		overview_panel.position = Vector2(right_x, 170.0)
		overview_panel.size = Vector2(maxf(300.0, vp.x - right_x - 40.0), maxf(300.0, vp.y - 210.0))
	if status_label != null:
		status_label.position = Vector2(60.0, maxf(0.0, vp.y - 48.0))

# 右侧角色总览面板：展示装备/加点后的整体属性与已装备技能。
func _build_overview_panel() -> void:
	overview_panel = PanelContainer.new()
	overview_panel.name = "OverviewPanel"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	overview_scroll = ScrollContainer.new()
	overview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	overview_box = VBoxContainer.new()
	overview_box.add_theme_constant_override("separation", 10)
	overview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_portrait = TextureRect.new()
	overview_portrait.custom_minimum_size = Vector2(0, 180)
	overview_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overview_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overview_box.add_child(overview_portrait)
	overview_label = Label.new()
	overview_label.add_theme_font_size_override("font_size", 20)
	overview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_box.add_child(overview_label)
	overview_scroll.add_child(overview_box)
	margin.add_child(overview_scroll)
	overview_panel.add_child(margin)
	add_child(overview_panel)

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

	start_button = Button.new()
	start_button.name = "StartGameButton"
	start_button.text = "保存并开始游戏"
	start_button.custom_minimum_size = Vector2(220, 44)
	start_button.pressed.connect(_start_game)
	add_child(start_button)

	# 角色选择按钮：放进横向滚动容器，角色数量增加时不会挤压标签页。
	role_scroll = ScrollContainer.new()
	role_scroll.name = "RoleScroll"
	role_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	role_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	role_box = HBoxContainer.new()
	role_box.add_theme_constant_override("separation", 12)
	role_scroll.add_child(role_box)
	add_child(role_scroll)
	for i in roster.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 42)
		btn.text = "%d. %s" % [i + 1, str(roster[i].get("type", "Unit"))]
		btn.pressed.connect(_on_role_selected.bind(i))
		role_box.add_child(btn)
		role_buttons.append(btn)

func _build_tab_bar() -> void:
	tab_bar = HBoxContainer.new()
	tab_bar.name = "TabBar"
	tab_bar.add_theme_constant_override("separation", 12)
	add_child(tab_bar)
	for t in [Tab.STATS, Tab.SKILLS, Tab.EQUIP]:
		var btn := Button.new()
		btn.text = ["属性", "技能", "装备"][t]
		btn.custom_minimum_size = Vector2(126, 40)
		btn.pressed.connect(_on_tab_selected.bind(t))
		tab_bar.add_child(btn)
		tab_buttons.append(btn)

func _on_role_selected(index: int) -> void:
	selected_index = index
	selected_skill = ""
	selected_skill_tag = ""
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
	var star := clampi(int(unit.get("star", 1)), 1, ProgressManager.MAX_STARS)
	var skill_slots := ProgressManager.get_skill_slot_limit(star)
	info.text = "%d星  等级 %d  经验 %d/%d  属性点 %d  技能点 %d  通用技能槽 %d/%d  升星道具 %d" % [
		star,
		int(unit.get("level", 1)), int(unit.get("exp", 0)),
		ProgressManager.required_exp_for_level(int(unit.get("level", 1))),
		int(unit.get("stat_points", 0)), int(unit.get("skill_points", 0)),
		unit.get("equipped_skills", []).size(), skill_slots,
		ProgressManager.get_star_item_count()
	]
	info.add_theme_font_size_override("font_size", 20)
	content_panel.add_child(info)
	var ascend_button := Button.new()
	var ascend_cost := ProgressManager.get_ascension_cost(star)
	ascend_button.text = "升星（消耗 %d 个升星道具）" % ascend_cost
	ascend_button.custom_minimum_size = Vector2(320, 40)
	ascend_button.disabled = star >= ProgressManager.MAX_STARS \
		or ProgressManager.get_star_item_count() < ascend_cost
	ascend_button.pressed.connect(_on_ascend_pressed)
	content_panel.add_child(ascend_button)
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
	var config: Dictionary = GameDatabase.get_unit(str(unit.get("type", "Hero")))
	var tags: Array = config.get("tags", [])
	var tags_text := "、".join(tags) if not tags.is_empty() else "无"
	var star := clampi(int(unit.get("star", 1)), 1, ProgressManager.MAX_STARS)
	lines.append("%s  %d星  Lv.%d" % [str(unit.get("type", "Unit")), star, int(unit.get("level", 1))])
	lines.append("标签：%s" % tags_text)
	lines.append("通用技能槽：%d/%d" % [unit.get("equipped_skills", []).size(), ProgressManager.get_skill_slot_limit(star)])
	lines.append("HP: %d" % int(total.get("hp", 0)))
	var total_armor := int(total.get("defense", 0))
	lines.append("攻击: %d   护甲: %d（%.1f%%减伤）   移动: %d" % [
		int(total.get("attack", 0)), total_armor, COMBAT_FORMULA.armor_reduction_percent(total_armor), int(total.get("move", 0))
	])
	lines.append("暴击率: %d%%   暴击伤害: %d%%" % [
		int(total.get("crit_rate", 0)), int(total.get("crit_damage", 0))
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
	var perm_mods: Dictionary = unit.get("permanent_mods", {})
	if not perm_mods.is_empty():
		lines.append("")
		lines.append("永久强化:")
		var stat_labels := {"hp": "生命上限", "attack": "攻击", "defense": "防御", "move": "移动"}
		for stat in perm_mods:
			lines.append("  %s +%d" % [str(stat_labels.get(stat, stat)), int(perm_mods[stat])])
	overview_label.text = "\n".join(lines)

# --- 属性子页 ---
func _build_stats_tab(unit: Dictionary) -> void:
	var config: Dictionary = GameDatabase.get_unit(str(unit.get("type", "Hero")))
	var allocated: Dictionary = unit.get("allocated_stats", {})
	var equip_mods := _get_equip_modifiers(unit)
	var perm_mods: Dictionary = unit.get("permanent_mods", {})
	var labels := {"attack": "攻击", "defense": "护甲", "move": "移动", "hp": "生命",
		"crit_rate": "暴击率", "crit_damage": "暴击伤害"}
	for stat in ProgressManager.POINTABLE_STATS:
		var base := Unit.get_scaled_base_stat(config, stat, int(unit.get("star", 1)))
		var alloc := int(allocated.get(stat, 0))
		var equip := int(equip_mods.get(stat, 0))
		var perm := int(perm_mods.get(stat, 0))
		var total := base + alloc + equip + perm
		var unit_text := "%d%%" % total if stat == "crit_rate" or stat == "crit_damage" else ("%d（%.1f%%减伤）" % [total, COMBAT_FORMULA.armor_reduction_percent(total)] if stat == "defense" else str(total))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(340, 40)
		btn.text = "%s: %s  (基础%d +加点%d +装备%d +永久%d)  [加点]" % [labels[stat], unit_text, base, alloc, equip, perm]
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

# 计算角色整体属性（基础+加点+装备+永久强化）。
func _get_total_stats(unit: Dictionary) -> Dictionary:
	var config: Dictionary = GameDatabase.get_unit(str(unit.get("type", "Hero")))
	var allocated: Dictionary = unit.get("allocated_stats", {})
	var equip_mods := _get_equip_modifiers(unit)
	var perm_mods: Dictionary = unit.get("permanent_mods", {})
	var result: Dictionary = {}
	for stat in ProgressManager.POINTABLE_STATS:
		result[stat] = Unit.get_scaled_base_stat(config, stat, int(unit.get("star", 1))) \
			+ int(allocated.get(stat, 0)) + int(equip_mods.get(stat, 0)) \
			+ int(perm_mods.get(stat, 0))
	return result

# 收集角色实际带进战斗的技能名（固有 + 已装备 + 装备授予；已学未装备的不生效）。
func _get_all_skill_names(unit: Dictionary) -> Array:
	var names: Array = []
	var config: Dictionary = GameDatabase.get_unit(str(unit.get("type", "Hero")))
	var innate_id: String = str(config.get("innate_skill", ""))
	if innate_id != "":
		var innate_data: Dictionary = GameDatabase.get_skill(innate_id)
		names.append(str(innate_data.get("name", innate_id)))
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

func _on_ascend_pressed() -> void:
	if ProgressManager.ascend_unit(_current_unit()):
		selected_skill = ""
		status_label.text = "升星成功"
		_refresh()
	else:
		status_label.text = "升星失败：需要升星道具且不能超过最高星级"

func _on_add_stat(stat: String) -> void:
	if ProgressManager.add_stat_point(_current_unit(), stat):
		_refresh()
		status_label.text = "已为属性 %s +1" % stat
	else:
		status_label.text = "属性点不足"

# --- 技能子页（固有技能锁定区 + 通用技能池，点击技能查看详情） ---
func _build_skills_tab(unit: Dictionary) -> void:
	var config: Dictionary = GameDatabase.get_unit(str(unit.get("type", "Hero")))
	var list_title := Label.new()
	list_title.text = "技能列表（点击技能查看详情）"
	list_title.add_theme_font_size_override("font_size", 18)
	content_panel.add_child(list_title)
	var tag_filter_box := HBoxContainer.new()
	tag_filter_box.add_theme_constant_override("separation", 6)
	var tag_label := Label.new()
	tag_label.text = "标签筛选："
	tag_filter_box.add_child(tag_label)
	var all_tag_button := Button.new()
	all_tag_button.text = "全部"
	all_tag_button.pressed.connect(_on_skill_tag_filter.bind(""))
	tag_filter_box.add_child(all_tag_button)
	for tag in _get_skill_filter_tags():
		var tag_button := Button.new()
		tag_button.text = str(tag)
		tag_button.pressed.connect(_on_skill_tag_filter.bind(str(tag)))
		tag_filter_box.add_child(tag_button)
	content_panel.add_child(tag_filter_box)
	# 固有技能：模板独有，自动生效，不可更换
	var innate_id: String = str(config.get("innate_skill", ""))
	if innate_id == "":
		var none := Label.new()
		none.text = "固有技能：（无）"
		none.add_theme_font_size_override("font_size", 16)
		content_panel.add_child(none)
	else:
		var innate_data: Dictionary = GameDatabase.get_skill(innate_id)
		var info := Label.new()
		info.text = "固有技能（始终生效，不可更换）：%s\n%s" % [
			str(innate_data.get("name", innate_id)), _skill_detail_text(innate_id)
		]
		info.modulate = Color(1.5, 1.25, 0.5)
		info.add_theme_font_size_override("font_size", 14)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(560, 0)
		content_panel.add_child(info)
	# 已选中的通用技能：详情 + 操作（放在列表上方，保证可见）
	if selected_skill != "" and GameDatabase.get_skill(selected_skill).has("common"):
		var detail := Label.new()
		detail.text = _skill_detail_text(selected_skill)
		detail.add_theme_font_size_override("font_size", 14)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(560, 0)
		content_panel.add_child(detail)
		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(280, 40)
		action_btn.text = _skill_action_label(selected_skill, unit)
		action_btn.pressed.connect(_on_selected_skill_action)
		content_panel.add_child(action_btn)
	# 技能池：常规检索只展示可检索的通用技能；已通过指定手段获得的隐藏技能仍保留在角色列表中。
	var learned: Array = unit.get("learned_skills", [])
	var equipped: Array = unit.get("equipped_skills", [])
	var skill_ids: Array = GameDatabase.get_searchable_skill_ids(true, [selected_skill_tag] if selected_skill_tag != "" else [])
	for owned_id in learned + equipped:
		var owned_data: Dictionary = GameDatabase.get_skill(str(owned_id))
		var owned_tags: Array = owned_data.get("tags", [])
		var tag_matches := selected_skill_tag == "" or owned_tags.has(selected_skill_tag)
		if bool(owned_data.get("common", false)) and tag_matches and not skill_ids.has(str(owned_id)):
			skill_ids.append(str(owned_id))
	if skill_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "暂无技能数据（请检查 data/skill/skills.json）"
		empty_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5, 1.0))
		content_panel.add_child(empty_label)
	for skill_id in skill_ids:
		var data: Dictionary = GameDatabase.get_skill(skill_id)
		var status := ""
		var is_innate := str(skill_id) == innate_id
		var is_common := bool(data.get("common", false))
		if not is_innate and not is_common:
			continue
		# 当前角色的固有技能在上方已经有详细说明，这里不重复加入可检索列表。
		if is_innate:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		if equipped.has(skill_id):
			status = "  已装备"
		else:
			status = "  未装备"
		btn.text = "%s%s" % [str(data.get("name", skill_id)), status]
		if selected_skill == skill_id:
			btn.modulate = Color(1.2, 1.2, 0.5)
		btn.pressed.connect(_on_select_skill.bind(skill_id))
		content_panel.add_child(btn)

func _get_skill_filter_tags() -> Array:
	var result: Array = []
	for skill_id in GameDatabase.get_searchable_skill_ids(true):
		var data: Dictionary = GameDatabase.get_skill(skill_id)
		for tag in data.get("tags", []):
			if not result.has(tag):
				result.append(tag)
	return result

func _on_skill_tag_filter(tag: String) -> void:
	selected_skill_tag = tag
	selected_skill = ""
	_refresh()

# 技能详情文本：描述 + 触发时机 + 冷却 +（按需）射程 + 目标 + 效果列表（含持续时间）。
func _skill_detail_text(skill_id: String) -> String:
	return SKILL_DETAIL_FORMATTER.build(skill_id)

# 目标解析中文说明。
func _skill_target_label(condition: Dictionary) -> String:
	var target_type: String = str(condition.get("target_type", condition.get("target", "target")))
	var labels := {"self": "自身", "target": "当前目标", "enemy": "射程内敌人", "ally": "射程内友军",
		"all_enemies": "全体敌人", "all_allies": "全体友军", "random_enemy": "随机敌人"}
	var text: String = str(labels.get(target_type, target_type))
	if condition.has("hp_percent"):
		text += "（附加自身生命比例条件）"
	if condition.has("has_buff"):
		text += "（附加持有指定Buff条件）"
	if condition.has("target_has_buff"):
		text += "（附加目标持有指定Buff条件）"
	return text

# 单条效果的中文描述。
func _skill_effect_text(effect: Dictionary) -> String:
	var etype: String = str(effect.get("type", ""))
	var text := ""
	match etype:
		"damage":
			text = "造成 %.1f 倍攻击伤害" % float(effect.get("power", 1.0))
			if bool(effect.get("ignore_defense", false)):
				text += "（无视防御）"
		"heal":
			text = "恢复 %d 点生命" % int(effect.get("amount", 0))
		"shield":
			text = "获得 %d 点护罩%s" % [int(effect.get("amount", 0)), _duration_text(int(effect.get("duration", 0)))]
		"buff":
			var buff_id: String = str(effect.get("buff", ""))
			var bdata: Dictionary = GameDatabase.get_buff(buff_id)
			var bname: String = str(bdata.get("name", buff_id))
			var bdur: int = int(bdata.get("duration", 0))
			text = "附加状态「%s」%s" % [bname, _duration_text(bdur)]
			if int(bdata.get("tick_damage", 0)) > 0:
				text += "（每回合 %d 点持续伤害）" % int(bdata.get("tick_damage", 0))
			if int(bdata.get("tick_heal", 0)) > 0:
				text += "（每回合恢复 %d 点）" % int(bdata.get("tick_heal", 0))
		"stat_mod":
			var parts: Array = []
			for k in effect.get("stats", {}):
				var v: int = int(effect["stats"][k])
				parts.append("%s%s%d" % [str(SKILL_STAT_LABELS.get(k, k)), "+" if v >= 0 else "", v])
			text = "属性变化：%s%s" % ["、".join(parts), _duration_text(int(effect.get("duration", 0)))]
		"dot":
			text = "持续伤害 %d 点%s" % [int(effect.get("damage", 0)), _duration_text(int(effect.get("duration", 0)))]
		"summon":
			text = "召唤「%s」%s" % [str(effect.get("unit_type", "？")), _duration_text(int(effect.get("duration", 0)))]
		"revive":
			text = "复活目标（恢复 %d%% 生命上限）" % roundi(float(effect.get("hp_percent", 0.5)) * 100.0)
		"dispel":
			var friendly: String = "（仅驱散目标身上不利效果）" if not bool(effect.get("friendly", false)) else "（仅驱散有利效果）"
			text = "驱散目标效果%s" % friendly
		"permanent_stat":
			var pstat: String = str(effect.get("stat", "hp"))
			text = "永久提升%s %d（%s）" % [
				str(SKILL_STAT_LABELS.get(pstat, pstat)), int(effect.get("amount", 1)),
				"全局永久" if bool(effect.get("persist", false)) else "本局永久"
			]
		"teleport":
			text = "位移（%s）" % str(effect.get("mode", "target"))
		"taunt":
			text = "挑衅（持续期间敌人只能攻击自己）%s" % _duration_text(int(effect.get("duration", 0)))
		"immunity":
			text = "免疫指定状态%s" % _duration_text(int(effect.get("duration", 0)))
		"reflect":
			text = "反射 %.0f%% 受到的伤害%s" % [float(effect.get("percent", 0.3)) * 100.0, _duration_text(int(effect.get("duration", 0)))]
		"protect":
			text = "受到伤害减少 %.0f%%%s" % [float(effect.get("reduction", 0.3)) * 100.0, _duration_text(int(effect.get("duration", 0)))]
		"ignore":
			text = "攻击无视目标防御/护罩%s" % _duration_text(int(effect.get("duration", 0)))
		"mark":
			text = "标记目标（供其他技能作条件）%s" % _duration_text(int(effect.get("duration", 0)))
		"lifesteal":
			text = "吸血：造成伤害时恢复 %.0f%%%s" % [float(effect.get("percent", 0.3)) * 100.0, _duration_text(int(effect.get("duration", 0)))]
		"percentage_damage":
			text = "造成目标生命上限 %.0f%% 的伤害" % (float(effect.get("percent", 0.1)) * 100.0)
		"chain_damage":
			text = "连锁伤害：%.1f 倍，最多连锁 %d 次" % [float(effect.get("power", 1.0)), int(effect.get("chain", 2))]
		_:
			text = "类型：%s" % etype
	return text

# 持续时间文字：>0 显示回合数，<0 常驻，否则空。
func _duration_text(dur: int) -> String:
	if dur < 0:
		return "（常驻）"
	if dur > 0:
		return "（持续 %d 回合）" % dur
	return ""

# 当前选中技能的下一步操作按钮文字。
func _skill_action_label(skill_id: String, unit: Dictionary) -> String:
	var learned: Array = unit.get("learned_skills", [])
	var equipped: Array = unit.get("equipped_skills", [])
	if equipped.has(skill_id):
		return "卸下技能"
	if learned.has(skill_id):
		return "装备技能"
	return "学习并装备（消耗 1 技能点）"

# 点击技能行：选中并展开详情。
func _on_select_skill(skill_id: String) -> void:
	selected_skill = skill_id
	_refresh()

# 对当前选中的技能执行 学习/装备/卸下。
func _on_selected_skill_action() -> void:
	var skill_id := selected_skill
	if skill_id == "":
		return
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

func _start_game() -> void:
	ProgressManager.save_roster()
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
