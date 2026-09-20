# 无头战斗冒烟测试：真实实例化 BattleManager 并驱动 tick，
# 验证单位是否会自动行动/移动/攻击，任何异常会带完整回溯打出来。
extends Node

const FRAMES := 900   # 15 秒，60fps
const DELTA := 1.0 / 60.0

func _ready() -> void:
	var ok := run()
	get_tree().quit(0 if ok else 1)

func run() -> bool:
	GameSession.mode = GameSession.MODE_TOWER
	GameSession.tower_floor = 1
	GameSession.run_relics = []
	GameSession.run_blessings = []

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

	return total_actions > 0