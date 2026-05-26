class_name BattleCombatProfile
extends Resource

# 战斗配置只描述“这个生物默认怎么参与战斗”。
# 行为树先作为资源入口预留，当前自动战斗仍走 default_skill。

const DEFAULT_ATTACK_SKILL_SCRIPT := preload("res://presentation/battle_scene/combat/default_attack_skill.gd")

enum Faction { CHARACTER, ENEMY, NEUTRAL }
enum Stance { AGGRESSIVE, PASSIVE, DEFENSIVE, OTHER }

@export var faction: Faction = Faction.ENEMY
@export var stance: Stance = Stance.AGGRESSIVE
@export var skills: Array[BattleSkill] = []
@export var default_skill: BattleSkill
@export var behavior_tree: Resource = null


func initialize_default(default_faction: Faction = Faction.ENEMY) -> void:
	# 只给旧卡运行时补齐默认配置；已经手动配置的 profile 不在这里被覆盖。
	faction = default_faction
	default_skill = DEFAULT_ATTACK_SKILL_SCRIPT.new()
	skills.clear()
	skills.append(default_skill)


func get_default_skill() -> BattleSkill:
	return default_skill
