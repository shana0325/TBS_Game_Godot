# 回合管理（自走棋·时间驱动）：每个单位有独立的行动计时器。
# tick(delta) 统一推进：达到该单位 turn_interval 时触发其行动，返回该单位，否则返回 null。
# 同一时刻多个单位到点则按顺序逐个返回（由 BattleManager 逐个结算）。
class_name TurnManager
extends RefCounted

const PLAYER_CAMP := "player"
const ENEMY_CAMP := "enemy"

var units: Array = []
var turn_number: int = 1
var battle_time: float = 0.0
var pending: Array = []

func _init(all_units: Array = []) -> void:
	units = all_units

# 每帧推进，返回本次应行动的单位列表（可能为多个）。
func tick(delta: float) -> Array:
	battle_time += delta
	var acted: Array = []
	for unit in units:
		if not (unit is Unit) or not unit.alive:
			continue
		unit.acted = false
		unit.moved = false
		unit.turn_timer += delta
		if unit.turn_timer >= unit.turn_interval:
			unit.turn_timer -= unit.turn_interval
			acted.append(unit)
	return acted

# 初始化所有单位的计时器（行动顺序由速度/随机决定：初始计时器按 turn_interval 随机偏移避免齐射）。
func setup() -> void:
	for unit in units:
		if unit is Unit:
			unit.turn_timer = randf() * unit.turn_interval

func reset_acted() -> void:
	for unit in units:
		if unit is Unit and unit.alive:
			unit.acted = false
			unit.moved = false

func get_turn_label() -> String:
	return "时间 %.1fs  回合 %d" % [battle_time, turn_number]
