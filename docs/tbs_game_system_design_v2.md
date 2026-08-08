
# 简单 2D 战棋游戏系统设计文档（改进版）

## 1. 项目目标
- 类型：回合制 2D 战棋（单机，PVE）
- 平台：PC（Windows 优先）
- 核心体验：单位移动、攻击、技能、地形影响、胜负条件
- 开发策略：先完成最小可玩版本（MVP），再逐步扩展系统复杂度

---

## 2. 设计原则

### 2.1 玩法闭环优先
保证以下循环完整可运行：

战斗开始 → 玩家操作 → 敌方行动 → 战斗结算 → 胜负判定

### 2.2 强模块化
游戏逻辑必须与渲染/UI分离：

- 战斗规则：Battle层
- 表现层：Render/UI
- 数据配置：Data

这样可以避免规则逻辑被 UI 代码污染。

### 2.3 数据驱动设计
所有可调参数使用配置文件：

- 单位属性
- 技能效果
- 地图结构
- 关卡配置

配置文件统一使用 JSON。

---

# 3. 总体系统架构

系统模块划分：

Core  
Battle  
Entity  
AI  
Data  
UI  
Render  
Save

模块职责：

### Core
- 游戏主循环
- 场景管理
- 输入分发

### Battle
- 战斗规则
- 行动系统
- 回合管理
- 战斗计算

### Entity
- 单位对象
- 技能对象
- Buff对象

### AI
- 敌方行动逻辑
- 目标选择
- 移动规划

### Data
- JSON配置加载
- 数据校验

### UI
- 操作菜单
- 血条
- 战斗日志

### Render
- 地图渲染
- 单位显示
- 动画与特效

### Save
- 战斗存档
- 关卡进度

---

# 4. 核心系统设计

## 4.1 回合系统

采用阵营回合制：

玩家回合 → 敌方回合 → 下一回合

单位状态：

Ready  可行动  
Acted  已行动  
Dead   已死亡

回合结束条件：

- 玩家主动结束回合
- 当前阵营全部单位已行动

---

## 4.2 网格与地图系统

地图使用 Tile Grid（方格地图）。

每个 Tile 包含：

move_cost       移动消耗  
defense_bonus   防御加成  
passable        是否可通行  

### 移动范围算法

采用 **Dijkstra 算法** 计算可到达区域。

原因：

不同地形具有不同移动成本。

### 路径搜索

路径规划使用：

A* (A-star) 算法

---

## 4.3 单位系统

### 单位基础属性

hp  
max_hp  
atk  
def  
move  
range_min  
range_max  
camp  

### 单位运行时状态

pos  
acted  
alive  
team_id  
buffs  
cooldowns  

### 单位行为

Move  
Attack  
UseSkill  
Wait

---

## 4.4 行动系统（Action System）

所有行为通过 Action 执行：

MoveAction  
AttackAction  
SkillAction  
WaitAction  

执行流程：

单位选择行动 → 生成 Action → Action Queue 执行

这样可以支持复杂行为组合，例如：

移动 → 攻击  
攻击 → 技能  
技能 → 移动

---

## 4.5 战斗与伤害系统

基础伤害公式：

damage = max(1, attacker.atk - (defender.def + terrain_bonus))

说明：

地形加成为防守方防御加成。

### 反击规则

若满足以下条件则可反击：

- 防守单位存活
- 攻击者在攻击范围内

每次攻击最多触发一次反击。

---

## 4.6 技能系统

技能数据结构：

id  
name  
cost  
cooldown  
target_type  
range  
aoe  
effect  

技能效果类型：

Damage  
Heal  
Buff  
Debuff  
Displacement

技能执行流程：

选择技能 → 选择目标 → 合法性检测 → 结算效果 → 写入战斗日志

---

## 4.7 AI系统

AI行为分为三个阶段：

1 目标选择  
2 移动规划  
3 行动选择  

### MVP AI规则

1 如果可以攻击玩家单位  
优先攻击可击杀目标  

2 如果不能攻击  
移动到最近玩家单位  

3 如果无法移动  
待机

---

## 4.8 视野系统（可选扩展）

为未来扩展预留接口：

vision_range  
visible_tiles

未来可支持：

- 战争迷雾
- 潜行单位
- 侦察单位

---

## 4.9 胜负条件

胜利条件：

- 歼灭所有敌人
- 占领关键区域

失败条件：

- 主角死亡
- 回合数超过限制

---

# 5. 数据模型设计

## 配置文件结构

units.json  
skills.json  
maps/<map_id>.json  
stages/<stage_id>.json  

### 关键实体

UnitConfig      单位模板  
UnitState       单位运行状态  
SkillConfig     技能模板  
BattleState     战斗状态  

BattleState包含：

- 当前回合
- 单位列表
- 地图状态
- 战斗日志

---

# 6. 核心流程

## 玩家操作流程

1 选择单位  
2 选择移动位置  
3 选择行动类型  
4 结算行动  
5 标记为 Acted  

---

## 战斗结算流程

1 校验合法性  
2 计算伤害  
3 扣减 HP  
4 死亡判定  
5 执行反击  
6 写入战斗日志  

---

# 7. 推荐目录结构

TBS_Game/

main.py

game/

core/
battle/
    combat
    turn
    movement

entity/
ai/
data/
ui/
render/

assets/
maps/
units/
skills/

docs/

---

# 8. MVP 迭代计划

## M1 可玩原型

- 方格地图
- 单位移动
- 普通攻击
- 回合系统
- 胜负判定

## M2 战斗增强

- 技能系统
- 地形加成
- 简单 AI

## M3 内容扩展

- 多关卡
- 单位成长
- 装备系统
- 存档系统

---

# 9. 风险控制

风险：规则耦合

解决：

战斗规则统一集中在 Battle 层。

风险：配置混乱

解决：

统一 JSON schema 并在启动时进行校验。

风险：AI复杂度过高

解决：

先实现规则 AI，再逐步升级。

---

# 10. MVP验收标准

满足以下条件视为完成：

- 可完整进行一场战斗
- 战斗可自动结算胜负
- UI可显示血量与回合
- 单位与地图参数可通过配置修改

