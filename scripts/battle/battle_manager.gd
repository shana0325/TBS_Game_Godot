# 战斗管理器：纯逻辑战斗状态机，负责战局创建与独立移动/普攻/技能计时，与 UI 解耦。
class_name BattleManager
extends RefCounted

signal battle_finished(winner_camp: String)

const TILE_SIZE := 64

var grid: Grid
var units: Array = []
var turn_manager: TurnManager
var event_system: EventSystem
var combat_system: CombatSystem
var game = null
var scenario_id: String = ""
var scenario_name: String = ""
var scenario_override: Dictionary = {}
var deployed_units: Array = []
var winner: String = ""
var relic_revive_used: bool = false
var active_damage_chain: Dictionary = {}
# 遗物战斗运行时状态（由 RelicSystem.begin_battle 初始化，按秒和伤害事件读写）。
var relic_state: Dictionary = {}
# 战斗经过秒数：供技能限流/时间窗等取时（tick 累加）。
var battle_time: float = 0.0
# 最近一次非特效命中的上下文（含 hp_lost/damage_kind/damage），供 on_hit/on_taaken_damage 技能读取。
var active_hit: Dictionary = {}
var battle_started: bool = false
var awakened_this_tick: Array = []

func get_battle_time() -> float:
	return battle_time

func get_active_hit() -> Dictionary:
	return active_hit

func _init(p_scenario_id: String = "battle_01", p_game = null, p_deployed_units: Array = [], p_scenario_override: Dictionary = {}) -> void:
	scenario_id = p_scenario_id
	game = p_game
	deployed_units = p_deployed_units
	scenario_override = p_scenario_override

func setup() -> void:
	var scenario := _load_scenario()
	scenario_name = str(scenario.get("name", "战斗"))
	grid = Grid.new(int(scenario.get("width", 10)), int(scenario.get("height", 10)))
	_spawn_player_units(scenario)
	_spawn_enemy_units(scenario)
	turn_manager = TurnManager.new(units)
	event_system = EventSystem.new(units, game)
	combat_system = CombatSystem.new(game, event_system, grid, self)
	for unit in units:
		if unit is Unit:
			unit.set_battle(self)

func _load_scenario() -> Dictionary:
	# 优先使用运行时覆盖的场景（爬塔分层生成），否则读关卡文件
	if not scenario_override.is_empty():
		return scenario_override
	var path := "res://data/scenario/%s.json" % scenario_id
	if not FileAccess.file_exists(path):
		push_error("缺少关卡文件: %s" % path)
		return {"width": 10, "height": 8, "player_units": [], "enemy_units": []}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"width": 10, "height": 8, "player_units": [], "enemy_units": []}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"width": 10, "height": 8, "player_units": [], "enemy_units": []}
	return parsed

func _spawn_player_units(scenario: Dictionary) -> void:
	var roster_units: Array = GameDatabase.player_roster.get("units", [])
	# 优先使用部署结果（可含 mod 单位）；否则回退到关卡默认编成。
	if not deployed_units.is_empty():
		_spawn_from_deployed(roster_units)
		return
	for entry in scenario.get("player_units", []):
		var index := int(entry.get("roster_index", -1))
		if index < 0 or index >= roster_units.size():
			continue
		var rd: Dictionary = roster_units[index]
		var unit_type := str(rd.get("type", "Hero"))
		var config: Dictionary = GameDatabase.get_unit(unit_type)
		if config.is_empty():
			continue
		var pos := Vector2i(int(entry.pos[0]), int(entry.pos[1]))
		units.append(Unit.create_from_config(unit_type, TurnManager.PLAYER_CAMP, pos, config, rd, GameDatabase))

