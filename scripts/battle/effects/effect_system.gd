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
static func apply_effects(user: Unit, target: Unit, effects: Array, game = null, battle = null) -> Dictionary:
	var report := {"damage": 0, "heal": 0, "buffs": [], "shield": 0, "revived": false}
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var effect_type := str(effect.get("type", ""))
		match effect_type:
			"damage":
				report["damage"] += _apply_damage(user, target, effect, game, battle)
			"heal":
				report["heal"] += _apply_heal(user, target, effect, game)
			"buff":
				var buff := _apply_buff(user, target, effect, game, battle)
				if buff != null:
					report["buffs"].append(buff.name)
			"dot":
				var dot_buff := _apply_buff(user, target, {"type": "buff", "buff": str(effect.get("buff", ""))}, game, battle)
				if dot_buff != null:
					report["buffs"].append(dot_buff.name)
			"shield":
				var sh := _apply_shield(target, effect, game)
				report["shield"] += sh
			"shield_max_hp_percent":
				var max_sh := _apply_max_hp_shield(target, effect, game)
				report["shield"] += max_sh
			"stat_mod":
				_apply_stat_mod(target, effect, game)
			"revive":
				if _apply_revive(target, effect, game):
					report["revived"] = true
			"dispel":
				_apply_dispel(target, effect, game)
			"cleanse":
				_apply_dispel(target, {"friendly": true}, game)
			"summon":
				_apply_summon(user, effect, battle if battle != null else game)
			"taunt":
				_apply_status_buff(target, effect, game, "taunt")
			"stealth", "divine_shield", "silence":
				_apply_timed_status(target, effect, effect_type)
			"dormant":
				_apply_dormant(target, effect)
			"poison":
				_apply_poison(user, target, effect)
			"burn":
				_apply_burn(user, target, effect)
			"frost":
				_apply_frost(target, effect)
			"aura":
				_apply_aura(target, effect)
			"double_stats":
				_apply_double_stats(target, effect)
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
			"teleport":
				_apply_teleport(user, target, effect, game)
			"percentage_damage":
				report["damage"] += _apply_percentage_damage(user, target, effect, game, battle)
			"chain_damage":
				report["damage"] += _apply_chain_damage(user, target, effect, game, battle)
			"permanent_stat":
				_apply_permanent_stat(user, target, effect, game)
			_:
				push_warning("未知技能效果类型: %s" % effect_type)
	return report

# --- 各效果实现（可独立注册/扩展） ---

static func _apply_damage(user: Unit, target: Unit, config: Dictionary, game, battle = null) -> int:
	if user == null or target == null or not target.alive:
		return 0
	# JSON 技能的 damage 效果默认是主动技能直伤，未显式指定时归为技能伤害；
	# 想要特效/普攻语义由配置里的 damage_kind 显式覆盖。
	var damage_config := config.duplicate()
	if not damage_config.has("damage_kind"):
		damage_config["damage_kind"] = DamageSystem.SKILL
	var resolved := DamageSystem.apply(user, target, damage_config, battle, game)
	var damage: int = resolved.get("damage", 0)
	var crit: bool = resolved.get("crit", false)
	if game != null and game.has_method("add_log"):
		var prefix := "暴击！" if crit else ""
		game.add_log("%s 对 %s%s 造成 %d 点伤害" % [user.get_display_name(), target.get_display_name(), prefix, damage])
	return damage

static func _apply_heal(user: Unit, target: Unit, config: Dictionary, game) -> int:
	if target == null or not target.alive:
		return 0
	var amount := int(config.get("amount", 0))
	if amount <= 0:
		amount = 0
	var healed := target.heal(amount, user)
	if healed > 0 and game != null and game.has_method("add_log"):
		game.add_log("%s 恢复 %d 点生命" % [target.get_display_name(), healed])
	return healed

static func _apply_buff(user: Unit, target: Unit, config: Dictionary, game, battle) -> Buff:
	if target == null:
		return null
	var buff_id := str(config.get("buff", ""))
	return BuffEffect.apply(target, buff_id, game, user, battle)

static func _apply_shield(target: Unit, config: Dictionary, game) -> int:
	if target == null:
		return 0
	var amount := int(config.get("amount", 0))
	if amount <= 0:
		return 0
	var gained := target.gain_shield(amount, str(config.get("name", "护罩")),
		int(config.get("duration", 2)), bool(config.get("permanent", false)))
	if gained > 0 and game != null and game.has_method("add_log"):
		game.add_log("%s 获得 %d 点护罩" % [target.get_display_name(), gained])
	return gained

static func _apply_max_hp_shield(target: Unit, config: Dictionary, game) -> int:
	if target == null or not target.alive:
		return 0
	var amount := maxi(1, roundi(float(target.max_hp) * float(config.get("percent", 0.1))))
	return _apply_shield(target, {"amount": amount, "duration": int(config.get("duration", -1)), "permanent": bool(config.get("permanent", true))}, game)

