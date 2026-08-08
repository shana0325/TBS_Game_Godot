# 装备：Equipment 保存槽位、属性修正和授予技能，由 equipments.json 创建。
class_name Equipment
extends RefCounted

var id: String
var name: String
var slot: String
var modifiers: Dictionary = {}
var granted_skills: Array = []

static func from_data(equipment_id: String, data: Dictionary) -> Equipment:
	var equipment := Equipment.new()
	equipment.id = equipment_id
	equipment.name = str(data.get("name", equipment_id))
	equipment.slot = str(data.get("slot", ""))
	equipment.modifiers = data.get("modifiers", {})
	equipment.granted_skills = data.get("granted_skills", [])
	return equipment