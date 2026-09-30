# 战斗计时器：每个单位分别累计普攻和移动时间，向战斗管理器报告已就绪单位。
# 同一时刻多个单位到点则按顺序逐个返回（由 BattleManager 逐个结算）。
class_name TurnManager
extends RefCounted

const PLAYER_CAMP := "player"
const ENEMY_CAMP := "enemy"

var units: Array = []
var turn_number: int = 1
var battle_time: float = 0.0
var pending: Array = []

# 狂暴阶段：60 秒后开始，每 30 秒使双方最终伤害再增加 50%。
const FRENZY_START_TIME := 60.0
const FRENZY_INTERVAL := 30.0
const FRENZY_STEP_PERCENT := 50.0

func _init(all_units: Array = []) -> void:
	units = all_units

# 每帧推进两种计时器；就绪状态最多保留一次，不积攒连续攻击或移动。
func tick(delta: float) -> Array:
	battle_time += delta
	var ready: Array = []
	for unit in units:
		if not (unit is Unit) or not unit.alive:
			continue
		unit.acted = false
		unit.moved = false
		var attack_interval: float = unit.get_effective_attack_interval()
		unit.attack_timer = minf(unit.attack_timer + delta, attack_interval)
		var move_interval: float = unit.move_interval
		unit.move_timer = minf(unit.move_timer + delta, move_interval)
		if unit.attack_timer >= attack_interval or (unit.get_move_points() > 0 and unit.move_timer >= move_interval):
			ready.append(unit)
	return ready

# 随机错开初次普攻和移动，避免全场单位同时起步。
func setup() -> void:
	for unit in units:
		if unit is Unit:
			var attack_interval: float = unit.get_effective_attack_interval()
			var move_interval: float = unit.move_interval
			unit.attack_timer = randf() * attack_interval if is_finite(attack_interval) else 0.0
			unit.move_timer = randf() * move_interval if is_finite(move_interval) else 0.0

func reset_acted() -> void:
	for unit in units:
		if unit is Unit and unit.alive:
			unit.acted = false
			unit.moved = false

# 顶部标签：自走棋为时间驱动，无"回合"概念，仅显示战斗用时。
func get_turn_label() -> String:
	return "战斗时间 %.1fs" % battle_time

# 当前狂暴阶段的最终伤害增幅百分比；未到 60 秒时为 0。
func get_final_damage_bonus_percent() -> float:
	if battle_time < FRENZY_START_TIME:
		return 0.0
	var stage := floori((battle_time - FRENZY_START_TIME) / FRENZY_INTERVAL) + 1
	return float(stage) * FRENZY_STEP_PERCENT

func get_final_damage_multiplier() -> float:
	return 1.0 + get_final_damage_bonus_percent() / 100.0
