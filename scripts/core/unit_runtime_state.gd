# UnitRuntimeState：单位战斗运行时统一状态库。
# 把此前散落的"叠层/按目标计数/限流冷却/时间窗"临时字典收进来，供技能和遗物共用，
# 避免每种机制各自造一套按单位 id 的字典。
# 时间相关方法统一接收 battle 的"当前战斗秒数"（battle.get_battle_time()）。
class_name UnitRuntimeState
extends RefCounted

var stacks: Dictionary = {}       # key -> int 叠层
var notes: Dictionary = {}        # key -> Variant 任意临时数据
var per_target: Dictionary = {}   # key -> {target_id: int} 按目标计数
var throttles: Dictionary = {}    # key -> float 下次可用秒数
var windows: Dictionary = {}      # key -> {target_id: Array(float 命中时刻)}

# --- 叠层 ---
func stack_get(key: String) -> int:
	return int(stacks.get(key, 0))

func stack_set(key: String, value: int) -> void:
	stacks[key] = maxi(0, value)

func bump(key: String, amount: int = 1) -> int:
	stacks[key] = int(stacks.get(key, 0)) + amount
	return int(stacks[key])

func stacked_add(key: String, amount: int = 1, cap: int = -1) -> int:
	var value := int(stacks.get(key, 0)) + amount
	if cap >= 0:
		value = mini(value, cap)
	stacks[key] = value
	return value

# --- 按目标计数 ---
func per_target_bump(key: String, target, amount: int = 1) -> int:
	var tid: int = target.get_instance_id() if target != null else -1
	var bucket: Dictionary = per_target.get(key, {})
	bucket[tid] = int(bucket.get(tid, 0)) + amount
	per_target[key] = bucket
	return int(bucket[tid])

func per_target_count(key: String, target) -> int:
	var tid: int = target.get_instance_id() if target != null else -1
	return int(per_target.get(key, {}).get(tid, 0))

# --- 限流冷却（now 秒内至多触发一次）---
func throttle_ready(key: String, now: float) -> bool:
	return now >= float(throttles.get(key, -1.0e9))

func throttle_use(key: String, now: float, cooldown: float) -> bool:
	if not throttle_ready(key, now):
		return false
	throttles[key] = now + cooldown
	return true

# --- 时间窗命中计数：统计 now 往前 seconds 秒内对指定目标的命中次数并记录本次 ---
func window_hit(key: String, target, now: float, seconds: float) -> int:
	var tid: int = target.get_instance_id() if target != null else -1
	var bucket: Dictionary = windows.get(key, {})
	var times: Array = bucket.get(tid, [])
	var keep: Array = []
	for t in times:
		if float(t) > now - seconds:
			keep.append(t)
	keep.append(now)
	bucket[tid] = keep
	windows[key] = bucket
	return keep.size()
