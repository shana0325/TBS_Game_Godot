# TBS_Game_Godot 交接文档

> 交接时间：2026-08-08
> 项目路径：`D:\Shana Program\文档\TBS_Game_Godot`
> 参考项目：`D:\PycharmProjects\TBS_Game`（旧 Python/pygame 版，仅作设计参考，不混用代码）

## 1. 当前项目是什么

这是一个使用 **Godot 4.7 + GDScript** 重新实现的 2D 回合制战棋原型。

目标是从旧 Python/pygame 项目迁移架构，但代码完全使用 Godot/GDScript 重新编写。

当前已完成的不是可玩游戏，而是：

- Godot 工程骨架
- JSON 数据加载
- 核心实体（Tile / Grid / Unit / Skill / Buff / Equipment）
- 战斗逻辑基础层（移动、伤害、回合、效果、事件）
- 可无头启动的主菜单占位场景

最近一次验证结果：

```text
Godot Engine v4.7.1
GameDatabase loaded: units=4 skills=11 buffs=10 equipments=5
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
  screens/              # 战斗外流程（目前只有主菜单占位）
  ui/                   # 后续 UI 组件
assets/                 # 美术/音频资源
docs/                   # 设计文档、交接文档
```

## 4. 数据文件

数据全部放在 `data/`，由 `GameDatabase` autoload 统一加载。

```text
data/unit/units.json                 # 单位模板
data/skill/skills.json               # 技能与 effect 列表
data/buff/buffs.json                 # Buff 配置
data/equipment/equipments.json       # 装备配置
data/player/player_roster.json       # 玩家编成、成长、技能、装备
```

创建 `Unit` 时会合并：

- 单位模板 `units.json`
- 玩家编成数据 `player_roster.json`
- 角色成长点 `allocated_stats`
- 已学/已装备技能
- 装备属性修正与装备授予技能

## 5. 已实现模块说明

### 核心实体

- `scripts/core/tile.gd`：单个格子，保存坐标、移动消耗、防御加成、可通行状态。
- `scripts/core/grid.gd`：二维 Tile 网格，负责取格子和获取上下左右可通行邻居。
- `scripts/core/unit.gd`：单位，组合模板、成长、技能、Buff、装备；提供属性计算、受伤、治疗、Buff、控制状态等方法。
- `scripts/core/skill.gd`：技能模板，保存射程与 effect 列表，执行统一交给 EffectSystem。
- `scripts/core/buff.gd`：Buff，支持属性修正、持续伤害、持续治疗、控制、护盾、触发型效果、反击标记等字段。
- `scripts/core/equipment.gd`：装备，保存槽位、属性修正、授予技能。
- `scripts/core/game_database.gd`：Godot autoload，统一加载和访问 JSON 数据。

### 战斗系统

- `scripts/battle/movement/pathfinder.gd`：Dijkstra 移动范围计算和简单路径回溯。
- `scripts/battle/combat/damage_calculator.gd`：纯数值计算，不修改单位状态。
- `scripts/battle/combat/combat_system.gd`：普通攻击执行、射程判断、ON_ATTACK / ON_HIT / ON_KILL 事件分发。
- `scripts/battle/turn/turn_manager.gd`：阵营回合切换、单位 acted 状态管理。
- `scripts/battle/effects/effect_system.gd`：按 effect 类型分发技能效果。
- `scripts/battle/effects/damage_effect.gd`：技能伤害效果。
- `scripts/battle/effects/heal_effect.gd`：技能治疗效果。
- `scripts/battle/effects/buff_effect.gd`：从 buffs.json 创建 Buff 并挂到单位。
- `scripts/battle/events/event_types.gd`：事件常量，避免字符串散落。
- `scripts/battle/events/battle_event.gd`：事件数据对象。
- `scripts/battle/events/event_system.gd`：遍历单位 Buff，将匹配 trigger 的事件交给 Buff。

### 界面与流程（M3 新增：主菜单→选关→部署→战斗→结算）

- `scripts/core/game_session.gd`：全局会话 autoload，跨屏幕传递当前关卡、部署位置与战斗结果。
- `scripts/screens/main_menu.gd`：主菜单，显示数据加载结果，提供开始游戏（进入选关）与退出入口。
- `scripts/screens/level_select.gd`：选关屏幕，扫描 `data/scenario/` 生成关卡按钮，选择后进入部署。
- `scripts/screens/deployment_screen.gd`：部署屏幕，展示地图与蓝色部署区，右侧编成槽位，点选单位后点击部署格放置（可反复调整位置，槽位显示已部署状态），全部就绪后可开始战斗。
- `scripts/screens/result_screen.gd`：结算屏幕，展示胜负结果，提供"再来一局"与"返回主菜单"。
- `scenes/level_select.tscn` / `scenes/deployment_screen.tscn` / `scenes/result_screen.tscn`：对应场景。

### 成长与装备（M4 新增）

