# TBS Game Godot 项目结构索引

本文件是项目级导航地图，不记录每个脚本的完整内容。处理任务时，先根据任务类型定位相关目录，再读取必要的文件。

## 项目定位

- 引擎：Godot 4.7，主要语言为 GDScript。
- 类型：2D 自走棋式战棋、自动战斗、爬塔原型。
- 核心方式：JSON 数据驱动，战斗逻辑与 UI 表现分离。
- 当前流程：主菜单 → 选关 → 部署 → 自动战斗 → 当前场景内结算/奖励 → 下一层。

## 文档层级

| 目的 | 入口 | 用途 |
| --- | --- | --- |
| 开发维护规则 | `AGENTS.md` | 上下文读取、改动边界、验证与文档维护约定 |
| 项目导航 | `docs/PROJECT_MAP.md` | 目录职责、模块关系、任务路由 |
| 系统设计 | `docs/tbs_game_system_design_v2.md` | 总体玩法、系统和架构意图 |
| 数值技能设计 | `docs/数值与技能设计文档_V1.md` | 职业模板、技能与数值方向 |
| 爬塔方向 | `docs/爬塔模式设计方向.md` | 爬塔流程、奖励和局内成长方向 |
| 当前交接 | `docs/HANDOFF.md` | 已完成内容、恢复步骤和后续优先级 |
| Mod 制作 | `docs/MOD_GUIDE.md` | 单位、技能、素材 Mod 的数据格式 |
| LC2 参考 | `docs/LC2参考索引.md` | 外部参考项目的目录级索引；不等于源码副本 |

设计文档描述目标，代码和数据描述当前实际行为；若两者不一致，修改前先判断任务是修正实现还是更新设计，不要自动用代码覆盖设计意图。

## 顶层目录

| 目录 | 职责 | 是否默认读取 |
| --- | --- | --- |
| `data/` | 单位、技能、Buff、装备、遗物、玩家编成等 JSON 数据 | 相关数据任务时读取 |
| `scenes/` | Godot 场景资源和节点布局 | UI/流程任务时读取 |
| `scripts/core/` | 数据库、实体、会话、资源管理等基础模块 | 核心逻辑或数据流任务时读取 |
| `scripts/battle/` | 战斗管理、移动、回合、伤害、效果、事件和技能触发 | 战斗任务时读取 |
| `scripts/screens/` | 主菜单、选关、部署、成长、结算等界面控制器 | 流程/UI 任务时读取 |
| `scripts/ui/` | 战场显示、单位视图、信息卡、背包弹窗和可复用 UI 组件 | UI 任务时读取 |
| `assets/fonts/` | 当前运行时字体 | 字体/UI 任务时读取 |
| `assets/skills/` | 当前运行时技能图标 | 技能图标或美术任务时读取 |
| `assets/units/` | 当前运行时单位图片和立绘 | 单位表现任务时读取 |
| `assets/reference/ui_material/` | 原 `material` 目录及未接入 UI 候选素材 | 仅视觉素材任务明确需要时读取 |
| `mods/` | Mod 示例、清单和外部内容入口 | Mod 任务时读取 |
| `docs/` | 设计、交接、索引和制作说明 | 按任务读取相关文档 |
| `tools/` | 发布、部署和辅助工具 | 发布/工具任务时读取 |
| `feature_profiles/` | 功能开关或开发配置 | 配置任务时读取 |
| `script_templates/` | 脚本模板 | 新建对应脚本时读取 |
| `text_editor_themes/` | 编辑器主题配置 | 编辑器配置任务时读取 |
| `.godot/` | Godot 生成的导入缓存和编辑器状态 | 默认不读取、不手动编辑 |
| `web_build/` | 网页发布生成物 | 默认不读取，发布验证时读取 |

## 运行时关系

```text
project.godot
  └─ autoload: GameDatabase / ModLoader / ArtManager / GameSession
       ├─ data/*.json → GameDatabase → Unit / Skill / Buff / Equipment
       ├─ scenes/main.tscn → 主菜单 → 选关 → 部署 → 战斗
       └─ BattleManager → 战斗状态/事件 → battle_screen 与复用 UI 组件
```

### 主要边界

- `scripts/core/` 和 `scripts/battle/` 负责状态、规则和事件，不应直接依赖具体 UI 场景节点。
- `scripts/screens/` 负责页面流程和输入协调，通过 `GameSession`、`BattleManager` 等接口驱动显示。
- `scripts/ui/` 负责表现和交互组件；部署与战斗需要一致的单位信息时，优先复用已有组件和文本格式。
- 数据平衡优先修改 `data/` 与对应设计文档，不把可配置数值硬编码到界面脚本。

## 按任务定位

| 任务 | 首先读取 | 通常还需要 |
| --- | --- | --- |
| 修改部署/战斗布局 | `scenes/`、对应 `scripts/screens/` | `scripts/ui/`、相关场景资源 |
| 修改战斗规则 | `scripts/battle/` | `scripts/core/`、对应 `data/` |
| 修改单位/技能数值 | `data/`、数值技能设计文档 | `GameDatabase`、实体脚本 |
| 修改单位信息卡 | `scripts/ui/unit_detail_panel.gd` | 部署/战斗调用处 |
| 修改背包弹窗 | `scripts/ui/backpack_panel.gd` | 部署界面调用处、`ProgressManager` 背包接口 |
| 修改技能图标 | `scripts/core/art_manager.gd` | `assets/skills/`、技能数据 |
| 修改单位图片 | `scripts/core/art_manager.gd` | `assets/units/`、单位数据 |
| 处理未接入 UI 素材 | `assets/reference/ui_material/介绍文档.md` | 仅在确认接入时读取具体图片并修改主题/场景 |
| 参考 LC2 某项功能 | `docs/LC2参考索引.md` | 仅读取索引指向的少量 LC2 文件 |

## 资源组织规则

- 已被运行时引用的资源放入 `assets/` 下对应的正式目录。
- `assets/reference/ui_material/` 仅是候选/参考素材，不应在场景或脚本中直接引用。
- 资源正式接入时，应同时检查引用路径、Godot 导入状态和 README/相关说明。
- `.import`、`.uid`、`.godot/` 内容由 Godot 或工具生成，默认不手动修改。
- 旧素材不因“看起来可能有用”重新接入；接入必须由明确的视觉任务驱动。

## 文档更新规则

- 目录移动、核心模块新增/删除、架构边界变化：更新本索引。
- 玩法、数值、技能目标变化：更新对应设计文档。
- 阶段性功能完成或交接：更新 `docs/HANDOFF.md`。
- 用户可见的运行方式或项目概览变化：更新根目录 `README.md`。
- 小型 bug 修复、局部样式调整不要求重写整套文档。

## 最近一次结构整理

2026-08-29：将未被运行时引用的根目录 `material/` 和未引用的 `assets/ui/panel_ornate_reference.png` 归入 `assets/reference/ui_material/`；删除空的 `assets/ui/placeholders/` 与空的 `assets/ui/`。当前运行时资源目录未改变。
