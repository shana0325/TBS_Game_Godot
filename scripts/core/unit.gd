# 战斗单位：Unit 组合基础配置、运行时状态、技能和 Buff。
class_name Unit
extends RefCounted

const MAX_STARS := 3

var unit_id: String = ""
var display_name: String = "Unit"
var unit_type: String = ""
var tags: Array = []
var camp: String = "player"
var team_id: int = 0
var pos: Vector2i = Vector2i.ZERO
# 本场战斗锁定的普攻目标使用弱引用，避免交战双方互相持有导致无法释放。
var current_target_ref: WeakRef = null
var config: Dictionary = {}
var level: int = 1
var star: int = 1
var hp: float = 0.0
var max_hp: float = 0.0
var acted: bool = false
var moved: bool = false
var alive: bool = true
var turn_interval: float = 4.0
var turn_timer: float = 0.0
var permanent_mods: Dictionary = {}
var battle_stat_mods: Dictionary = {}
var percent_mods: Dictionary = {}
var stat_multiplier: float = 1.0
var skills: Array = []
var buffs: Array = []
var equipped_skill_names: Array = []
var learned_skill_names: Array = []
# 战斗运行时状态库（叠层/按目标计数/限流/时间窗），由技能和遗物共用。
var runtime: UnitRuntimeState = UnitRuntimeState.new()

static func create_from_config(
	unit_type: String,
	camp: String,
	spawn_pos: Vector2i,
	config_data: Dictionary,
	roster_data: Dictionary = {},
	game_db = null
) -> Unit:
	var unit := Unit.new()
	unit.unit_id = str(roster_data.get("id", ""))
	unit.unit_type = unit_type
	unit.display_name = str(config_data.get("display_name", unit_type))
	unit.tags = _string_array(config_data.get("tags", []))
	unit.camp = camp
	unit.pos = spawn_pos
	unit.config = config_data
	unit.level = int(roster_data.get("level", 1))
	unit.star = clampi(int(roster_data.get("star", 1)), 1, MAX_STARS)
	unit.turn_interval = float(config_data.get("turn_interval", 4.0))
	unit.permanent_mods = roster_data.get("permanent_mods", {})
	# 敌方属性倍率（爬塔敌人按层成长用，玩家为 1.0）
	unit.stat_multiplier = float(roster_data.get("stat_multiplier", 1.0))
	unit.learned_skill_names = roster_data.get("learned_skills", [])
	unit.equipped_skill_names = roster_data.get("equipped_skills", [])
	unit.max_hp = float(unit.get_base_stat("hp")) + float(unit.permanent_mods.get("hp", 0.0))
	unit.hp = unit.max_hp
	unit.apply_skills(game_db)
	return unit

func get_base_stat(stat: String) -> int:
	var key := stat
	if stat == "attack":
		key = "atk"
	var base_value := int(config.get(key, 0))
	if stat in ["hp", "attack", "defense"]:
		base_value = roundi(float(base_value) * get_star_multiplier(star))
		base_value = roundi(float(base_value) * stat_multiplier)
	return base_value

func get_stat(stat: String) -> float:
	var value := float(get_base_stat(stat))
	value += float(permanent_mods.get(stat, 0.0))
	for buff in buffs:
		value += buff.get_stat_modifier_for_unit(self, stat)
	var percent := float(percent_mods.get(stat, 0.0))
	if not is_zero_approx(percent):
		value += value * percent
	value += float(battle_stat_mods.get(stat, 0.0))
	return value

func get_attack() -> float:
	return get_stat("attack")

func get_defense() -> float:
	return get_stat("defense")

func get_move_points() -> int:
	return roundi(get_stat("move"))

func get_crit_rate() -> float:
	return get_stat("crit_rate")

func get_crit_damage() -> float:
	return get_stat("crit_damage")

# 技能急速：每 1 点 = on_timer 定时技能施放频率 +1%（作用于真实秒冷却）。
func get_ability_haste() -> int:
	return roundi(get_stat("ability_haste"))

# 为本场战斗增减属性；生命上限变化时单独处理当前生命并返回实际变化量。
func add_battle_stat(stat: String, amount: float, grant_current_hp: bool = false) -> float:
	if is_zero_approx(amount):
		return 0.0
	var applied := amount
	if stat == "hp":
		applied = maxf(amount, 1.0 - max_hp)
		max_hp += applied
		if grant_current_hp and applied > 0.0:
			hp += applied
		hp = clampf(hp, 0.0, max_hp)
	battle_stat_mods[stat] = float(battle_stat_mods.get(stat, 0.0)) + applied
	return applied

