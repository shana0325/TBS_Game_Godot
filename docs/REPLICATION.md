# TBS_Game_Godot 完整复刻文档（REPLICATION.md）

> 生成时间：2026-08-08
> 数据来源：Codex 历史会话记录（3月~8月完整开发日志）+ 现有代码 + 设计文档
> 目的：让接手者仅凭本文档 + 原仓库即可**完整复刻**本战棋游戏项目

---

## 1. 项目概述

- **游戏类型**：2D 回合制战棋（TBS），单机 PVE，PC（Windows）优先
- **引擎**：Godot 4.7 + GDScript（GL Compatibility 渲染模式）
- **仓库**：https://github.com/shana0325/TBS_Game_Godot.git
- **参考原版**：`D:\PycharmProjects\TBS_Game`（Python 3 + pygame 完整实现，仅作设计/功能参考，**代码不混用**）
- **开发策略**：先做最小可玩版本（MVP），再逐步扩展系统复杂度；游戏逻辑与 UI 严格分层

### 1.1 两个版本的定位

| 版本 | 语言/引擎 | 完成度 | 说明 |
|---|---|---|---|
| TBS_Game（原版） | Python + pygame | 高（完整 MVP+扩展） | 有完整屏幕流程、成长、装备、技能、i18n |
| TBS_Game_Godot（本仓库） | Godot 4.7 + GDScript | 高（完整可玩闭环） | 重构完成，可完整游玩 |

### 1.2 当前 Godot 版状态速览

- ✅ Godot 工程骨架（project.godot、autoload GameDatabase / GameSession）
- ✅ JSON 数据加载（units/skills/buffs/equipments/player_roster/scenario）
- ✅ 核心实体：Tile / Grid / Unit / Skill / Buff / Equipment
- ✅ 战斗逻辑：Pathfinder(Dijkstra) / DamageCalculator / TurnManager / EffectSystem / EventSystem / CombatSystem
- ✅ 战斗管理器 BattleManager、敌方 AI EnemyAI、战斗界面 battle_screen（选中/移动/攻击/技能/回合/日志/胜负）
- ✅ 双战场（左右 4×3 + gap 2）与跨战场攻击规则（逻辑列差忽略 Y 轴）
- ✅ 完整流程：主菜单 → 选关 → 部署 → 战斗 → 结算
- ✅ 成长系统 UI（属性/技能/装备子页 + 整体属性总览 + 战斗内单位信息）
- ✅ 胜利奖励经验写回编成；多关卡（battle_01/battle_02）
- ✅ 像素小人贴图 + 中文字体 + GDScript 像素小人生成器
- ⚠️ 滚动列表组件未做（不做 i18n，仅中文版）

---

## 2. 设计目标与原则

### 2.1 玩法闭环（第一优先）
```
战斗开始 → 玩家操作 → 敌方行动 → 战斗结算 → 胜负判定
```

### 2.2 强模块化
- 战斗规则：Battle 层（纯逻辑，不依赖渲染）
- 表现层：UI / Render
- 数据配置：Data（JSON）

### 2.3 数据驱动
所有可调参数进 JSON：单位属性、技能效果、地图结构、关卡配置。

### 2.4 编码约定（用户明确要求，来自 AGENTS.md/会话）
1. 与用户交流优先中文
2. 每个脚本文件写简短中文注释说明模块作用
3. 逻辑层与 UI 分离，规则不污染 UI
4. 新增功能优先新增模块，不大范围重写已有逻辑
5. 可配置数值放 JSON，不写死在脚本里
6. **Godot 项目只使用 GDScript/Godot 资源，不混用旧 Python/pygame 代码**
7. 函数尽量小、职责单一、避免隐藏副作用（计算函数不修改状态）

---

## 3. 系统设计（来自 tbs_game_system_design_v2.md）

