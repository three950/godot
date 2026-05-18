---
name: godot-global-timer-pause
description: "Use when adding, changing, reviewing, or debugging any Godot timing behavior in this repository, including Timer nodes, SceneTreeTimer usage, cooldowns, attack intervals, spawn delays, progress bars, Tweens used as gameplay timing, async waits, countdown loops, or elapsed-time accumulation. Enforces listening to res://script_folder/events.gd signal timers_pause_changed(is_paused: bool) so all gameplay timers support the global pause state."
---

# Godot Global Timer Pause

Any gameplay timing logic must follow the project global pause state from `Events`.

## Required Rules

1. Read `res://script_folder/events.gd` before implementing timer behavior if the current code does not already show the pattern.
2. Initialize new timing logic from `Events.timers_paused`.
3. Connect to `Events.timers_pause_changed(is_paused: bool)` and update the timer/tween/loop immediately when the signal fires.
4. Disconnect only when necessary; prefer connecting from scene-owned nodes that die with the scene.
5. Do not use `get_tree().create_timer(...)` for gameplay timing that must pause. Use a `Timer` node or a custom remaining-time loop that explicitly stops advancing while `Events.timers_paused` is true.
6. UI-only animation that should continue during pause may opt out, but add a short comment explaining why it is not gameplay timing.

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

## Tween Pattern

If a tween represents gameplay timing, pause and resume it with the same signal:

```gdscript
var gameplay_tweens: Array[Tween] = []

func _on_timers_pause_changed(is_paused: bool) -> void:
	for tween in gameplay_tweens.duplicate():
		if tween == null or not tween.is_valid():
			gameplay_tweens.erase(tween)
			continue
		if is_paused:
			tween.pause()
		else:
			tween.play()
```

## Manual Delta Pattern

For `_process(delta)` or `_physics_process(delta)` countdowns, skip elapsed-time updates while paused:

```gdscript
func _process(delta: float) -> void:
	if Events.timers_paused:
		return
	remaining_time -= delta
```

If the code already has a central tick method, put the pause check at the tick boundary so every timer path shares it.
