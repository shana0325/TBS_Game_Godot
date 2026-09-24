# 同层事件队列验证：检查商店与追加事件顺序、对象状态和场景改写钩子。
extends Node

const FAKE_BOSS_EVENT = preload("res://tests/fake_boss_event.gd")

# 执行调度与事件队列验证，并报告进程退出码。
func _ready() -> void:
	var previous_events = GameDatabase.tower_config.get("floor_events", {}).duplicate(true)
	GameDatabase.tower_config["floor_events"] = {"10": ["supply"], "20": ["recruit"]}
	var ok := TowerEventFactory.kinds_for_floor(10) == ["shop", "supply"] \
		and TowerEventFactory.kinds_for_floor(20) == ["shop", "recruit"] \
		and TowerEventFactory.kinds_for_floor(1).is_empty()
	GameSession.tower_floor = 10
	GameSession.tower_scenario = TowerGenerator.generate_scenario(10)
	var original_enemy_count: int = GameSession.tower_scenario["enemy_units"].size()
	GameSession.prepare_tower_events()
	ok = ok and GameSession.pending_tower_events.size() == 2
	var first := GameSession.get_pending_tower_event()
	ok = ok and first != null and first.title == "行商营地"
	var shop_screen: Control = (load("res://scenes/tower_event_screen.tscn") as PackedScene).instantiate() as Control
	add_child(shop_screen)
	ok = ok and shop_screen.get("tower_event") == first \
		and (shop_screen.get("continue_button") as Button).text == "下一个事件"
	shop_screen.queue_free()
	if first != null:
		first.complete = true
	ok = ok and GameSession.get_pending_tower_event() == first \
		and GameSession.get_pending_tower_event().complete
	GameSession.finish_tower_event()
	var second := GameSession.get_pending_tower_event()
	ok = ok and second != null and second.title == "旅途补给"
	GameSession.finish_tower_event()
	ok = ok and GameSession.get_pending_tower_event() == null
	# 未来 Boss 事件可阻止跳过，并在事件出队时追加 Boss，保留该层原有敌军。
	var boss: TowerEvent = FAKE_BOSS_EVENT.new(10)
	ok = ok and not boss.can_continue()
	GameSession.pending_tower_events.append(boss)
	var boss_screen: Control = (load("res://scenes/tower_event_screen.tscn") as PackedScene).instantiate() as Control
	add_child(boss_screen)
	ok = ok and (boss_screen.get("continue_button") as Button).disabled
	boss.complete = true
	ok = ok and boss.can_continue()
	boss_screen.call("_refresh_options")
	ok = ok and not (boss_screen.get("continue_button") as Button).disabled
	boss_screen.queue_free()
	GameSession.finish_tower_event()
	ok = ok and GameSession.tower_scenario.get("test_boss_floor") == 10 \
		and GameSession.scenario_override.get("test_boss_floor") == 10 \
		and GameSession.tower_scenario["enemy_units"].size() == original_enemy_count + 1 \
		and is_equal_approx(float(GameSession.tower_scenario["enemy_units"].back()["stat_multiplier"]),
			pow(GameDatabase.get_enemy_growth_rate(), 9))
	GameDatabase.tower_config["floor_events"] = previous_events
	GameSession.pending_tower_events.clear()
	if not ok:
		push_error("同层事件队列未按顺序保留状态或改写场景")
	print("同层事件队列验证：", "通过" if ok else "失败")
	get_tree().quit(0 if ok else 1)