### 3.1 总体架构模块
```
Core    游戏主循环、场景管理、输入分发
Battle  战斗规则、行动系统、回合管理、战斗计算
Entity  单位对象、技能对象、Buff 对象
AI      敌方行动逻辑、目标选择、移动规划
Data    JSON 配置加载、数据校验
UI      操作菜单、血条、战斗日志
Render  地图渲染、单位显示、动画特效
Save    战斗存档、关卡进度
```

### 3.2 核心系统

#### 回合系统
- 阵营回合制：玩家回合 → 敌方回合 → 下一回合
- 单位状态：Ready（可行动）/ Acted（已行动）/ Dead（死亡）
- 回合结束：玩家主动结束 或 当前阵营全部单位已行动

#### 网格与地图
- Tile 字段：`move_cost`（移动消耗）、`defense_bonus`（防御加成）、`passable`（可通行）
- 移动范围：**Dijkstra 算法**（不同地形不同成本）
- 路径搜索：A*（当前实现为 Dijkstra 回溯，可升级）
- **双战场**：左右各 3x4 独立网格，中间 gap，单位不能跨战场移动（原版 DualGrid，Godot 版待恢复）

#### 单位系统
- 属性：hp / max_hp / atk / def / move / range_min / range_max / camp
- 运行时状态：pos / acted / alive / team_id / buffs / cooldowns
- 行为：Move / Attack / UseSkill / Wait

#### 行动系统（设计目标）
所有行为通过 Action 执行：MoveAction / AttackAction / SkillAction / WaitAction，支持"移动→攻击"等组合。

#### 战斗与伤害
- 基础公式：`damage = max(1, attacker.atk - (defender.def + terrain_bonus))`
- 反击：防守方存活且攻击者在攻击范围内，每次攻击最多一次反击
- **跨战场攻击规则（原版关键规则）**：攻击距离 =（玩家单位到中间的距离 + 敌方单位到中间的距离），忽略 Y 轴偏移，小于等于最大攻击距离即可攻击

#### 技能系统
- 数据结构：id / name / cost / cooldown / target_type / range / aoe / effect
- 效果类型：Damage / Heal / Buff / Debuff / Displacement / Summon / Revive
- 执行流程：选择技能 → 选择目标 → 合法性检测 → 结算效果 → 写入战斗日志

#### AI 系统（MVP）
1. 攻击范围内有玩家单位 → 优先攻击可击杀目标
2. 不能攻击 → 移动到最近玩家单位
3. 无法移动 → 待机

#### 胜负条件
- 胜利：歼灭所有敌人
- 失败：主角死亡 / 回合数超限

---

## 4. 数据模型（JSON 格式，全部已落地）

### 4.1 data/unit/units.json（单位模板）
```json
{
  "Hero":   { "hp": 22, "atk": 7, "defense": 5, "move": 4, "range_min": 1, "range_max": 2, "skills": [] },
  "Knight": { "hp": 20, "atk": 6, "defense": 4, "move": 4, "range_min": 1, "range_max": 1, "skills": ["Power Strike"] },
  "Goblin": { "hp": 14, "atk": 4, "defense": 1, "move": 4, "range_min": 1, "range_max": 1, "skills": [] },
  "Orc":    { "hp": 18, "atk": 5, "defense": 2, "move": 3, "range_min": 1, "range_max": 1, "skills": [] }
}
```
注：字段名用 `defense`（避免 Python 关键字习惯保留）；攻击字段用 `atk`。

### 4.2 data/skill/skills.json（技能与 effect 列表，11 个）
结构：`{ "技能名": { "name", "min_range", "max_range", "effects": [ {type, power/buff/unit_type/hp_percent...} ] } }`
效果类型已配置：`damage`、`buff`、`summon`（Raise Skeleton）、`revive`（Revive Prayer）

技能清单：
- Power Strike（1.5x 伤害）、Poison Strike（伤害+中毒）、Regen Aura（回血）、Guard Shield（护盾）、Battle Chant（攻击提升）、Concussion Blow（伤害+眩晕）、Counter Stance（反击）、War Banner（光环）、Blood Rush（吸血）、Raise Skeleton（召唤）、Revive Prayer（复活）

