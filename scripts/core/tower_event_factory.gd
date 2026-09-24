# 爬塔事件调度：按楼层生成有序事件类型，再实例化招募、补给、商店和探索事件。
class_name TowerEventFactory
extends RefCounted

const RECRUIT_EVENT = preload("res://scripts/core/events/recruit_event.gd")
const SUPPLY_EVENT = preload("res://scripts/core/events/supply_event.gd")
const SHOP_EVENT = preload("res://scripts/core/events/shop_event.gd")
const EXPLORATION_EVENT = preload("res://scripts/core/events/exploration_event.gd")
const BOSS_EVENT = preload("res://scripts/core/events/boss_event.gd")

# 十层为一个循环；floor_events 可在同一层追加事件而不覆盖原商店。
static func kinds_for_floor(floor: int) -> Array:
	var kinds: Array = []
	if floor <= 1:
		return kinds
	match floor % 10:
		3: kinds.append("recruit")
		4: kinds.append("supply")
		5, 0: kinds.append("shop")
		8: kinds.append("exploration")
	var additions: Dictionary = GameDatabase.tower_config.get("floor_events", {})
	var scheduled = additions.get(str(floor), [])
	if scheduled is Array:
		for kind in scheduled:
			if kind is String and not kinds.has(kind):
				kinds.append(kind)
	return kinds

# 实例化对应的代码事件，屏幕无需知道每种事件的具体规则。
static func create_event(kind: String, floor: int) -> TowerEvent:
	match kind:
		"recruit": return RECRUIT_EVENT.new(floor)
		"supply": return SUPPLY_EVENT.new(floor)
		"shop": return SHOP_EVENT.new(floor)
		"exploration": return EXPLORATION_EVENT.new(floor)
		"boss": return BOSS_EVENT.new(floor)
	return null
