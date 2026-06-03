---
name: stackabyss-godot-gameplay-skill
description: "StackAbyss Godot gameplay and scene-code rules. Use when editing gameplay code, UI scene scripts, card interactions, stacked cards, card reparenting, timers, battle behavior, 3D y offsets, visual layering, render priority, or runtime node setup. Requires scene/resource-owned sizing and tunable parameters, global timer pause support through Events.timers_pause_changed for timers only, stacked-card children_card handling, card reparent targets from the Cards3D scene group parent, and documentation updates for y-offset/render-priority changes."
---

# StackAbyss Godot Gameplay Skill

Only gameplay timers and countdowns follow the project global pause state from `Events`.
Animations do not pause globally.

## Required Rules

1. Read `res://script_folder/events.gd` before implementing timer behavior if the current code does not already show the pattern.
2. Initialize new timer or countdown logic from `Events.timers_paused`.
3. Connect to `Events.timers_pause_changed(is_paused: bool)` only for gameplay timers/countdowns, and update those timers immediately when the signal fires.
4. Disconnect only when necessary; prefer connecting from scene-owned nodes that die with the scene.
5. Do not use `get_tree().create_timer(...)` for gameplay timing that must pause. Use a `Timer` node or a custom remaining-time loop that explicitly stops advancing while `Events.timers_paused` is true.
6. Do not pause animations through the global timer pause. Tweens, `AnimationPlayer`, reveal/deal animations, combat visual effects, UI animation, and other visual-only motion continue during pause.
7. For any logic involving card interaction with cards, enemies, slots, effects, or other gameplay objects, treat cards as potentially stacked and include `children_card` handling so stacked children are not skipped.
8. For any new node generation or existing node modification involving 3D y position, y offset, transform-origin y, card-related y behavior, visual layering, or `render_priority`, confirm the intended change with the user before finalizing. After the user confirms, update the relevant documentation under `文档/`: `3D_Y_POSITION_ORDER.txt`, `CARD_RELATED_3D_Y_OFFSETS.txt`, and/or `3D_RENDER_PRIORITY_ORDER.txt`. This applies to both static scene/resource edits and dynamic runtime logic in scripts.
9. For any card node `reparent(...)`, use the parent node of cards in the `Cards3D` scene group as the target parent. Do not reparent card nodes to a battle scene, a battle scene's parent container, or an arbitrary nearby node when a normal `Cards3D` parent is available.
10. If a node already exists in a scene, always configure its tunable parameters in the `.tscn`/`.tres` file. **Do not** hardcode in scripts values that can be set via `.tscn`/`.tres`.

If code must create nodes dynamically, expose reusable constants or exported configuration and add a comment.

## Timer Node Pattern

Use this pattern for cooldowns, attacks, spawn delays, and delayed actions:

```gdscript
var action_timer: Timer

func _ready() -> void:
	action_timer = Timer.new()
	action_timer.one_shot = true
	add_child(action_timer)
	action_timer.timeout.connect(_on_action_timeout)
	_apply_timer_pause(Events.timers_paused)
	if not Events.timers_pause_changed.is_connected(_on_timers_pause_changed):
		Events.timers_pause_changed.connect(_on_timers_pause_changed)


func _on_timers_pause_changed(is_paused: bool) -> void:
	_apply_timer_pause(is_paused)


func _apply_timer_pause(is_paused: bool) -> void:
	if action_timer != null and is_instance_valid(action_timer):
		action_timer.paused = is_paused
```

For multiple timers, keep them in an array or dictionary and apply the same `paused` value to every live timer.

## Animation Rule

Tweens, `AnimationPlayer`, reveal/deal animations, combat visual effects, UI animation, and other visual-only motion must not connect to `Events.timers_pause_changed`.
Global pause only pauses timers/countdowns.

## Manual Delta Pattern

For `_process(delta)` or `_physics_process(delta)` countdowns, skip elapsed-time updates while paused:

```gdscript
func _process(delta: float) -> void:
	if Events.timers_paused:
		return
	remaining_time -= delta
```

If the code already has a central tick method, put the pause check at the tick boundary so every timer path shares it.