# 从部署列表生成玩家单位：roster_index>=0 用编成成长数据，否则用单位模板（mod 角色）。
func _spawn_from_deployed(roster_units: Array) -> void:
	for entry in deployed_units:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var unit_type := str(entry.get("type", "Hero"))
		var config: Dictionary = GameDatabase.get_unit(unit_type)
		if config.is_empty():
			continue
		var index := int(entry.get("roster_index", -1))
		var rd: Dictionary = {}
		if index >= 0 and index < roster_units.size():
			rd = roster_units[index]
		var pos: Vector2i = entry.get("pos", Vector2i(0, 0))
		units.append(Unit.create_from_config(unit_type, TurnManager.PLAYER_CAMP, pos, config, rd, GameDatabase))

func _spawn_enemy_units(scenario: Dictionary) -> void:
	for entry in scenario.get("enemy_units", []):
		var unit_type := str(entry.get("type", "Warrior"))
		var config: Dictionary = GameDatabase.get_unit(unit_type)
		if config.is_empty():
			continue
		var pos := Vector2i(int(entry.pos[0]), int(entry.pos[1]))
		# 敌人额外技能走技能槽通道（塔层生成器按层配技能）；属性倍率用于按层成长
		var roster_data: Dictionary = {
			"equipped_skills": entry.get("skills", []),
			"stat_multiplier": float(entry.get("stat_multiplier", 1.0)),
		}
		units.append(Unit.create_from_config(unit_type, TurnManager.ENEMY_CAMP, pos, config, roster_data))

func get_unit_at(cell: Vector2i) -> Unit:
	for unit in units:
		if unit is Unit and unit.alive and unit.pos == cell:
			return unit
	return null

func get_move_tiles(unit: Unit) -> Array:
	var result: Array = []
	if unit == null or not unit.alive or unit.acted or unit.moved:
		return result
	var start := grid.get_tile(unit.pos.x, unit.pos.y)
	var blocked := get_occupied_cells(unit)
	var reachable := Pathfinder.get_reachable_tiles(grid, start, unit.get_move_points(), blocked)
	for tile in reachable:
		if tile == null:
			continue
		var cell: Vector2i = tile.get_position()
		if cell == unit.pos:
			continue
		var occupant := get_unit_at(cell)
		if occupant != null and occupant != unit:
			continue
		result.append(cell)
	return result

func move_unit(unit: Unit, cell: Vector2i) -> bool:
	if unit == null or not unit.alive or unit.acted or unit.moved:
		return false
	if not get_move_tiles(unit).has(cell):
		return false
	unit.move_to(cell)
	unit.moved = true
	if event_system != null:
		event_system.dispatch(BattleEvent.new(EventTypes.ON_MOVE, unit, null, {"to": cell}))
	return true

# 强制位移（位移类技能用）：无视移动力把单位移到指定格。
# 目标格必须在地图内、可通行且未被占用。返回是否成功。
func move_unit_to(unit: Unit, cell: Vector2i) -> bool:
	if unit == null or not unit.alive:
		return false
	if not grid.in_bounds(cell.x, cell.y):
		return false
	if not grid.get_tile(cell.x, cell.y).passable:
		return false
	var occupant := get_unit_at(cell)
	if occupant != null and occupant != unit:
		return false
	unit.move_to(cell)
	if event_system != null:
		event_system.dispatch(BattleEvent.new(EventTypes.ON_MOVE, unit, null, {"to": cell}))
	return true

func get_attack_targets(attacker: Unit) -> Array:
	var result: Array = []
	if attacker == null or not attacker.alive or attacker.acted or attacker.is_dormant():
		return result
	for unit in units:
		if unit is Unit and can_target_enemy(attacker, unit):
			if combat_system.is_in_range(attacker, unit):
				result.append(unit)
	var taunters: Array = result.filter(func(candidate: Unit) -> bool: return candidate.has_taunt())
	if not taunters.is_empty():
		result = taunters
	var preferred := attacker.get_current_target()
	if result.has(preferred):
		result.erase(preferred)
		result.push_front(preferred)
	return result

