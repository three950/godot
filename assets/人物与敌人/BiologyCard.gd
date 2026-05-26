class_name BiologyCard
extends CardInfo

signal stats_changed

const BATTLE_COMBAT_PROFILE_SCRIPT := preload("res://presentation/battle_scene/combat/battle_combat_profile.gd")

# 所有“生物卡”的战斗数据父类。
# CharacterCard 和 EnemyCard 继承这里，3D 战斗只读取这层统一属性。
@export var MAX_HP := 1 : set = set_MAX_HP
@export var ATK: int : set = set_ATK
@export var speed: int : set = set_speed
enum attackType {close, remote}
@export var attack_type: attackType = attackType.close
@export var combat_profile: BattleCombatProfile

var HP: int : set = set_HP
@export var DEF: int : set = set_DEF


func set_HP(value : int) -> void:
	# HP 只能在 0 和最大生命之间变化，避免伤害/治疗把卡牌状态推到非法范围。
	HP = clampi(value, 0, MAX_HP)
	stats_changed.emit()


func set_MAX_HP(value : int) -> void:
	# 提高最大生命时同步补足新增血量；降低最大生命时把当前血量压回上限。
	var diff := value - MAX_HP
	MAX_HP = value
	
	if diff > 0:
		HP += diff
	elif HP > MAX_HP:
		HP = MAX_HP
	
	stats_changed.emit()


func set_DEF(value : int) -> void:
	DEF = clampi(value, 0, 999)
	stats_changed.emit()


func set_ATK(value: int) -> void:
	ATK = value
	stats_changed.emit()


func set_speed(value: int) -> void:
	speed = value
	stats_changed.emit()


func take_damage(damage : int) -> void:
	if damage <= 0:
		return
	# 防御只抵消本次伤害，不会反向治疗。
	var actual_damage = clampi(damage - DEF, 0, damage)
	HP -= actual_damage


func heal(amount : int) -> void:
	if amount <= 0:
		return
	HP += amount


func get_combat_profile() -> BattleCombatProfile:
	# 旧生物资源没有 combat_profile；第一次进入战斗时按旧类型补齐默认配置。
	if combat_profile == null:
		combat_profile = BATTLE_COMBAT_PROFILE_SCRIPT.new() as BattleCombatProfile
		combat_profile.initialize_default(_get_default_combat_faction())
	return combat_profile


func _get_default_combat_faction() -> BattleCombatProfile.Faction:
	# 这里保留旧数据的语义：CharacterCard 属于角色侧，EnemyCard 属于非角色侧。
	if self is CharacterCard:
		return BATTLE_COMBAT_PROFILE_SCRIPT.Faction.CHARACTER
	return BATTLE_COMBAT_PROFILE_SCRIPT.Faction.ENEMY
