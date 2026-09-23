# 遗物系统：爬塔局内遗物的静态加成、成长效果与事件触发。
# 效果类型：stat_percent（百分比属性）、reflect（反射，永久Buff）。
# 触发类型：on_kill（击杀回血）、on_first_death（首次死亡复活，每场战斗一次）。
class_name RelicSystem
extends RefCounted

# 战斗开始：把本局遗物效果应用到玩家单位。
static func apply_run_bonuses(manager: BattleManager) -> void:
	for unit in manager.units:
		if not (unit is Unit) or unit.camp != TurnManager.PLAYER_CAMP:
			continue
		apply_run_bonuses_to_unit(unit, manager.game)

# 给新建单位应用完整 Run 加成；部署预览和正式战斗共用此入口。
static func apply_run_bonuses_to_unit(unit: Unit, game = null) -> void:
	if unit == null or unit.camp != TurnManager.PLAYER_CAMP:
		return
	for relic_id in GameSession.run_relics:
		var relic := GameDatabase.get_relic(str(relic_id))
		if not relic.is_empty():
			_apply_effects(unit, relic.get("effects", []), game, GameSession.get_relic_stack(str(relic_id)))
	_apply_persistent_growth(unit)

# 将 Run 级遗物成长重新应用到每场战斗新建的单位。
static func _apply_persistent_growth(unit: Unit) -> void:
	var state: Dictionary = GameSession.run_relic_state
	var global_hp := int(state.get("overgrowth_hp", 0))
	var unit_growth: Dictionary = state.get("units", {}).get(_run_unit_key(unit), {})
	var flat_hp := global_hp + int(unit_growth.get("grasp_hp", 0))
	var percent_hp := float(unit_growth.get("manaflow_percent", 0.0))
	var percent_add := roundi(float(unit.max_hp) * percent_hp)
	var total := flat_hp + percent_add
	if total > 0:
		unit.max_hp += total
		unit.hp += total

# 旧预览入口保留为兼容别名，实际统一应用完整 Run 加成。
static func apply_persistent_growth_to_unit(unit: Unit) -> void:
	apply_run_bonuses_to_unit(unit)

# Run 内单位成长使用存档单位 id；无 id 的测试/模组单位退回单位类型。
static func _run_unit_key(unit: Unit) -> String:
	if unit == null:
		return ""
	return unit.unit_id if not unit.unit_id.is_empty() else "type:%s" % unit.unit_type

# 获取并写回指定单位的 Run 级成长桶。
static func _unit_growth(unit: Unit) -> Dictionary:
	var units: Dictionary = GameSession.run_relic_state.get("units", {})
	var key := _run_unit_key(unit)
	var growth: Dictionary = units.get(key, {})
	units[key] = growth
	GameSession.run_relic_state["units"] = units
	return growth

# 根据遗物数据中的 growth_display 声明生成当前成长文本，供所有遗物界面复用。
static func get_growth_display_lines(relic_id: String) -> Array[String]:
	var relic: Dictionary = GameDatabase.get_relic(relic_id)
	var lines: Array[String] = []
	if bool(relic.get("repeatable", false)):
		var stacks := GameSession.get_relic_stack(relic_id)
		var max_stacks := int(relic.get("max_stacks", 0))
		lines.append("当前层数：%d / %d" % [stacks, max_stacks] if max_stacks > 0 else "当前层数：%d" % stacks)
		for effect in relic.get("effects", []):
			if effect is Dictionary and str(effect.get("type", "")) == "stat_percent":
				var stat_name: String = str({"attack": "全体攻击力", "defense": "全体防御力", "hp": "全体最大生命"}.get(str(effect.get("stat", "")), "全队属性"))
				lines.append("%s：+%s%%" % [stat_name, String.num(float(effect.get("percent", 0.0)) * stacks * 100.0, 1).trim_suffix(".0")])
	for raw in relic.get("growth_display", []):
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		var label := str(item.get("label", "成长"))
		match str(item.get("source", "run")):
			"tower_floor":
				var floor_value := maxf(float(GameSession.tower_floor) + float(item.get("offset", 0.0)), 0.0)
				var value := floor_value * float(item.get("scale", 1.0))
				if item.has("cap"):
					value = minf(value, float(item["cap"]))
				lines.append("%s：%s" % [label, _format_growth_value(value, item)])
			"unit":
				_append_unit_growth_lines(lines, label, item)
			_:
				var value := float(GameSession.run_relic_state.get(str(item.get("key", "")), 0.0))
				lines.append("%s：%s" % [label, _format_growth_value(value, item)])
	return lines

