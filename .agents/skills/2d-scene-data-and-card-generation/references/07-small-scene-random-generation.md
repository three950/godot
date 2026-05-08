# 07 Small Scene Random Generation

Script: `assets/小场景/Small_Scene.gd` (inherits `Scene`)

It reuses stack, timer, instantiate, and launch behavior from `Scene`, but overrides speed and pool selection.

## Speed Calculation Difference

Small scene does not average character resource `speed`.

Model:

- each character contributes base speed `20`
- apply scene multiplier from `scene.speed_change(character_features)`
- sum total speed
- `duration = 100.0 / total_speed`

`assets/小场景/scene_card_pool/scene_card_pool.gd` currently returns:

- `2` when required feature exists
- `1` otherwise

So matching scene requirement doubles effective speed.

## Pool Selection Difference

Small scene timer completion does not use global `CardPool` weighted type draw.

Instead:

```gdscript
spawn_card_info = scene.card_pool.pick_random()
_spawn_card()
```

Each small-scene `.tres` can own its own independent card list.
