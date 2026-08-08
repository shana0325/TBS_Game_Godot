# 事件系统：EventSystem 遍历单位 Buff，把匹配 trigger 的事件交给 Buff 处理。
class_name EventSystem
extends RefCounted

var units: Array = []
var game = null

func _init(p_units: Array = [], p_game = null) -> void:
	units = p_units
	game = p_game

func dispatch(event: BattleEvent) -> void:
	if event == null:
		return
	for unit in units:
		if unit is Unit:
			_process_unit_buffs(unit, event)

func _process_unit_buffs(unit: Unit, event: BattleEvent) -> void:
	for buff in unit.buffs:
		if buff.trigger != "" and buff.trigger == event.event_type:
			buff.on_trigger(unit, event, game)