# 展开按单位保存的成长数值；没有成长记录时也明确显示当前为零。
static func _append_unit_growth_lines(lines: Array[String], label: String, item: Dictionary) -> void:
	var units: Dictionary = GameSession.run_relic_state.get("units", {})
	var key := str(item.get("key", ""))
	var found := false
	for unit_key in units.keys():
		var growth = units[unit_key]
		if not (growth is Dictionary) or not growth.has(key):
			continue
		found = true
		lines.append("%s · %s：%s" % [_growth_unit_name(str(unit_key)), label,
			_format_growth_value(float(growth.get(key, 0.0)), item)])
	if not found:
		lines.append("%s：%s" % [label, _format_growth_value(0.0, item)])

# 把存档单位 id 转换成玩家可读名称；模组或测试单位保留类型名。
static func _growth_unit_name(unit_key: String) -> String:
	for roster_data in GameDatabase.player_roster.get("units", []):
		if str(roster_data.get("id", "")) == unit_key:
			var unit_type := str(roster_data.get("type", unit_key))
			return str(GameDatabase.get_unit(unit_type).get("display_name", unit_type))
	return unit_key.trim_prefix("type:")

# 统一格式化百分比与普通数值，后续成长类型只需在数据里选择格式和单位。
static func _format_growth_value(value: float, item: Dictionary) -> String:
	var text := ""
	if str(item.get("format", "number")) == "percent":
		text = "+%s%%" % String.num(value * 100.0, 1).trim_suffix(".0")
	else:
		text = "+%s" % String.num(value, 2).trim_suffix("0").trim_suffix(".")
	return text + str(item.get("suffix", ""))

# 按遗物层数应用数据效果；普通遗物的层数恒为 1。
static func _apply_effects(unit: Unit, effects: Array, game, stacks: int = 1) -> void:
	# 跨层成长基数：进入过的新层数（当前层已把加成算入 tower_floor）。
	var floors := maxi(GameSession.tower_floor - 1, 0) if GameSession.mode == GameSession.MODE_TOWER else 0
	for effect in effects:
		if not (effect is Dictionary):
			continue
		match str(effect.get("type", "")):
			"stat_percent":
				var stat: String = str(effect.get("stat", "attack"))
				var p := float(effect.get("percent", 0.0)) * float(maxi(stacks, 1))
				unit.percent_mods[stat] = float(unit.percent_mods.get(stat, 0.0)) + p
				if stat == "hp":
					# 生命百分比加成需要同步到生命上限（基础+永久为基数），当前生命跟随
					var base_max := float(unit.get_base_stat("hp")) + float(unit.permanent_mods.get("hp", 0.0))
					var new_max := base_max * (1.0 + float(unit.percent_mods.get("hp", 0.0)))
					unit.hp += maxf(0.0, new_max - unit.max_hp)
					unit.max_hp = new_max
			"glayer_stat_percent":
				# 每进入新一层，指定属性按百分比提升：总加成 = percent_per_floor × 进入过的新层数
				var lstat := str(effect.get("stat", "attack"))
				var lp := float(effect.get("percent_per_floor", 0.01))
				if floors > 0:
					unit.percent_mods[lstat] = float(unit.percent_mods.get(lstat, 0.0)) + lp * float(floors)
			"glayer_haste":
				# 每进入新一层，按秒触发技能间隔缩短 percent_per_floor，至多 cap。
				# 技能急速公式：实际间隔 = 基础 × 100/(100+haste)，故缩短 r% 需 haste = 100·r/(1-r)。
				if floors > 0:
					var total := minf(float(effect.get("percent_per_floor", 0.01)) * float(floors), float(effect.get("cap", 0.08)))
					if total > 0.0:
						unit.permanent_mods["ability_haste"] = int(unit.permanent_mods.get("ability_haste", 0)) \
							+ int(round(100.0 * total / (1.0 - total)))
			"reflect":
				var data := {
					"name": str(effect.get("name", "荆棘反伤")), "duration": -1,
					"reflect_percent": float(effect.get("percent", 0.3)),
					"permanent": true, "is_beneficial": true,
				}
				unit.add_buff(Buff.from_data(data))
			_:
				push_warning("未知遗物效果类型: %s" % str(effect.get("type", "")))

