# TBS_Game_Godot 交接文档

> 交接时间：2026-08-08
> 项目路径：`D:\PycharmProjects\TBS_Game_Godot`
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
D:\PycharmProjects\TBS_Game_Godot\project.godot
```

运行主场景：

```text
res://scenes/main.tscn
```

命令行无头检查：

```powershell
& 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'D:\PycharmProjects\TBS_Game_Godot' --quit
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

### 界面

- `scripts/screens/main_menu.gd`：主菜单占位，显示数据加载结果。
- `scenes/main.tscn`：当前主场景，只有标题和数据状态。

## 6. 尚未实现 / 下一阶段优先级

当前 EffectSystem 只实现了：

- `damage`
- `heal`
- `buff`

但 `skills.json` 里已经配置了更高级的技能数据，例如：

- `summon`（召唤）
- `revive`（复活）

因此这些 effect 类型需要新增 `SummonEffect` / `ReviveEffect` 后才能真正使用。

下一步建议按顺序做：

1. 搭建可交互的 `BattleScreen` / 战斗场景：网格渲染、单位显示、点击选择、行动菜单。
2. 接入 `TurnManager` 与 Enemy AI：让玩家回合、敌人回合能完整运行。
3. 补齐 `summon` / `revive` effect，并完善 Aura、Counter 等触发逻辑。
4. 实现战斗日志、胜利/失败判定。
5. 再做主菜单、关卡选择、部署、成长等外部流程。

## 7. 给新对话的恢复步骤

新对话中打开本文件后，先确认：

```powershell
Test-Path 'D:\PycharmProjects\TBS_Game_Godot\project.godot'
```

然后运行无头检查确认工程可编译：

```powershell
& 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'D:\PycharmProjects\TBS_Game_Godot' --quit
```

确认无报错后，从第 6 节“下一步建议”开始继续。

## 8. 编码约定

- 与用户交流优先使用中文。
- 每个 GDScript 文件都要有简短中文注释，说明模块作用。
- 保持逻辑层与 UI 分离。
- 新增功能优先做新模块，不要大范围重写已有逻辑。
- 数据优先放在 JSON，不要把可配置数值写死在脚本里。
- 不要混用旧 Python/pygame 代码，Godot 项目只使用 GDScript/Godot 资源。