func get_range_min() -> int:
	return int(config.get("range_min", 1))

func get_range_max() -> int:
	var max_range := int(config.get("range_max", 1))
	for skill in skills:
		if skill is Skill:
			max_range += (skill as Skill).get_attack_range_bonus()
	return max_range

# 设置当前普攻目标；战斗单位之间不建立强引用环。
func set_current_target(target: Unit) -> void:
	current_target_ref = weakref(target) if target != null else null

# 查询当前普攻目标；目标对象释放后自动返回空。
func get_current_target() -> Unit:
	return current_target_ref.get_ref() as Unit if current_target_ref != null else null

func get_display_name() -> String:
	return display_name

func get_tags() -> Array:
	return tags.duplicate()

static func get_star_multiplier(star_level: int) -> float:
	return 1.0 + 0.5 * float(maxi(star_level - 1, 0))

static func get_scaled_base_stat(config_data: Dictionary, stat: String, star_level: int = 1) -> int:
	var key := "atk" if stat == "attack" else stat
	var base_value := int(config_data.get(key, 0))
	if stat in ["hp", "attack", "defense"]:
		base_value = roundi(float(base_value) * get_star_multiplier(star_level))
	return base_value

static func get_skill_slot_limit(star_level: int) -> int:
	# 初始 1 格，前两次升星各增加 1 格；未来提高最高星级时仍保持该上限。
	return 1 + mini(maxi(star_level - 1, 0), 2)

func is_dead() -> bool:
	return not alive

func move_to(new_pos: Vector2i) -> void:
	pos = new_pos

# --- 战斗统计（伤害输出/治疗产出/承伤，供战后统计界面） ---
var damage_dealt: int = 0
var healing_done: int = 0
var damage_taken: int = 0

func take_damage(amount: int, game = null) -> Dictionary:
	var result := {
		"damage": maxi(0, amount),
		"shield_absorbed": 0,
		"hp_lost": 0,
		"lethal": false
	}
	if not alive or amount <= 0:
		return result
	var remaining := amount
	var shield_absorbed := 0
	for buff in buffs.duplicate():
		if buff.shield > 0 and remaining > 0:
			var absorbed := mini(buff.shield, remaining)
			buff.shield -= absorbed
			shield_absorbed += absorbed
			remaining -= absorbed
	var hp_lost := minf(float(remaining), hp)
	hp -= hp_lost
	result["shield_absorbed"] = shield_absorbed
	result["hp_lost"] = hp_lost
	# 承伤统计：实际扣血 + 护盾吸收
	damage_taken += ceili(hp_lost) + shield_absorbed
	if hp <= 0:
		hp = 0
		alive = false
		result["lethal"] = true
	return result

# 治疗：可指定来源（计入来源单位的治疗产出）；缺省按自疗计。
func heal(amount: int, source: Unit = null) -> int:
	if not alive or amount <= 0:
		return 0
	amount = _amplify_player_vital(source, amount)
	var old_hp := hp
	hp = minf(max_hp, hp + float(amount))
	var healed := hp - old_hp
	var heal_src := source if source != null else self
	heal_src.healing_done += ceili(healed)
	return ceili(healed)

# 愈心祭司：我方单位施加的治疗/护盾数值 +10%；目标低于 40% 生命时改为 +20%。
func _amplify_player_vital(source: Unit, amount: int) -> int:
	if source == null or source.camp != TurnManager.PLAYER_CAMP or camp != TurnManager.PLAYER_CAMP:
		return amount
	if not GameSession.run_relics.has("revitalize_amp"):
		return amount
	var amp := 0.10
	if hp / maxf(max_hp, 1.0) < 0.4:
		amp = 0.20
	return maxi(1, roundi(float(amount) * (1.0 + amp)))

func add_buff(buff: Buff) -> void:
	if buff != null:
		buffs.append(buff)

# 当前所有独立护盾实例的剩余总量。
func get_total_shield() -> int:
	var total := 0
	for buff in buffs:
		total += maxi(0, buff.shield)
	return total

# 查询当前护盾上限；技能可提高比例，或通过 unlimited_shield 将其改为无上限。
func get_shield_cap() -> int:
	var cap_percent := 1.0
	for skill in skills:
		if not (skill is Skill):
			continue
		if skill.unlimited_shield or skill.shield_cap_percent < 0.0:
			return -1
		cap_percent = maxf(cap_percent, skill.shield_cap_percent)
	return maxi(0, roundi(float(max_hp) * cap_percent))

