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
var selected_skill: String = ""

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
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 200)
	scroll.custom_minimum_size = Vector2(620, 440)
	add_child(scroll)
	content_panel = VBoxContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_constant_override("separation", 10)
	scroll.add_child(content_panel)
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
	var labels := {"attack": "攻击", "defense": "防御", "move": "移动", "hp": "生命"}
	var base_keys := {"attack": "atk", "defense": "defense", "move": "move", "hp": "hp"}
	for stat in ProgressManager.POINTABLE_STATS:
		var base := int(config.get(base_keys[stat], 0))
		var alloc := int(allocated.get(stat, 0))
		var equip := int(equip_mods.get(stat, 0))
		var perm := int(perm_mods.get(stat, 0))
		var total := base + alloc + equip + perm
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(340, 40)
		btn.text = "%s: %d  (基础%d +加点%d +装备%d +永久%d)  [加点]" % [labels[stat], total, base, alloc, equip, perm]
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
	var base_keys := {"attack": "atk", "defense": "defense", "move": "move", "hp": "hp"}
	var result: Dictionary = {}
	for stat in ProgressManager.POINTABLE_STATS:
		result[stat] = int(config.get(base_keys[stat], 0)) \
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

func _on_add_stat(stat: String) -> void:
	if ProgressManager.add_stat_point(_current_unit(), stat):
		_refresh()
		status_label.text = "已为属性 %s +1" % stat
	else:
		status_label.text = "属性点不足"

# --- 技能子页（固有技能锁定区 + 通用技能池，点击技能查看详情） ---
func _build_skills_tab(unit: Dictionary) -> void:
	var config: Dictionary = GameDatabase.get_unit(str(unit.get("type", "Hero")))
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
	# 通用技能池：仅展示 common 标记的技能，点击查看详情与操作
	var learned: Array = unit.get("learned_skills", [])
	var equipped: Array = unit.get("equipped_skills", [])
	for skill_id in GameDatabase.skills.keys():
		var data: Dictionary = GameDatabase.get_skill(skill_id)
		if not bool(data.get("common", false)):
			continue
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
		if selected_skill == skill_id:
			btn.modulate = Color(1.2, 1.2, 0.5)
		btn.pressed.connect(_on_select_skill.bind(skill_id))
		content_panel.add_child(btn)

# 技能详情文本：描述 + 触发时机 + 冷却 +（按需）射程 + 目标 + 效果列表（含持续时间）。
func _skill_detail_text(skill_id: String) -> String:
	var data: Dictionary = GameDatabase.get_skill(skill_id)
	if data.is_empty():
		return "（未知技能）"
	var lines: Array = []
	var desc: String = str(data.get("desc", ""))
	if desc != "":
		lines.append("描述：%s" % desc)
	var trigger: String = str(data.get("trigger", ""))
	var trigger_label: String = str(SKILL_TRIGGER_LABELS.get(trigger, trigger))
	lines.append("触发时机：%s   冷却：%d 次触发间隔" % [trigger_label, int(data.get("cooldown", 0))])
	# 仅目标为位置类（敌人/友军/单体目标）时才显示射程；自身/全体类无关射程
	var condition: Dictionary = data.get("condition", {})
	var target_type: String = str(condition.get("target_type", condition.get("target", "target")))
	if target_type in ["enemy", "ally", "target", "random_enemy"]:
		lines.append("射程：%s 至 %s 格" % [str(data.get("min_range", 1)), str(data.get("max_range", 1))])
	lines.append("目标：%s" % _skill_target_label(condition))
	lines.append("效果：")
	var effects: Array = data.get("effects", [])
	if effects.is_empty():
		if data.get("code_script") is GDScript:
			lines.append("  · （由代码实现的自定义效果，详见描述）")
		else:
			lines.append("  · （无效果）")
	for effect in effects:
		if effect is Dictionary:
			lines.append("  · %s" % _skill_effect_text(effect))
	return "\n".join(lines)

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