func can_attack(attacker: Unit, defender: Unit) -> bool:
	return attacker != null and attacker.alive and defender != null and defender.alive and not attacker.acted \
		and not attacker.is_dormant() and can_target_enemy(attacker, defender) \
		and combat_system.is_in_range(attacker, defender) \
		and (not _has_attackable_taunter(attacker) or defender.has_taunt())

# 潜行仅在同阵营还有未潜行的存活单位时阻止敌方单目标选择。
func can_target_enemy(attacker: Unit, target: Unit) -> bool:
	if attacker == null or target == null or not target.alive or attacker.camp == target.camp:
		return false
	if not target.is_stealthed():
		return true
	for other in units:
		if other is Unit and other.alive and other.camp == target.camp and not other.is_stealthed():
			return false
	return true

# 嘲讽仅限制普攻的可攻击目标，不改变技能的指定目标。
func _has_attackable_taunter(attacker: Unit) -> bool:
	for other in units:
		if other is Unit and other.has_taunt() and can_target_enemy(attacker, other) \
				and combat_system.is_in_range(attacker, other):
			return true
	return false

# 执行一次攻击，返回 { "damage": int, "crit": bool }（供 UI 飙字等使用）。
func perform_attack(attacker: Unit, defender: Unit) -> Dictionary:
	var empty := {"damage": 0, "crit": false}
	if not can_attack(attacker, defender):
		return empty
	# 攻击前触发
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_ATTACK_START, {"actor": attacker, "user": attacker, "target": defender})
	if not can_attack(attacker, defender):
		return empty
	attacker.set_current_target(defender)
	# 普攻目标已确认，在扣血和伤害计算前触发；本次偷取等属性变化会影响本次普攻。
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_ATTACK_HIT_BEFORE,
		{"actor": attacker, "user": attacker, "target": defender, "damage_kind": DamageSystem.ATTACK})
	if not can_attack(attacker, defender):
		return empty
	var result := combat_system.perform_attack(attacker, defender, 0, get_final_damage_multiplier())
	attacker.attack_count += 1
	var damage: int = result.get("damage", 0)
	var crit: bool = result.get("crit", false)
	# 技能反射和遗物反射分别结算，避免遗物伤害被误算成技能伤害。
	if defender.alive and damage > 0:
		for reflect_kind in [DamageSystem.SKILL, DamageSystem.EFFECT]:
			var reflect_damage := roundi(damage * defender.get_reflect_percent(reflect_kind))
			if reflect_damage <= 0:
				continue
			DamageSystem.apply(defender, attacker, {"damage_kind": reflect_kind,
				"raw_damage": reflect_damage, "true_damage": true}, self, game)
			if game != null and game.has_method("add_log"):
				game.add_log("%s 反射 %d 点伤害给 %s" % [defender.get_display_name(), reflect_damage, attacker.get_display_name()])
	# 攻击时触发
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_ATTACK, {"actor": attacker, "user": attacker, "target": defender, "crit": crit})
	# 普攻的伤害联动在攻击技能结算后发出，维持原有攻击事件顺序。
	if int(result.get("actual_damage", 0)) > 0:
		on_damage_resolved(attacker, defender, result)
	# 受击触发
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_BE_ATTACKED, {"actor": defender, "user": defender, "target": attacker})
	# 攻击后触发（附带技能伤害阶段）
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_ATTACK_END, {"actor": attacker, "user": attacker, "target": defender})
	_check_winner()
	return result

# 收集其他存活单位占据的格子，供移动范围和动画寻路统一避让。
func get_occupied_cells(excluded_unit: Unit = null) -> Dictionary:
	var blocked := {}
	for other in units:
		if other is Unit and other.alive and other != excluded_unit:
			blocked[other.pos] = true
	return blocked

