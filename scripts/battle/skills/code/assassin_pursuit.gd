# 刺客固有技能：锁定目标死亡时切换到最低生命敌人，并瞬移到其身边。
extends CodeSkill

const ADJACENT_OFFSETS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

# 声明供战斗触发系统和技能详情使用的元数据。
func _init() -> void:
	name = "索命追击"
	desc = "当前攻击目标死亡后，立即锁定当前生命值最低的敌人，并瞬移至其旁边的空格。"
	trigger = SkillTriggerSystem.ON_TARGET_DEATH
	condition = {"target_type": "self"}
	common = false
	searchable = false
	tags = ["固有", "追击", "位移"]

# 仅在原锁定目标死亡且仍有存活敌人时触发。
func check_condition(battle, context: Dictionary) -> bool:
	var user: Unit = context.get("actor")
	var fallen: Unit = context.get("target")
	if user == null or fallen == null or fallen.alive or user.get_current_target() != fallen:
		return false
	for enemy in battle.units:
		if enemy is Unit and enemy.alive and enemy.camp != user.camp:
			return true
	return false

# 选取当前生命最低的敌人；有多个可用相邻空格时选离原位置最近的一格。
func execute(user: Unit, _targets: Array, _game = null, battle = null) -> Array:
	var weakest: Unit = null
	for enemy in battle.units:
		if not (enemy is Unit) or not enemy.alive or enemy.camp == user.camp:
			continue
		if weakest == null or enemy.hp < weakest.hp:
			weakest = enemy
	if weakest == null:
		return []
	user.set_current_target(weakest)
	if Grid.manhattan_distance(user.pos, weakest.pos) == 1:
		return []
	var best_cell := user.pos
	var best_distance := 999999
	for offset in ADJACENT_OFFSETS:
		var cell: Vector2i = weakest.pos + offset
		if not battle.grid.in_bounds(cell.x, cell.y):
			continue
		if not battle.grid.get_tile(cell.x, cell.y).passable or battle.get_unit_at(cell) != null:
			continue
		var distance := Grid.manhattan_distance(user.pos, cell)
		if distance < best_distance:
			best_cell = cell
			best_distance = distance
	if best_cell != user.pos:
		battle.move_unit_to(user, best_cell)
	return []