# 单位级伤害倍率：汇总本局遗物中按条件加成的普攻/技能伤害。
# kind=attack/skill 时生效；特效伤害不享受。供 DamageSystem 查询。
static func get_damage_bonus_percent(source: Unit, target: Unit, kind: String, state: Dictionary = {}) -> float:
	if source == null or target == null or source.camp != TurnManager.PLAYER_CAMP:
		return 0.0
	if kind == DamageSystem.EFFECT:
		return 0.0
	var bonus := 0.0
	for relic_id in GameSession.run_relics:
		var relic := GameDatabase.get_relic(str(relic_id))
		match str(relic_id):
			"coup_grace":  # 处决：对生命<40%敌人 +12%
				if float(target.hp) / maxf(target.max_hp, 1.0) < 0.4:
					bonus += 0.12
			"cut_down":    # 先手：对生命>60%敌人 +12%
				if float(target.hp) / maxf(target.max_hp, 1.0) > 0.6:
					bonus += 0.12
			"last_stand":  # 背水为战：自身低生命判定
				var ratio := float(source.hp) / maxf(source.max_hp, 1.0)
				if ratio < 0.25:
					bonus += 0.20
				elif ratio < 0.50:
					bonus += 0.10
			"gathering_storm":  # 层积风暴：每层普攻/技能伤害 +1%
				if GameSession.mode == GameSession.MODE_TOWER:
					bonus += 0.01 * float(maxi(GameSession.tower_floor - 1, 0))
	# 猎魔嗅探：战斗中被标记（攻击力最高的敌人）8 秒内，我方对其伤害 +20%
	if not state.is_empty() and int(state.get("sixth_mark", -1)) != -1:
		if target.get_instance_id() == int(state.get("sixth_mark", -1)) \
				and float(state.get("time", 0.0)) <= float(state.get("sixth_mark_expiry", 0.0)):
			bonus += 0.20
	return bonus

# 触发型：击杀触发。凯旋号角全队回已损+击杀者额外最大；噬骸成长全队永久HP+1。
static func on_kill(manager: BattleManager, killer: Unit, game) -> void:
	if killer == null or killer.camp != TurnManager.PLAYER_CAMP:
		return
	for relic_id in GameSession.run_relics:
		var relic := GameDatabase.get_relic(str(relic_id))
		match str(relic_id):
			"triumph_horn":
				_apply_triumph_horn(manager, killer, game)
			"overgrowth":
				_apply_overgrowth(manager, game)
		for trigger in relic.get("triggers", []):
			if trigger is Dictionary and str(trigger.get("event", "")) == "on_kill":
				var heal_percent := float(trigger.get("heal_percent", 0.0))
				if heal_percent > 0.0:
					var healed := killer.heal(roundi(killer.max_hp * heal_percent), killer)
					if healed > 0 and game != null and game.has_method("add_log"):
						game.add_log("%s 通过遗物%s恢复 %d 点生命" % [killer.get_display_name(), str(relic.get("name", "")), healed])

# 凯旋号角：全员各回复 5% 已损生命，击杀者额外回复 2.5% 最大生命。
static func _apply_triumph_horn(manager: BattleManager, killer: Unit, game) -> void:
	for unit in manager.units:
		if not (unit is Unit) or not unit.alive or unit.camp != TurnManager.PLAYER_CAMP:
			continue
		var lost: float = unit.max_hp - unit.hp
		if lost > 0:
			var healed: int = unit.heal(roundi(lost * 0.05), killer)
			if healed > 0 and game != null and game.has_method("add_log"):
				game.add_log("%s 通过凯旋号角恢复 %d 点生命" % [unit.get_display_name(), healed])
	if killer != null and killer.alive:
		var extra := roundi(killer.max_hp * 0.025)
		if extra > 0:
			var healed2 := killer.heal(extra, killer)
			if healed2 > 0 and game != null and game.has_method("add_log"):
				game.add_log("凯旋号角回响：%s 额外恢复 %d 点生命" % [killer.get_display_name(), healed2])

# 噬骸成长：每个敌人死亡，全队最大生命永久 +1（当前生命跟随）。
static func _apply_overgrowth(manager: BattleManager, game) -> void:
	GameSession.run_relic_state["overgrowth_hp"] = int(GameSession.run_relic_state.get("overgrowth_hp", 0)) + 1
	for unit in manager.units:
		if not (unit is Unit) or not unit.alive or unit.camp != TurnManager.PLAYER_CAMP:
			continue
		unit.max_hp += 1
		unit.hp = minf(unit.hp + 1.0, unit.max_hp)
	if game != null and game.has_method("add_log"):
		game.add_log("噬骸成长：全体最大生命 +1")

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