# 统一分发伤害后的联动；特效伤害只结算击杀和死亡，不触发新的伤害附加效果。
func on_damage_resolved(source: Unit, target: Unit, report: Dictionary) -> void:
	var kind := str(report.get("damage_kind", DamageSystem.EFFECT))
	var damage := int(report.get("actual_damage", 0))
	if damage <= 0:
		return
	RelicSystem.on_shield_break(self, source, target, report)
	RelicSystem.on_critical_hit(self, source, report)
	if kind != DamageSystem.EFFECT:
		var previous_chain := active_damage_chain
		active_damage_chain = previous_chain if not previous_chain.is_empty() else {"used": []}
		var context := {"actor": source, "user": source, "target": target,
			"damage": damage, "damage_kind": kind, "crit": bool(report.get("crit", false)),
			"hp_lost": int(report.get("result", {}).get("hp_lost", 0)),
			"proc_chain": active_damage_chain}
		active_hit = context
		if event_system != null:
			event_system.dispatch(BattleEvent.new(EventTypes.ON_HIT, source, target, context))
		if source != null:
			SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_HIT, context)
			RelicSystem.on_hit(self, source, target, kind, game)
		if target.alive:
			SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_TAKEN_DAMAGE,
				{"actor": target, "user": target, "target": source, "damage": damage,
				"damage_kind": kind, "hp_lost": int(report.get("result", {}).get("hp_lost", 0)),
				"proc_chain": active_damage_chain})
			if source != null:
				RelicSystem.on_taken_damage(self, target, source, damage, game)
		active_damage_chain = previous_chain
	if not bool(report.get("result", {}).get("lethal", false)):
		return
	if event_system != null:
		event_system.dispatch(BattleEvent.new(EventTypes.ON_KILL, source, target,
			{"damage": damage, "damage_kind": kind}))
	if source != null:
		SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_KILL,
			{"actor": source, "user": source, "target": target})
		RelicSystem.on_kill(self, source, game)
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_DEATH,
		{"actor": target, "user": target, "target": source})
	for ally in units:
		if ally is Unit and ally.alive and ally.camp == target.camp and ally != target:
			SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_ALLY_DEATH,
				{"actor": ally, "user": ally, "target": target})
			if not target.is_summoned:
				SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_AVENGE,
					{"actor": ally, "user": ally, "target": target})
	# 锁定目标死亡时通知追击者；即使击杀来自其他单位也能重选目标。
	for pursuer in units:
		if pursuer is Unit and pursuer.alive and pursuer.get_current_target() == target:
			SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_TARGET_DEATH,
				{"actor": pursuer, "user": pursuer, "target": target})
			if pursuer.get_current_target() == target:
				pursuer.set_current_target(null)
	RelicSystem.on_death(self, target, game)

func is_damage_skill(skill: Skill) -> bool:
	for effect in skill.effects:
		if effect is Dictionary and str(effect.get("type", "")) == "damage":
			return true
	return false

func get_skill_targets(user: Unit, skill: Skill) -> Array:
	var result: Array = []
	if user == null or skill == null or user.acted:
		return result
	var target_camp := user.camp if is_damage_skill(skill) else user.camp
	if is_damage_skill(skill):
		target_camp = TurnManager.ENEMY_CAMP if user.camp == TurnManager.PLAYER_CAMP else TurnManager.PLAYER_CAMP
	else:
		target_camp = user.camp
	for unit in units:
		if unit is Unit and unit.alive and unit != user and unit.camp == target_camp \
				and (unit.camp == user.camp or can_target_enemy(user, unit)):
			var distance := _get_combat_distance(user, unit.pos)
			if distance >= skill.min_range and distance <= skill.max_range:
				result.append(unit)
	return result

func can_cast_skill(user: Unit, skill: Skill, target: Unit) -> bool:
	if user == null or skill == null or target == null or not target.alive:
		return false
	return get_skill_targets(user, skill).has(target)

func cast_skill(user: Unit, skill: Skill, target: Unit) -> void:
	if not can_cast_skill(user, skill, target):
		return
	skill.execute(user, [target], game, self)
	if event_system != null:
		event_system.dispatch(BattleEvent.new(EventTypes.ON_SKILL_CAST, user, target, {"skill": skill.name}))
	_check_winner()

