# TBS Game Godot 系统设计文档

> 版本：v3（2026-08-11）
> 适用范围：本仓库（Godot 4.7 + GDScript 自走棋版）的当前实现设计。
> 说明：早期 Python/pygame 时代的"手动回合制 / 双战场 / 行动菜单 / i18n"等设计已废弃，本文档不再复述，仅覆盖现网实现。

---

## 1. 项目概述

- **游戏类型**：2D 自走棋（auto-battler）式战棋，单机 PVE，PC（Windows）优先
- **引擎**：Godot 4.7 + GDScript（GL Compatibility 渲染）
- **核心玩法**：时间驱动独立回合 + 事件触发技能，全自动战斗
- **完整流程**：主菜单（继续游戏/开始新游戏）→ 选关 → 部署 → 自动战斗 → 结算（胜利发放经验写回编成）
- **成长**：属性/技能/装备 + 永久强化（击杀成长等跨战斗保留）+ 背包道具
- **内容**：12×6 单战场、单位动作图、中文字体、可扩展 mod

## 2. 设计原则

1. **玩法闭环优先**：主菜单 → 选关 → 部署 → 战斗 → 结算 → 成长，各环节完整可跑。
2. **强模块化**：战斗规则（Battle 层，纯逻辑）与表现层（UI）严格分离；规则不污染 UI。
3. **数据驱动**：可配置数值一律进 JSON（单位/技能/Buff/装备/关卡/编成）。
4. **技能双轨**：简单技能用 JSON 组合效果积木；复杂技能用 GDScript（CodeSkill）实现，二者统一注册、统一展示。
5. **单语言**：仅中文（i18n 已取消）。
6. **增量开发**：新增功能优先新模块，不大范围重写已有逻辑；不混用旧 Python 代码。

## 3. 总体架构

```text
data/       JSON 数据（单位/技能/Buff/装备/编成/关卡）
scenes/     Godot 场景（主菜单/选关/部署/战斗/结算/编成）
scripts/
  core/     autoload 与实体（GameDatabase/ModLoader/ArtManager/GameSession、Tile/Grid/Unit/Skill/Buff/Equipment、ProgressManager）
  battle/   战斗纯逻辑（BattleManager/TurnManager/EnemyAI/Pathfinder/Combat/EffectSystem/SkillTriggerSystem/EventSystem）
  screens/  战斗外界面（主菜单/选关/部署/结算/编成）
  ui/       战斗表现（battle_screen/grid_view/unit_view/battle_layout）
  tools/    工具（像素小人生成器）
assets/     美术/字体（units 动作图、LXGWWenKai 中文字体）
mods/       mod 示例（数据 + 素材约定目录）
docs/       设计/交接/技能规范/mod 指南
```

## 4. 核心实体（scripts/core）

### Tile / Grid
- Tile：坐标、移动消耗、防御加成、可通行状态。
- Grid：二维网格，格子访问与上下左右可通行邻居；单战场 12×6，曼哈顿距离射程；`setup_dual`/跨战场逻辑已弃用移除。

### Unit
- 静态来源：模板 `units.json` + 编成 `player_roster.json` + 成长/技能/装备 + 永久强化。Hero、战士、坦克、射手、刺客五个基础角色均有唯一持久化 ID。
- 属性：`hp/max_hp`、`atk/defense/move`（经 `get_base_stat` → `get_stat` 聚合 基础+加点+永久强化+装备+Buff）。角色拥有 `star` 星级；1 星为模板初始值，每升一星使初始生命/攻击/护甲提高 50%，不放大加点、装备和其他后置修正。
- 单位模板可通过 `tags` 配置 0 个或多个标签，角色信息面板展示这些标签。
- 当前数值模板：`Warrior` 战士（1400/100/25/1格）、`Tank` 坦克（2000/80/50/1格）、`Archer` 射手（1000/130/10/2格）、`Assassin` 刺客（800/160/5/1格）；另保留 Hero 作为固有技能测试单位。
- 运行时：`pos / camp / acted / moved / alive / turn_interval / turn_timer`、`buffs`、`skills`、`equipment`、`permanent_mods`、`star`、`tags`。
- 关键方法：`take_damage`（护盾吸收→扣血→致死）、`heal`、`add_buff`、回合 tick、状态查询（stun/silence/taunt/免疫/反射/减伤/无视/标记/反击）、`apply_skills`。

