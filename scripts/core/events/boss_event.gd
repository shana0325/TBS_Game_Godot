# Boss 事件：在指定爬塔层保留普通敌军，并于部署前追加一名对应 Boss。
extends TowerEvent

var boss_type: String = ""

# 从塔层配置读取 Boss，并要求玩家确认迎战后才能继续部署。
func _init(p_floor: int) -> void:
	super(p_floor)
	boss_type = str(GameDatabase.tower_config.get("boss_units", {}).get(str(floor), ""))
	var boss_name := str(GameDatabase.get_unit(boss_type).get("display_name", boss_type))
	title = "强敌来袭 · %s" % boss_name
	description = "本层原有敌军仍会出战，另有一名 %s 加入。" % boss_name
	skippable = false

# Boss 事件只有一次确认选项，不发放额外道具。
func get_options() -> Array:
	return [{"id": "challenge", "label": "迎战 Boss", "desc": "确认后可调整部署。",
		"enabled": not complete and not boss_type.is_empty()}]

# 记录确认状态，沿用普通层的战后奖励。
func choose(option_id: String) -> bool:
	if complete or option_id != "challenge" or boss_type.is_empty():
		return false
	complete = true
	return true

# 将 Boss 追加到未占用的敌方格子，重复应用时不再生成第二名。
func apply_to_scenario(scenario: Dictionary) -> Dictionary:
	if not complete or boss_type.is_empty() or GameDatabase.get_unit(boss_type).is_empty():
		return scenario
	var enemies: Array = scenario.get("enemy_units", []).duplicate(true)
	for enemy in enemies:
		if str(enemy.get("type", "")) == boss_type:
			return scenario
	var occupied: Dictionary = {}
	for enemy in enemies:
		var pos: Variant = enemy.get("pos", [])
		if pos is Vector2i:
			occupied[pos] = true
		elif pos is Array and pos.size() >= 2:
			occupied[Vector2i(int(pos[0]), int(pos[1]))] = true
	var width := int(scenario.get("width", 12))
	var height := int(scenario.get("height", 6))
	for x in range(width - 1, floori(float(width) * 0.5) - 1, -1):
		for offset in range(height):
			var y := (floori(float(height) * 0.5) + offset) % height
			var cell := Vector2i(x, y)
			if occupied.has(cell):
				continue
			enemies.append({"type": boss_type, "pos": [x, y],
				"stat_multiplier": TowerGenerator.floor_stat_multiplier(floor)})
			scenario["enemy_units"] = enemies
			return scenario
	push_warning("第 %d 层敌方区域无空格，无法加入 Boss" % floor)
	return scenario