func get_nearest_target(unit: Unit) -> Unit:
	var nearest: Unit = null
	var best := 999999
	for other in units:
		if other is Unit and can_target_enemy(unit, other):
			var d := _get_combat_distance(unit, other.pos)
			if d < best:
				best = d
				nearest = other
	return nearest

# 战斗距离：曼哈顿距离（横向+纵向），与 CombatSystem 保持一致。
func _get_combat_distance(from: Unit, to_pos: Vector2i) -> int:
	return Grid.manhattan_distance(from.pos, to_pos)

func wait(unit: Unit) -> void:
	pass

# 在指定位置附近召唤单位，并继承召唤者的关卡属性倍率。
func spawn_unit(unit_type: String, camp: String, near_pos: Vector2i, summoner: Unit = null) -> Unit:
	var config: Dictionary = GameDatabase.get_unit(unit_type)
	if config.is_empty():
		return null
	var spawn_pos := _find_empty_adjacent(near_pos)
	if spawn_pos.x < 0:
		return null
	var roster_data := {"stat_multiplier": summoner.stat_multiplier} if summoner != null else {}
	var unit := Unit.create_from_config(unit_type, camp, spawn_pos, config, roster_data)
	unit.is_summoned = true
	unit.set_battle(self)
	units.append(unit)
	unit.attack_timer = 0.0
	unit.move_timer = 0.0
	RelicSystem.on_summon(self, summoner, unit)
	if battle_started:
		SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_ENTER_BATTLE,
			{"actor": unit, "user": unit})
		SkillTriggerSystem.dispatch(self, SkillTriggerSystem.PASSIVE,
			{"actor": unit, "user": unit})
	return unit

# 找 near_pos 附近最近的空格。
func _find_empty_adjacent(near_pos: Vector2i) -> Vector2i:
	for radius in range(0, 3):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius and radius > 0:
					continue
				var cell := near_pos + Vector2i(dx, dy)
				if not grid.in_bounds(cell.x, cell.y):
					continue
				if not grid.get_tile(cell.x, cell.y).passable:
					continue
				if get_unit_at(cell) == null:
					return cell
	return Vector2i(-1, -1)

# 初始化战斗：应用遗物效果，启动每个单位的独立行动计时器，并触发战斗开始技能。
func setup_battle() -> void:
	# Run 遗物与跨战斗成长先应用到玩家单位。
	RelicSystem.apply_run_bonuses(self)
	# 遗物战斗运行时状态初始化（标记/计时/计数类效果）
	RelicSystem.begin_battle(self)
	if turn_manager != null:
		turn_manager.setup()
	battle_started = true
	for unit in units:
		if unit is Unit:
			for skill in unit.skills:
				if skill is Skill and skill.trigger == SkillTriggerSystem.ON_TIMER:
					skill.interval_remaining = skill.interval_seconds
	RelicSystem.prepare_first_active_cast(self)
	# 战吼与战斗开始技能分别分发；召唤入场只触发战吼。
	var initial_units := units.duplicate()
	for unit in initial_units:
		if unit is Unit and unit.alive:
			SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_ENTER_BATTLE, {"actor": unit, "user": unit})
	for unit in initial_units:
		if unit is Unit and unit.alive:
			SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_BATTLE_START, {"actor": unit, "user": unit})
	# passive：常驻被动技能在战斗开始即生效
	for unit in units:
		if unit is Unit and unit.alive:
			SkillTriggerSystem.dispatch(self, SkillTriggerSystem.PASSIVE, {"actor": unit, "user": unit})
	# on_round_start 保留旧触发标识，但只在战斗开始时各触发一次。
	for unit in units:
		if unit is Unit and unit.alive:
			SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_ROUND_START, {"actor": unit, "user": unit})

