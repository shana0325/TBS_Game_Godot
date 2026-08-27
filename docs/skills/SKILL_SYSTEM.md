# 技能体系设计文档（自走棋向）

> 版本：v0.1（2026-08-10）
> 目标：为自走棋式战斗（自动攻击、技能按触发时机自动释放）设计一套**数据驱动、可扩展、基础效果可组合**的技能体系。
> 设计原则：
> 1. 所有技能效果通过 JSON 数据声明，不写死在脚本。
> 2. 技能由"触发时机 + 条件 + 基础效果列表"组成。
> 3. 基础效果类型做成"原子积木"，复杂技能由原子效果组合而成。
> 4. 效果类型可扩展：新增效果 = 新增一个处理器脚本 + 注册，不改动技能数据格式。

---

## 1. 技能整体结构

```json
{
  "id": "power_slash",
  "name": "强力斩击",
  "desc": "对前方直线敌人造成 1.2 倍攻击伤害",
  "trigger": "on_attack",
  "condition": {},
  "cooldown": 2,
  "target": {
    "type": "enemy",
    "mode": "area",
    "shape": "line",
    "range": 2
  },
  "effects": [
    { "type": "damage", "power": 1.2 }
  ]
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 技能唯一标识 |
| `name` | string | 显示名 |
| `desc` | string | 技能描述 |
| `trigger` | string | 触发时机（见第 3 节） |
| `condition` | dict | 触发条件（见第 4 节） |
| `cooldown` | int | 冷却回合数（0=无冷却） |
| `target` | dict | 目标选择（见第 5 节） |
| `effects` | array | 效果列表（见第 6 节） |

---

## 2. 自走棋战斗流程（技能触发上下文）

自走棋模式下，战斗按"攻击事件流"推进，技能在事件流的各个节点自动触发：

```
回合开始(双方)
  │
  ▼
单位A 行动开始 ── on_turn_start（行动时触发）
  │
  ├─ 选目标 ── 判定攻击范围
  │
  ▼
A 攻击 B ── on_attack_start（攻击前触发）→ 可结算附加效果
  │
  ▼
命中判定 ── on_attack（攻击时触发）
  │
  ▼
伤害结算 ── on_hit（造成伤害后触发）/ on_taken_damage（受到伤害后触发）
  │
  ▼
攻击结束 ── on_attack_end（攻击后触发）→ 附带技能伤害在此阶段结算
  │
  ▼
B 受击后 ── on_be_attacked（受到攻击后触发）→ 用于反击/免疫类技能
  │
  ▼
若 B 死亡 ── on_kill（击杀者）/ on_death（阵亡者）
  │
  ▼
