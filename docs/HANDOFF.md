# TBS_Game_Godot 交接文档

> 交接时间：2026-08-28（UI/流程同步）
> 项目路径：`D:\Shana Program\文档\TBS_Game_Godot`
> 参考项目：`D:\PycharmProjects\TBS_Game`（旧 Python/pygame 版，仅作设计参考，不混用代码）
> 参考素材：`E:\SteamLibrary\steamapps\common\Brave Nine`（棕色尘埃单机版，用于提取技能体系与中文文本）

## 1. 当前项目是什么

这是一个使用 **Godot 4.7 + GDScript** 实现的 **自走棋式战棋游戏**。

核心玩法已从"手动回合制战棋"改为**自走棋（auto-battler）**：

- **时间驱动独立回合**：每个单位有独立的 `turn_interval`（秒），到点自动行动
- **自动战斗**：射程内有敌人→攻击；无→移动再尝试攻击，直到一方全灭
- **事件触发技能**：技能按触发时机（攻击前/攻击时/受击/行动/击杀等）自动施放，非手动选择
- 完整流程：主菜单 → 选关 → 部署 → 自动战斗 → 结算
- 成长：属性/技能/装备三子页、胜利奖励经验写回编成
- 素材：动作图（站立/移动/攻击/死亡）+ 中文字体 + 可扩展 mod 系统

最近一次验证结果：

```text
Godot Engine v4.7.1
GameDatabase loaded: units=5 skills=12 buffs=11 equipments=5 relics=5
```

## 2. 如何运行

使用 Godot 4.7 打开：

```text
D:\Shana Program\文档\TBS_Game_Godot\project.godot
```

运行主场景：

```text
res://scenes/main.tscn
```

命令行无头检查：

```powershell
& 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'D:\Shana Program\文档\TBS_Game_Godot' --quit
```

### 网页版（GitHub Pages）

- 在线地址：<https://shana0325.github.io/TBS_Game_Godot/>
- 发布方式：一键脚本 `tools/deploy_web.ps1`（无头导出 Web 构建 → 独立 worktree 整体重建 gh-pages 分支并强推 → 清理；主分支工作区不受影响）。
- 每次想更新网页版：改完 main 后直接重跑该脚本即可，无需手动管理分支。
- 约束：Web 导出预设 `export_presets.cfg` 必须保持 `variant/thread_support=false`（GitHub Pages 无法设置 COOP/COEP 头，线程版会因 SharedArrayBuffer 不可用而无法启动）；Pages 源分支为 gh-pages 根目录。
- 进度保存：编成与背包数据写 `user://`（网页上自动落到浏览器 IndexedDB），首次运行由内建 JSON 播种（`GameDatabase._sync_user_roster`）。

## 3. 当前架构

```text
data/                   # JSON 数据配置
scenes/                 # Godot 场景
scripts/
  core/                 # 数据加载、实体、基础对象
  battle/
    movement/           # Dijkstra 移动范围与路径
    combat/             # 伤害计算、普通攻击/事件协调
    turn/               # 回合管理
    effects/            # 技能效果分发：damage / heal / buff
    events/             # 战斗事件常量、事件对象、事件分发
  screens/              # 主菜单、选关、部署、成长、结算、奖励界面控制器
  ui/                   # 战场显示、单位卡、背包弹窗、共享信息文本与布局组件
assets/                 # 美术/音频资源
  fonts/                # 当前运行时字体
  skills/               # 当前运行时技能图标
  units/                # 当前运行时单位图片和立绘
  reference/ui_material/ # 未接入的 UI 候选素材
docs/                   # 设计文档、交接文档
```

## 4. 数据文件

数据全部放在 `data/`，由 `GameDatabase` autoload 统一加载。

```text
data/unit/units.json                 # 单位模板（含 innate_skill 固有技能）
data/skill/skills.json               # 技能与 effect 列表（common=true 通用技能；无标记为固有/专用）
data/buff/buffs.json                 # Buff 配置
data/equipment/equipments.json       # 装备配置
data/relic/relics.json               # 遗物配置（爬塔局内成长）
data/tower/tower_config.json         # 爬塔配置（enemy_growth_rate 敌方属性成长率等）
data/player/player_roster.json       # 玩家编成、成长、技能、装备、permanent_mods 永久强化、inventory 背包
```

