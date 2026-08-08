# Buff 效果：BuffEffect 从 buffs.json 创建 Buff 并挂到目标单位。
class_name BuffEffect
extends RefCounted

static func apply(target: Unit, buff_id: String, game = null) -> Buff:
	if target == null:
		return null
	var db = GameDatabase
	if game != null and game.has_method("get_database"):
		db = game.get_database()
	var data: Dictionary = db.get_buff(buff_id)
	if data.is_empty():
		return null
	var buff := Buff.from_data(data)
	target.add_buff(buff)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 获得 %s 效果" % [target.get_display_name(), buff.name])
	return buff