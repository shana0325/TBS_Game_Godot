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
var deployed_positions: Dictionary = {}
var winner: String = ""

func _init(p_scenario_id: String = "battle_01", p_game = null, p_deployed_positions: Dictionary = {}) -> void:
	scenario_id = p_scenario_id
	game = p_game
	deployed_positions = p_deployed_positions

func setup() -> void:
	var scenario := _load_scenario()
	if int(scenario.get("side_width", 0)) > 0:
		grid = Grid.new()
		grid.setup_dual(
			int(scenario.get("side_width", 4)),
			int(scenario.get("height", 3)),
			int(scenario.get("gap_width", 2))
		)
	else:
		grid = Grid.new(int(scenario.get("width", 10)), int(scenario.get("height", 8)))
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
		if deployed_positions.has(index):
			var dp = deployed_positions[index]
			pos = Vector2i(int(dp[0]), int(dp[1]))
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
	combat_system.perform_attack(attacker, defender)
	turn_manager.mark_acted(attacker)
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
	skill.execute(user, target, game)
	turn_manager.mark_acted(user)
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

# 战斗距离：同战场 Chebyshev；跨战场逻辑列差（忽略 Y），与 CombatSystem 保持一致。
func _get_combat_distance(from: Unit, to_pos: Vector2i) -> int:
	if grid != null and grid.is_dual():
		var from_side := grid.get_side_for_position(from.pos.x, from.pos.y)
		var to_side := grid.get_side_for_position(to_pos.x, to_pos.y)
		if from_side != "" and to_side != "" and from_side != to_side:
			return grid.cross_grid_distance(from.pos.x, to_pos.x)
	return maxi(abs(from.pos.x - to_pos.x), abs(from.pos.y - to_pos.y))

func wait(unit: Unit) -> void:
	if unit != null:
		turn_manager.mark_acted(unit)

# 切换回合，并对旧阵营执行回合结束 tick、对新阵营执行回合开始 tick。
func next_turn() -> void:
	if turn_manager == null:
		return
	var prev_camp := turn_manager.current_camp
	turn_manager.next_turn()
	for unit in units:
		if unit is Unit and unit.alive and unit.camp == prev_camp:
			unit.tick_turn_end(game)
	for unit in units:
		if unit is Unit and unit.alive and unit.camp == turn_manager.current_camp:
			unit.tick_turn_start(game)
	_check_winner()

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
