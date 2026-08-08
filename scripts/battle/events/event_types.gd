# 事件常量：统一战斗事件名称，避免字符串散落。
class_name EventTypes
extends RefCounted

const ON_ATTACK := "on_attack"
const ON_HIT := "on_hit"
const ON_KILL := "on_kill"
const ON_TURN_START := "on_turn_start"
const ON_TURN_END := "on_turn_end"
const ON_MOVE := "on_move"
const ON_SKILL_CAST := "on_skill_cast"