### Skill（技能基类，双轨）
- 数据字段：`name / desc / trigger / condition / cooldown / priority / min_range / max_range / effects / common / once`。
- 三个可覆写钩子：
  - `check_condition(battle, context)`：触发条件（默认数据驱动）
  - `resolve_targets(battle, user, context)`：目标解析（默认按 target_type）
  - `execute(user, targets, game)`：效果执行（默认把 effects 交给 EffectSystem）
- JSON 轨走基类默认实现；代码轨（`CodeSkill`）覆写钩子实现任意复杂逻辑。

### Buff
- 字段：`duration / modifiers / tick_damage / tick_heal / tick_phase / control / shield / trigger / counter / aura_range / heal_percent / immunity / reflect_percent / reduce_percent / ignore_defense / is_mark`。
- 生命周期：回合 tick 递减，`duration <= 0` 移除；触发型（吸血）、护盾吸收、反击、光环等按语义生效。

### Equipment
- 槽位：weapon / offhand / accessory；字段：槽位、属性修正 `modifiers`、授予技能 `granted_skills`。

## 5. 战斗系统（自走棋）

### 5.1 BattleManager（状态机）
- `tick(delta)` 推进时间与行动，产出行动事件（attack / move / move_attack / wait）供 UI 播放。
- `_auto_act`：射程内有敌人→攻击；否则移动（当前 1 移动力）再尝试攻击；其余待机。
- `perform_attack`：伤害结算 + 技能触发时机分发 + 反射/减伤/护盾处理 + 胜负检查。
- 供技能调用的接口：`spawn_unit` / `move_unit_to`（位移家族使用）/ `add_log` / `record_skill_damage`。

### 5.2 回合（TurnManager）
- 时间驱动独立回合：每单位 `turn_interval`（秒）+ 各自 `turn_timer`，到点自动行动，非阵营轮流。
- 新职业模板的行动间隔统一为 4 秒；Hero 也使用 4 秒行动间隔。

### 5.3 敌人 AI（EnemyAI）
- 射程内有敌人 → 攻击（含嘲讽引导目标）；否则朝最近目标移动；无法移动则待机。

### 5.4 移动
- Pathfinder：Dijkstra 计算可达范围与路径回溯（当前移动力为 1，多为相邻格）。

### 5.5 伤害与减伤
- 基础伤害按攻击力经过护甲百分比减伤结算（下限 1），护甲减伤率为 `护甲 / (100 + 护甲)`，技能按 `power` 倍率；
- 暴击：攻击/技能独立判定，暴击率 `crit_rate`、暴击伤害 `crit_damage`（普通单位 5%/150%，刺客模板 10%/150%），在减伤后应用倍率，日志标注"暴击！"；
- 支持：无视防御（ignore/ignore_defense）、减伤（protect/reduce_percent）、护盾吸收（shield）、反射（reflect_percent）。

### 5.6 胜负
- 胜利：歼灭全部敌人；失败：己方全灭。胜利发放经验并写回编成，自动进入结算场景。

## 6. 技能体系

### 6.1 JSON 结构
```json
{
  "skill_id": {
    "name": "中文名", "desc": "描述",
    "trigger": "on_attack", "condition": {"target_type": "target"},
    "cooldown": 2, "min_range": 1, "max_range": 1,
    "common": true,
    "tags": ["通用", "攻击"],
    "searchable": true,
    "effects": [{ "type": "damage", "power": 1.5 }]
  }
}
```
- `common: true` = 通用技能（编成中学习/装备）；无标记 = 固有/专用（由 units.json 的 `innate_skill` 引用）。
- `tags` 为 0 个或多个检索标签；`searchable: false` 表示不进入敌人随机技能、爬塔随机奖励和常规学习池，但可以由特定逻辑直接指定获取。