static func _apply_stat_mod(target: Unit, config: Dictionary, game) -> void:
	if target == null:
		return
	var data := {
		"name": str(config.get("name", "属性变化")),
		"duration": int(config.get("duration", 2)),
		"modifiers": config.get("stats", {}),
		"conditional_hp_percent": config.get("conditional_hp_percent", {}),
		"permanent": bool(config.get("permanent", false)),
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
		if is_beneficial == friendly or bool(buff.raw_data.get("uncleansable", false)):
			kept.append(buff)
	target.buffs = kept
	if game != null and game.has_method("add_log"):
		game.add_log("%s 的效果被驱散" % target.get_display_name())

# 刷新单份限时状态；潜行和圣盾不因重复施加而叠层。
static func _apply_timed_status(target: Unit, config: Dictionary, status_name: String) -> void:
	if target == null or not target.alive or target.is_immune(status_name):
		return
	for buff in target.buffs:
		if buff.status == status_name:
			buff.seconds_left = maxf(buff.seconds_left, float(config.get("duration_seconds", 6.0)))
			return
	var beneficial := status_name != "silence"
	target.add_buff(Buff.from_data({"name": str(config.get("name", status_name)),
		"status": status_name, "control": status_name if not beneficial else "",
		"duration_seconds": float(config.get("duration_seconds", 6.0)),
		"permanent": true, "is_beneficial": beneficial}))

# 休眠期间仍可受伤；解除时由 BattleManager 一次性执行苏醒效果。
static func _apply_dormant(target: Unit, config: Dictionary) -> void:
	if target == null or not target.alive or target.is_dormant():
		return
	target.add_buff(Buff.from_data({"name": str(config.get("name", "休眠")),
		"status": "dormant", "duration_seconds": float(config.get("duration_seconds", 20.0)),
		"awaken_effects": config.get("awaken_effects", []), "permanent": true,
		"uncleansable": true, "is_beneficial": true}))

# 中毒只创建一个状态，内部每层独立记持续时间与伤害来源。
static func _apply_poison(user: Unit, target: Unit, config: Dictionary) -> void:
	if target == null or not target.alive or target.is_immune("poison"):
		return
	var poison: Buff = null
	for buff in target.buffs:
		if buff.status == "poison":
			poison = buff
			break
	if poison == null:
		poison = Buff.from_data({"name": "中毒", "status": "poison", "permanent": true,
			"is_beneficial": false})
		target.add_buff(poison)
	var interval := maxf(0.1, float(config.get("tick_interval_seconds", 2.0)))
	var layer := {"remaining": maxf(0.1, float(config.get("duration_seconds", 6.0))),
		"until_tick": interval, "interval": interval, "damage": maxi(1, int(config.get("damage", 5))),
		"source_ref": weakref(user) if user != null else null}
	if poison.stacks.size() >= maxi(1, int(config.get("max_stacks", 5))):
		poison.stacks.pop_front()
	poison.stacks.append(layer)

# 灼烧不叠层：重复施加刷新时间并保留较高的每跳伤害。
static func _apply_burn(user: Unit, target: Unit, config: Dictionary) -> void:
	if target == null or not target.alive or target.is_immune("burn"):
		return
	for buff in target.buffs:
		if buff.status == "burn":
			buff.seconds_left = maxf(0.1, float(config.get("duration_seconds", 6.0)))
			if int(config.get("damage", 5)) > buff.tick_damage:
				buff.tick_damage = int(config.get("damage", 5))
				buff.source_ref = weakref(user) if user != null else null
			return
	target.add_buff(Buff.from_data({"name": "灼烧", "status": "burn",
		"duration_seconds": maxf(0.1, float(config.get("duration_seconds", 6.0))),
		"tick_interval_seconds": maxf(0.1, float(config.get("tick_interval_seconds", 2.0))),
		"tick_damage": maxi(1, int(config.get("damage", 5))), "source": user,
		"permanent": true, "is_beneficial": false}))

# 霜冻每层减移动并延长行动间隔；第三层冻结下一次行动并短暂防止连锁冻结。
static func _apply_frost(target: Unit, config: Dictionary) -> void:
	if target == null or not target.alive or target.is_immune("frost") or target.has_status("frost_resist"):
		return
	var frost: Buff = null
	for buff in target.buffs:
		if buff.status == "frost":
			frost = buff
			break
	if frost == null:
		frost = Buff.from_data({"name": "霜冻", "status": "frost", "stacks": 0,
			"duration_seconds": 5.0, "permanent": true, "is_beneficial": false})
		target.add_buff(frost)
	frost.raw_data["stacks"] = int(frost.raw_data.get("stacks", 0)) + int(config.get("stacks", 1))
	frost.seconds_left = maxf(0.1, float(config.get("duration_seconds", 5.0)))
	if int(frost.raw_data["stacks"]) >= 3:
		target.remove_status("frost")
		target.add_buff(Buff.from_data({"name": "冻结", "status": "frozen", "permanent": true,
			"is_beneficial": false}))
		target.add_buff(Buff.from_data({"name": "抗冻", "status": "frost_resist",
			"duration_seconds": 3.0, "permanent": true, "is_beneficial": true}))

# 光环不复制到友军身上，由单位查询属性时按当前位置实时统计。
static func _apply_aura(target: Unit, config: Dictionary) -> void:
	if target == null or not target.alive:
		return
	target.add_buff(Buff.from_data({"name": str(config.get("name", "光环")),
		"aura_range": maxi(1, int(config.get("range", 2))),
		"modifiers": config.get("stats", {}),
		"duration_seconds": float(config.get("duration_seconds", -1.0)),
		"permanent": true, "is_beneficial": true}))

# 战斗内翻倍指定基础属性；最大生命与当前生命同步翻倍，保持生命比例。
static func _apply_double_stats(target: Unit, config: Dictionary) -> void:
	if target == null or not target.alive:
		return
	for stat in config.get("stats", ["hp", "attack", "defense"]):
		match str(stat):
			"hp":
				var old_hp := target.hp
				target.add_battle_stat("hp", target.max_hp)
				target.hp = minf(target.max_hp, old_hp * 2.0)
			"attack":
				target.add_battle_stat("attack", target.get_attack())
			"defense":
				target.add_battle_stat("defense", target.get_defense())

# 召唤：在施放者附近生成仅存在于本场战斗的单位。
static func _apply_summon(user: Unit, config: Dictionary, game) -> void:
	if user == null:
		return
	var unit_type := str(config.get("unit_type", "Warrior"))
	var config_data: Dictionary = GameDatabase.get_unit(unit_type)
	if config_data.is_empty():
		push_warning("召唤未知单位: %s" % unit_type)
		return
	# 由 BattleManager 寻找空位并绑定楼层倍率与入场事件。
	var battle = game
	if battle != null and battle.has_method("spawn_unit"):
		var summoned: Unit = battle.spawn_unit(unit_type, user.camp, user.pos, user)
		if summoned != null and game.has_method("add_log"):
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
		"duration_seconds": float(config.get("duration_seconds", 6.0)),
		"permanent": true,
		"status": control,
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
		"reflect_damage_kind": str(config.get("damage_kind", DamageSystem.SKILL)),
		"permanent": bool(config.get("permanent", false)),
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
		"duration_seconds": float(config.get("duration_seconds", -1.0)),
		"permanent": bool(config.get("permanent", false)),
		"trigger": "on_hit",
		"heal_percent": float(config.get("percent", 0.3)),
		"is_beneficial": true,
	}
	var buff := Buff.from_data(data)
	target.add_buff(buff)
	if game != null and game.has_method("add_log"):
		game.add_log("%s 获得 %s" % [target.get_display_name(), buff.name])

