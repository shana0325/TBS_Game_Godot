# 战斗管理器：纯逻辑战斗状态机，负责战局创建与移动/攻击/技能/回合等操作入口，与 UI 解耦。
class_name BattleManager
extends RefCounted

const TILE_SIZE := 64

var grid: Grid
var units: Array = []
var turn_manager: TurnManager
var event_system: EventSystem
var combat_system: CombatSystem
var game = null
var scenario_id: String = ""
var deployed_units: Array = []
var winner: String = ""

func _init(p_scenario_id: String = "battle_01", p_game = null, p_deployed_units: Array = []) -> void:
	scenario_id = p_scenario_id
	game = p_game
	deployed_units = p_deployed_units

func setup() -> void:
	var scenario := _load_scenario()
	grid = Grid.new(int(scenario.get("width", 10)), int(scenario.get("height", 10)))
	_spawn_player_units(scenario)
	_spawn_enemy_units(scenario)
	turn_manager = TurnManager.new(units)
	event_system = EventSystem.new(units, game)
	combat_system = CombatSystem.new(game, event_system, grid)

func _load_scenario() -> Dictionary:
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
		var unit_type := str(entry.get("type", "Goblin"))
		var config: Dictionary = GameDatabase.get_unit(unit_type)
		if config.is_empty():
			continue
		var pos := Vector2i(int(entry.pos[0]), int(entry.pos[1]))
		units.append(Unit.create_from_config(unit_type, TurnManager.ENEMY_CAMP, pos, config))

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
	var reachable := Pathfinder.get_reachable_tiles(grid, start, unit.get_move_points())
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
	if attacker == null or not attacker.alive or attacker.acted:
		return result
	for unit in units:
		if unit is Unit and unit.alive and unit != attacker and unit.camp != attacker.camp:
			if combat_system.is_in_range(attacker, unit):
				result.append(unit)
	return result

func can_attack(attacker: Unit, defender: Unit) -> bool:
	return attacker != null and defender != null and defender.alive and not attacker.acted \
		and attacker.camp != defender.camp and combat_system.is_in_range(attacker, defender)

func perform_attack(attacker: Unit, defender: Unit) -> void:
	if not can_attack(attacker, defender):
		return
	# 攻击前触发
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_ATTACK_START, {"actor": attacker, "user": attacker, "target": defender})
	var damage := combat_system.perform_attack(attacker, defender)
	# 反射：防御方有反射 buff 时，把部分伤害反射回攻击者
	if defender.alive and defender.get_reflect_percent() > 0.0 and damage > 0:
		var reflect_damage := roundi(damage * defender.get_reflect_percent())
		if reflect_damage > 0:
			attacker.take_damage(reflect_damage, game)
			if game != null and game.has_method("add_log"):
				game.add_log("%s 反射 %d 点伤害给 %s" % [defender.get_display_name(), reflect_damage, attacker.get_display_name()])
	# 攻击时触发
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_ATTACK, {"actor": attacker, "user": attacker, "target": defender})
	# 受击触发
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_BE_ATTACKED, {"actor": defender, "user": defender, "target": attacker})
	# 击杀/死亡触发
	if not defender.alive:
		SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_KILL, {"actor": attacker, "user": attacker, "target": defender})
		SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_DEATH, {"actor": defender, "user": defender, "target": attacker})
	# 攻击后触发（附带技能伤害阶段）
	SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_ATTACK_END, {"actor": attacker, "user": attacker, "target": defender})
	_check_winner()

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
		if unit is Unit and unit.alive and unit != user and unit.camp == target_camp:
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
	skill.execute(user, [target], game)
	if event_system != null:
		event_system.dispatch(BattleEvent.new(EventTypes.ON_SKILL_CAST, user, target, {"skill": skill.name}))
	_check_winner()

func get_nearest_target(unit: Unit) -> Unit:
	var nearest: Unit = null
	var best := 999999
	for other in units:
		if other is Unit and other.alive and other.camp != unit.camp:
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

