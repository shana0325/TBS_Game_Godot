# MOD 开发指南（新建角色）

> 当前 Mod 接口以数据和素材扩展为主。Mod 可以添加单位、技能、Buff、装备和角色图片；不建议直接替换核心战斗脚本或界面控制器。

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
    equipments/<装备名>.json   # 可选：装备数据
    art/units/<角色名>/        # 角色素材
      idle.png                 # 必填：战场站立图
      attack.png               # 可选：攻击动作（缺省回退 idle）
      hurt.png                 # 可选：受击动作（缺省回退 idle）
      death.png                # 可选：死亡动作（缺省回退 idle）
      skill.png                # 可选：技能动作（缺省回退 idle）
      portrait.png             # 可选：立绘（信息面板/成长界面显示）
```

游戏启动时自动扫描并合并，无需任何手动配置。同名的单位/技能/Buff/装备会**覆盖原版数据**。

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
    "hp": 24,
    "atk": 8,
    "defense": 5,
    "move": 4,
    "range_min": 1,
    "range_max": 1,
    "skills": ["Power Strike"]
  }
}
```

字段说明：

| 字段 | 说明 |
|---|---|
| `display_name` | 中文显示名（缺省显示键名） |
| `hp` / `atk` / `defense` / `move` | 基础属性 |
| `range_min` / `range_max` | 攻击射程 |
| `skills` | 自带技能名列表（引用 skills.json 中的技能） |

## 4. 技能数据（skills/*.json）

```json
{
  "Power Slash": {
    "name": "Power Slash",
    "min_range": 1,
    "max_range": 2,
    "effects": [
      { "type": "damage", "power": 1.5 },
      { "type": "buff", "buff": "stun" }
    ]
  }
}
```

效果类型：`damage`（伤害，`power` 倍率）、`heal`（治疗，`amount`）、`buff`（附加状态，`buff` 指定 buffs.json 中的 id）。

## 5. 图片规格

- **idle/attack/hurt/death/skill**：战斗小人，建议正方形透明 PNG（32 或 64 像素均可，游戏中会自动缩放）。只需一张 `idle.png` 即可运行。
- **portrait**：立绘，建议 256×256 以上，透明背景，信息面板与成长界面会居中显示。

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

`mods/example_mod/` 是一个完整的示例：包含 mod.json、SampleHero 单位、Power Strike 技能、idle 与 portrait 图片。复制它改成自己的即可。

> 提示：新增图片后需让 Godot 重新导入（首次启动会自动导入）。

## 9. 代码技能（进阶）

普通技能用 JSON 组合效果积木即可（见第 4 节）。需要**自定义条件或复杂流程**的技能，可以用 GDScript 实现（技能双轨制）：

1. 新建脚本继承 `CodeSkill`（基类：`res://scripts/battle/skills/code_skill.gd`），并按需覆写：
   - `check_condition(battle, context)`：触发条件（缺省按 JSON `condition` 判断）
   - `resolve_targets(battle, user, context)`：目标解析（缺省按 `target_type` 与射程）
   - `execute(user, targets, game)`：效果执行（缺省把 `effects` 交给效果库；可直接调用 `EffectSystem.apply_effects`）
2. 元数据（名称/描述/触发时机/冷却/射程/common 标记）在脚本 `_init` 中设置。
3. 在集中注册文件 `scripts/battle/skills/skill_code_registry.gd` 的 `get_entries()` 里注册一行：
   ```gdscript
   "My Skill Name": "res://scripts/你脚本的路径.gd",
   ```
4. 脚本需声明 `class_name`；新增后运行一次 Godot `--import` 刷新全局类缓存（或启动游戏自动扫描导入）。

代码技能与 JSON 技能统一并入技能表，编成界面、战斗触发、单位创建均自动生效。