# 位移：按 mode/dir/distance 移动自己或目标。
# mode: self(移自己) / target(移目标)。dir: target(朝目标) / away(远离) / self(拉向自己)。
# distance: 格数（0=贴脸，-1=瞬移到目标位置，N=指定距离）。
static func _apply_teleport(user: Unit, target: Unit, config: Dictionary, game) -> void:
	if user == null or target == null:
		return
	var battle = game
	if battle == null or not battle.has_method("move_unit_to"):
		return
	var mode := str(config.get("mode", "target"))
	var dir := str(config.get("dir", "target"))
	var distance := int(config.get("distance", 1))
	var subject: Unit = user if mode == "self" else target
	var anchor: Unit = target if mode == "self" else user
	# 起点与方向向量
	var start := subject.pos
	var target_pos := anchor.pos
	var delta := target_pos - start
	if distance == -1:
		# 瞬移到对方位置（直接换位）
		battle.move_unit_to(subject, target_pos)
		return
	# 计算方向单位向量（曼哈顿：取差值较大的轴为主方向）
	var step := Vector2i(0, 0)
	if delta != Vector2i.ZERO:
		if absi(delta.x) >= absi(delta.y):
			step = Vector2i(sign(delta.x), 0)
		else:
			step = Vector2i(0, sign(delta.y))
	var move_vec := Vector2i.ZERO
	match dir:
		"away":
			move_vec = -step
		"self":
			# 拉向自己：被移动单位朝 anchor(user) 移动，即沿主方向 step
			move_vec = step
		_:
			move_vec = step
	# 计算目标格
	var cell := start
	if distance == 0:
		# 突脸/拉贴脸：移动到 anchor 相邻格（贴脸）
		var adjacent := anchor.pos - step
		if _is_cell_walkable(battle, adjacent):
			cell = adjacent
	else:
		for i in range(distance):
			var next_cell := cell + move_vec
			if not _is_cell_walkable(battle, next_cell):
				break
			cell = next_cell
		if cell != start:
			battle.move_unit_to(subject, cell)