# ===== 战斗运行时遗物：需要逐帧/逐事件状态跟踪的效果 =====
# 状态统一存于 manager.relic_state（战斗级字典），由 BattleManager 的
# setup_battle / tick / on_damage_resolved / on_turn 分发对应钩子调用。
# 涉及：行军口粮、猎魔嗅探、守护精灵、灵能循环、不朽血契、守护之盾、收割之魂。

# 战斗开始：初始化运行时状态，并处理即时生效的遗物（猎魔标记、血契计时）。
static func begin_battle(manager: BattleManager) -> void:
	manager.relic_state = {
		"time": 0.0,
		"sixth_mark": -1, "sixth_mark_expiry": -1.0,
		"harvest_hits": {},
		"manaflow_counts": {},
		"grasp_grant": {},
		"guardian_turn": {},
		"unit_turns": {},
		"airy_last": {},
		"biscuit_next_tick": 1.0,
	}
	var relics = GameSession.run_relics
	for unit in manager.units:
		if not (unit is Unit) or unit.camp != TurnManager.PLAYER_CAMP or not unit.alive:
			continue
		if relics.has("grasp_undying"):
			manager.relic_state["grasp_grant"][unit.get_instance_id()] = {"next": 4.0, "empowered": false}
	if relics.has("sixth_sense"):
		_apply_sixth_sense_start(manager)

# 猎魔嗅探：战斗开始时标记敌方攻击力最高者 8 秒（真实时限按 state 时间判断）。
static func _apply_sixth_sense_start(manager: BattleManager) -> void:
	var mark: Unit = null
	var best := -1.0
	for unit in manager.units:
		if unit is Unit and unit.alive and unit.camp != TurnManager.PLAYER_CAMP:
			var a: float = unit.get_attack()
			if a > best:
				best = a
				mark = unit
	if mark == null:
		return
	var st: Dictionary = manager.relic_state
	st["sixth_mark"] = mark.get_instance_id()
	st["sixth_mark_expiry"] = 8.0
	# 视觉标记（约 2 次行动后消失，真实失效以 state 时间为准）
	var data := {"name": "猎魔标记", "duration": 2, "is_mark": true, "is_beneficial": false}
	mark.add_buff(Buff.from_data(data))
	if manager.game != null and manager.game.has_method("add_log"):
		manager.game.add_log("%s 被猎魔嗅探标记（攻击力最高的敌人）" % mark.get_display_name())

# 每帧推进：累计战场时间，处理随时间刷新的遗物（行军口粮、不朽血契）。
static func tick_battle(manager: BattleManager, delta: float) -> void:
	var st: Dictionary = manager.relic_state
	if st.is_empty():
		return
	st["time"] = float(st.get("time", 0.0)) + delta
	var game: Object = manager.game
	var relics = GameSession.run_relics
	# 行军口粮：第 1~10 秒各结算一次，避免逐帧取整令低生命单位无法回血。
	if relics.has("biscuit_delivery"):
		var next_tick := float(st.get("biscuit_next_tick", 1.0))
		while next_tick <= 10.0 and float(st["time"]) >= next_tick:
			for unit in manager.units:
				if unit is Unit and unit.alive and unit.camp == TurnManager.PLAYER_CAMP:
					unit.heal(roundi(unit.max_hp * 0.05), unit)
			next_tick += 1.0
		st["biscuit_next_tick"] = next_tick
	# 不朽血契：每 4 秒给有该遗物的我方单位发放一次"下次普攻强化"
	if relics.has("grasp_undying"):
		var grasp: Dictionary = st.get("grasp_grant", {})
		for unit in manager.units:
			if not (unit is Unit) or unit.camp != TurnManager.PLAYER_CAMP or not unit.alive:
				continue
			var g: Dictionary = grasp.get(unit.get_instance_id(), {})
			if g.is_empty():
				continue
			if float(st["time"]) >= float(g.get("next", 0.0)):
				g["empowered"] = true
				g["next"] = float(st["time"]) + 4.0
				if game != null and game.has_method("add_log"):
					game.add_log("%s 获得下一次普攻强化（不朽血契）" % unit.get_display_name())