- `scripts/core/progress_manager.gd`：成长逻辑（加点/学技能/装技能/换装备/写回 player_roster.json），纯逻辑不依赖 UI。
- `scripts/screens/progression_screen.gd`：成长界面，两段式（先选角色再成长），属性/技能/装备三个子页；右侧整体属性总览面板（含装备修正）实时刷新。
- `scenes/progression_screen.tscn`：成长界面场景；主菜单新增"队伍编成"入口。
- 战斗内单位信息面板（`battle_screen.gd`）：点击任意单位在左上角显示其属性/装备/技能/Buff。
- `scripts/ui/battle_screen.gd`：战斗界面控制器，处理点击选择/移动/行动菜单/技能目标，驱动 BattleManager 与敌方 AI。
- `scripts/ui/grid_view.gd`：网格渲染，绘制地板、边框与移动/攻击/目标/悬停高亮。
- `scripts/ui/unit_view.gd`：单位渲染，按阵营绘制方块、名称、等级、血条，支持移动补间。
- `scenes/battle_screen.tscn`：战斗场景，包含网格、单位层、日志面板、回合标签、结束回合按钮。
- `data/scenario/battle_01.json`：第一个关卡（双战场 4+2+4×3，2 玩家单位 vs 3 敌方单位）。

### 战斗流程（本轮新增）

- `scripts/battle/battle_manager.gd`：纯逻辑战斗状态机，负责战局创建（读关卡与编成）、移动范围、攻击、技能、回合与胜负判定；新增 `next_turn()` 在切换回合时执行 Buff 回合 tick。
- `scripts/battle/enemy_ai.gd`：敌方简单 AI，射程内有玩家就攻击，否则朝最近的玩家移动。
- `scripts/core/grid.gd`：支持双战场（`setup_dual`：左右子战场 + 中间不可通行 gap），提供 `get_side_for_position` / `cross_grid_distance`。
- `scripts/battle/combat/combat_system.gd`：跨战场攻击规则——同战场 Chebyshev 距离，跨战场按逻辑列差（忽略 Y 轴）。
- `scripts/core/unit.gd`：新增 `moved` 状态，单回合限制"移动一次 + 攻击/技能一次"（可先移动后攻击）。

## 6. 尚未实现 / 下一阶段优先级

已完成（M1+M2）：

- M1 可玩闭环：可交互的战斗场景（网格渲染、单位显示、点击选择/移动、行动菜单、普通攻击、技能、日志、结束回合、敌方 AI、胜负判定）。
- 行动规则：单回合移动一次 + 攻击/技能一次，先移动后攻击，待机结束行动。
- Buff 回合 tick：切换回合时旧阵营 tick_end、新阵营 tick_start（毒/燃烧/回血/晕眩真实生效）。
- M2 双战场：左右 4×3 子战场 + 中间 2 列 gap，单位不可跨战场移动，跨战场攻击按逻辑列差忽略 Y 轴。

当前 EffectSystem 只实现了：

- `damage`
- `heal`
- `buff`

但 `skills.json` 里已经配置了更高级的技能数据，例如：

- `summon`（召唤）
- `revive`（复活）

因此这些 effect 类型需要新增 `SummonEffect` / `ReviveEffect` 后才能真正使用。

下一步建议按顺序做（对应 REPLICATION.md 路线图 M5/M6）：

1. **M5/M6 系统完善与内容扩展**：summon/revive effect、Aura/Counter 触发完善、A* 路径、AOE、多关卡、战斗日志增强、存档。

> 已取消：i18n（仅中文版）。

## 6.1 已完成里程碑（2026-08-08 会话）

- **M1 可玩闭环**：战斗交互（选中/移动/攻击/技能/回合/胜负）、行动规则（单回合移动一次+攻击一次）、Buff 回合 tick。
- **M2 双战场**：左右 4×3 + gap 2，跨战场攻击按逻辑列差忽略 Y 轴。
- **M3 完整流程**：主菜单 → 选关 → 部署 → 战斗 → 结算（全部鼠标可点，GameSession 传递状态）。
- **M4 成长/装备**：属性/技能/装备三子页 + 右侧整体属性总览 + 战斗内单位信息面板 + 胜利奖励经验写回 roster。
- **素材**：像素小人贴图（hero/knight/goblin/orc）、霞鹜文楷中文字体、GDScript 像素小人生成器（逐像素对齐原版）。

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

确认无报错后，从第 6 节“下一步建议”开始继续。

> 注意：项目现位于 `D:\Shana Program\文档\TBS_Game_Godot`（已克隆自 `shana0325/TBS_Game_Godot`）。

## 8. 编码约定

- 与用户交流优先使用中文。
- 每个 GDScript 文件都要有简短中文注释，说明模块作用。
- 保持逻辑层与 UI 分离。
- 新增功能优先做新模块，不要大范围重写已有逻辑。
- 数据优先放在 JSON，不要把可配置数值写死在脚本里。
- 不要混用旧 Python/pygame 代码，Godot 项目只使用 GDScript/Godot 资源。
