# LC2 参考项目索引

## 使用边界

LC2 项目位于：

`D:\Shana Program\文档\lc2`

该项目默认只作为参考资料，不作为 TBS 的依赖，也不作为当前开发目标。

除非用户明确提出“参考 LC2 的某个功能/界面/实现”，否则不读取 LC2 的具体脚本、场景和资源，不运行 LC2，不修复 LC2，也不扫描 LC2 全项目。

这份文档只记录目录级索引和功能定位，避免把 LC2 的大量文件内容带入当前项目上下文。

## LC2 顶层目录索引

| LC2 目录 | 主要内容 | 适合在什么需求下读取 |
| --- | --- | --- |
| `core/` | 角色、队伍、技能、Buff、装备、遗物、物品、存档和全局数据对象 | 需要参考数据对象关系、对象工厂、状态管理时 |
| `core/global/` | 全局系统、数据加载、常量、随机池、存档接口 | 需要参考全局服务、数据初始化或存档结构时 |
| `tscn/` | Godot 场景和场景脚本，覆盖主界面、地图、战斗、事件、角色详情等 | 需要参考某个 UI 或场景组织方式时 |
| `tscn/base/` | 通用弹窗、基础对话框、通用 UI 组件 | 需要参考弹窗、通用面板或基础控件时 |
| `tscn/chara/` | 角色战场显示、动画、血条、角色小人 | 需要参考战场单位显示或动画时 |
| `tscn/charaDlg/` | 角色详情、属性、技能、装备和 Buff 面板 | 需要参考角色信息面板时 |
| `tscn/bat/` | 战斗场景、战斗日志、伤害详情和战斗相关 UI | 需要参考战斗界面或战斗统计时 |
| `tscn/map/` | 地图、设施、地图单位和地图交互 | 需要参考地图或设施系统时 |
| `tscn/eventDlg/` | 事件、奖励、购买、选择和事件弹窗 | 需要参考事件/奖励选择流程时 |
| `ex/` | 大量具体角色、技能、Buff、装备、遗物、设施和事件内容 | 需要参考具体内容的实现方式时 |
| `ex2/` | 第二组扩展内容 | 需要对比另一种具体内容实现时 |
| `ex3/` | 少量第三组扩展内容 | 明确指定相关扩展时 |
| `!ve/base/` | Vanilla Expanded 基础框架和扩展基础组件 | 需要参考大角色面板、扩展基类或复用式 UI 框架时 |
| `!ve/base/tscn/charaDlg/` | `!ve` 版本角色详情面板及属性/技能/装备子面板 | 明确要求参考 LC2 `!ve` 角色面板时，优先读取这里 |
| `!ve/base/tscn/exCharaDlg/` | 扩展角色详情面板 | 需要参考扩展角色面板或 Mod 适配时 |
| `!ve/additional/` | 额外优化、重写和扩展内容 | 用户明确要求参考某项额外功能时 |
| `res/` | 图片、字体、音频、Theme 和 Shader | 需要参考资源组织或视觉素材时 |
| `lg/` | 多语言翻译文件 | 需要参考本地化组织时 |
| `addons/` | Godot 编辑器插件 | 明确需要参考资源导入插件时 |
| `sdk/` | Steam 等 SDK 相关内容 | 明确需要参考平台接入时 |

## 与 TBS 的功能对应关系

| TBS 需求 | LC2 首选参考范围 | TBS 当前对应位置 |
| --- | --- | --- |
| 大型角色信息面板 | `!ve/base/tscn/charaDlg/` | `scripts/ui/unit_detail_panel.gd` |
| 角色属性展示 | `!ve/base/tscn/charaDlg/att.tscn`、`att.gd` | `scripts/core/unit.gd`、角色面板脚本 |
| 技能列表和技能详情 | `!ve/base/tscn/charaDlg/skill/`、`!ve/base/tscn/exCharaDlg/skillPan.tscn` | `scripts/core/skill.gd`、`scripts/ui/unit_detail_panel.gd` |
| 装备槽和装备展示 | `!ve/base/tscn/charaDlg/eqp*` | `scripts/core/equipment.gd`、角色面板脚本 |
| 战场小人和血条 | `!ve/base/tscn/chara/` | `scripts/ui/unit_view.gd`、`scripts/core/art_manager.gd` |
| 战斗日志和战后统计 | `!ve/tscn/bat/`、`!ve/tscn/bat/hurt/` | `scripts/ui/battle_screen.gd`、`scripts/screens/result_screen.gd` |
| 地图/设施交互 | `!ve/tscn/map/`、`ex/faci/` | TBS 当前地图与战斗流程脚本 |
| 事件和奖励选择 | `!ve/tscn/eventDlg/`、`!ve/tscn/game/gameEndDlg.tscn` | `scripts/screens/reward_screen.gd`、`progression_screen.gd` |
| 数据对象和内容注册 | `core/global/data.gd`、`core/base.gd`、`ex/` | `scripts/core/game_database.gd`、`data/` |

## 后续按需读取规则

当用户明确要求参考某一功能时，按以下顺序处理：

1. 先根据本索引确定一个最小目录范围。
2. 只用文件名搜索和关键词搜索定位相关场景/脚本。
3. 优先读取入口场景、入口脚本和直接依赖，不读取整个目录。
4. 只提取与当前需求相关的节点结构、信号、初始化函数和数据流。
5. 将 LC2 的实现思路转换为 TBS 当前架构，不直接复制 Godot 3 代码。
6. 不因参考某个功能而启动 LC2 的全项目迁移或兼容性修复。

## 需求到读取范围示例

| 用户说法 | 只读取的范围 |
| --- | --- |
| “参考 LC2 的大角色面板” | `!ve/base/tscn/charaDlg/`，必要时加 `!ve/base/tscn/exCharaDlg/` |
| “参考 LC2 的战斗日志” | `!ve/tscn/bat/`、`!ve/tscn/bat/hurt/` |
| “参考 LC2 的遗物奖励选择” | `!ve/tscn/eventDlg/`、`!ve/tscn/bat/relic/` |
| “参考 LC2 的角色数据结构” | `core/chara.gd`、`core/skill.gd`、`core/team.gd`，必要时加对应 `ex/` 内容 |
| “参考 LC2 的地图设施” | `core/faci.gd`、`tscn/map/`、指定的 `ex/faci/` 文件 |
| “参考 LC2 的 Mod 框架” | `!ve/README.md`、`!ve/base/`、指定 Mod 相关文件 |

## 当前约定

- LC2 目录不加入 TBS 的运行时依赖。
- 不把 LC2 的完整文件内容复制进 TBS 文档。
- 不默认读取 LC2 的 `.godot/`、导入缓存、`.uid` 或生成文件。
- 不默认查看 LC2 的图片、音频和其他资源内容；只有视觉参考需求才读取指定资源。
- 如果某项参考需要读取的文件超过一个小功能范围，应先向用户说明范围和原因。
