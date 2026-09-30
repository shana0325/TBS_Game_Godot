# DotBuff：按真实秒数结算的持续伤害 Buff 基类，灼魂焚身使用此类。
class_name DotBuff
extends Buff

var caster: Unit = null          # 施放者（伤害按其攻击力计算）
var atk_percent: float = 0.0     # 每跳伤害 = 施放者攻击力 × 该值
var hits_remaining: int = 0      # 剩余结算次数
var final_double: bool = false   # 最后一次是否翻倍
var base_name: String = "灼烧"
var tick_interval_seconds: float = 1.0

# 标明这是独立的持续伤害状态。
func is_dot() -> bool:
	return true

func is_expired() -> bool:
	return hits_remaining <= 0

# 每隔指定秒数结算一跳，允许一次大步长推进多跳。
func tick_seconds(unit: Unit, delta: float, game = null, battle = null) -> void:
	if hits_remaining <= 0 or unit == null or not unit.alive:
		return
	tick_elapsed += maxf(delta, 0.0)
	seconds_left = maxf(0.0, float(hits_remaining) * tick_interval_seconds - tick_elapsed)
	while tick_elapsed >= tick_interval_seconds and hits_remaining > 0 and unit.alive:
		tick_elapsed -= tick_interval_seconds
		var raw := roundi(caster.get_attack() * atk_percent) if caster != null else 0
		if hits_remaining == 1 and final_double:
			raw *= 2
		hits_remaining -= 1
		if raw > 0:
			DamageSystem.apply(caster, unit, {"damage_kind": DamageSystem.EFFECT,
				"raw_damage": raw}, battle, game)
	seconds_left = maxf(0.0, float(hits_remaining) * tick_interval_seconds - tick_elapsed)