### 4.3 data/buff/buffs.json（10 个）
字段：`name / duration / modifiers / tick_damage / tick_heal / tick_phase / control / shield / trigger / counter / aura_range / heal_percent`
- poison（3回合 DOT）、burn（2回合 DOT）、regen（HOT）、attack_up（+3攻击）、counter（反击标记）、attack_aura（2格光环+2攻击）、lifesteal（on_hit 吸血30%）、stun（眩晕）、silence（沉默）、shield（20点护盾）

### 4.4 data/equipment/equipments.json（5 件）
字段：`name / slot / modifiers / granted_skills`
- iron_sword（武器+2攻）、bronze_spear（武器+1攻+1防，授予 Counter Stance）、wooden_shield（副手+2防）、swift_boots（饰品+1移）、toxic_charm（饰品，授予 Poison Strike）

### 4.5 data/player/player_roster.json（玩家编成）
```json
{ "units": [ { "id", "type", "level", "exp", "stat_points", "skill_points",
               "equipment": {weapon/offhand/accessory}, "allocated_stats": {},
               "learned_skills": [], "equipped_skills": [], "extra_skills": [] } ] }
```
创建战斗单位时合并：模板 + 编成数据 + 成长点 + 已学/已装备技能 + 装备修正与装备授予技能。

### 4.6 data/scenario/battle_01.json（关卡，Godot 版新增）
```json
{ "name": "草原遭遇战", "width": 10, "height": 8,
  "player_units": [ { "roster_index": 0, "pos": [1,3] }, { "roster_index": 1, "pos": [2,4] } ],
  "enemy_units": [ { "type": "Goblin", "pos": [8,2] }, { "type": "Goblin", "pos": [8,5] }, { "type": "Orc", "pos": [7,4] } ] }
```

---

## 5. 架构与目录结构

### 5.1 Godot 版当前目录
```text
TBS_Game_Godot/
  project.godot                  # 主场景 main.tscn；autoload: GameDatabase
  scenes/
    main.tscn                    # 主菜单占位（标题 + 数据加载状态）
    battle_screen.tscn           # 战斗场景（TurnLabel/EndTurnButton/VictoryLabel/BattleView/LogPanel）
  scripts/
    core/
      game_database.gd           # autoload，加载全部 JSON
      tile.gd / grid.gd          # 网格
      unit.gd                    # 单位（属性计算/受伤/治疗/Buff/装备/技能）
      skill.gd / buff.gd / equipment.gd
    battle/
      movement/pathfinder.gd     # Dijkstra 可达范围 + 路径回溯
      combat/damage_calculator.gd / combat_system.gd
      turn/turn_manager.gd       # 阵营回合、acted 管理
      effects/effect_system.gd / damage_effect.gd / heal_effect.gd / buff_effect.gd
      events/event_types.gd / battle_event.gd / event_system.gd
      battle_manager.gd          # 战斗状态机：关卡加载/生成单位/移动/攻击/技能/胜负
      enemy_ai.gd                # 敌方决策
    screens/
      main_menu.gd               # 主菜单占位
    ui/
      battle_screen.gd           # 战斗界面：渲染+输入+行动菜单+技能菜单+敌方回合
      grid_view.gd               # 网格绘制与高亮（移动/攻击/目标/选中/悬停）
      unit_view.gd               # 单位绘制（阵营色块/名称/等级/血条）
  data/                          # JSON 数据（见第 4 节）
  docs/
    tbs_game_system_design_v2.md # 系统设计
    HANDOFF.md                   # 交接文档
  assets/                        # 美术/音频资源（当前为空）
```

