class_name DefaultAttackSkill
extends BattleSkill

# 当前默认普攻技能：复刻原 BattleScene3DCombatController 的 speed 冷却、目标选择和基础攻击。


func get_cooldown(user: Card3D, context) -> float:
	return context.get_basic_attack_cooldown(user)


func can_use(user: Card3D, context) -> bool:
	return context.is_unit_alive(user)


func choose_target(user: Card3D, context) -> Card3D:
	return context.get_first_alive_opponent(user)


func execute(user: Card3D, target: Card3D, context):
	await context.perform_basic_attack(user, target)