### 6.2 触发时机（14 种，事件驱动自动施放）
| trigger | 含义 |
|---|---|
| on_battle_start | 战斗开始时 |
| on_turn_start | 行动开始时 |
| on_attack_start | 攻击前 |
| on_attack | 攻击时 |
| on_attack_end | 攻击结束后 |
| on_hit | 造成伤害后 |
| on_be_attacked | 受到攻击后 |
| on_taken_damage | 受到伤害后 |
| on_kill | 击杀敌人后 |
| on_death | 阵亡时 |
| on_ally_death | 友军阵亡时 |
| on_turn_end | 行动结束时 |
| on_round_start | 首回合开始时 |
| passive | 常驻被动 |

规则：同一单位同一时机按 `priority` 排序依次触发；冷却中的不触发；条件不满足不触发。

### 6.3 触发条件
当前支持：`hp_percent`（lt/lte/gt/gte/eq）、`target_hp_percent`、`has_buff`、`target_has_buff`、`crit`。扩展方向见第 12 节。

### 6.4 目标解析
`self / target（当前目标）/ enemy / ally / all_enemies / all_allies`（按射程或全体）。

### 6.5 效果函数库（20 类原子效果）
- 即时：`damage`、`heal`、`revive`、`dispel`、`summon`、`mark`、`teleport`（位移家族：突脸/拉人/击退/闪现/后撤）
- 伤害变体：`percentage_damage`（按生命上限比例）、`chain_damage`（连锁）
- 状态：`buff`、`dot`、`shield`、`shield_max_hp_percent`、`stat_mod`、`taunt`、`immunity`、`reflect`、`protect`、`ignore`、`lifesteal`
- 永久成长：`permanent_stat`（永久属性强化；`persist=true` 全局永久写回编成，`false` 仅本局永久）

新增效果 = EffectSystem 新增一个 match 分支 + apply 函数（未来改为注册表驱动）。

### 6.6 双轨制
- JSON 轨：skills.json 组合效果积木。
- 代码轨：继承 `CodeSkill`（scripts/battle/skills/code_skill.gd）覆写 `check_condition / resolve_targets / execute`，在 `skill_code_registry.gd` 集中注册一行（id + 脚本路径）。
- GameDatabase 启动时合并两条轨道，战斗/编成/信息面板统一可见。

### 6.7 固有技能 / 通用技能
- 固有技能：`units.json → innate_skill`，模板独有、始终生效、不可更换；可为空。
- 通用技能：`common: true`，编成中花技能点学习并装备后才参与战斗。
- 通用技能槽初始 1 格；前两次升星各增加 1 格，最多因升星增加 2 格。未来提高最高星级时，该升星带来的槽位增量上限不变。
- 所有技能均有 `tags` 与 `searchable` 字段。不可检索技能不会进入敌人随机技能、爬塔随机奖励或常规学习池；通过指定手段直接获得后仍可显示、学习记录和装备。
- 示例：Hero 固有"以战养战"（on_kill → permanent_stat，生命上限永久 +1，当前血同步 +1，无上限）。
- 当前 V1 模板技能先接入强击、连斩、斩杀、吸血、铁壁、坚韧、复苏、锐利、致命、荆棘、破胆；溅射、行动进度、护盾破裂和动态成长类效果待后续事件语义确定后接入。

## 7. 成长与编成