# 自走棋主驱动：每帧推进时间，处理所有到点单位的自动行动。
# 返回本帧发生的事件列表（供 UI 播放动画/日志）。
func tick(delta: float) -> Array:
	if turn_manager == null or winner != "":
		return []
	battle_time += maxf(delta, 0.0)
	awakened_this_tick.clear()
	var due_units: Array = turn_manager.tick(delta)
	var events: Array = []
	_tick_statuses(delta)
	_tick_seconds_skill_cooldowns(delta)
	_tick_timed_skills(delta)
	RelicSystem.tick_battle(self, delta)
	for unit in due_units:
		if winner != "":
			break
		if not unit.alive or unit.is_dormant() or awakened_this_tick.has(unit):
			continue
		# 冻结期间不能移动；下一次普攻就绪时跳过该次普攻并解除冻结。
		if unit.has_status("frozen"):
			if unit.attack_timer >= unit.get_effective_attack_interval():
				unit.attack_timer = 0.0
				unit.remove_status("frozen")
			continue
		var prev_pos: Vector2i = unit.pos
		var acted := _auto_act(unit)
		if acted:
			events.append({
				"unit": unit,
				"action": acted.get("action", ""),
				"target": acted.get("target", null),
				"to": acted.get("to", null),
				"from": prev_pos,
				"damage": acted.get("damage", 0),
				"crit": acted.get("crit", false)
			})
		_check_winner()
		if winner != "":
			break
	return events

# 每完成一次普攻推进事件技能的普攻计数冷却。
func _tick_skill_cooldowns(unit: Unit) -> void:
	for skill in unit.skills:
		if skill is Skill and skill.trigger != SkillTriggerSystem.ON_TIMER:
			skill.tick_cooldown()

# 战斗中持续推进事件技能的秒冷却，与普攻次数无关。
func _tick_seconds_skill_cooldowns(delta: float) -> void:
	for unit in units:
		if unit is Unit and unit.alive:
			for skill in unit.skills:
				if skill is Skill:
					skill.tick_seconds_cooldown(delta)

# 每帧检查定时技能；到点立即尝试施放，无合法目标时保持就绪。
func _tick_timed_skills(delta: float) -> void:
	for unit in units:
		if winner != "":
			return
		if not (unit is Unit) or not unit.alive or unit.is_dormant() or unit.is_silenced():
			continue
		for skill in unit.skills:
			if not (skill is Skill) or skill.trigger != SkillTriggerSystem.ON_TIMER:
				continue
			skill.tick_interval(delta)
			if not skill.is_ready():
				continue
			var context := {"actor": unit, "user": unit, "skill_filter": skill}
			var targets := Skill.units_in_range(self, unit, "enemy", skill.min_range, skill.max_range)
			if not targets.is_empty():
				context["target"] = targets[0]
			var casted: Array = SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_TIMER, context)
			# 回响节点：每次按秒触发技能实际施放成功后计数，累计 3 次缩短其他定时技能。
			if not casted.is_empty():
				SkillKit.register_timed_cast(unit, skill)
			_check_winner()

# 普攻与移动各用自己的就绪计时；射程内等待普攻，射程外按移动计时靠近。
func _auto_act(unit: Unit) -> Dictionary:
	if not unit.alive:
		return {}
	var targets := get_attack_targets(unit)
	if targets.size() > 0:
		if unit.attack_timer >= unit.get_effective_attack_interval():
			var target: Unit = targets[0]
			var res := _auto_attack(unit, target)
			return {"action": "attack", "target": target, "damage": res.get("damage", 0), "crit": res.get("crit", false)}
		return {}
	if unit.get_move_points() <= 0 or unit.move_timer < unit.move_interval:
		return {}
	var decision := EnemyAI.get_decision(self, unit)
	if decision.action == "move":
		var to: Vector2i = decision.to
		if not move_unit(unit, to):
			return {}
		unit.move_timer = 0.0
		var new_targets := get_attack_targets(unit)
		if new_targets.size() > 0 and unit.attack_timer >= unit.get_effective_attack_interval():
			var target2: Unit = new_targets[0]
			var res2 := _auto_attack(unit, target2)
			return {"action": "move_attack", "target": target2, "to": to, "damage": res2.get("damage", 0), "crit": res2.get("crit", false)}
		return {"action": "move", "to": to}
	return {}