# 敌方单位每回合判定点：为守护之盾提供"每回合至多一次"的回合计数。
static func on_turn_start(manager: BattleManager, unit: Unit, game) -> void:
	var st: Dictionary = manager.relic_state
	if st.is_empty() or unit == null:
		return
	var turns: Dictionary = st.get("unit_turns", {})
	var uid := unit.get_instance_id()
	turns[uid] = int(turns.get(uid, 0)) + 1
	st["unit_turns"] = turns

# 我方造成普攻/技能伤害时触发：收割之魂、守护精灵、灵能循环、不朽血契强化普攻。
static func on_hit(manager: BattleManager, source: Unit, target: Unit, kind: String, game) -> void:
	if source == null or target == null or source.camp != TurnManager.PLAYER_CAMP:
		return
	if not source.alive:
		return
	var st: Dictionary = manager.relic_state
	var relics = GameSession.run_relics
	var sid := source.get_instance_id()
	# 不朽血契：强化普攻追加 3% 最大生命的真实特效伤害并回复等量；击杀则永久 +5
	if kind == DamageSystem.ATTACK and relics.has("grasp_undying"):
		var grasp: Dictionary = st.get("grasp_grant", {})
		var g: Dictionary = grasp.get(sid, {})
		if not g.is_empty() and bool(g.get("empowered", false)):
			g["empowered"] = false
			var dmg := roundi(source.max_hp * 0.03)
			var empowered_kill := not target.alive
			if dmg > 0 and target.alive:
				DamageSystem.apply(source, target, {"damage_kind": DamageSystem.EFFECT,
					"raw_damage": dmg, "true_damage": true}, manager, game)
				if game != null and game.has_method("add_log"):
					game.add_log("%s 强化普攻对 %s 造成 %d 点真实伤害并回复自身" % [source.get_display_name(), target.get_display_name(), dmg])
				empowered_kill = not target.alive
			source.heal(roundi(source.max_hp * 0.03), source)
			if empowered_kill:
				var growth := _unit_growth(source)
				growth["grasp_hp"] = int(growth.get("grasp_hp", 0)) + 5
				source.max_hp += 5
				source.hp = minf(source.hp + 5.0, source.max_hp)
				if game != null and game.has_method("add_log"):
					game.add_log("不朽血契击杀蔓延：%s 最大生命永久 +5" % source.get_display_name())
	if not target.alive:
		return
	# 收割之魂、守护精灵：仅在普攻/技能伤害时判断
	if kind == DamageSystem.ATTACK or kind == DamageSystem.SKILL:
		if relics.has("harvest_soul"):
			_apply_harvest_soul(manager, source, target, game)
		if relics.has("airy_guardian"):
			_apply_airy_guardian(manager, source, target, game)
	# 灵能循环：技能伤害计数成长
	if kind == DamageSystem.SKILL and relics.has("manaflow_band"):
		_apply_manaflow(manager, source, game)

# 收割之魂：对生命<25%的敌人首次造成普攻/技能伤害时加 10+成长点特效伤害，每目标每场一次。
static func _apply_harvest_soul(manager: BattleManager, source: Unit, target: Unit, game) -> void:
	var st: Dictionary = manager.relic_state
	if not target.alive:
		return
	if float(target.hp) / maxf(target.max_hp, 1.0) >= 0.25:
		return
	var tid := target.get_instance_id()
	var hits: Dictionary = st.get("harvest_hits", {})
	if hits.has(tid):
		return
	hits[tid] = true
	st["harvest_hits"] = hits
	var bonus := int(GameSession.run_relic_state.get("harvest_bonus", 0))
	var dmg := 10 + bonus
	if target.alive:
		DamageSystem.apply(source, target, {"damage_kind": DamageSystem.EFFECT,
			"raw_damage": dmg}, manager, game)
		GameSession.run_relic_state["harvest_bonus"] = bonus + 10
		if game != null and game.has_method("add_log"):
			game.add_log("收割之魂：对 %s 追加 %d 点特效伤害（成长值 %d）" % [target.get_display_name(), dmg, bonus])

