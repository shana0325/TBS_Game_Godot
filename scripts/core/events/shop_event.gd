# 商店事件：每件商品限购一次，离店前可购买多件。
extends TowerEvent

var offers: Array = []
var purchased: Dictionary = {}

# 固定商店库存，防止多次刷新重抽商品。
func _init(p_floor: int) -> void:
	super(p_floor)
	title = "行商营地"
	description = "金币可购买同伴、指定技能书、升星材料与上阵人口。每件商品限购一次。"
	multiple_purchases = true
	var unit_types: Array = GameDatabase.get_random_pool_unit_ids()
	unit_types.shuffle()
	if not unit_types.is_empty():
		var unit_type := str(unit_types[0])
		offers.append({"id": "unit:%s" % unit_type,
			"label": "招募：%s" % str(GameDatabase.get_unit(unit_type).get("display_name", unit_type)),
			"desc": "新增一名 1 星角色。", "price": ProgressManager.economy_value("shop_recruit_price", 18)})
	var book_ids := GameDatabase.get_searchable_skill_ids(true)
	book_ids.shuffle()
	for skill_id in book_ids.slice(0, 3):
		offers.append({"id": "book:%s" % skill_id,
			"label": "技能书：%s" % str(GameDatabase.get_skill(str(skill_id)).get("name", skill_id)),
			"desc": "购买指定通用技能书 ×1。", "price": ProgressManager.economy_value("shop_book_price", 12)})
	offers.append({"id": "stars", "label": "升星材料 ×2", "desc": "可用于角色升星。",
		"price": ProgressManager.economy_value("shop_star_price", 8)})
	offers.append({"id": "population", "label": "上阵人口 +1", "desc": "永久提高一位上阵人数，上限 6。",
		"price": ProgressManager.economy_value("shop_population_price", 24)})

# 附加金币和容量检查，供商店按钮即时刷新。
func get_options() -> Array:
	var result: Array = []
	for offer in offers:
		var item: Dictionary = offer.duplicate()
		var id := str(item["id"])
		var enabled := not purchased.has(id) and ProgressManager.get_gold() >= int(item["price"])
		if id.begins_with("unit:"):
			enabled = enabled and GameDatabase.get_player_units().size() < ProgressManager.MAX_ROSTER_SIZE
		elif id == "population":
			enabled = enabled and ProgressManager.get_deployment_limit() < ProgressManager.MAX_DEPLOYMENT_LIMIT
		item["enabled"] = enabled
		item["purchased"] = purchased.has(id)
		result.append(item)
	return result

# 按商品种类调用同一组存档事务接口，成功才标记售罄。
func choose(option_id: String) -> bool:
	if purchased.has(option_id):
		return false
	for offer in get_options():
		if str(offer["id"]) != option_id or not bool(offer["enabled"]):
			continue
		var price := int(offer["price"])
		var success := false
		if option_id.begins_with("unit:"):
			success = ProgressManager.recruit_unit(option_id.trim_prefix("unit:"), price)
		elif option_id.begins_with("book:"):
			success = ProgressManager.purchase_supply("skill_book", option_id.trim_prefix("book:"), 1, price)
		elif option_id == "stars":
			success = ProgressManager.purchase_supply("star_items", "", 2, price)
		elif option_id == "population":
			success = ProgressManager.purchase_deployment_limit(price)
		if success:
			purchased[option_id] = true
		return success
	return false
