# 战斗事件：BattleEvent 是 EventSystem 广播的最小数据对象。
class_name BattleEvent
extends RefCounted

var event_type: String
var source = null
var target = null
var data: Dictionary = {}

func _init(p_event_type: String, p_source = null, p_target = null, p_data: Dictionary = {}) -> void:
	event_type = p_event_type
	source = p_source
	target = p_target
	data = p_data