当前基础职业模板为 `Warrior`、`Tank`、`Archer`、`Assassin`，另保留 `Hero` 作为固有技能测试单位；旧的 Knight/Goblin/Orc 测试单位已删除。

创建 `Unit` 时会合并：

- 单位模板 `units.json`
- 玩家编成数据 `player_roster.json`
- 角色成长点 `allocated_stats`
- 永久强化 `permanent_mods`（跨战斗保留，如固有技能"以战养战"击杀成长）
- 固有技能（`innate_skill`，始终生效）与已装备的通用技能
- 装备属性修正与装备授予技能

## 5. 已实现模块说明

### 核心实体

- `scripts/core/tile.gd`：单个格子，保存坐标、移动消耗、防御加成、可通行状态。
- `scripts/core/grid.gd`：二维 Tile 网格，负责取格子和获取上下左右可通行邻居。
- `scripts/core/unit.gd`：单位，组合模板、成长、技能、Buff、装备；提供属性计算、受伤、治疗、Buff、控制状态等方法。
- `scripts/core/skill.gd`：技能基类，保存触发时机/条件/射程/effect 列表；支持一次性技能与目标生命/暴击条件。
- `scripts/core/buff.gd`：Buff，支持属性修正、条件属性修正、持续伤害、持续治疗、控制、护盾、触发型效果、反击标记等字段。
- `scripts/core/equipment.gd`：装备，保存槽位、属性修正、授予技能。
- `scripts/core/game_database.gd`：Godot autoload，统一加载和访问 JSON 数据；启动时合并代码技能（双轨）。

### 战斗系统

- `scripts/battle/movement/pathfinder.gd`：Dijkstra 移动范围计算和简单路径回溯。
- `scripts/battle/combat/damage_calculator.gd`：纯数值计算，不修改单位状态。
- `scripts/core/combat_formula.gd`：共享护甲减伤公式，供伤害计算与 UI 数值展示共用。
- `scripts/battle/combat/combat_system.gd`：普通攻击执行、射程判断、ON_ATTACK / ON_HIT / ON_KILL 事件分发。
- `scripts/battle/turn/turn_manager.gd`：阵营回合切换、单位 acted 状态管理。
- `scripts/battle/effects/effect_system.gd`：按 effect 类型分发技能效果（20 类原子效果函数）。
- `scripts/battle/effects/damage_effect.gd`：技能伤害效果。
- `scripts/battle/effects/heal_effect.gd`：技能治疗效果。
- `scripts/battle/effects/buff_effect.gd`：从 buffs.json 创建 Buff 并挂到单位。
- `scripts/battle/events/event_types.gd`：事件常量，避免字符串散落。
- `scripts/battle/events/battle_event.gd`：事件数据对象。
- `scripts/battle/events/event_system.gd`：遍历单位 Buff，将匹配 trigger 的事件交给 Buff。

### 界面与流程（当前：主菜单→选关→部署→战斗→结算/爬塔奖励）

- `scripts/core/game_session.gd`：全局会话 autoload，跨屏幕传递当前关卡、部署位置与战斗结果。
- `scripts/screens/main_menu.gd`：主菜单，提供“继续游戏”“开始新游戏”、队伍编成与退出入口；新游戏从内置种子重建角色和背包。
- `scripts/screens/level_select.gd`：选关屏幕，扫描 `data/scenario/` 生成关卡按钮，选择后进入部署。
- `scripts/screens/deployment_screen.gd`：部署屏幕，展示地图与底部横向单位栏；支持拖拽部署、拖拽换位、拖出部署区自动撤回，点击己方/敌方单位查看信息。
- `scripts/screens/result_screen.gd`：结算屏幕，展示胜负结果，提供"再来一局"与"返回主菜单"。
- `scenes/level_select.tscn` / `scenes/deployment_screen.tscn` / `scenes/result_screen.tscn`：对应场景。

### 成长与装备（M4 新增）

