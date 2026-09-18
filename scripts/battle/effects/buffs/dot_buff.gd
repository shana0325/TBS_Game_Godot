# DotBuff：行动次数型持续伤害 Buff 基类（灼烧用）。
# 这是 Buff 家族的一个扩展子类示例：将来的中毒/寒冷/其他持续伤害可各自再建子类，
# 每个子类覆写自己的按行动结算逻辑，无需改动 Buff 基类与 central dispatch。
# 本类约定：附着单位每次行动开始时结算一次伤害，至多 hits 次；末次可翻倍。
class_name DotBuff
extends Buff

var caster: Unit = null          # 施放者（伤害按其攻击力计算）
var atk_percent: float = 0.0     # 每跳伤害 = 施放者攻击力 × 该值
var hits_remaining: int = 0      # 剩余结算次数
var final_double: bool = false   # 最后一次是否翻倍
var base_name: String = "灼烧"

func is_dot() -> bool:
	return true

func is_expired() -> bool:
	return hits_remaining <= 0

func on_turn_start(unit, game, battle = null) -> void:
	if hits_remaining <= 0:
		return
	var raw := 0
	if caster != null:
		raw = roundi(caster.get_attack() * atk_percent)
	if hits_remaining == 1 and final_double:
		raw *= 2
	hits_remaining -= 1
	if raw <= 0:
		return
	if unit == null or not unit.alive:
		return
	DamageSystem.apply(caster, unit, {"damage_kind": DamageSystem.EFFECT,
		"raw_damage": raw, "true_damage": true}, battle, game)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 因 %s 受到 %d 点持续伤害（剩余 %d 次）" % [unit.get_display_name(), base_name, raw, hits_remaining])