# MOD 开发指南（新建角色）

> 当前 Mod 接口以数据和素材扩展为主。Mod 可以添加单位、技能、Buff、遗物及对应图片；不建议直接替换核心战斗脚本或界面控制器。

> 目标：任何人无需 Godot 编辑器，只要**放文件夹 + 图片 + JSON**，就能为游戏添加新角色。

## 1. 快速开始

在项目根目录（或用户目录 `user://mods/`）新建一个 mod 文件夹，结构如下：

```
mods/
  <mod_id>/                    # 文件夹名 = mod 唯一 id
    mod.json                   # 必填：mod 元数据
    units/<角色名>.json        # 可选：单位数据
    skills/<技能名>.json       # 可选：技能数据
    buffs/<buff名>.json        # 可选：Buff 数据
    relics/<遗物名>.json       # 可选：遗物数据
    art/relics/<遗物ID>.png    # 遗物图标，建议 64×64 透明 PNG
    art/units/<角色名>/        # 角色素材
      stand.png                # 必填：战场站立图
      move.png                 # 可选：移动动作（缺省回退 stand）
      attack.png               # 可选：攻击动作（缺省回退 stand）
      death.png                # 可选：死亡动作（缺省回退 stand）
      skill.png                # 可选：技能动作（缺省回退 stand）
      portrait.png             # 可选：立绘（信息面板/成长界面显示）
```

游戏启动时自动扫描并合并，无需任何手动配置。同名的单位/技能/Buff/遗物会**覆盖原版数据**。

## 2. mod.json（元数据）

```json
{
  "id": "my_char",
  "name": "我的角色包",
  "version": "1.0.0",
  "author": "你的名字",
  "description": "给游戏添加了新角色。"
}
```

## 3. 单位数据（units/*.json）

```json
{
  "MyHero": {
    "display_name": "新英雄",
    "hp": 1400,
    "atk": 100,
    "defense": 25,
    "move": 1,
    "attack_interval": 2.0,
    "move_interval": 1.0,
    "range_min": 1,
    "range_max": 1,
    "random_pool_enabled": true,
    "innate_skill": "Power Slash",
    "tags": ["战士"]
  }
}
```

字段说明：

| 字段 | 说明 |
|---|---|
| `display_name` | 中文显示名（缺省显示键名） |
| `hp` / `atk` / `defense` / `move` | 基础属性 |
| `attack_interval` | 基础普攻间隔，现有角色统一为 2.0 秒；实际间隔受 `attack_speed` 百分比加成影响 |
| `move_interval` | 基础移动间隔，默认 1.0 秒；每次最多移动 `move` 格，初版现有单位均为 1.0 秒 |
| `range_min` / `range_max` | 攻击射程 |
| `innate_skill` | 固有技能 ID，可为空 |
| `random_pool_enabled` | 是否进入随机招募、商店和普通敌人池；默认 `true`。设为 `false` 后仍可由开局编成、指定关卡或特殊事件直接获得/生成 |
| `tags` | 单位标签数组 |

## 4. 技能数据（skills/*.json）

```json
{
  "Power Slash": {
    "name": "Power Slash",
    "desc": "攻击时造成一次技能伤害",
    "trigger": "on_attack",
    "common": false,
    "min_range": 1,
    "max_range": 2,
    "effects": [
      { "type": "damage", "power": 1.5 },
      { "type": "buff", "buff": "stun" }
    ]
  }
}
```

效果类型和字段以 [技能体系设计文档](skills/SKILL_SYSTEM.md) 为准。复杂技能可使用 `CodeSkill`，但需要同时完成脚本注册和运行验证。
普攻计数条件可在 `condition` 中使用 `"attack_count_multiple": 6`，表示完成前 5 次普攻后，第 6 次普攻触发；`cooldown` 则表示触发后需再完成的普攻次数。移动与定时主动技能均不计入。

## 5. 图片规格

遗物 Mod 可在 `relics/*.json` 中加入：

```json
{
  "my_relic": {
    "name": "练习徽记",
    "desc": "全队攻击力 +10%",
    "icon": "art/relics/my_relic.png",
    "effects": [{ "type": "stat_percent", "stat": "attack", "percent": 0.10 }],
    "triggers": []
  }
}
```

`icon` 是相对于本 Mod 根目录、位于 `art/relics/` 下的 PNG 路径；省略时自动查找 `art/relics/<遗物ID>.png`。玩家安装到 `user://mods/` 的 PNG 也会在运行时加载。遗物进入与内置遗物相同的等概率奖励池，不需要稀有度字段。上例的属性效果由现有数据接口实现；特殊战斗机制目前仍需游戏本体支持。

