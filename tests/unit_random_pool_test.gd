# 单位随机池验证：检查招募、商店与普通敌人均排除不可抽取单位。
extends Node

const RECRUIT_EVENT = preload("res://scripts/core/events/recruit_event.gd")
const SHOP_EVENT = preload("res://scripts/core/events/shop_event.gd")

# 加载完成后逐项验证，并通过退出码报告结果。
func _ready() -> void:
	var original_warrior: Dictionary = GameDatabase.get_unit("Warrior").duplicate(true)
	var pool: Array = GameDatabase.get_random_pool_unit_ids()
	var ok := not pool.has("Hero") and pool.has("Warrior") and pool.has("Tank") \
		and pool.has("Archer") and pool.has("Assassin")
	var starter_has_hero := false
	var starter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/player/player_roster.json"))
	for member in starter.get("units", []):
		if str(member.get("type", "")) == "Hero":
			starter_has_hero = true
	ok = ok and starter_has_hero
	var recruit: TowerEvent = RECRUIT_EVENT.new(3)
	var shop: TowerEvent = SHOP_EVENT.new(5)
	for option in recruit.get_options():
		ok = ok and str(option.get("id", "")) != "Hero"
	for option in shop.get_options():
		ok = ok and str(option.get("id", "")) != "unit:Hero"
	for floor in [1, 4, 10, 20, 30]:
		for enemy in TowerGenerator.generate_enemies(floor):
			ok = ok and pool.has(str(enemy.get("type", "")))
	# 临时排除原本会出现在前三层的战士，验证默认配置不会绕过筛选。
	GameDatabase.units["Warrior"]["random_pool_enabled"] = false
	var filtered: Array = GameDatabase.get_random_pool_unit_ids()
	ok = ok and not filtered.has("Warrior")
	for enemy in TowerGenerator.generate_enemies(1):
		ok = ok and str(enemy.get("type", "")) != "Warrior"
	GameDatabase.units["Warrior"] = original_warrior
	# 缺省字段必须可抽取，便于旧版单位数据和新 Mod 直接兼容。
	GameDatabase.units["TestDefault"] = {"display_name": "测试单位"}
	ok = ok and GameDatabase.get_random_pool_unit_ids().has("TestDefault")
	GameDatabase.units.erase("TestDefault")
	if not ok:
		push_error("单位可抽取筛选未覆盖全部随机入口")
	print("单位随机池验证：", "通过" if ok else "失败")
	get_tree().quit(0 if ok else 1)
