# TBS Game Godot

参考现有 Python/pygame 版本架构，使用 Godot 4.7 重新实现的原型项目。

## 当前状态

- 已完成 Godot 工程骨架
- 已接入 JSON 数据加载（单位、技能、Buff、装备、玩家编成）
- 已建立核心实体基础：Tile / Grid / Unit / Skill / Buff / Equipment
- 已建立战斗基础模块：Pathfinder / DamageCalculator / TurnManager / EffectSystem / EventSystem / CombatSystem
- 自走棋玩法：时间驱动独立回合、事件触发技能（14 时机）、自动战斗与胜负结算
- 完整流程：主菜单 → 选关 → 部署 → 自动战斗 → 结算；成长/装备、多关卡、素材、mod 系统
- 技能双轨制：固有技能（Hero"以战养战"击杀永久成长）+ 通用技能池；复杂技能支持 GDScript 代码实现
- 战斗表现：护盾条、技能详情（触发时机/冷却/持续时间）、移动+攻击动画链条

UI 与完整战斗流程仍在后续阶段实现

## 运行方式

1. 使用 Godot 4.7 打开 `project.godot`
2. 运行主场景 `scenes/main.tscn`
3. 当前主场景仅验证数据加载与工程可运行

## 目录

```text
data/                 # 从原 Python 项目复用的 JSON 数据
scenes/               # Godot 场景
scripts/
  core/               # 数据加载与实体
  battle/             # 战斗逻辑
  screens/            # 战斗外流程
  ui/                 # UI 组件
docs/                 # 设计文档与移植说明
assets/               # 美术/音频资源
```
## 交接文档

- [HANDOFF.md](docs/HANDOFF.md)：当前进度、架构、恢复步骤与下一步优先级。
- [tbs_game_system_design_v2.md](docs/tbs_game_system_design_v2.md)：系统设计参考。