# 在指定位置附近召唤一个新单位（召唤类技能用）。返回生成的单位或 null。
func spawn_unit(unit_type: String, camp: String, near_pos: Vector2i) -> Unit:
	var config: Dictionary = GameDatabase.get_unit(unit_type)
	if config.is_empty():
		return null
	var spawn_pos := _find_empty_adjacent(near_pos)
	if spawn_pos.x < 0:
		return null
	var unit := Unit.create_from_config(unit_type, camp, spawn_pos, config)
	units.append(unit)
	unit.turn_timer = 0.0
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

# 初始化战斗：启动每个单位的独立行动计时器。
func setup_battle() -> void:
	if turn_manager != null:
		turn_manager.setup()

# 自走棋主驱动：每帧推进时间，处理所有到点单位的自动行动。
# 返回本帧发生的事件列表（供 UI 播放动画/日志）。
func tick(delta: float) -> Array:
	if turn_manager == null or winner != "":
		return []
	var due_units: Array = turn_manager.tick(delta)
	var events: Array = []
	for unit in due_units:
		if not unit.alive:
			continue
		# 行动开始 tick
		unit.tick_turn_start(game)
		SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_TURN_START, {"actor": unit, "user": unit})
		var prev_pos: Vector2i = unit.pos
		var acted := _auto_act(unit)
		if acted:
			events.append({
				"unit": unit,
				"action": acted.get("action", ""),
				"target": acted.get("target", null),
				"to": acted.get("to", null),
				"from": prev_pos
			})
		unit.tick_turn_end(game)
		# 行动结束触发 + 冷却推进
		SkillTriggerSystem.dispatch(self, SkillTriggerSystem.ON_TURN_END, {"user": unit})
		_tick_skill_cooldowns(unit)
		_check_winner()
		if winner != "":
			break
	return events

# 推进单位技能冷却。
func _tick_skill_cooldowns(unit: Unit) -> void:
	for skill in unit.skills:
		if skill is Skill:
			skill.tick_cooldown()

# 单位自动行动：射程内有敌人则攻击；否则移动（可能因嘲讽被引导），移动后再尝试攻击。
func _auto_act(unit: Unit) -> Dictionary:
	if not unit.alive:
		return {}
	# 射程内是否有敌人
	var targets := get_attack_targets(unit)
	if targets.size() > 0:
		var target: Unit = targets[0]
		perform_attack(unit, target)
		return {"action": "attack", "target": target}
	# 无目标：移动（含嘲讽引导），移动后再次尝试攻击
	var decision := EnemyAI.get_decision(self, unit)
	if decision.action == "move":
		var to: Vector2i = decision.to
		move_unit(unit, to)
		# 移动后再尝试攻击
		var new_targets := get_attack_targets(unit)
		if new_targets.size() > 0:
			var target2: Unit = new_targets[0]
			perform_attack(unit, target2)
			return {"action": "move_attack", "target": target2, "to": to}
		return {"action": "move", "to": to}
	return {"action": "wait"}

func _check_winner() -> void:
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

# 胜利奖励：给所有存活玩家单位加经验并写回 roster，返回 {unit_type, exp_gained, levels_gained} 列表。
func grant_victory_exp(reward: int = 100) -> Array:
	var reports: Array = []
	if winner != TurnManager.PLAYER_CAMP:
		return reports
	for unit in units:
		if not (unit is Unit) or not unit.alive or unit.camp != TurnManager.PLAYER_CAMP:
			continue
		if unit.unit_id == "":
			continue
		var rd := _find_roster_unit(unit.unit_id)
		if rd.is_empty():
			continue
		var result := ProgressManager.add_exp(rd, reward)
		reports.append({
			"unit_type": unit.unit_type,
			"exp_gained": int(result.get("exp_gained", 0)),
			"levels_gained": int(result.get("levels_gained", 0)),
			"level": int(rd.get("level", 1))
		})
	ProgressManager.save_roster()
	return reports

func _find_roster_unit(unit_id: String) -> Dictionary:
	for rd in GameDatabase.player_roster.get("units", []):
		if str(rd.get("id", "")) == unit_id:
			return rd
	return {}