# 自动普攻只推进普攻事件与按普攻次数计算的技能冷却。
func _auto_attack(unit: Unit, target: Unit) -> Dictionary:
	unit.attack_timer = 0.0
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_TURN_START, {"actor": unit, "user": unit})
	var result := perform_attack(unit, target)
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_TURN_END, {"actor": unit, "user": unit})
	_tick_skill_cooldowns(unit)
	return result

func _check_winner() -> void:
	if winner != "":
		return
	var players := 0
	var enemies := 0
	for unit in units:
		if unit is Unit and unit.alive:
			if unit.camp == TurnManager.PLAYER_CAMP:
				players += 1
			elif unit.camp == TurnManager.ENEMY_CAMP:
				enemies += 1
	if players == 0:
		winner = TurnManager.ENEMY_CAMP
	elif enemies == 0:
		winner = TurnManager.PLAYER_CAMP
	if winner != "":
		battle_finished.emit(winner)

# 对外提供本场战斗当前的狂暴最终伤害增幅，供 UI 和非普通攻击效果复用。
func get_final_damage_bonus_percent() -> float:
	return turn_manager.get_final_damage_bonus_percent() if turn_manager != null else 0.0

func get_final_damage_multiplier() -> float:
	return turn_manager.get_final_damage_multiplier() if turn_manager != null else 1.0

# 单位级伤害倍率：委托遗物系统按来源/目标/伤害种类汇总（处决/先手/背水/层积风暴等）。
func get_damage_bonus_percent(source: Unit, target: Unit, kind: String) -> float:
	var bonus := RelicSystem.get_damage_bonus_percent(source, target, kind, relic_state) \
		+ (0.0 if source != null and source.is_silenced() else SkillKit.passive_damage_bonus(source, target))
	if source != null and not source.is_silenced():
		for skill in source.skills:
			if skill is Skill:
				bonus += (skill as Skill).get_damage_bonus_percent(source, target, kind)
	return bonus

# 按秒推进状态；持续伤害与状态到期不依赖单位行动频率。
func _tick_statuses(delta: float) -> void:
	for unit in units.duplicate():
		if not (unit is Unit) or not unit.alive:
			continue
		for buff in unit.buffs.duplicate():
			if not unit.alive:
				break
			buff.tick_seconds(unit, delta, game, self)
			if buff.status == "dormant" and buff.seconds_left <= 0.0:
				awaken_unit(unit)
		unit.remove_expired_buffs()
	_check_winner()

# 苏醒只执行一次；保持生命比例，并从苏醒时重新开始行动计时。
func awaken_unit(unit: Unit) -> void:
	if unit == null or not unit.alive:
		return
	for buff in unit.buffs.duplicate():
		if buff.status != "dormant":
			continue
		var awaken_effects: Array = buff.raw_data.get("awaken_effects", [])
		unit.buffs.erase(buff)
		unit.attack_timer = 0.0
		unit.move_timer = 0.0
		awakened_this_tick.append(unit)
		EffectSystem.apply_effects(unit, unit, awaken_effects, game, self)
		return

# 实时计算同阵营光环；施放者休眠、沉默或死亡时立刻失效。
func get_aura_stat_bonus(target: Unit, stat: String) -> float:
	var bonus := 0.0
	for source in units:
		if not (source is Unit) or not source.alive or source.camp != target.camp \
				or source.is_silenced() or source.is_dormant():
			continue
		for buff in source.buffs:
			if buff.aura_range > 0 and Grid.manhattan_distance(source.pos, target.pos) <= buff.aura_range:
				bonus += float(buff.modifiers.get(stat, 0.0))
	return bonus