### 5.2 Python 原版目录（复刻功能参照，代码不搬）
```text
game/
  ai/enemy_ai.py
  battle/combat/{combat_system,damage_calculator,highlight_system}.py
  battle/effects/{effect_system,damage_effect,heal_effect,buff_effect,summon_effect,revive_effect}.py
  battle/events/{battle_event,event_system,event_types}.py
  battle/movement/{grid,tile,pathfinder}.py        # grid.py 含 DualGrid 双战场
  battle/turn/turn_manager.py
  controllers/{player_controller,enemy_controller}.py
  core/{game,game_state,game_app,input_handler,scene_manager,texts}.py
  core/i18n/{zh_cn,en_us}.py
  data/{config_loader,game_database,schema_validator}.py
  entity/{buff,equipment,skill,unit}.py
  levels/level/{level_1,level_loader}.py
  levels/scenario/{scenario_1,scenario_loader}.py
  levels/systems/spawn_system.py
  player/{equipment_system,player_army,player_unit_data,progression_system}.py
  render/{map_renderer,highlight_renderer,path_renderer,attack_highlight_renderer}.py
  screens/{main_menu,level_select,progression_character_select,progression,deployment,battle,result}_screen.py + screen_base/manager
  state/{idle,move,attack,skill,game_state_base}.py
  ui/{action_menu,battle_log,battle_log_panel,font_manager,hud,language_shortcut,menu,scrollable_list,skill_menu,ui_system,unit_info_panel,progression_tabs,progression_stat_panel,progression_skill_panel,progression_equipment_panel,progression_unit_summary_panel}.py
  save/save_manager.py
tools/generate_unit_sprites.py   # 像素小人批量生成工具（+说明文档）
```

---

## 6. 原版已实现功能全貌（= Godot 版复刻目标）

### 6.1 核心战斗
- Grid/Tile、双战场 DualGrid（左右 3x4 + 中间 gap）
- Unit（config+state）、Dijkstra 移动范围、路径预览
- 伤害计算（含 Buff 修正与技能倍率）、攻击距离判定、跨战场攻击规则
- 回合管理（阵营切换、acted、Buff 生命周期、事件触发）
- 敌方 AI（攻击/移动/等待，逐单位执行）

### 6.2 战斗交互（原版 MVP 交互链）
- 选中单位 → 移动范围蓝色高亮 → 悬停路径预览 → 行动菜单（移动/攻击/技能/待机）→ 攻击范围红色高亮 → 攻击/技能结算 → 战斗日志
- 攻击/技能目标黄色高亮；取消与状态回退（曾修"无目标卡死"bug）
- 敌方回合自动运行 AI，每步 0.25s 延迟
- 战斗日志滚动显示（我方/敌方不同颜色），胜负判定与结算界面

### 6.3 战斗外流程（原版完整，Godot 版待补）
```
主菜单 → 选关 → 角色选择成长（属性/技能/装备三子页）→ 部署 → 战斗 → 结算
```
- 主菜单/选关/部署/结算屏幕
- 成长系统：EXP、升级、属性点、技能点、学习技能、装备技能，写回 player_roster.json
- 装备系统：weapon/offhand/accessory 三槽，属性修正 + 授予技能
- 部署系统：读取全局编成，放置到部署区

### 6.4 系统组件（原版，Godot 版待补）
- ~~i18n：中文/英文语言包~~（不做，仅中文版）
- 字体管理：LXGWWenKai-Light.ttf 中文支持
- 通用 ScrollableList 滚动组件
- 像素小人批量生成工具 tools/generate_unit_sprites.py（+ 使用说明 md）
- SaveManager 存档骨架

---

## 7. Godot 版当前实现细节（关键类说明）

### 7.1 core/game_database.gd（autoload）
- `_ready()` 加载 5 个 JSON；`get_unit/get_skill/get_buff/get_equipment/get_player_units/get_data_summary`
- 验证输出：`GameDatabase loaded: units=4 skills=11 buffs=10 equipments=5`