# 统一护盾入口：各份护盾独立保存持续时间，总量由 get_shield_cap() 的单位规则限制。
func gain_shield(amount: int, shield_name: String = "护盾", duration: int = -1, permanent: bool = true) -> int:
	if not alive or amount <= 0:
		return 0
	if camp == TurnManager.PLAYER_CAMP and GameSession.run_relics.has("revitalize_amp"):
		var amp := 0.10
		if hp / maxf(max_hp, 1.0) < 0.4:
			amp = 0.20
		amount = maxi(1, roundi(float(amount) * (1.0 + amp)))
	var shield_cap := get_shield_cap()
	var gained := amount if shield_cap < 0 else mini(amount, maxi(0, shield_cap - get_total_shield()))
	if gained <= 0:
		return 0
	var data := {"name": shield_name, "duration": duration, "shield": gained,
		"permanent": permanent, "is_beneficial": true}
	add_buff(Buff.from_data(data))
	runtime.bump("shield_credit", gained)
	return gained

# 推进回合开始状态，并把战斗上下文传给持续伤害结算。
func tick_turn_start(game = null, battle = null) -> void:
	for buff in buffs.duplicate():
		buff.on_turn_start(self, game, battle)

# 推进回合结束状态，并把战斗上下文传给持续伤害结算。
func tick_turn_end(game = null, battle = null) -> void:
	for buff in buffs.duplicate():
		buff.on_turn_end(self, game, battle)
	remove_expired_buffs()

func remove_expired_buffs() -> void:
	for buff in buffs.duplicate():
		if buff.is_expired():
			buffs.erase(buff)

func is_stunned() -> bool:
	return _has_control("stun")

func is_silenced() -> bool:
	return _has_control("silence")

func has_counter() -> bool:
	for buff in buffs:
		if buff.counter:
			return true
	return false

func has_taunt() -> bool:
	return _has_control("taunt")

# 反射比例（按伤害类别分别汇总；不指定时返回全部反射 buff 之和）。
func get_reflect_percent(kind: String = "") -> float:
	var total := 0.0
	for buff in buffs:
		if kind.is_empty() or buff.reflect_damage_kind == kind:
			total += buff.reflect_percent
	return total

# 汇总所有状态提供的百分比伤害减免；由 DamageSystem 对全部伤害类别统一应用。
func get_reduce_percent() -> float:
	var total := 0.0
	for buff in buffs:
		total += buff.reduce_percent
	return total

# 是否免疫指定状态/类型。
func is_immune(kind: String) -> bool:
	for buff in buffs:
		if buff.immunity.has("*") or buff.immunity.has(kind):
			return true
	return false

# 是否无视防御（直接伤害视角：命中时忽略目标防御）。
func has_ignore_defense() -> bool:
	for buff in buffs:
		if buff.ignore_defense:
			return true
	return false

# 是否被标记。
func has_mark() -> bool:
	for buff in buffs:
		if buff.is_mark:
			return true
	return false

func add_skill(skill: Skill) -> void:
	if skill != null and not has_skill(skill.name):
		skill.owner = self
		skills.append(skill)

func has_skill(skill_name: String) -> bool:
	for skill in skills:
		if skill.name == skill_name or skill.skill_id == skill_name:
			return true
	return false

func apply_skills(game_db = null) -> void:
	var db = game_db
	if db == null:
		db = GameDatabase
	var skill_names: Array = []
	# 固有技能：模板独有，永远生效
	var innate_id: String = str(config.get("innate_skill", ""))
	if innate_id != "":
		skill_names.append(innate_id)
	for extra_innate in config.get("innate_skills", []):
		var extra_id := str(extra_innate)
		if not extra_id.is_empty() and not skill_names.has(extra_id):
			skill_names.append(extra_id)
	# 通用技能：仅已装备的参与战斗（已学未装备的不生效）
	var equipped_count := 0
	for equipped_id in equipped_skill_names:
		var equipped_data: Dictionary = db.get_skill(str(equipped_id))
		if not bool(equipped_data.get("common", false)):
			continue
		if equipped_count >= get_skill_slot_limit(star):
			break
		skill_names.append(str(equipped_id))
		equipped_count += 1
	for skill_name in skill_names:
		var data: Dictionary = db.get_skill(str(skill_name))
		if not data.is_empty():
			var skill_data := data.duplicate()
			skill_data["id"] = str(skill_name)
			add_skill(Skill.from_data(skill_data))

func _has_control(control_type: String) -> bool:
	for buff in buffs:
		if buff.control == control_type:
			return true
	return false

static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	return result
