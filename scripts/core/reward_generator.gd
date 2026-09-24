# 爬塔奖励生成：每层自动发放技能书与金币，遗物单独三选一。
class_name RewardGenerator
extends RefCounted

# 奖励选项数量：布局支持横向滚动，未来可直接改为 4 或 5。
const REWARD_OPTION_COUNT := 3

# 生成指定数量的互不重复遗物选项。
static func generate_options() -> Array:
	var candidates: Array = []
	# 普通遗物仅出现一次；可重复遗物在达到层数上限前都可再次出现。
	for relic_id in GameDatabase.relics.keys():
		var data: Dictionary = GameDatabase.get_relic(relic_id)
		var current_stack := GameSession.get_relic_stack(str(relic_id))
		var repeatable := bool(data.get("repeatable", false))
		var max_stacks := int(data.get("max_stacks", 0))
		if current_stack > 0 and (not repeatable or (max_stacks > 0 and current_stack >= max_stacks)):
			continue
		candidates.append({"type": "relic", "id": relic_id,
			"label": str(data.get("name", relic_id)), "desc": str(data.get("desc", "遗物"))})
	candidates.shuffle()
	return candidates.slice(0, REWARD_OPTION_COUNT)

# 应用遗物选项；失败时奖励页不应推进楼层。
static func apply_option(option: Dictionary) -> bool:
	return str(option.get("type", "")) == "relic" and GameSession.add_run_relic(str(option.get("id", "")))

# 当前队伍/本局状态摘要（供奖励界面展示）。
static func run_summary() -> String:
	var lines: Array = []
	if GameSession.run_relics.size() > 0:
		var relic_names: Array = []
		for rid in GameSession.run_relics:
			var name := str(GameDatabase.get_relic(str(rid)).get("name", rid))
			var stacks := GameSession.get_relic_stack(str(rid))
			relic_names.append("%s ×%d" % [name, stacks] if stacks > 1 else name)
		lines.append("遗物：%s" % "、".join(relic_names))
	return "\n".join(lines)