### 7.2 core/unit.gd
- `create_from_config(unit_type, camp, spawn_pos, config_data, roster_data, game_db)`：合并模板+编成+装备+技能
- 属性：`get_base_stat / get_stat`（模板+成长点+装备修正+Buff）；`get_attack/get_defense/get_move_points/get_range_min/get_range_max`
- 状态：`take_damage`（护盾吸收→扣血→致死判定）、`heal`、`add_buff`、`tick_turn_start/end`、`remove_expired_buffs`
- 控制：`is_stunned/is_silenced/has_counter`；技能：`add_skill/has_skill/apply_skills`

### 7.3 battle/battle_manager.gd（战斗状态机，纯逻辑）
- `setup()`：读 scenario → 建 Grid → 生成双方单位 → 组装 TurnManager/EventSystem/CombatSystem
- `get_move_tiles(unit)`：可达格（排除自身与占用）；`move_unit`（派发 ON_MOVE）
- `get_attack_targets / can_attack / perform_attack`（含胜负检查）
- `get_skill_targets / can_cast_skill / cast_skill`（伤害技能选敌阵营，增益技能选己方阵营）
- `get_nearest_target / wait / _check_winner`

### 7.4 battle/enemy_ai.gd
- `get_decision(manager, unit)`：范围内有敌→攻击；否则朝最近目标移动一格最优位置；否则待机

### 7.5 ui/battle_screen.gd（战斗界面）
- 状态机：IDLE → SELECTED → TARGETING → ENEMY_TURN → GAME_OVER
- 输入：鼠标移动悬停、左键点击；`_screen_to_cell` 基于 BattleView 局部坐标
- 选中 → 移动高亮 + 行动菜单（攻击/技能/待机/取消）→ 目标高亮 → 结算 → 日志
- 敌方回合：`_start_enemy_turn` → 逐单位 EnemyAI 决策 → 移动动画（tween 0.25s）→ 攻击 → 0.25s 延迟
- 胜负：`_check_battle_end` 显示胜利/失败
- `add_log` 日志上限 100 条

### 7.6 ui/grid_view.gd（绘制与高亮）
- 棋盘格（深浅交替）、不可通行暗色；移动=绿、攻击=红、目标=黄、选中=蓝、悬停=白透明

### 7.7 ui/unit_view.gd（单位绘制）
- 玩家蓝块/敌方红块、已行动变暗、名称/等级、血条与 HP 数字

---

## 8. 差距清单（Godot 版）

> 状态（2026-08-08）：重构完成，可完整游玩。以下按是否完成标注。

### P0 战斗体验修复 ✅
1. 双战场：左右各 4×3 + 中间 gap 2，单位不可跨战场移动
2. 战斗界面可操作性：真机已验证可用（曾修复根节点 mouse_filter 吞点击问题）
3. 跨战场攻击距离规则：逻辑列差忽略 Y 轴
4. 移动范围排除敌方占用格 + 无目标取消防卡死

### P1 战斗外流程 ✅
5. 主菜单 → 选关 → 部署 → 战斗 → 结算 屏幕链
6. 战斗外输入全部鼠标可点

### P2 成长与装备 ✅
7. 成长界面：属性加点 / 技能学习装备 / 装备切换 三个子页（两段式：先选角色再成长）
8. EXP/升级/点数写回 player_roster.json；装备槽位与授予技能；胜利奖励经验
9. 部署阶段读取全局编成

### P3 系统组件 ⚠️ 部分
10. 字体管理 ✅（霞鹜文楷）；i18n 已取消（仅中文版）
11. ScrollableList 通用滚动组件（未做）
12. 战斗日志增强、SaveManager（未做）

### P4 内容与工具 ⚠️ 部分
13. summon/revive effect 实现（数据已配置，EffectSystem 未实现）
14. Aura/Counter 触发完善、A* 路径、AOE/位移技能（未做）
15. 像素小人资源与批量生成工具 ✅（GDScript 重写，逐像素对齐原版）
16. 多关卡 ✅（battle_01/battle_02）；剧情内容扩展（后续按需求）

