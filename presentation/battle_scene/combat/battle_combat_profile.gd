class_name BattleCombatProfile
extends Resource

# 战斗配置只描述“这个生物默认怎么参与战斗”。
# 行为树先作为资源入口预留，当前自动战斗默认使用 skills[0]。

enum Faction { CHARACTER, ENEMY, NEUTRAL }
enum Stance { AGGRESSIVE, PASSIVE, DEFENSIVE, OTHER }

@export var faction: Faction = Faction.ENEMY
@export var stance: Stance = Stance.AGGRESSIVE
@export var skills: Array[BattleSkill] = []
@export var behavior_tree: Resource = null
