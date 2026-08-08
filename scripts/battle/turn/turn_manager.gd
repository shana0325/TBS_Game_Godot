# 回合管理：TurnManager 管理当前阵营、行动状态和回合切换。
class_name TurnManager
extends RefCounted

const PLAYER_CAMP := "player"
const ENEMY_CAMP := "enemy"

var current_camp: String = PLAYER_CAMP
var units: Array = []
var turn_number: int = 1

func _init(all_units: Array = []) -> void:
	units = all_units

func get_active_units() -> Array:
	var result: Array = []
	for unit in units:
		if unit is Unit and unit.alive and unit.camp == current_camp and not unit.acted:
			result.append(unit)
	return result

func mark_acted(unit: Unit) -> void:
	if unit != null:
		unit.acted = true

func is_turn_over() -> bool:
	return get_active_units().is_empty()

func next_turn() -> void:
	if current_camp == PLAYER_CAMP:
		current_camp = ENEMY_CAMP
	else:
		current_camp = PLAYER_CAMP
		turn_number += 1
	reset_acted()

func reset_acted() -> void:
	for unit in units:
		if unit is Unit and unit.alive:
			unit.acted = false
			unit.moved = false

func get_turn_label() -> String:
	var label := "Player"
	if current_camp == ENEMY_CAMP:
		label = "Enemy"
	return "Turn %d - %s" % [turn_number, label]