下一个单位行动...
```

**重要设计：攻击前触发与攻击后触发**
- `on_attack_start`：攻击者出手前触发（如"先给自己加攻击力再出招"）
- `on_attack_end`：攻击者本次攻击完全结束后触发
- 附带技能伤害：在 `on_attack_end` 阶段结算，与普通攻击伤害分离

---

## 3. 触发时机（trigger）

技能通过 `trigger` 字段声明何时自动释放。全部为事件驱动。

| trigger 值 | 含义 | 触发方 | 实现状态 |
|---|---|---|---|
| `on_battle_start` | 战斗开始时 | 所有单位 | ✅ |
| `on_turn_start` | 该单位行动开始时 | 当前行动单位 | ✅ |
| `on_attack_start` | 该单位即将攻击前 | 攻击者 | ✅ |
| `on_attack` | 该单位攻击时（与命中同步） | 攻击者 | ✅ |
| `on_attack_end` | 该单位攻击完全结束后 | 攻击者 | ✅ |
| `on_hit` | 该单位造成伤害后 | 攻击者 | ✅ |
| `on_be_attacked` | 该单位受到攻击后 | 被攻击者 | ✅ |
| `on_taken_damage` | 该单位受到伤害结算后 | 被攻击者 | ✅ |
| `on_kill` | 该单位击杀敌人后 | 攻击者 | ✅ |
| `on_death` | 该单位死亡时 | 阵亡者 | ✅ |
| `on_ally_death` | 友军死亡时 | 同阵营存活单位 | ✅ |
| `on_turn_end` | 该单位行动结束时 | 当前行动单位 | ✅ |
| `on_round_start` | 战斗首回合开始 | 所有单位 | ✅（仅首回合） |
| `passive` | 常驻被动（无条件持续生效） | 拥有者 | ✅（战斗开始即生效） |

**技能触发规则**
- 一个单位每个时机只能触发一次对应技能（除非配置 `repeat`）。
- 同一单位同一时机有多个技能时，按技能 `priority` 字段排序依次触发。
- 触发后技能进入 `cooldown`，冷却中的技能不触发。

---

## 4. 触发条件（condition）

`condition` 可选，缺省表示无条件触发。支持组合。

```json
{
  "trigger": "on_attack",
  "condition": {
    "hp_percent": { "lt": 0.5 },          // 自身生命低于 50%
    "target_hp_percent": { "gt": 0.3 },   // 目标生命高于 30%
    "has_buff": "poison",                  // 自身有指定 Buff
    "target_has_buff": "poison",           // 目标有指定 Buff
    "round": { "eq": 3 },                  // 第 3 回合
    "range": { "lte": 2 }                  // 与目标距离 ≤ 2
  }
}
```

| 条件字段 | 比较操作符 |
|---|---|
| `hp_percent` / `target_hp_percent` | `lt`/`lte`/`gt`/`gte`/`eq`（0.0~1.0 比例） |
| `hp` / `target_hp` | 同上（绝对值） |
| `round` | 同上（整数） |
| `has_buff` / `target_has_buff` | 字符串或数组（Buff id） |
| `range` | 与目标距离 |
| `is_boss` | 目标是否为 Boss（布尔） |
| `element` | 本次攻击元素 |

多条件默认"与"关系（全部满足才触发）。若需"或"，使用 `any_of`: `[cond1, cond2]`。

---

## 5. 目标选择（target）

```json
{
  "target": {
    "type": "enemy",            // enemy / ally / self / all_enemies / all_allies / random_enemy
    "mode": "area",             // single（单体）/ area（范围）
    "shape": "cross",           // 范围形状（mode=area 时生效）
    "range": 2,                 // 作用范围格数
    "include_self": false       // 范围是否包含自身（如光环、自爆）
  }
}
```

| `type` | 含义 |
|---|---|
| `enemy` | 敌方（攻击者目标） |
| `ally` | 友方（不含自己） |
| `self` | 自己 |
| `all_enemies` | 全体敌人 |
| `all_allies` | 全体友方 |
| `random_enemy` | 随机敌人 |
| `area` | 以自身或目标为中心的范围内单位（配合 `shape`/`range`） |

范围形状 `shape`：
| 形状 | 说明 |
|---|---|
| `cross` | 十字（上下左右 + 中心） |
| `line` | 直线（前方 N 格） |
| `around` | 圆形范围（曼哈顿距离 ≤ range） |
| `square` | 方形范围（Chebyshev 距离 ≤ range） |
| `single` | 单体 |

---

## 6. 基础效果类型（effect 原子积木）

每个 effect 是一个 JSON 对象，`type` 决定处理器。当前计划实现以下类型（按功能分组）。

### 6.1 即时效果（施放瞬间生效）

#### damage — 造成伤害
```json
{ "type": "damage", "power": 1.0, "ignore_defense": false, "ignore_shield": false, "can_crit": true }
```
| 参数 | 说明 |
|---|---|
| `power` | 倍率（攻击力 × power） |
| `ignore_defense` | 是否无视防御（即"直接伤害"思路的雏形，后续可扩展） |
| `ignore_shield` | 是否无视护罩 |
| `flat` | 固定伤害（可选，替代 power 计算） |
| `can_crit` | 是否可暴击（默认 true；特殊技能可禁用） |

**暴击规则（已实现）**
- 每次攻击/技能伤害独立判定暴击（必定命中，暂不考虑闪避/命中率）。
- 暴击率来自攻击者属性 `crit_rate`（百分数，如 5 = 5%），暴击伤害倍率来自 `crit_damage`（百分数，150 = 1.5 倍）。
- 暴击时：`最终伤害 = 基础伤害 × crit_damage 倍率`（在减伤之后、power 倍率之前应用）。
- 通过 Unit 属性/Buff/装备/加点均可调整（`get_stat` 统一聚合）。默认：Hero/Knight/Goblin 5%/150%，Orc 10%/160%。

**直接伤害（预留）**
- `ignore_defense: true` 视为"直接伤害"，无视目标防御减伤；后续可扩展为独立伤害类型。

#### heal — 治疗
```json
{ "type": "heal", "amount": 50, "power": 0.6 }
```
`amount` 固定值或 `power`（攻击力/魔力 × power）。

#### revive — 复活
```json
{ "type": "revive", "hp_percent": 0.5 }
```
将死亡目标复活至生命上限的 50%。目标必须已死亡。

#### summon — 召唤
```json
{ "type": "summon", "unit": "Skeleton", "position": "adjacent", "duration": 3 }
```
在指定位置召唤单位，`duration` 为存活回合数（可选）。

#### dispel — 解除（驱散）
```json
{ "type": "dispel", "friendly": false, "category": "all" }
```
`friendly=true` 驱散目标有利 Buff，`false` 驱散不利 Buff。`category` 可指定只驱散某类（all/buff/dot/shield...）。

#### mark — 标识
```json
{ "type": "mark", "mark": "assassin_target", "duration": 2 }
```
给目标打上标记，供其他技能作条件（如"对被标记目标伤害+50%"）。

#### teleport — 位移（重要，后续扩展基础）
```json
{ "type": "teleport", "mode": "self", "position": "adjacent_to_target" }
```
将目标（或自身）移动到指定位置。**位移是后续扩展的基石**，可在此基础上派生：

| 位移派生 | 说明 | 参数示例 |
|---|---|---|
| **击退** | 把目标沿攻击方向推后 N 格 | `{"type":"teleport","mode":"target","dir":"away","distance":2}` |
| **闪现** | 自己瞬移到指定格 | `{"type":"teleport","mode":"self","dir":"target","distance":-1}` |
| **后撤** | 自己向远离目标方向退 N 格 | `{"type":"teleport","mode":"self","dir":"away","distance":2}` |
| **突脸** | 自己冲向目标身边 | `{"type":"teleport","mode":"self","dir":"target","distance":0}`（贴脸） |
| **拉人** | 把目标拉到自己身边 | `{"type":"teleport","mode":"target","dir":"self","distance":0}`（拉贴脸） |

`mode`：`self`（移自己）/`target`（移目标）。
`dir`：`target`（朝向目标）/`away`（远离目标）/`self`（拉向自己）。
`distance`：移动格数（0=贴脸，-1=瞬移到目标位置，N=指定距离）。
`position`：也可直接给固定格子坐标。

### 6.2 状态效果（持续回合，通过 Buff 实现）

#### stat_mod — 能力值强化/弱化
```json
{ "type": "stat_mod", "stats": { "attack": 3, "defense": -2 }, "duration": 3 }
```
按回合修改属性（可为负，即弱化）。

#### dot — 持续伤害
```json
{ "type": "dot", "damage": 8, "duration": 3, "phase": "turn_start" }
```
每回合开始/结束时扣血。

#### hot — 持续恢复
```json
{ "type": "hot", "heal": 5, "duration": 3, "phase": "turn_start" }
```

#### shield — 护罩（吸收伤害）
```json
{ "type": "shield", "amount": 20, "duration": 2 }
```
吸收固定伤害量，吸收完或到期消失。

#### protect — 防护罩（减伤）
```json
{ "type": "protect", "reduction": 0.3, "duration": 2 }
```
受到伤害降低 30%。

#### taunt — 挑衅
```json
{ "type": "taunt", "duration": 1 }
```
持续时间内，敌人只能攻击该单位。

#### immunity — 免疫
```json
{ "type": "immunity", "states": ["stun", "silence"], "duration": 2 }
```
免疫指定状态（眩晕/沉默/中毒等）。`*` 表示免疫全部负面状态。

#### ignore — 无视
```json
{ "type": "ignore", "duration": 1 }
```
持续时间内，该单位的攻击无视目标防御/护罩/防护罩。

#### reflect — 反射反击
```json
{ "type": "reflect", "percent": 0.3, "duration": 2 }
```
受到攻击时，将 30% 伤害反射给攻击者。

#### lifesteal — 吸收（吸血）
```json
{ "type": "lifesteal", "percent": 0.3, "duration": 2 }
```
造成伤害时恢复伤害量 30% 的生命。

#### stun — 禁止（眩晕）
```json
{ "type": "stun", "duration": 1 }
```
无法行动。

#### silence — 封印（沉默）
```json
{ "type": "silence", "duration": 2 }
```
无法释放技能（仍可普攻）。

#### aura — 光环
```json
{ "type": "aura", "stats": { "attack": 2 }, "range": 2, "duration": -1 }
```
范围内友方获得属性加成。`duration=-1` 表示常驻。

#### counter — 反击标记
```json
{ "type": "counter", "duration": 2 }
```
受击后必定反击一次。

### 6.3 复合/特殊

#### chain_damage — 连锁伤害
```json
{ "type": "damage", "power": 0.5, "chain": 2, "chain_range": 2 }
```
对目标造成伤害后，向附近敌人连锁 N 次，每次伤害衰减。

#### bonus_damage — 额外伤害（攻击后附带）
```json
{ "type": "damage", "power": 0.8 }
```
作为技能 `trigger: "on_attack_end"` 时即为攻击后结算的附带伤害，与普通攻击伤害分离。

#### percentage_damage — 百分比伤害（直接伤害思路）
```json
{ "type": "percentage_damage", "percent": 0.1, "max": 1000 }
```
按目标生命上限百分比造成伤害（无视攻击力/防御）。

---

## 7. Buff 数据（buffs.json 扩展）

状态效果会落到 `buffs.json` 中，格式扩展：

```json
{
  "bleed": {
    "name": "流血",
    "type": "dot",
    "duration": 3,
    "tick_damage": 8,
    "tick_phase": "turn_start",
    "can_dispel": true,
    "is_beneficial": false
  }
}
```

新增字段：`type`（对应效果类型）、`can_dispel`（能否被驱散）、`is_beneficial`（是否有利，用于驱散判定）、`stackable`（是否可叠加）、`max_stacks`。

---

## 8. 效果注册表（实现层）

EffectSystem 改为注册表驱动：

```gdscript
# effect_system.gd
const HANDLERS := {
    "damage": DamageEffect,
    "heal": HealEffect,
    "dot": DotEffect,
    "shield": ShieldEffect,
    ...
}
```

每个 Effect 处理器实现统一接口：
```gdscript
class_name BaseEffect
static func apply(context: EffectContext) -> Dictionary
```

`EffectContext` 包含：`user`、`targets`、`trigger`、`battle`、`config`。

新增效果步骤：
1. 新建脚本 `scripts/battle/effects/xxx_effect.gd`
2. 实现 `apply(context)`
3. 在 `effect_system.gd` 的 `HANDLERS` 注册一行

技能数据无需改动，直接可用。

---

## 9. 自走棋机制对接（当前实现状态）

已改为自走棋模式（时间驱动独立回合，技能按事件流自动触发）：

1. ✅ 移除技能选择菜单，行动自动触发。
2. ✅ 战斗流程为事件驱动（第 2 节的攻击事件流），单位按各自 `turn_interval` 独立行动。
3. ✅ `battle_manager.gd` 在每个攻击/行动阶段调用 `SkillTriggerSystem.dispatch`，扫描单位技能匹配触发。
4. ✅ 现有 effect 处理器无需改动，调用时机从"手动施放"变为"事件自动触发"。

**当前实际实现清单**：

- ✅ 时间驱动回合：`TurnManager.tick(delta)`，每单位独立 `turn_interval`
- ✅ 自动行动：攻击范围内有敌人则攻击，否则移动（1 移动力）再尝试攻击
- ✅ 技能触发系统：`SkillTriggerSystem.dispatch(battle, trigger, context)`，支持 14 个触发时机
- ✅ 技能结构：`trigger`/`condition`/`cooldown`/`priority`/`min_range`/`max_range`/`effects`
- ✅ 效果类型（已实现 20 类）：
  - 即时：`damage`/`heal`/`revive`/`dispel`/`summon`/`mark`/`teleport`（位移家族）
  - 伤害变体：`percentage_damage`/`chain_damage`
  - 状态：`buff`/`dot`/`shield`/`stat_mod`/`taunt`/`immunity`/`reflect`/`protect`/`ignore`/`lifesteal`
  - 永久成长：`permanent_stat`（永久属性强化，persist=true 全局永久写回编成 / false 仅本局永久）
- ✅ 位移家族：`teleport`（mode self/target × dir target/away/self × distance，支持突脸/拉人/击退/闪现/后撤）
- ✅ 目标系统：`self`/`target`/`enemy`/`ally`/`all_enemies`/`all_allies`（按射程/全体解析）
- ✅ 条件系统：`hp_percent`/`has_buff`/`target_has_buff` 等基础条件

**尚未实现（按需补充）**：
- ⬜ AOE 范围形状（`shape`：cross/line/around/square）——当前目标解析支持全体但范围形状未落地
- ⬜ `random_enemy`/`area` 目标类型
- ⬜ 更多触发条件（`round`/`range`/`is_boss` 等）

---

## 10. 待确认问题（已确认项）

- [x] `teleport` 位移保留，已实现位移家族（突脸/拉人/击退/闪现/后撤）。
- [x] 不做元素类型表，先纯物理伤害；已通过 `ignore_defense` 实现"直接伤害"雏形。
- [x] 抵消附带伤害暂不实现（后续做复杂机制时再引入）。
- [x] 需要暴击；不考虑命中率，必定命中。
- [x] 暴击率/暴击伤害默认值（已定：Hero/Knight/Goblin 5%/150%，Orc 10%/160%；可加点/装备/Buff 调整）。
- [ ] 位移在自走棋中是否受"移动点数"限制（当前位移无视移动力）。
- [ ] AOE 范围形状（cross/line/around/square）是否实现。

---

## 11. 双轨实现与固有/通用技能（2026-08-11）

### 11.1 固有技能 / 通用技能

- 单位模板 `units.json` 的 `innate_skill` 声明固有技能：模板独有、始终生效、不可更换；可为空（兼容）。
- `skills.json` 中 `common: true` 标记通用技能：在队伍编成中花费技能点学习并装备后才参与战斗。
- 修复：已学未装备的技能不再自动生效（只有已装备的通用技能 + 固有技能进入战斗）。
- 示例：Hero 固有"以战养战"（on_kill 触发，permanent_stat 永久生命上限 +1，persist=true 写回编成）。

### 11.2 代码技能双轨

为覆盖 JSON 难以表达的复杂逻辑（任意条件、多段流程），技能分为两条轨道：

| 轨道 | 方式 | 适用 |
|---|---|---|
| JSON 轨 | skills.json 组合效果积木 | 简单/组合型技能，mod 初学者 |
| 代码轨 | 继承 `CodeSkill` 覆写钩子 | 复杂条件/流程逻辑，进阶作者 |

实现：

- `Skill` 基类三个可覆写钩子（默认实现 = 原有数据驱动逻辑，JSON 技能行为不变）：
  - `check_condition(battle, context)`：触发条件（血量/护盾/任意自定义）
  - `resolve_targets(battle, user, context)`：目标解析
  - `execute(user, targets, game)`：效果执行（可直接调用 EffectSystem 效果库）
- `CodeSkill`（scripts/battle/skills/code_skill.gd）：代码技能基类，元数据（名称/触发/冷却/射程/common）在 `_init` 中设置，`export_meta()` 供合并注册。
- `skill_code_registry.gd`：集中注册文件，一行（技能 id + 脚本 res:// 路径）。
- GameDatabase 启动时把代码技能并入全局技能表，战斗创建/编成界面/信息面板统一访问，与 JSON 技能无差别。
- 代码技能与 JSON 技能共用同一条触发分发管线与效果函数库。
