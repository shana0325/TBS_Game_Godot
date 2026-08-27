# 爬塔奖励生成：胜利后三选一（通用技能 / 装备 / 祝福 / 遗物），应用结果写入会话或编成。
class_name RewardGenerator
extends RefCounted

const BLESSINGS := [
	{"name": "攻击祝福", "desc": "全体攻击 +10%", "effects": [{"type": "stat_percent", "stat": "attack", "percent": 0.10}]},
	{"name": "生命祝福", "desc": "全体生命 +20%", "effects": [{"type": "stat_percent", "stat": "hp", "percent": 0.20}]},
	{"name": "防御祝福", "desc": "全体防御 +10%", "effects": [{"type": "stat_percent", "stat": "defense", "percent": 0.10}]},
	{"name": "急速祝福", "desc": "全体行动速度 +8%", "effects": [{"type": "turn_speed", "percent": 0.08}]},
]

# 奖励选项数量：布局支持横向滚动，未来可直接改为 4 或 5。
const REWARD_OPTION_COUNT := 3

	# 生成指定数量的互不重复选项。
static func generate_options() -> Array:
	var candidates: Array = []
	# 通用技能（队伍尚未拥有）
	var roster: Array = GameDatabase.player_roster.get("units", [])
	for skill_id in GameDatabase.skills.keys():
		var data: Dictionary = GameDatabase.get_skill(skill_id)
		if not bool(data.get("common", false)):
			continue
		if _party_has_skill(roster, skill_id):
			continue
		candidates.append({"type": "skill", "id": skill_id,
			"label": str(data.get("name", skill_id)), "desc": str(data.get("desc", "通用技能"))})
	# 装备
	for equip_id in GameDatabase.equipments.keys():
		var data: Dictionary = GameDatabase.get_equipment(equip_id)
		candidates.append({"type": "equipment", "id": equip_id,
			"label": str(data.get("name", equip_id)), "desc": "装备（%s）" % str(data.get("slot", ""))})
	# 祝福
	for blessing in BLESSINGS:
		candidates.append({"type": "blessing", "label": str(blessing["name"]),
			"desc": str(blessing["desc"]), "effects": blessing["effects"]})
	# 遗物（本局尚未获得）
	for relic_id in GameDatabase.relics.keys():
		if GameSession.run_relics.has(relic_id):
			continue
		var data: Dictionary = GameDatabase.get_relic(relic_id)
		candidates.append({"type": "relic", "id": relic_id,
			"label": str(data.get("name", relic_id)), "desc": str(data.get("desc", "遗物"))})
	candidates.shuffle()
	return candidates.slice(0, REWARD_OPTION_COUNT)

# 应用选中的奖励。
static func apply_option(option: Dictionary) -> void:
	var roster: Array = GameDatabase.player_roster.get("units", [])
	match str(option.get("type", "")):
		"skill":
			var unit := _first_party_unit(roster)
			if unit != null:
				ProgressManager.grant_skill_free(unit, str(option.get("id", "")))
				ProgressManager.save_roster()
		"equipment":
			var data: Dictionary = GameDatabase.get_equipment(str(option.get("id", "")))
			var slot: String = str(data.get("slot", ""))
			var unit := _unit_with_empty_slot(roster, slot)
			if unit != null:
				ProgressManager.equip_item(unit, slot, str(option.get("id", "")))
				ProgressManager.save_roster()
		"blessing":
			GameSession.run_blessings.append({"name": str(option.get("label", "祝福")), "effects": option.get("effects", [])})
		"relic":
			GameSession.run_relics.append(str(option.get("id", "")))

static func _party_has_skill(roster: Array, skill_id: String) -> bool:
	for unit in roster:
		if unit.get("learned_skills", []).has(skill_id):
			return true
	return false

static func _first_party_unit(roster: Array) -> Dictionary:
	for unit in roster:
		return unit
	return {}

static func _unit_with_empty_slot(roster: Array, slot: String) -> Dictionary:
	for unit in roster:
		if str(unit.get("equipment", {}).get(slot, "")) == "":
			return unit
	return {}

# 当前队伍/本局状态摘要（供奖励界面展示）。
static func run_summary() -> String:
	var lines: Array = []
	if GameSession.run_relics.size() > 0:
		var relic_names: Array = []
		for rid in GameSession.run_relics:
			relic_names.append(str(GameDatabase.get_relic(str(rid)).get("name", rid)))
		lines.append("遗物：%s" % "、".join(relic_names))
	if GameSession.run_blessings.size() > 0:
		var blessing_names: Array = []
		for b in GameSession.run_blessings:
			blessing_names.append(str(b.get("name", "")))
		lines.append("祝福：%s" % "、".join(blessing_names))
	return "\n".join(lines)
