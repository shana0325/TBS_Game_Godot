# TBS Game Godot

使用 Godot 4.7 / GDScript 实现的自走棋式战棋爬塔项目，旧 Python/pygame 版本仅作为设计参考。

## 当前状态

- 已完成 Godot 工程骨架
- 已接入 JSON 数据加载（单位、技能、Buff、装备、遗物、玩家编成与背包）
- 已建立核心实体基础：Tile / Grid / Unit / Skill / Buff / Equipment
- 已建立战斗基础模块：Pathfinder / DamageCalculator / TurnManager / EffectSystem / EventSystem / CombatSystem
- 自走棋玩法：时间驱动独立回合、事件触发技能（14 时机）、自动战斗与胜负结算
- 完整流程：主菜单（继续游戏/开始新游戏）→ 选关 → 部署 → 自动战斗 → 结算；成长/装备、多关卡、素材、mod 系统
- 技能双轨制：固有技能（Hero"以战养战"击杀永久成长）+ 通用技能池；复杂技能支持 GDScript 代码实现
- 战斗表现：护盾条、技能详情（触发时机/冷却/持续时间）、移动+攻击动画链条
- 爬塔模式：按层生成敌人、战斗场景内悬浮奖励选择、三选一奖励、技能书/遗物/祝福、跳过奖励进入下一层
- 部署体验：1920×1080 适配、非全屏窗口、底部横向单位栏、拖拽部署/换位/移出区域自动撤回
- 战斗体验：部署与战斗保持同一战场尺寸，底部未部署单位栏只读显示，日志悬浮展开，倍速跨战斗保留
- 单位信息：部署和战斗共用同一信息卡，点击己方/敌方单位查看，点击信息卡外区域隐藏；部署点击底部卡片与战场单位使用同一解析入口
- 角色养成：单位支持多标签与 1/2/3 星成长；星级提高初始生命/攻击/护甲，前两次升星增加通用技能槽
- 技能检索：固有/通用技能分轨，技能支持多标签与 `searchable` 开关；隐藏技能不进入常规学习和随机获取池
- 背包：部署界面右侧可打开背包，显示可堆叠升星道具和技能书；技能书可指定角色使用并学习
- 战斗信息：已打开的单位信息卡按约 0.1 秒刷新一次，实时显示生命、Buff 与技能状态；技能伤害有独立飘字和日志
- 狂暴机制：战斗超过 60 秒后每 30 秒提高双方最终伤害 50%，战斗顶部同步显示当前增幅
- UI 结构：核心战斗逻辑不引用 UI；界面控制器通过 `GameSession`、`BattleManager` 等接口驱动显示

当前仍属于可玩的原型，视觉素材暂不接入游戏界面，使用 Godot 内置 `StyleBoxFlat` 维持可读性。

## UI 与素材说明

当前界面使用 Godot 内置的 `StyleBoxFlat` 绘制面板和按钮边框，保留深色底、浅色文字与金色悬停/焦点反馈。

当前已落地的 UI 结构包括：部署/战斗共用战场布局、底部单位栏、统一单位信息卡、战斗日志悬浮窗、战斗胜利悬浮奖励窗和右侧操作区。

`assets/reference/ui_material/` 目录中的图片素材保留为后续视觉迭代素材库，但当前没有被游戏场景或主题引用。待素材风格确认后，再逐项接入，避免影响现有界面可读性。

此前生成的装饰 SVG、PNG 面板背景、临时占位图和自定义图片主题样式均已从项目引用中撤回；未接入素材统一保存在 `assets/reference/ui_material/`，不会被运行时自动使用。

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
assets/               # 美术/音频资源
  fonts/              # 当前使用的字体
  skills/             # 当前使用的技能图标
  units/              # 当前使用的单位立绘/战场小人
  reference/          # 未接入的候选素材与视觉参考
    ui_material/      # 原 material 目录及未接入 UI 图片
```

## 开发维护入口

- [AGENTS.md](AGENTS.md)：本项目的上下文读取、代码修改、验证和文档维护规则。
- [PROJECT_MAP.md](docs/PROJECT_MAP.md)：目录职责、模块关系和按任务定位文件的索引。
- [HANDOFF.md](docs/HANDOFF.md)：当前进度、架构、恢复步骤与下一步优先级。
- [tbs_game_system_design_v2.md](docs/tbs_game_system_design_v2.md)：系统设计参考。
- [MOD_GUIDE.md](docs/MOD_GUIDE.md)：单位数据、技能和素材 Mod 制作规范。