- **stand/move/attack/death/skill**：战斗小人，建议正方形透明 PNG（32 或 64 像素均可，游戏中会自动缩放）。只需一张 `stand.png` 即可运行。
- **portrait**：立绘，建议 256×256 以上，透明背景，信息面板与成长界面会居中显示。
- **遗物图标**：建议 64×64 透明 PNG；每件遗物一张，图鉴、奖励和详情共用同一文件。

## 6. 安装方式

- **开发/本机**：把 mod 文件夹放进项目根目录的 `mods/`。
- **玩家安装**：放进用户数据目录 `user://mods/`（游戏内自动创建）。
- **未来 Steam 创意工坊**：订阅后自动下载到 mods 目录即可被加载（架构已支持目录扫描）。

## 7. UI Mod 边界

当前项目的核心逻辑位于 `scripts/core/` 与 `scripts/battle/`，不依赖界面节点。仅替换或新增角色图片、数据 JSON，不会改变战斗计算。

界面控制器位于 `scripts/screens/` 与 `scripts/ui/`，负责把核心数据呈现出来并响应按钮/拖拽操作。直接替换这些脚本仍可能破坏场景节点、`GameSession` 或 `BattleManager` 的调用约定，因此目前不保证任意 UI 脚本 Mod 的完全隔离。

安全的 UI 扩展方式：

- 优先使用 Godot Theme、场景节点和素材替换；
- 保留现有场景根节点名称与核心信号；
- 不在 UI Mod 中修改 `Unit`、`BattleManager`、`CombatSystem` 等核心逻辑；
- 如需新增显示内容，通过读取现有公开数据，不要直接改写战斗状态。

## 8. 示例

`mods/example_mod/` 是一个素材示例；`mods/hero/` 是完整实例，包含 Hero 单位数据、战斗图片、立绘与代码固有技能。

> 提示：新增图片后需让 Godot 重新导入（首次启动会自动导入）。

## 9. 代码技能（进阶）

普通技能用 JSON 组合效果积木即可（见第 4 节）。需要**自定义条件或复杂流程**的技能，可以用 GDScript 实现（技能双轨制）：

1. 新建脚本继承 `CodeSkill`（基类：`res://scripts/battle/skills/code_skill.gd`），并按需覆写：
   - `check_condition(battle, context)`：触发条件（缺省按 JSON `condition` 判断）
   - `resolve_targets(battle, user, context)`：目标解析（缺省按 `target_type` 与射程）
   - `execute(user, targets, game, battle)`：效果执行（缺省把 `effects` 交给效果库；可直接调用 `EffectSystem.apply_effects`）
2. 元数据（名称/描述/触发时机/冷却/射程/common 标记）只在脚本 `_init` 中设置；同一代码技能不需要再建一份 `skills/*.json`。代码技能若直接造成伤害，还需声明 `damage_kinds = [DamageSystem.SKILL]`，或按实际结算类型使用 `ATTACK` / `EFFECT`；详情页据此显示伤害类型。JSON 伤害效果未配置 `damage_kind` 时默认是技能伤害。
3. 对项目内置代码技能，在 `scripts/battle/skills/skill_code_registry.gd` 注册。对 Mod 代码技能，在 `mod.json` 中加入：
   ```json
   "code_skills": {"My Skill Name": "code_skills/my_skill.gd"}
   ```
   路径必须位于该 Mod 的 `code_skills/` 目录。脚本放在对应目录，继承 `CodeSkill` 即可，无须修改项目的集中注册文件。
4. 新增脚本后运行一次 Godot 编辑器扫描以完成导入；代码技能与单位数据会在玩家存档校验前一起注册。

代码技能与 JSON 技能统一并入技能表，编成界面、战斗触发、单位创建均自动生效。

`mods/hero/` 展示了固有代码技能“属性汲取”：它通过 `on_attack_hit_before` 在普攻扣血前按目标记录偷取次数，战斗结束信号触发时将存活角色偷取总量的 20% 写入编成永久属性。生命、攻击、护甲与暴击属性支持小数存储，最终伤害仍按现有伤害结算规则取整。

代码技能保存永久成长时，应给 `ProgressManager.add_permanent_stats(unit_id, amounts, skill_id)` 传入技能 ID；`permanent_stat` 效果可填 `source_skill_id`。编成中的 `permanent_mods` 仍保存总加成，新增的 `permanent_mod_sources` 按技能 ID 记录各自贡献，供角色的技能详情展示。旧存档没有来源记录的加成会标为“历史强化（来源未记录）”，不会猜测归属。
