# MOD 开发指南（新建角色）

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

## 7. 示例

`mods/example_mod/` 是一个完整的示例：包含 mod.json、SampleHero 单位、Power Strike 技能、idle 与 portrait 图片。复制它改成自己的即可。

> 提示：新增图片后需让 Godot 重新导入（首次启动会自动导入）。
