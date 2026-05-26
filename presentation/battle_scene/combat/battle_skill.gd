class_name BattleSkill
extends Resource

# BattleSkill 是单位可持有的技能资源。
# 普攻只是默认技能；后续装备、buff、debuff、治疗、召唤等都可以扩展这个接口。


func get_cooldown(_user: Card3D, _context) -> float:
	return 1.0


func can_use(_user: Card3D, _context) -> bool:
	return true


func choose_target(_user: Card3D, _context) -> Card3D:
	return null


func execute(_user: Card3D, _target: Card3D, _context):
	# 不标注返回类型：具体技能可以是同步动作，也可以 await controller 的表现结算。
	pass