---

## 9. 开发历史与关键决策（时间线）

### 阶段一：Python 版（2026-03-09 ~ 03-12，会话 019cd228）
1. 设计文档 v2 → 项目骨架 → Tile/Grid → Unit → Pathfinder(Dijkstra) → DamageCalculator → TurnManager → EnemyAI → CLI 验证 → pygame 渲染 → HUD
2. 移动高亮 / 路径预览 / 行动菜单 / 攻击范围高亮 → Game 类重构 → **双战场系统**（3x4+gap）→ UI 面板布局 → **跨战场攻击规则**（距离=到中线之和，忽略Y轴）
3. 控制器拆分（player/enemy controller）→ 多单位支持 → Level/Scenario/SpawnSystem → Screen 系统 → Deployment 部署 → 战斗日志 → 技能系统（多 effect）→ Buff 系统（DOT/HOT/Stun/Silence/Shield/Counter/Aura）→ **Event System**（事件驱动反击/触发）
4. Progression 成长系统（EXP/加点/学技能）→ ProgressionScreen（属性/技能/装备三子页，两段式角色选择）→ 装备系统 → i18n（zh_cn/en_us，F2 切换）→ ScrollableList → 像素小人生成工具
5. 约定固化：中文注释、中文交流、数据驱动、逻辑UI分离（写入 AGENTS.md）

### 阶段二：Godot 迁移（2026-08-07 ~ 08-08）
6. 8/7 反复询问"godot 和 pygame 相比如何"（多次重试，Codex 当时已开始异常）→ 决定用 Godot 重写
7. 8/8 新建 GitHub 仓库 TBS_Game_Godot → 创建工程骨架 → 迁移 JSON 数据 → 实现核心实体与战斗逻辑 → 主菜单占位 → 验证通过（headless 输出 units=4 skills=11 buffs=10 equipments=5）
8. 期间 Codex 桌面版频繁"只回一句就停"（上下文管理 bug：request_model 错位为 gpt-5.4、窗口 128K vs 实际 1M、选择器 #19694 过滤），开发反复中断
9. 新窗口重构后战斗界面简陋（单战场、不可操作），用户要求输出完整复刻文档 → **本文档**

### 关键经验（接手者须知）
- Codex 会话历史里 189 条用户消息 + 648 条助手消息 + 1211 次工具调用 = 完整需求与实现决策来源
- 用户最终改用 opencode 开发；Codex 遗留问题不再纠缠

---

## 10. 复刻实施路线图（完成状态）

> 全部里程碑已完成（2026-08-08）。M5/M6 中的滚动列表、日志增强、存档、summon/revive、Aura/Counter、A*、AOE 等项目重构阶段不再展开，后续按新需求进行。

1. ✅ **M1 可玩闭环**：战斗交互 + 行动规则（移动一次+攻击一次）+ Buff 回合 tick
2. ✅ **M2 双战场**：DualGrid + 跨战场攻击规则
3. ✅ **M3 流程补齐**：主菜单 → 选关 → 部署 → 战斗 → 结算
4. ✅ **M4 成长/装备**：三子页 + 整体属性总览 + 战斗内单位信息 + 胜利奖励经验
5. ✅ **M5 系统完善**：字体管理（仅中文版）；滚动列表/日志增强/存档不展开
6. ✅ **M6 内容扩展**：多关卡 + 像素资源；summon/revive 等不展开

每个里程碑验收标准：无 headless 报错 + 真机手动可玩 + 数据可配置。

---

## 11. 运行与验证

```powershell
# 无头编译检查（验证脚本无语法错误）
& 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'D:\PycharmProjects\TBS_Game_Godot' --quit

# 正常启动（Godot 编辑器打开 project.godot，运行 main.tscn）
```
预期输出：`GameDatabase loaded: units=4 skills=11 buffs=10 equipments=5`

Godot 版本要求：4.7.x（当前用 4.7.1-stable，GL Compatibility）。
