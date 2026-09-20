# 技能+遗物机制实战验证：给玩家单位挂上全部 16 个代码通用技能，并启用全部 17 个遗物，
# 按 UI 正规流程走 setup + setup_battle，驱动真实战斗。测试节点实现 add_log / record_skill_damage，
# 使每次技能/遗物激活都写入日志，据此审计各机制是否真正被触发，并捕获运行时错误。
extends Node

const FRAMES := 2400   # 40 秒，60fps
const DELTA := 1.0 / 60.0
const CHECK_SKILLS: Array = [
	"Triple Pursuit", "Frenzy Chain", "Onset Might", "Blooddrain Victim",
	"Calm Branch", "Electrocute Burst", "Blade Opening", "Taste Blood",
	"Comet Fall", "Deathfire Burn", "Transcend Row", "Absolute Focus",
	"Scorch Tick", "Demolish Scene", "Shield Bash", "Second Wind",
]
const RELIC_IDS: Array = [
	"triumph_horn", "haste_legacy", "cd_legacy", "coup_grace", "cut_down",
	"last_stand", "harvest_soul", "sixth_sense", "airy_guardian", "manaflow_band",
	"gathering_storm", "grasp_undying", "guardian_cord", "conditioning_late",
	"overgrowth", "revitalize_amp", "biscuit_delivery",
]

var game_log: Array = []

# 由技能/遗物/触发系统回调，把触发轨迹收进日志做审计。
func add_log(text: String) -> void:
	game_log.append(str(text))

func record_skill_damage(actor, target, damage: int, skill_name: String) -> void:
	pass

func _ready() -> void:
	var ok := run()
	get_tree().quit(0 if ok else 1)

func run() -> bool:
	GameSession.mode = GameSession.MODE_TOWER
	GameSession.tower_floor = 3   # floors=2，激活跨层成长类遗物
	GameSession.run_relics = RELIC_IDS
	GameSession.run_blessings = []

	var scenario := {
		"width": 12, "height": 8,
		"enemy_units": [
			{"type": "Warrior", "pos": [7, 1], "name": "E1", "stat_multiplier": 4.0},
			{"type": "Warrior", "pos": [7, 3], "name": "E2", "stat_multiplier": 4.0},
			{"type": "Warrior", "pos": [7, 5], "name": "E3", "stat_multiplier": 4.0},
			{"type": "Warrior", "pos": [9, 4], "name": "E4", "stat_multiplier": 4.0},
			{"type": "Warrior", "pos": [10, 2], "name": "E5", "stat_multiplier": 4.0},
		],
	}
	var battle := BattleManager.new("verify", self, [
		{"type": "Warrior", "pos": Vector2i(1, 1), "name": "P1", "roster_index": -1},
	], scenario)
	battle.setup()
	_equip_all_skills(battle)
	battle.setup_battle()   # 复刻 UI 正规流程：应用遗物 + 初始化运行时 + 触发战斗开始钩子

	# 加速行动节奏，确保战斗持续足够久以覆盖按秒技能计时间隔
	for u in battle.units:
		u.turn_interval = 0.5
		u.turn_timer = 0.5
	# 给玩家一个耐久缓冲，避免敌方属性放大后瞬间反杀，让战斗持续到检验按秒技能
	if battle.units.size() > 0:
		var p0: Unit = battle.units[0]
		p0.max_hp = 9000
		p0.hp = 9000

	var total_actions := 0
	for i in FRAMES:
		var events: Array = battle.tick(DELTA)
		total_actions += events.size()
		if battle.winner != "":
			break

	print("==== Skill+Relic 验证战斗结束：winner=%s time=%.1fs actions=%d ====" % [
		battle.winner, battle.get_battle_time(), total_actions])

	# 审计每个技能的触发次数（按日志里出现的中文名计数）
	var skill_fired: Dictionary = {}
	for skill_name in CHECK_SKILLS:
		var name_cn := _chinese_name(skill_name)
		var count := 0
		for line in game_log:
			if line.begins_with(name_cn) or line.contains(name_cn):
				count += 1
		skill_fired[name_cn] = count
		print("  技能触发: %-10s x%d" % [name_cn, count])

	# 关键遗物激活轨迹
	for kw in ["凯旋号角", "噬骸成长", "灵能循环", "不朽血契", "守护精灵", "收割之魂", "守卫之盾", "猎魔嗅探"]:
		var cnt := 0
		for line in game_log:
			if line.contains(kw):
				cnt += 1
		if cnt > 0:
			print("  遗物激活: %s x%d" % [kw, cnt])

	var p: Unit = null
	for u in battle.units:
		if u is Unit and u.camp == TurnManager.PLAYER_CAMP:
			p = u
	for e in battle.units:
		if e is Unit and e.camp != TurnManager.PLAYER_CAMP:
			print("  敌方[%s] hp=%d/%d alive=%s" % [e.get_display_name(), e.hp, e.max_hp, e.alive])
	if p != null:
		print("  玩家[%s] hp=%d/%d dmg=%d heal=%d runtime=%s" % [
			p.get_display_name(), p.hp, p.max_hp, p.damage_dealt, p.healing_done,
			str(p.runtime.notes if p.runtime != null else {})])
		print("  玩家技能数=%d " % p.skills.size())
		for s in p.skills:
			print("    - %s (%s)" % [s.name, s.trigger])

	# 待审计技能（出现次数为 0 的可能是机制 bug，也可能是本局条件未达成）
	var zero: Array = []
	var fired: Array = []
	for skill_name in CHECK_SKILLS:
		var name_cn := _chinese_name(skill_name)
		if int(skill_fired.get(name_cn, 0)) > 0:
			fired.append(name_cn)
		else:
			zero.append(name_cn)
	print("已触发技能(%d): %s" % [fired.size(), "、".join(fired)])
	if not zero.is_empty():
		print("未触发技能(条件未满足可能): %s" % "、".join(zero))

	var pass_ok := p != null and p.skills.size() == CHECK_SKILLS.size() \
		and p.damage_dealt > 0 and p.healing_done > 0 and not fired.is_empty()
	if battle.winner == "":
		print("警告：战斗超时未分出胜负")
	return pass_ok

func _equip_all_skills(battle: BattleManager) -> void:
	for u in battle.units:
		if not (u is Unit) or u.camp != TurnManager.PLAYER_CAMP:
			continue
		for sid in CHECK_SKILLS:
			var data: Dictionary = GameDatabase.get_skill(str(sid))
			if not data.is_empty():
				u.add_skill(Skill.from_data(data))

func _chinese_name(id: String) -> String:
	match id:
		"Triple Pursuit": return "破军追击"
		"Frenzy Chain": return "疾风电涌"
		"Onset Might": return "骁勇累积"
		"Blooddrain Victim": return "燃血命脉"
		"Calm Branch": return "回气指环"
		"Electrocute Burst": return "雷霆连锁"
		"Blade Opening": return "破阵序斩"
		"Taste Blood": return "血腥回响"
		"Comet Fall": return "彗星溅射"
		"Deathfire Burn": return "灼魂焚身"
		"Transcend Row": return "回响节点"
		"Absolute Focus": return "盈血之力"
		"Scorch Tick": return "余烬引燃"
		"Demolish Scene": return "攻坚重锤"
		"Shield Bash": return "盾辉反击"
		"Second Wind": return "残喘气血"
	return id