# 检查格子可走（地图内/可通行/未被占用）。
static func _is_cell_walkable(battle, cell: Vector2i) -> bool:
	if battle == null or not battle.has_method("move_unit_to"):
		return false
	if not battle.grid.in_bounds(cell.x, cell.y):
		return false
	if not battle.grid.get_tile(cell.x, cell.y).passable:
		return false
	if battle.get_unit_at(cell) != null:
		return false
	return true

# 百分比伤害：按目标生命上限百分比造成伤害（无视攻击/防御）。
static func _apply_percentage_damage(user: Unit, target: Unit, config: Dictionary, game, battle = null) -> int:
	if target == null or not target.alive:
		return 0
	var percent := float(config.get("percent", 0.1))
	var max_damage := int(config.get("max", 999999))
	var damage := mini(roundi(target.max_hp * percent), max_damage)
	damage = maxi(1, damage)
	var damage_config := config.duplicate()
	damage_config["raw_damage"] = damage
	if not damage_config.has("damage_kind"):
		damage_config["damage_kind"] = DamageSystem.SKILL
	if not damage_config.has("true_damage") and not damage_config.has("ignore_defense"):
		damage_config["true_damage"] = true
	var resolved := DamageSystem.apply(user, target, damage_config, battle, game)
	damage = int(resolved.get("damage", 0))
	if game != null and game.has_method("add_log"):
		game.add_log("%s 受到 %d 点百分比伤害" % [target.get_display_name(), damage])
	return damage

# 连锁伤害：对目标造成伤害后，向附近敌人连锁 N 次，每次伤害递减。
static func _apply_chain_damage(user: Unit, target: Unit, config: Dictionary, game, battle = null) -> int:
	if user == null or target == null:
		return 0
	if battle == null:
		return 0
	var power := float(config.get("power", 1.0))
	var chain := int(config.get("chain", 2))
	var chain_range := int(config.get("chain_range", 2))
	var total := 0
	var current_target: Unit = target
	var hit: Array = [target]
	for i in range(chain):
		if current_target == null or not current_target.alive:
			break
		var damage_config := config.duplicate()
		damage_config["power"] = power
		if not damage_config.has("damage_kind"):
			damage_config["damage_kind"] = DamageSystem.SKILL
		var resolved := DamageSystem.apply(user, current_target, damage_config, battle, game)
		var damage: int = resolved.get("damage", 0)
		var crit: bool = resolved.get("crit", false)
		total += damage
		if game != null and game.has_method("add_log"):
			var prefix := "暴击！" if crit else ""
			game.add_log("%s 连锁攻击 %s%s 造成 %d 点伤害" % [user.get_display_name(), current_target.get_display_name(), prefix, damage])
		# 找下一个未被命中且最近的敌人
		var next_unit: Unit = null
		var best := 999999
		for unit in battle.units:
			if not (unit is Unit) or not unit.alive or unit == user:
				continue
			if unit.camp == user.camp:
				continue
			if hit.has(unit):
				continue
			var d := Grid.manhattan_distance(current_target.pos, unit.pos)
			if d <= chain_range and d < best:
				best = d
				next_unit = unit
		current_target = next_unit
		if current_target != null:
			hit.append(current_target)
	return total

# 永久属性强化：提升属性（跨战斗全局永久或本局永久）。
# config: { stat, amount, persist }。persist=true 写回编成（全局永久），false 仅本局生效。
static func _apply_permanent_stat(user: Unit, target: Unit, config: Dictionary, game) -> void:
	var owner := user if user != null and user.alive else target
	if owner == null or not owner.alive:
		return
	var stat := str(config.get("stat", "hp"))
	var amount := int(config.get("amount", 1))
	if amount == 0:
		return
	owner.permanent_mods[stat] = float(owner.permanent_mods.get(stat, 0.0)) + amount
	if stat == "hp":
		# 生命上限永久 +amount，当前生命同步跟随（不超过新的上限）
		owner.max_hp += amount
		owner.hp = minf(owner.hp + amount, owner.max_hp)
	if bool(config.get("persist", false)):
		# 全局永久：写回编成存档；无编成 id（如敌方单位）时仅本局生效
		ProgressManager.add_permanent_stat(owner.unit_id, stat, amount)
	if game != null and game.has_method("add_log"):
		var stat_label: String = str({"hp": "生命上限", "attack": "攻击", "defense": "防御", "move": "移动"}.get(stat, stat))
		game.add_log("%s 的%s永久 +%d" % [owner.get_display_name(), stat_label, amount])
