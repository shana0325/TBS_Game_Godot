# 效果系统（注册表驱动）：按 effect.type 分发到对应处理器。
# 新增效果只需实现一个 apply 函数并注册到 HANDLERS，技能数据无需改动。
class_name EffectSystem
extends RefCounted

# 效果处理器注册表：type -> 处理函数（static func(user, target, config, game) -> Dictionary）
const HANDLERS := {
	"damage": "damage",
	"heal": "heal",
	"buff": "buff",
	"dot": "dot",
	"shield": "shield",
	"stat_mod": "stat_mod",
	"revive": "revive",
	"dispel": "dispel",
	"cleanse": "cleanse",
}

# 对单个目标应用一组效果，返回汇总报告。
static func apply_effects(user: Unit, target: Unit, effects: Array, game = null) -> Dictionary:
	var report := {"damage": 0, "heal": 0, "buffs": [], "shield": 0, "revived": false}
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var effect_type := str(effect.get("type", ""))
		match effect_type:
			"damage":
				report["damage"] += _apply_damage(user, target, effect, game)
			"heal":
				report["heal"] += _apply_heal(target, effect, game)
			"buff":
				var buff := _apply_buff(target, effect, game)
				if buff != null:
					report["buffs"].append(buff.name)
			"dot":
				var dot_buff := _apply_buff(target, {"type": "buff", "buff": str(effect.get("buff", ""))}, game)
				if dot_buff != null:
					report["buffs"].append(dot_buff.name)
			"shield":
				var sh := _apply_shield(target, effect, game)
				report["shield"] += sh
			"stat_mod":
				_apply_stat_mod(target, effect, game)
			"revive":
				if _apply_revive(target, effect, game):
					report["revived"] = true
			"dispel":
				_apply_dispel(target, effect, game)
			"summon":
				_apply_summon(user, effect, game)
			"taunt":
				_apply_status_buff(target, effect, game, "taunt")
			"immunity":
				_apply_immunity(target, effect, game)
			"reflect":
				_apply_reflect(target, effect, game)
			"protect":
				_apply_protect(target, effect, game)
			"ignore":
				_apply_ignore(target, effect, game)
			"mark":
				_apply_mark(target, effect, game)
			"lifesteal":
				_apply_lifesteal(target, effect, game)
			_:
				push_warning("未知技能效果类型: %s" % effect_type)
	return report

# --- 各效果实现（可独立注册/扩展） ---

static func _apply_damage(user: Unit, target: Unit, config: Dictionary, game) -> int:
	if user == null or target == null or not target.alive:
		return 0
	var power := float(config.get("power", 1.0))
	var terrain_bonus := int(config.get("terrain_bonus", 0))
	var damage := DamageCalculator.calculate_skill_damage(user, target, power, terrain_bonus)
	target.take_damage(damage, game)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 对 %s 造成 %d 点伤害" % [user.get_display_name(), target.get_display_name(), damage])
	return damage

static func _apply_heal(target: Unit, config: Dictionary, game) -> int:
	if target == null or not target.alive:
		return 0
	var amount := int(config.get("amount", 0))
	if amount <= 0:
		amount = 0
	var healed := target.heal(amount)
	if healed > 0 and game != null and game.has_method("add_log"):
		game.add_log("%s 恢复 %d 点生命" % [target.get_display_name(), healed])
	return healed

static func _apply_buff(target: Unit, config: Dictionary, game) -> Buff:
	if target == null:
		return null
	var buff_id := str(config.get("buff", ""))
	return BuffEffect.apply(target, buff_id, game)

static func _apply_shield(target: Unit, config: Dictionary, game) -> int:
	if target == null:
		return 0
	var amount := int(config.get("amount", 0))
	if amount <= 0:
		return 0
	var data := {
		"name": "护罩",
		"duration": int(config.get("duration", 2)),
		"shield": amount,
	}
	var buff := Buff.from_data(data)
	target.add_buff(buff)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 获得 %d 点护罩" % [target.get_display_name(), amount])
	return amount

static func _apply_stat_mod(target: Unit, config: Dictionary, game) -> void:
	if target == null:
		return
	var data := {
		"name": str(config.get("name", "属性变化")),
		"duration": int(config.get("duration", 2)),
		"modifiers": config.get("stats", {}),
	}
	var buff := Buff.from_data(data)
	target.add_buff(buff)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 属性变化" % target.get_display_name())

static func _apply_revive(target: Unit, config: Dictionary, game) -> bool:
	if target == null or target.alive:
		return false
	var hp_percent := float(config.get("hp_percent", 0.5))
	target.alive = true
	target.hp = maxi(1, roundi(target.max_hp * hp_percent))
	target.acted = false
	target.moved = false
	if game != null and game.has_method("add_log"):
		game.add_log("%s 复活！" % target.get_display_name())
	return true