# 守护精灵：目标<40%血 → 追加 30% 攻击力特效伤害；否则给最低血友军 60% 攻击力护盾。每敌方 6 秒至多一次。
static func _apply_airy_guardian(manager: BattleManager, source: Unit, target: Unit, game) -> void:
	var st: Dictionary = manager.relic_state
	var tid := target.get_instance_id()
	var last: Dictionary = st.get("airy_last", {})
	var t := float(st.get("time", 0.0))
	if t - float(last.get(tid, -999.0)) < 6.0:
		return
	last[tid] = t
	st["airy_last"] = last
	if not target.alive:
		return
	if float(target.hp) / maxf(target.max_hp, 1.0) < 0.4:
		var dmg := roundi(source.get_attack() * 0.30)
		if dmg > 0:
			DamageSystem.apply(source, target, {"damage_kind": DamageSystem.EFFECT, "raw_damage": dmg}, manager, game)
			if game != null and game.has_method("add_log"):
				game.add_log("守护精灵：对 %s 追加 %d 点特效伤害" % [target.get_display_name(), dmg])
	else:
		# 给当前生命比例最低的存活友军施加施放者 60% 攻击力的护盾
		var lowest: Unit = null
		var lowest_ratio := 1.01
		for ally in manager.units:
			if ally is Unit and ally.alive and ally.camp == TurnManager.PLAYER_CAMP:
				var r := float(ally.hp) / maxf(ally.max_hp, 1.0)
				if r < lowest_ratio:
					lowest_ratio = r
					lowest = ally
		if lowest != null:
			_apply_shield_to(lowest, roundi(source.get_attack() * 0.60), game)

# 灵能循环：每累计 3 次造成技能伤害，最大生命 +1%（至多 +8%）；满后改回复 3% 已损生命。
static func _apply_manaflow(manager: BattleManager, source: Unit, game) -> void:
	var st: Dictionary = manager.relic_state
	var counts: Dictionary = st.get("manaflow_counts", {})
	var sid := source.get_instance_id()
	var growth := _unit_growth(source)
	var persisted_bonus := float(growth.get("manaflow_percent", 0.0))
	var e: Dictionary = counts.get(sid, {"count": 0, "bonus": persisted_bonus})
	e["count"] = int(e.get("count", 0)) + 1
	counts[sid] = e
	if int(e["count"]) < 3:
		st["manaflow_counts"] = counts
		return
	e["count"] = 0
	var bonus := float(e.get("bonus", 0.0))
	if bonus < 0.08:
		var inc := minf(0.01, 0.08 - bonus)
		e["bonus"] = bonus + inc
		growth["manaflow_percent"] = float(growth.get("manaflow_percent", 0.0)) + inc
		var prior_percent := float(growth["manaflow_percent"]) - inc
		var base_hp := roundi(float(source.max_hp) / maxf(1.0 + prior_percent, 0.01))
		var add := roundi(float(base_hp) * inc)
		if add > 0:
			source.max_hp += add
			source.hp = minf(source.hp + add, source.max_hp)
		if game != null and game.has_method("add_log"):
			game.add_log("灵能循环：%s 最大生命 +%d" % [source.get_display_name(), add])
	else:
		var healed := source.heal(roundi(float(source.max_hp - source.hp) * 0.03), source)
		if game != null and game.has_method("add_log"):
			game.add_log("灵能循环满溢：%s 回复 %d 点生命" % [source.get_display_name(), healed])
	st["manaflow_counts"] = counts

# 我方单位受到普攻/技能伤害后：守护之盾，单次损失>=10%最大生命 -> 8%最大生命护盾，每回合至多一次。
static func on_taken_damage(manager: BattleManager, unit: Unit, attacker: Unit, damage: int, game) -> void:
	if unit == null or not unit.alive or unit.camp != TurnManager.PLAYER_CAMP:
		return
	if not GameSession.run_relics.has("guardian_cord"):
		return
	if damage < roundi(float(unit.max_hp) * 0.10):
		return
	var st: Dictionary = manager.relic_state
	var used: Dictionary = st.get("guardian_turn", {})
	var uid := unit.get_instance_id()
	var turns: Dictionary = st.get("unit_turns", {})
	var own_turn := int(turns.get(uid, 0))
	if int(used.get(uid, -1)) >= own_turn:
		return
	used[uid] = own_turn
	st["guardian_turn"] = used
	_apply_shield_to(unit, roundi(float(unit.max_hp) * 0.08), game)

# 给单位施加无固定时长的护盾（守护精灵/守护之盾共用）；统一走 unit.gain_shield 以便愈心祭司放大与记录护盾信用。
static func _apply_shield_to(unit: Unit, amount: int, game) -> void:
	if unit == null or not unit.alive or amount <= 0:
		return
	var gained := unit.gain_shield(amount, "遗物护盾")
	if gained > 0 and game != null and game.has_method("add_log"):
		game.add_log("%s 获得 %d 点护盾" % [unit.get_display_name(), gained])
