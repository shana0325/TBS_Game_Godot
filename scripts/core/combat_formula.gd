# 共享战斗公式：提供护甲减伤等不依赖具体界面的基础数值计算。
class_name CombatFormula
extends RefCounted

static func armor_reduction(armor: float) -> float:
	# 采用护甲 / (100 + 护甲)，并限制负护甲避免分母为零。
	var safe_armor := maxf(-99.0, armor)
	return safe_armor / (100.0 + safe_armor)

static func armor_reduction_percent(armor: float) -> float:
	return armor_reduction(armor) * 100.0

static func apply_armor(raw_damage: float, armor: float) -> int:
	return maxi(1, roundi(raw_damage * (1.0 - armor_reduction(armor))))