static func _apply_dispel(target: Unit, config: Dictionary, game) -> void:
	if target == null:
		return
	var friendly := bool(config.get("friendly", false))
	var kept: Array = []
	for buff in target.buffs:
		var is_beneficial: bool = bool(buff.raw_data.get("is_beneficial", false))
		if is_beneficial == friendly:
			kept.append(buff)
	target.buffs = kept
	if game != null and game.has_method("add_log"):
		game.add_log("%s 的效果被驱散" % target.get_display_name())

# 召唤：在目标（或自身）附近生成一个单位，存活 duration 回合。
static func _apply_summon(user: Unit, config: Dictionary, game) -> void:
	if user == null:
		return
	var unit_type := str(config.get("unit_type", "Goblin"))
	var config_data: Dictionary = GameDatabase.get_unit(unit_type)
	if config_data.is_empty():
		push_warning("召唤未知单位: %s" % unit_type)
		return
	# 在目标旁找空位（简化：复用 game 的 BattleManager 添加单位）
	var battle = game
	if battle != null and battle.has_method("spawn_unit"):
		battle.spawn_unit(unit_type, user.camp, user.pos)
		if game.has_method("add_log"):
			game.add_log("%s 召唤了 %s" % [user.get_display_name(), unit_type])
	else:
		if game != null and game.has_method("add_log"):
			game.add_log("%s 尝试召唤 %s（缺少 spawn_unit）" % [user.get_display_name(), unit_type])

# 状态型 Buff（挑衅等 control 类）。
static func _apply_status_buff(target: Unit, config: Dictionary, game, control: String) -> void:
	if target == null:
		return
	var data := {
		"name": str(config.get("name", control)),
		"duration": int(config.get("duration", 1)),
		"control": control,
		"is_beneficial": bool(config.get("is_beneficial", false)),
	}
	var buff := Buff.from_data(data)
	target.add_buff(buff)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 获得 %s 效果" % [target.get_display_name(), buff.name])

# 免疫：免疫指定状态（stun/silence/poison 等，* 表示全部负面）。
static func _apply_immunity(target: Unit, config: Dictionary, game) -> void:
	if target == null:
		return
	var data := {
		"name": str(config.get("name", "免疫")),
		"duration": int(config.get("duration", 2)),
		"immunity": config.get("states", []),
		"is_beneficial": true,
	}
	var buff := Buff.from_data(data)
	target.add_buff(buff)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 获得 %s" % [target.get_display_name(), buff.name])

# 反射：受到伤害时按比例反射给攻击者。
static func _apply_reflect(target: Unit, config: Dictionary, game) -> void:
	if target == null:
		return
	var data := {
		"name": str(config.get("name", "反射")),
		"duration": int(config.get("duration", 2)),
		"reflect_percent": float(config.get("percent", 0.3)),
		"is_beneficial": true,
	}
	var buff := Buff.from_data(data)
	target.add_buff(buff)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 获得 %s" % [target.get_display_name(), buff.name])

# 减伤（防护罩）：受到伤害降低指定比例。
static func _apply_protect(target: Unit, config: Dictionary, game) -> void:
	if target == null:
		return
	var data := {
		"name": str(config.get("name", "防护罩")),
		"duration": int(config.get("duration", 2)),
		"reduce_percent": float(config.get("reduction", 0.3)),
		"is_beneficial": true,
	}
	var buff := Buff.from_data(data)
	target.add_buff(buff)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 获得 %s" % [target.get_display_name(), buff.name])

# 无视：攻击时无视目标防御/护盾。
static func _apply_ignore(target: Unit, config: Dictionary, game) -> void:
	if target == null:
		return
	var data := {
		"name": str(config.get("name", "无视")),
		"duration": int(config.get("duration", 1)),
		"ignore_defense": true,
		"is_beneficial": true,
	}
	var buff := Buff.from_data(data)
	target.add_buff(buff)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 获得 %s" % [target.get_display_name(), buff.name])

# 标记：给目标打上标记，供其他技能作条件。
static func _apply_mark(target: Unit, config: Dictionary, game) -> void:
	if target == null:
		return
	var data := {
		"name": str(config.get("name", "标识")),
		"duration": int(config.get("duration", 2)),
		"is_mark": true,
		"is_beneficial": false,
	}
	var buff := Buff.from_data(data)
	target.add_buff(buff)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 被标记" % target.get_display_name())

# 吸血：造成伤害时按比例恢复生命。
static func _apply_lifesteal(target: Unit, config: Dictionary, game) -> void:
	if target == null:
		return
	var data := {
		"name": str(config.get("name", "吸血")),
		"duration": int(config.get("duration", 2)),
		"trigger": "on_hit",
		"heal_percent": float(config.get("percent", 0.3)),
		"is_beneficial": true,
	}
	var buff := Buff.from_data(data)
	target.add_buff(buff)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 获得 %s" % [target.get_display_name(), buff.name])
