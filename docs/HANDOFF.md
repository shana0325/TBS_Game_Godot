# TBS Game Godot 当前交接

> 更新日期：2026-09-30
> 当前主分支：`main`
> 引擎：Godot 4.7.1

## 当前可玩流程

- 主菜单：开始新游戏、继续游戏、技能/遗物图鉴。
- 快速战斗：选关 → 部署 → 自动战斗 → 结算。
- 爬塔：部署 → 自动战斗 → 固定技能书与金币、遗物三选一 → 同层有序事件队列 → 下一层；阵容和站位可跨层调整。
- 角色管理：升星、技能书学习与遗忘、招募和出售；初始上阵 4 人，最多 6 人。

## 已实现的核心规则

- 单位按独立的攻击间隔与移动间隔自动战斗，自动寻路、攻击和触发技能；现有单位基础攻击间隔统一为 2.0 秒。
- 现有单位每 1.0 秒获得一次移动机会，每次最多移动当前移动力对应的格数；角色资料只显示移动力，不显示移动间隔。
- 限时状态及原每回合结算效果按真实秒数推进；明确依附普攻的技能按普攻次数触发，自动主动技能按秒数施放。
- 伤害统一经过 `DamageSystem`，区分普攻、技能和特效伤害；真实伤害是独立标记。
- 特效伤害不再次触发“造成伤害时”效果，避免递归套娃。
- 百分比伤害减免作用于全部伤害，包括真实伤害。
- 护盾通过 `Unit.gain_shield` 统一获得，每份护盾独立保存持续时间并按获得顺序消耗。
- `Unit.get_shield_cap` 默认返回最大生命；技能可配置 `shield_cap_percent` 或 `unlimited_shield`。
- 护盾只属于当前战斗单位，不跨战斗保存。

## 技能与遗物

- 当前已注册 61 个技能：51 个通用技能、10 个角色或 Boss 专属技能。实际界面正文见 `docs/当前技能清单.md`，不再保留已完成的旧调整意见。
- 已删除强力打击、誓约圣盾；荆棘改为受到普攻时按自身当前护甲的 100% 反击。中毒默认每层每秒造成施加者当前攻击力 5% 的特效伤害，瘴气波使用该默认规则。
- 机制关键字在正文中可悬停 1 秒查看图鉴规则；只有触发整段效果的战吼、亡语、休眠、复仇放在开头。角色列表、学习/遗忘列表、详情正文和技能图鉴复用同一描述组件。

- 数据技能和 `CodeSkill` 共用触发系统，主动技能的自动施放间隔受技能急速影响。
- 角色固有技能与可学习通用技能分离；装备不提供技能。
- 当前有 16 个代码通用技能、26 个机制遗物和 3 个可重复数值遗物；新机制遗物涵盖攻速、碎盾、异常状态、召唤、净化和首次主动施放。
- 新增 10 个 JSON 通用技能，覆盖驱散、智能选友军、群体异常状态、阵亡救援、状态免疫与周期召唤；战斗行为由 `tests/common_skill_mechanics_test.gd` 验证。
- 遗物三选一从当前可获得的遗物中等概率无放回抽取；遗物不设稀有度。每件内置遗物使用独立图标，Mod 可添加自己的遗物数据与 PNG 图标。
- 力量祝福、守御祝福、生命祝福是可无限叠加的数值遗物。
- `run_relics` 保存唯一遗物 ID，`run_relic_stacks` 保存可重复遗物层数。
- 战斗和部署预览都通过 `RelicSystem.apply_run_bonuses_to_unit` 应用完整加成。
- 跨战斗成长保存在 `run_relic_state`；只有主菜单“开始新游戏”会清空。
- 战后固定奖励每层只发放一次；商店、补给、探索与 Boss 使用 `TowerEvent` 基类，同层事件对象由 `GameSession` 按序保存。第 10、20、30 层会在原有敌军外各追加一名 Boss，三者共用每 20 秒征召一名享受层数增益的随机敌军技能。数值与固有技能见 `docs/BOSS_DESIGN.md`，经济初值见 `data/tower/tower_config.json`。

## 当前 UI

- 部署和战斗复用同一个 `BattlefieldStage` 场景节点，开始战斗时沿用棋盘和站位。
- 备战栏按槽位保存单位位置，已上场单位不显示在备战栏；新获得单位从左向右填充空槽，可鼠标滚动与拖拽换位。
- 单位详情为左侧导航、中间立绘、右侧连续滚动内容；战斗中动态属性定时刷新。
- 技能支持学习、遗忘和详情查看。
- 遗物顶部栏显示图标及层数，点击打开详情。
- 单位、技能、遗物和奖励弹窗均处理输入遮挡；ESC 和鼠标右键用于关闭详情。
- 奖励弹窗的隐藏按钮位于独立 `CanvasLayer`，避免被其他控件遮挡。

## 关键文件

| 领域 | 文件 |
| --- | --- |
| 会话与 Run 状态 | `scripts/core/game_session.gd` |
| 单位与护盾规则 | `scripts/core/unit.gd` |
| 技能基类 | `scripts/core/skill.gd` |
| 遗物规则 | `scripts/core/relic_system.gd` |
| 奖励生成 | `scripts/core/reward_generator.gd` |
| 事件调度与基类 | `scripts/core/tower_event_factory.gd`、`tower_event.gd` |
| 事件界面 | `scripts/screens/tower_event_screen.gd` |
| 统一伤害结算 | `scripts/battle/combat/damage_system.gd` |
| 战斗管理 | `scripts/battle/battle_manager.gd` |
| 部署界面 | `scripts/screens/deployment_screen.gd` |
| 角色详情 | `scripts/ui/unit_detail_panel.gd` |
| 遗物详情 | `scripts/ui/relic_detail_popup.gd` |

## 验证命令

```powershell
& 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path '<项目路径>' --editor --quit
& 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path '<项目路径>' 'res://tests/run_battle_smoke.tscn'
& 'D:\Shana Program\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path '<项目路径>' 'res://tests/run_skill_relic_verify.tscn'
git diff --check
git status --short
```

无头场景结束时可能报告 Dummy Renderer 的 RID/ObjectDB 泄漏；当前属于强制退出短场景时的已知日志。交互改动仍需在实际窗口中复查。

## 后续优先事项

- 继续统一按钮、弹窗与字体的主题资源，减少脚本内重复样式。
- 为新增角色、技能和遗物补齐独立美术资源。
- 在现有 Boss 战基础上扩充敌人机制、精英层与专属奖励。
- 在新增复杂技能前补对应的战斗验证用例。
