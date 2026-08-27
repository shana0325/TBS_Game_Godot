# 遗物系统：爬塔局内遗物/祝福的效果应用与事件触发。
# 效果类型：stat_percent（百分比属性）、turn_speed（行动速度）、reflect（反射，永久Buff）。
# 触发类型：on_kill（击杀回血）、on_first_death（首次死亡复活，每场战斗一次）。
class_name RelicSystem
extends RefCounted

# 战斗开始：把本局遗物与祝福的效果应用到玩家单位。
static func apply_run_bonuses(manager: BattleManager) -> void:
	for unit in manager.units:
		if not (unit is Unit) or unit.camp != TurnManager.PLAYER_CAMP:
			continue
		for relic_id in GameSession.run_relics:
			var relic := GameDatabase.get_relic(str(relic_id))
			if not relic.is_empty():
				_apply_effects(unit, relic.get("effects", []), manager.game)
		for blessing in GameSession.run_blessings:
			if blessing is Dictionary:
				_apply_effects(unit, blessing.get("effects", []), manager.game)

static func _apply_effects(unit: Unit, effects: Array, game) -> void:
	for effect in effects:
		if not (effect is Dictionary):
			continue
		match str(effect.get("type", "")):
			"stat_percent":
				var stat: String = str(effect.get("stat", "attack"))
				var p := float(effect.get("percent", 0.0))
				unit.percent_mods[stat] = float(unit.percent_mods.get(stat, 0.0)) + p
				if stat == "hp":
					# 生命百分比加成需要同步到生命上限（基础+永久为基数），当前生命跟随
					var base_max := unit.get_base_stat("hp") + int(unit.permanent_mods.get("hp", 0))
					var new_max := base_max + roundi(base_max * float(unit.percent_mods.get("hp", 0.0)))
					unit.hp += maxi(0, new_max - unit.max_hp)
					unit.max_hp = new_max
			"turn_speed":
				var p := float(effect.get("percent", 0.0))
				unit.turn_interval = maxf(0.2, unit.turn_interval * (1.0 - p))
			"reflect":
				var data := {
					"name": str(effect.get("name", "荆棘反伤")), "duration": -1,
					"reflect_percent": float(effect.get("percent", 0.3)),
					"permanent": true, "is_beneficial": true,
				}
				unit.add_buff(Buff.from_data(data))
			_:
				push_warning("未知遗物/祝福效果类型: %s" % str(effect.get("type", "")))

# 触发型：击杀回血（鲜血吊坠）。
static func on_kill(manager: BattleManager, killer: Unit, game) -> void:
	if killer == null or killer.camp != TurnManager.PLAYER_CAMP:
		return
	for relic_id in GameSession.run_relics:
		var relic := GameDatabase.get_relic(str(relic_id))
		for trigger in relic.get("triggers", []):
			if trigger is Dictionary and str(trigger.get("event", "")) == "on_kill":
				var heal_percent := float(trigger.get("heal_percent", 0.0))
				if heal_percent > 0.0:
					var healed := killer.heal(roundi(killer.max_hp * heal_percent))
					if healed > 0 and game != null and game.has_method("add_log"):
						game.add_log("%s 通过遗物%s恢复 %d 点生命" % [killer.get_display_name(), str(relic.get("name", "")), healed])

# 触发型：首次死亡复活（不灭徽记，每场战斗限一次）。
static func on_death(manager: BattleManager, unit: Unit, game) -> void:
	if unit == null or unit.camp != TurnManager.PLAYER_CAMP:
		return
	if manager.relic_revive_used:
		return
	for relic_id in GameSession.run_relics:
		var relic := GameDatabase.get_relic(str(relic_id))
		for trigger in relic.get("triggers", []):
			if trigger is Dictionary and str(trigger.get("event", "")) == "on_first_death" \
					and bool(trigger.get("revive", false)):
				unit.alive = true
				unit.hp = unit.max_hp
				unit.acted = false
				unit.moved = false
				manager.relic_revive_used = true
				if game != null and game.has_method("add_log"):
					game.add_log("%s 被「%s」复活！" % [unit.get_display_name(), str(relic.get("name", ""))])
				return