# 新遗物专项测试：验证图标注册、战斗计时与关键事件效果。
extends Node

const IDS := ["war_drum", "shield_breaker", "ember_lens", "fallen_banner",
	"summon_call", "dawn_hourglass", "plague_censer", "purifying_bell", "critical_talisman"]

# 数据库完成加载后运行断言。
func _ready() -> void:
	call_deferred("_run")

# 逐个检查新遗物的实际触发，避免只有描述而没有行为。
func _run() -> void:
	for relic_id in GameDatabase.relics:
		if ArtManager.get_relic_icon(str(relic_id)) == null:
			_fail("内置遗物缺少独立图标：%s" % relic_id)
			return
	ModLoader._merge_mod("res://tests/fixtures/relic_mod", {})
	if GameDatabase.get_relic("custom_relic").is_empty() or ArtManager.get_relic_icon("custom_relic") == null:
		_fail("Mod 遗物数据或独立图标未加载")
		return
	var external_icon := "user://relic_icon_load_test.png"
	var output := FileAccess.open(external_icon, FileAccess.WRITE)
	if output == null:
		_fail("无法创建用户目录图标测试文件")
		return
	output.store_buffer(FileAccess.get_file_as_bytes("res://tests/fixtures/relic_mod/art/relics/custom_relic.png"))
	output.close()
	GameDatabase.relics["external_icon_test"] = {"_icon_path": external_icon}
	var external_loaded := ArtManager.get_relic_icon("external_icon_test") != null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(external_icon))
	GameDatabase.relics.erase("external_icon_test")
	if not external_loaded:
		_fail("用户目录 Mod 图标未能在运行时加载")
		return
	for relic_id in IDS:
		if GameDatabase.get_relic(relic_id).is_empty() or ArtManager.get_relic_icon(relic_id) == null:
			_fail("遗物或图标未注册：%s" % relic_id)
			return
	GameSession.run_relics = IDS.duplicate()
	var manager := BattleManager.new()
	manager.grid = Grid.new(10, 6)
	var hero := _unit("Warrior", TurnManager.PLAYER_CAMP, Vector2i(1, 2))
	var ally := _unit("Tank", TurnManager.PLAYER_CAMP, Vector2i(2, 2))
	var enemy := _unit("Warrior", TurnManager.ENEMY_CAMP, Vector2i(6, 2))
	manager.units = [hero, ally, enemy]
	for unit in manager.units:
		unit.set_battle(manager)
	RelicSystem.begin_battle(manager)
	if hero.get_attack_speed_bonus() < 25.0:
		_fail("先阵战鼓未在战斗开始时生效")
		return
	for buff in hero.buffs.duplicate():
		buff.tick_seconds(hero, 8.0)
	hero.remove_expired_buffs()
	if hero.get_attack_speed_bonus() >= 25.0:
		_fail("先阵战鼓八秒后仍未失效")
		return
	enemy.add_buff(Buff.from_data({"name": "测试中毒", "status": "poison",
		"stacks": [{"remaining": 6.0, "until_tick": 2.0, "damage": 1, "interval": 2.0}]}))
	if not is_equal_approx(RelicSystem.get_damage_bonus_percent(hero, enemy, DamageSystem.SKILL), 0.15) \
			or RelicSystem.get_damage_bonus_percent(hero, enemy, DamageSystem.ATTACK) > 0.0:
		_fail("余烬透镜的状态或伤害类别判断错误")
		return
	var active := Skill.new()
	active.trigger = SkillTriggerSystem.ON_TIMER
	active.interval_seconds = 10.0
	active.interval_remaining = 10.0
	hero.add_skill(active)
	RelicSystem.prepare_first_active_cast(manager)
	if not is_equal_approx(active.interval_remaining, 7.0):
		_fail("破晓沙漏未只缩短首次主动技能准备时间")
		return
	var summoned := manager.spawn_unit("Warrior", TurnManager.PLAYER_CAMP, hero.pos, hero)
	if summoned == null or hero.get_total_shield() <= 0 or ally.get_total_shield() <= 0:
		_fail("援军号令未在首次召唤时为全队施加护盾")
		return
	var shield_before := hero.get_total_shield()
	manager.spawn_unit("Warrior", TurnManager.PLAYER_CAMP, hero.pos, hero)
	if hero.get_total_shield() != shield_before:
		_fail("援军号令在第二次召唤时重复生效")
		return
	var crit_report := {"damage_kind": DamageSystem.ATTACK, "crit": true}
	RelicSystem.on_critical_hit(manager, hero, crit_report)
	RelicSystem.on_critical_hit(manager, hero, crit_report)
	if not is_equal_approx(hero.get_attack_speed_bonus(), 15.0):
		_fail("锐星符没有按单位每场只触发一次")
		return
	ally.alive = false
	RelicSystem.on_death(manager, ally, null)
	if not is_equal_approx(hero.get_attack_speed_bonus(), 25.0):
		_fail("残旗未在非召唤友军阵亡时生效")
		return
	enemy.buffs.clear()
	enemy.hp = enemy.max_hp
	RelicSystem.tick_battle(manager, 8.0)
	if not enemy.has_status("poison"):
		_fail("瘴疫香炉没有按八秒施加中毒")
		return
	hero.hp = hero.max_hp * 0.5
	hero.add_buff(Buff.from_data({"name": "负面测试", "status": "silence",
		"duration_seconds": 8.0, "is_beneficial": false}))
	RelicSystem.tick_battle(manager, 2.0)
	if hero.has_status("silence") or hero.hp <= hero.max_hp * 0.5:
		_fail("净心钟没有按十秒净化并治疗最低生命友军")
		return
	enemy.buffs.clear()
	enemy.hp = enemy.max_hp
	var break_report := {"damage_kind": DamageSystem.ATTACK,
		"result": {"shield_absorbed": 30}}
	var prior_hp := enemy.hp
	RelicSystem.on_shield_break(manager, hero, enemy, break_report)
	if enemy.hp >= prior_hp:
		_fail("碎盾锤没有在完全击破护盾时追加伤害")
		return
	prior_hp = enemy.hp
	RelicSystem.on_shield_break(manager, hero, enemy, break_report)
	if enemy.hp != prior_hp:
		_fail("碎盾锤三秒冷却失效")
		return
	print("PASS: 九件遗物的注册、图标与关键战斗效果")
	get_tree().quit(0)

# 创建不依赖玩家存档的战斗单位。
func _unit(unit_type: String, camp: String, pos: Vector2i) -> Unit:
	return Unit.create_from_config(unit_type, camp, pos, GameDatabase.get_unit(unit_type), {})

# 输出断言失败原因并停止测试。
func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
