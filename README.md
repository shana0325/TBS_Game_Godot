# TBS Game Godot

使用 Godot 4.7 / GDScript 实现的自走棋式战棋爬塔项目，旧 Python/pygame 版本仅作为设计参考。

## 当前状态

- 已完成 Godot 工程骨架
- 已接入 JSON 数据加载（单位、技能、Buff、装备、玩家编成）
- 已建立核心实体基础：Tile / Grid / Unit / Skill / Buff / Equipment
- 已建立战斗基础模块：Pathfinder / DamageCalculator / TurnManager / EffectSystem / EventSystem / CombatSystem
- 自走棋玩法：时间驱动独立回合、事件触发技能（14 时机）、自动战斗与胜负结算
- 完整流程：主菜单 → 选关 → 部署 → 自动战斗 → 结算；成长/装备、多关卡、素材、mod 系统
- 技能双轨制：固有技能（Hero"以战养战"击杀永久成长）+ 通用技能池；复杂技能支持 GDScript 代码实现
- 战斗表现：护盾条、技能详情（触发时机/冷却/持续时间）、移动+攻击动画链条
- 爬塔模式：按层生成敌人、战斗场景内悬浮奖励选择、三选一奖励、跳过奖励进入下一层、遗物与祝福
- 部署体验：1920×1080 适配、非全屏窗口、底部横向单位栏、拖拽部署/换位/移出区域自动撤回
- 战斗体验：部署与战斗保持同一战场尺寸，底部未部署单位栏只读显示，日志悬浮展开，倍速跨战斗保留
- 单位信息：部署和战斗共用信息文本格式，点击己方/敌方单位查看，点击信息卡外区域隐藏
- UI 结构：核心战斗逻辑不引用 UI；界面控制器通过 `GameSession`、`BattleManager` 等接口驱动显示

当前仍属于可玩的原型，视觉素材暂不接入游戏界面，使用 Godot 内置 `StyleBoxFlat` 维持可读性。

## 运行方式

1. 使用 Godot 4.7 打开 `project.godot`
2. 运行主场景 `scenes/main.tscn`
3. 主菜单可进入选关、部署、自动战斗、结算/爬塔奖励流程

无头检查：

```powershell
& 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path '<项目路径>' --editor --quit
```

## 目录

```text
data/                 # 从原 Python 项目复用的 JSON 数据
scenes/               # Godot 场景
scripts/
  core/               # 数据加载与实体
  battle/             # 战斗逻辑
  screens/            # 主菜单、选关、部署、成长、结算、奖励界面控制器
  ui/                 # 可复用 UI 组件与战场显示
docs/                 # 设计文档与移植说明
assets/               # 美术/音频资源
```
## 交接文档

- [HANDOFF.md](docs/HANDOFF.md)：当前进度、架构、恢复步骤与下一步优先级。
- [tbs_game_system_design_v2.md](docs/tbs_game_system_design_v2.md)：系统设计参考。
- [MOD_GUIDE.md](docs/MOD_GUIDE.md)：单位数据、技能和素材 Mod 制作规范。
