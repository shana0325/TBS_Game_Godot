# 无头战斗冒烟测试：真实实例化 BattleManager 并驱动 tick，
# 验证单位是否会自动行动/移动/攻击，任何异常会带完整回溯打出来。
extends Node

const FRAMES := 900   # 15 秒，60fps
const DELTA := 1.0 / 60.0

func _ready() -> void:
	var ok := run()
	get_tree().quit(0 if ok else 1)

func run() -> bool:
	var pathfinding_ok := _verify_pathfinding()
	var run_bonus_ok := _verify_repeatable_relics_and_shields()
	GameSession.mode = GameSession.MODE_TOWER
	GameSession.tower_floor = 1
	GameSession.run_relics = []
	GameSession.run_relic_stacks = {}

	# 敌方走 scenario 通道；玩家走 deployed 通道（允许 roster_index=-1 按模板生成，避免空阵营判负）
	var scenario := {
		"width": 10, "height": 8,
		"enemy_units": [{"type": "Warrior", "pos": [6, 4], "name": "E1"}],
	}
	var battle := BattleManager.new("smoke", self, [
		{"type": "Warrior", "pos": Vector2i(1, 1), "name": "P1", "roster_index": -1},
	], scenario)
	battle.setup()
	# 加速测试：把行动间隔压小，单位应能频繁行动
	for u in battle.units:
		u.turn_interval = 0.3
		u.turn_timer = 0.3

	var total_actions := 0
	var moved_frames := 0
	var last_positions: Dictionary = {}
	for i in FRAMES:
		var events: Array = battle.tick(DELTA)
		total_actions += events.size()
		for e in events:
			var unit := e.get("unit") as Unit
			if unit == null:
				continue
			var from := Vector2i.ZERO
			var to := Vector2i.ZERO
			var f = e.get("from")
			var t = e.get("to")
			if f is Vector2i:
				from = f as Vector2i
			if t is Vector2i:
				to = t as Vector2i
			var dmg: int = e.get("damage", 0)
			print("  [%.1fs] %s %s %s -> %s dmg=%d hp=%d/%d" % [
				battle.get_battle_time(), unit.get_display_name(), e.get("action"),
				from, to, dmg, unit.hp, unit.max_hp])
			# 攻击行动无目标位置（to 为空），仅真实的移动/移动攻击才计入移动数
			if from != to and to != Vector2i.ZERO:
				moved_frames += 1
		if battle.winner != "":
			break

	print("RESULT battle_time=%.1fs total_actions=%d moved_actions=%d winner=%s" % [
		battle.get_battle_time(), total_actions, moved_frames, battle.winner])
	for u in battle.units:
		print("  unit=%s camp=%s hp=%d/%d pos=%s alive=%s" % [
			u.get_display_name(), u.camp, u.hp, u.max_hp, u.pos, u.alive])

	return total_actions > 0 and pathfinding_ok and run_bonus_ok

# 验证可重复遗物按层叠加、部署预览使用完整加成，以及护盾总量上限与独立持续时间。
func _verify_repeatable_relics_and_shields() -> bool:
	var old_relics := GameSession.run_relics.duplicate()
	var old_stacks := GameSession.run_relic_stacks.duplicate(true)
	GameSession.run_relics = []
	GameSession.run_relic_stacks = {}
	if not GameSession.add_run_relic("power_blessing") or not GameSession.add_run_relic("power_blessing"):
		push_error("可重复遗物无法连续获得")
		return false
	if GameSession.run_relics.count("power_blessing") != 1 or GameSession.get_relic_stack("power_blessing") != 2:
		push_error("可重复遗物没有使用唯一 ID 与独立层数存储")
		return false
	GameSession.add_run_relic("guard_blessing")
	GameSession.add_run_relic("vitality_blessing")
	GameSession.add_run_relic("coup_grace")
	if GameSession.add_run_relic("coup_grace"):
		push_error("不可重复遗物被重复获得")
		return false
	var preview := Unit.create_from_config("Preview", TurnManager.PLAYER_CAMP, Vector2i.ZERO,
		{"display_name": "Preview", "hp": 100, "atk": 100, "defense": 10})
	RelicSystem.apply_run_bonuses_to_unit(preview)
	if preview.get_attack() != 120 or preview.get_defense() != 11 or preview.max_hp != 120:
		push_error("部署预览没有应用完整数值遗物：生命=%d 攻击=%d 防御=%d" % [preview.max_hp, preview.get_attack(), preview.get_defense()])
		return false
	preview.max_hp = 100
	preview.hp = 100
	var first := preview.gain_shield(80, "永久盾")
	var second := preview.gain_shield(50, "限时盾", 2, false)
	if first != 80 or second != 20 or preview.get_total_shield() != 100 or preview.buffs.size() != 2:
		push_error("护盾没有按最大生命封顶并独立保存：first=%d second=%d total=%d" % [first, second, preview.get_total_shield()])
		return false
	preview.tick_turn_end()
	if preview.buffs.size() != 2:
		push_error("限时护盾过早消失")
		return false
	preview.tick_turn_end()
	if preview.buffs.size() != 1 or preview.get_total_shield() != 80:
		push_error("限时护盾没有按自身持续时间独立消失")
		return false
	var unlimited := Skill.new()
	unlimited.unlimited_shield = true
	preview.skills.append(unlimited)
	var unlimited_gain := preview.gain_shield(150, "无上限盾")
	if preview.get_shield_cap() != -1 or unlimited_gain != 150 or preview.get_total_shield() != 230:
		push_error("技能提供的无上限护盾规则没有生效")
		return false
	GameSession.run_relics = old_relics
	GameSession.run_relic_stacks = old_stacks
	return true

# 验证单位阻挡不可穿越、可绕行，并优先选择总移动消耗更低的路径。
func _verify_pathfinding() -> bool:
	var grid := Grid.new(5, 3)
	var start := grid.get_tile(0, 1)
	var goal := grid.get_tile(2, 1)
	var blocked := {Vector2i(1, 1): true}
	var reachable := Pathfinder.get_reachable_tiles(grid, start, 2, blocked)
	if reachable.has(goal):
		push_error("寻路错误：单位穿过阻挡格抵达其后方")
		return false
	var detour := Pathfinder.find_path(grid, start, goal, blocked)
	if detour.size() != 5:
		push_error("寻路错误：未找到预期的四步绕行路径，节点数=%d" % detour.size())
		return false
	for tile in detour:
		if tile.get_position() == Vector2i(1, 1):
			push_error("寻路错误：绕行路径仍经过阻挡格")
			return false

	var weighted_grid := Grid.new(4, 3)
	weighted_grid.set_terrain(Vector2i(1, 1), 5)
	var weighted_path := Pathfinder.find_path(weighted_grid,
		weighted_grid.get_tile(0, 1), weighted_grid.get_tile(2, 1))
	if weighted_path.size() != 5:
		push_error("寻路错误：没有避开高消耗地形")
		return false
	return true