- `scripts/core/progress_manager.gd`：成长与背包逻辑（加点/升星/学技能/装备/换装备/技能书/写回 player_roster.json），纯逻辑不依赖 UI。
- `scripts/core/game_database.gd`：加载/迁移玩家存档；五个基础角色均为持久化角色，旧存档启动时自动补齐缺少的基础角色。
- `scripts/screens/progression_screen.gd`：成长界面，两段式（先选角色再成长），属性/技能/装备三个子页；右侧整体属性总览面板（含标签、星级、槽位和装备修正）实时刷新。
- `scenes/progression_screen.tscn`：成长界面场景；主菜单新增"队伍编成"入口。
- 战斗内单位信息面板（`battle_screen.gd`）：点击任意单位在左上角显示其属性/装备/技能/Buff。
- `scripts/ui/battle_screen.gd`：战斗界面（自走棋自动战斗），`_process` 驱动 `manager.tick`，播放行动动画/日志，判定胜负。
- `scripts/ui/grid_view.gd`：网格渲染，绘制地板、边框与高亮（当前自动战斗下移动/攻击高亮已不用，保留悬停/选中）。
- `scripts/ui/unit_view.gd`：单位渲染，动作贴图（stand/move/attack/death）填满格子，名称/血条/护盾条，acted 变暗。
- `scripts/ui/deployment_unit_card.gd`：部署/战斗底部单位卡共用组件；战斗中只读，部署中可拖动。
- `scripts/ui/unit_info_text.gd`：部署与战斗共用的单位信息文本格式化模块，防御显示为护甲及百分比减伤。
- `scripts/ui/backpack_panel.gd`：部署界面背包悬浮窗，以网格显示道具，提供名称/简介提示和技能书拖拽来源。
- `scripts/ui/backpack_item_cell.gd`：背包网格道具格子，负责技能书拖拽数据和道具悬停/点击交互。
- `scripts/ui/battle_layout.gd`：根据视口与行列数计算自适应格子大小并居中战场。
- `scenes/battle_screen.tscn`：战斗场景（网格、单位层、日志面板、回合标签）。
- `data/scenario/battle_01.json`：关卡（12×6，2 玩家 vs 3 敌方，玩家部署左半区 x0-5）。

当前 UI 行为约定：

- 部署与战斗使用同一战场安全区和底部单位栏尺寸规则。
- 战斗底部栏只显示未上场单位，保留展示但关闭拖动；底部卡片与部署阶段共用同一组件。
- 战斗胜利奖励在当前战斗场景内以半透明悬浮窗显示，可隐藏以查看战场；选择或跳过奖励均进入下一层部署。
- 信息卡无关闭按钮，点击卡片外区域隐藏；部署和战斗均可查看己方与敌方单位。
- 战斗倍速保存在 `GameSession`，下一场战斗继承；离开战斗时只重置时间缩放。

### 战斗系统（自走棋）

- `scripts/battle/battle_manager.gd`：纯逻辑战斗状态机，`tick(delta)` 驱动时间推进；`_auto_act` 处理单位自动行动（攻击/移动）；`perform_attack` 分发技能触发时机与反射；`spawn_unit`/`move_unit_to` 供技能调用。
- `scripts/battle/turn/turn_manager.gd`：时间驱动独立回合，每单位 `turn_interval` + `turn_timer`，`tick(delta)` 统一推进。
- `scripts/battle/enemy_ai.gd`：敌方 AI（含嘲讽引导目标）。
- `scripts/battle/skills/skill_trigger_system.gd`：技能触发系统，14 个触发时机按事件流自动施放（条件/冷却/目标解析均走 Skill 对象钩子，双轨兼容）。
- `scripts/battle/skills/code_skill.gd`：代码技能基类（继承 Skill），复杂逻辑技能覆写钩子实现。
- `scripts/battle/skills/skill_code_registry.gd`：代码技能集中注册文件（id -> 脚本路径），启动时并入技能表。
- `scripts/battle/effects/effect_system.gd`：注册表驱动效果分发，已实现 20 类 effect。
- `scripts/battle/combat/combat_system.gd` / `damage_calculator.gd`：攻击执行与伤害计算（曼哈顿距离射程，支持无视防御/减伤/反射）。
- `scripts/core/grid.gd`：10×10（或按关卡 12×6）单战场，曼哈顿距离；`setup_dual`/跨战场逻辑已弃用但保留兼容。
- `scripts/core/unit.gd`：`turn_interval`/`turn_timer`、`moved` 状态、状态查询（taunt/immune/reflect/ignore 等）。

## 6. 项目状态：自走棋改造（2026-08-10）

> 已完成从"手动回合制战棋"到"自走棋（auto-battler）"的改造，本阶段告一段落。
> 后续开发按新需求进行。

已完成里程碑（M1-M4 重构期 → 自走棋期）：

