class_name BattleUnitActionPlanner
extends RefCounted

# BattleUnitActionPlanner 只负责“轮到这个单位时，它准备怎么行动”。
# 出手顺序、队列串行、动画和扣血仍由 BattleScene3DCombatController 统一处理。

var unit_id: int = 0

var _controller = null


func configure(unit: Card3D, controller) -> void:
	unit_id = unit.get_instance_id() if unit != null and is_instance_valid(unit) else 0
	_controller = controller


func get_unit() -> Card3D:
	if unit_id == 0:
		return null
	var instance := instance_from_id(unit_id)
	if instance == null or not is_instance_valid(instance):
		return null
	return instance as Card3D


func can_act(context = null) -> bool:
	var battle_context = context if context != null else _controller
	var unit := get_unit()
	if battle_context == null or unit == null:
		return false
	if battle_context.is_neutral_unit(unit):
		return false
	if not battle_context.is_unit_alive(unit):
		return false
	return _select_skill(unit, battle_context) != null


func get_next_cooldown(context = null) -> float:
	var battle_context = context if context != null else _controller
	var unit := get_unit()
	var skill := _select_skill(unit, battle_context)
	if unit == null or skill == null:
		return 1.0
	return maxf(skill.get_cooldown(unit, battle_context), 0.05)


func perform_turn(context = null) -> void:
	var battle_context = context if context != null else _controller
	var unit := get_unit()
	if not can_act(battle_context):
		return

	var skill := _select_skill(unit, battle_context)
	if skill == null or not skill.can_use(unit, battle_context):
		return

	var target := skill.choose_target(unit, battle_context) as Card3D
	if target == null:
		return

	# 行动规划器只发起请求；controller 在 request_attack/perform_basic_attack 内再次验证存活状态。
	await battle_context.request_attack(unit, skill, target)


func _select_skill(unit: Card3D, context) -> BattleSkill:
	if unit == null or context == null:
		return null

	var profile: BattleCombatProfile = context.get_unit_combat_profile(unit)
	if profile == null or profile.skills.is_empty():
		return null

	# skills[0] 是当前默认技能；空数组或空槽都不自动补。
	#TODO:skill的优先级还需要调整，写在只拿[0].后续装备追加技能、被动技能、条件技能不稳，数组顺序一变默认普攻就变了
	var skill := profile.skills[0]
	if skill == null:
		return null
	return skill
