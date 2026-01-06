class_name CardHeightAnimator
extends Node
@export var card: Card

## 跳跃动画的 Tween
var jump_tween: Tween = null

## 让卡牌跳起（伪3D效果）
## target_height: 目标高度（0.0-2.0）
## duration: 跳跃持续时间
func jump_to_height(target_height: float, duration: float = 0.2) -> void:
	if jump_tween and jump_tween.is_valid():
		jump_tween.kill()
	jump_tween = create_tween()
	jump_tween.tween_property(card, "current_height", target_height, duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

## 让卡牌落回桌面
## duration: 下落持续时间
func land_on_table(duration: float = 0.15) -> void:
	var base_h := card.base_height
	if jump_tween and jump_tween.is_valid():
		jump_tween.kill()
	jump_tween = create_tween()
	jump_tween.tween_property(card, "current_height", base_h, duration)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

## 播放完整的跳跃动画（跳起 -> 停留 -> 落下）
## peak_height: 最高点高度
## hang_time: 在最高点停留时间
## up_duration: 上升时间
## down_duration: 下落时间
func play_jump_animation(peak_height: float = 1.0, hang_time: float = 0.1, 
		up_duration: float = 0.2, down_duration: float = 0.15) -> void:
	if jump_tween and jump_tween.is_valid():
		jump_tween.kill()
	
	var base_h := card.base_height
	
	jump_tween = create_tween()
	# 上升阶段
	jump_tween.tween_property(card, "current_height", peak_height, up_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# 停留阶段
	if hang_time > 0.0:
		jump_tween.tween_interval(hang_time)
	# 下落阶段
	jump_tween.tween_property(card, "current_height", base_h, down_duration)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

## 播放弹跳动画（多次小跳跃）
## bounces: 弹跳次数
## initial_height: 初始跳跃高度
## decay: 每次弹跳高度衰减比例
func play_bounce_animation(bounces: int = 2, initial_height: float = 0.8, 
		decay: float = 0.5) -> void:
	if jump_tween and jump_tween.is_valid():
		jump_tween.kill()
	
	var base_h := card.base_height
	
	jump_tween = create_tween()
	var h := initial_height
	
	for i in range(bounces):
		var up_time := 0.15 * pow(decay, i * 0.5)
		var down_time := 0.12 * pow(decay, i * 0.5)
		jump_tween.tween_property(card, "current_height", h, up_time)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		jump_tween.tween_property(card, "current_height", base_h, down_time)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		h *= decay

## 播放卡片生成翻转动画
func play_spawn_flip() -> void:
	if card.animation_player:
		card.animation_player.play("卡片生成翻转")