- **M1-M4（重构期，2026-08-08）**：可玩闭环、双战场、完整流程（主菜单→选关→部署→战斗→结算）、成长/装备、多关卡、像素素材、mod 系统。
- **自走棋核心**：时间驱动独立回合（每单位 `turn_interval`）、自动攻击/移动（1 移动力）、胜负判定。
- **战场规格**：单战场 12×6，曼哈顿距离射程，格子随视口自适应放大，单位动作图填满格子。
- **技能触发系统**：14 个触发时机（battle_start/turn_start/attack_start/attack/attack_end/hit/be_attacked/taken_damage/kill/death/ally_death/turn_end/round_start/passive）+ 条件/冷却/目标解析。
- **效果类型库（20 类）**：damage/heal/revive/dispel/summon/mark/teleport（位移家族）/percentage_damage/chain_damage/permanent_stat/buff/dot/shield/stat_mod/taunt/immunity/reflect/protect/ignore/lifesteal。
- **技能本地化**：全部技能/Buff/装备中文名（参照棕色尘埃效果类别）。
- **素材**：hero 四等分动作图（站立/移动/攻击/死亡）、中文字体、像素小人生成器。
- **mod 系统**：目录扫描加载 + 角色素材约定目录（详见 docs/MOD_GUIDE.md）。

### 技能体系双轨与养成改造（2026-08-11）

- **固有技能 + 通用技能**：units.json 新增 `innate_skill`（Hero 固有"以战养战"）；skills.json 现有技能标记 `common: true` 归入通用技能池（编成中学习/装备，消耗技能点）。
- **标签与检索**：单位模板支持 `tags`；技能支持 `tags` 与 `searchable`。不可检索技能排除常规学习、敌人随机技能和爬塔随机技能奖励，但可由指定逻辑直接获取。
- **星级与技能槽**：单位从 1 星开始，当前最高 3 星；每次升星使初始生命/攻击/护甲提高 50%。通用技能槽为 1/2/3 格，升星最多增加 2 格。
- **永久属性强化**：新效果类型 `permanent_stat`（persist=true 全局永久写回编成；false 仅本局永久）；Unit 新增 `permanent_mods` 字段；一并修复"max_hp 不吃装备/Buff 修正"的旧问题。
- **以战养战**：Hero 固有技能，`on_kill` 触发，生命上限永久 +1（当前生命同步 +1），无上限。
- **已学未装备修复**：只有"已装备"的通用技能参与战斗（原为学了就生效）。
- **护盾条**：战斗内血条上方蓝色护盾条（剩余/初始比例显示），信息面板显示"护罩 X/Y"。
- **技能详情**：队伍编成技能页点击技能显示完整详情（描述/触发时机/冷却/射程/目标/效果含持续时间）；非位置类目标（自身/全体）不显示射程。
- **部署区**：battle_01/battle_02 部署区扩为左半场全部 6 行（x0-5 × y0-5）。
- **动画修复**：同一行动"移动后攻击"的动画链条化，攻击动画不再被移动吞掉。

### 代码技能双轨（2026-08-11 新增架构）

- `Skill` 基类提供可覆写钩子：`check_condition`（触发条件）、`resolve_targets`（目标解析）、`execute`（效果执行）；JSON 技能走默认数据驱动实现，行为不变。
- 复杂技能：继承 `CodeSkill` 覆写钩子，并在 `skill_code_registry.gd` 集中注册一行（id + 脚本路径）。
- GameDatabase 启动时把代码技能并入全局技能表，战斗/编成/信息面板统一可见。
- 新增 `class_name` 后需运行一次 `--import` 刷新全局类缓存。

### 爬塔模式（阶段一，2026-08-11 新增）

设计方向见 `docs/爬塔模式设计方向.md`；本阶段为最小闭环：