### 7.1 ProgressManager（纯逻辑）
- 经验/升级：所需经验 `level * 100`；升级 +2 属性点 +1 技能点。
- 属性加点：attack / defense / move / hp。
- 升星：`ascend_unit` 消耗背包中的可堆叠 `inventory.star_items`，当前最高 3 星；`add_star_items` 供未来奖励/商店等明确来源调用。星级规则集中在 `Unit`，方便未来扩展最高星级。
- 通用技能槽：`1 + min(star - 1, 2)`；`equip_skill` 与战斗中的 `Unit.apply_skills` 共同限制装备技能数量。
- 技能：技能点学习可检索通用技能；背包技能书是指定获取手段，拖到单位后不消耗技能点、直接学习并装备；装备槽已满时选择覆盖一个已装备技能，取消不消耗技能书；装备与卸下仍受通用技能槽限制。
- 装备：三槽位校验装配/卸下。
- 永久强化：`add_permanent_stat(unit_id, stat, amount)` 累加 `permanent_mods` 并写回 player_roster.json。
- 持久化：`save_roster()` 写回 JSON。

### 7.2 队伍编成界面（progression_screen）
- 两段式：先选角色，再在 属性 / 技能 / 装备 三个子页成长。
- 技能页：固有技能锁定区（金色标注 + 完整详情）+ 通用技能池（点击查看详情：描述/触发时机/冷却/射程/目标/效果含持续时间；冒泡式操作：学习并装备/装备/卸下）。
- 总览面板：整体属性（含永久强化）、装备、带进战斗的技能（固有 + 已装备 + 装备授予）。

## 8. 关卡与部署

- `data/scenario/*.json`：name / width / height / deployment_zone（玩家部署区，battle_01/02 为左半场 x0-5 × y0-5）/ player_units（roster_index + pos）/ enemy_units（type + pos）。
- 部署界面：右侧编成槽位，点选单位后点击部署区放置，可反复调整；全部就绪后开始战斗。

## 9. 战斗表现（UI）

- GridView：棋盘格深浅交替 + 边框（自动战斗下移动/攻击高亮已不用，保留选中/悬停）。
- UnitView：动作图（stand/move/attack/death）填满格子、顶部名称、底部血条、血条上方蓝色护盾条（剩余/初始比例）；行动后（acted）变暗。
- 动画：移动逐格补间；"移动后攻击"链条化（移动结束接攻击冲刺），攻击动画不被吞。
- 信息面板：点击单位显示属性/射程/行动间隔/护盾/永久强化/装备/技能/Buff；战斗中仅对当前打开的信息卡约每 0.1 秒刷新一次，未打开单位不持续创建 UI。
- 布局：BattleLayout 按视口自适应格子大小并居中；日志面板最多 100 条。

## 10. mod 系统

- 数据 mod：`mods/<id>/mod.json` + units/skills/buffs/equipments JSON + `art/units/<角色名>/`（idle/attack/hurt/death/skill/portrait.png）；启动时自动扫描合并，同名数据覆盖原版（详见 docs/MOD_GUIDE.md）。
- 素材查找：ArtManager 按 mod → 内置顺序取图，缺省动作回退站立。
- 代码技能：进阶 mod 作者可通过 CodeSkill + 注册文件提供自定义逻辑技能（见 MOD_GUIDE 第 8 节）。

## 11. 运行与验证

- 打开 `project.godot`（Godot 4.7），F5 运行；或使用桌面快捷方式直接以运行模式启动。
- 无头检查：`Godot_v4.7.1-stable_win64_console.exe --headless --path <项目> --quit`
- 冒烟：`--quit-after N res://scenes/battle_screen.tscn`
- 新增 `class_name` 后先 `--import` 刷新全局类缓存。
- 预期输出：`GameDatabase loaded: units=5 skills=12 buffs=11 equipments=5`

## 12. 待办与演进方向

- AOE 范围形状（cross/line/around/square）目标解析未落地
- 更多触发条件（round / range / is_boss）与更丰富目标类型（random_enemy / area）
- 更多真实技能组合与角色固有技能设计
- 效果注册表驱动化（替换 match 分发）

## 13. 编码约定

- 与用户交流优先中文；每个 GDScript 文件有简短中文注释。
- 逻辑层与 UI 分离；可配置数值放 JSON。
- 简单技能改 JSON；复杂技能用代码轨（CodeSkill + 注册文件）。
- 不混用旧 Python/pygame 代码；Godot 项目只使用 GDScript/Godot 资源。