- **入口**：主菜单新增"爬塔模式"（与快速对战并存）；沿用当前编成自动部署。
- **会话**：`GameSession` 新增 `mode / tower_floor / run_relics / run_blessings` 与 `scenario_override`（运行时覆盖关卡字典）。
- **层生成**：`TowerGenerator` 按层生成敌人（使用四种职业模板，敌人按层配技能成长；精英/Boss 机制已移除，待重设计）。
- **背包**：部署界面右侧操作区提供“背包”按钮。悬浮窗以网格显示升星道具与技能书，点击/悬停显示名称和简介；技能书可直接拖到我方单位，满槽时弹出替换列表，取消不消耗技能书。点击背包外区域自动关闭。首次存档发放 99 个升星道具和每种可学习通用技能书 1 本用于测试。
- **技能详情**：`skill_detail_formatter.gd` 统一生成单位信息卡和背包技能书使用的技能详情；部署底部未上场角色卡也可直接接收技能书。
- **奖励**：胜利进入 `reward_screen` 三选一（技能书/装备/祝福/遗物，`RewardGenerator` 生成与应用）；技能书和装备奖励写回编成/背包。
- **狂暴**：`TurnManager` 在 60 秒后每 30 秒将双方最终伤害提高 50%；`BattleScreen` 在战斗时间右侧显示当前增幅，普攻、技能、百分比伤害和持续伤害统一应用。
- **遗物系统**：`data/relic/relics.json` 首期 5 个（战神徽章/急速披风/鲜血吊坠/不灭徽记/荆棘之心）；`RelicSystem` 战斗开始应用（stat_percent / turn_speed / 永久反射 Buff），事件钩子 on_kill 回血、on_first_death 复活（每场一次）。Unit 新增 `percent_mods`（百分比属性）、Buff 新增 `permanent` 标记（不衰减）。
- **敌方数值成长（配置化）**：`data/tower/tower_config.json` 提供 `enemy_growth_rate`（默认 1.04，第一轮测试参数，按战斗模拟结果调整）；敌人属性倍率 `Multiplier = rate^(层数-1)` 作用于 HP/ATK/DEF（Unit 新增 `stat_multiplier`）；技能数量按层段生成（1-10:0 / 11-20:1 / 21-30:2 / 31+:3，上限 3）。技能 tags 暂不参与抽取（仅预留）。参考 `docs/爬塔敌方数值设计文档_V1.md`。

已知边界：不灭徽记复活仅挂"攻击致死"路径（DOT/技能间接致死暂不触发）；商店/事件/31+ 无限层未做。

> 已取消：i18n（仅中文版）。文档见 `docs/skills/SKILL_SYSTEM.md`（含触发时机/效果实现状态与待办）。

## 7. 给新对话的恢复步骤

新对话中打开本文件后，先确认：

```powershell
Test-Path 'D:\Shana Program\文档\TBS_Game_Godot\project.godot'
```

然后运行无头检查确认工程可编译（首次需先生成 `.godot` 全局类缓存）：

```powershell
& 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'D:\Shana Program\文档\TBS_Game_Godot' --import
& 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'D:\Shana Program\文档\TBS_Game_Godot' --quit
```

跑战斗场景冒烟测试（自动退出）：

```powershell
& 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'D:\Shana Program\文档\TBS_Game_Godot' --quit-after 10 'res://scenes/battle_screen.tscn'
```

确认无报错后，项目状态见第 6 节；后续开发按新需求进行。

自走棋功能验证要点（GUI 手动）：

1. 主菜单 → 选关 → 部署 → 战斗，双方单位按各自 `turn_interval` 自动行动。
2. 观察动作图切换（站立/移动/攻击）、日志技能触发、中文技能名。
3. 胜负判定后自动进入结算（胜利发放经验）。
4. 点击单位查看信息面板（含技能/Buff/装备）。

技能/效果设计规范见 `docs/skills/SKILL_SYSTEM.md`；mod 角色制作见 `docs/MOD_GUIDE.md`。

> 注意：项目现位于 `D:\Shana Program\文档\TBS_Game_Godot`（已克隆自 `shana0325/TBS_Game_Godot`）。

## 8. 编码约定

- 与用户交流优先使用中文。
- 每个 GDScript 文件都要有简短中文注释，说明模块作用。
- 保持逻辑层与 UI 分离。
- 新增功能优先做新模块，不要大范围重写已有逻辑。
- 数据优先放在 JSON，不要把可配置数值写死在脚本里。
- 新增简单技能：改 JSON 组合效果积木；新增复杂技能：继承 CodeSkill 写代码并集中注册。
- 新增 `class_name` 的脚本后，运行一次 `--import` 刷新全局类缓存再跑无头检查。
- 不要混用旧 Python/pygame 代码，Godot 项目只使用 GDScript/Godot 资源。
- **删除目录/文件前先向用户确认**：尤其批量生成产物、非本会话创建或未提交 git 的文件；先说明价值判断（有用/无用/可重建），由用户明确同意后再删除。
