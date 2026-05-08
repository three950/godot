# 06 Abyss Scene Random Generation

Script: `assets/AbyssLayer/Scene.gd`

## Trigger Condition

Intended condition: character cards (`CardInfo.CardType.人物`) can be stacked onto abyss scene cards and trigger generation timing.

Flow:

character stacked on `Scene` -> `Scene.bestacked_on_me(children)` -> `_update_signal_connections()` -> `_start_timing()`

## Timing Speed

`_calculate_average_speed()` walks character cards on stack chain, reads each resource `speed`, and computes:

- `average_speed = total_speed / valid_character_count`
- `duration = 100.0 / average_speed`

If no valid speed, returns `1.0` so duration becomes `100` seconds.

## Progress Bar

`_start_timing()` connects `CardProgressBar.progress_completed` and starts:

```gdscript
card_progress_bar.start(duration)
```

When completed, callback goes to `_on_spawn_timer_completed()`.

## Spawn Selection

On timer complete:

```gdscript
var type = cardpool.get_random_type_in_abyss()
spawn_card_info = cardpool.get_cards_by_type(type)
_spawn_card()
```

`get_random_type_in_abyss()` uses weighted random type selection.
Then `get_cards_by_type(type)` filters global pool and picks one random card.

## Instantiate And Place

`_spawn_card()`:

1. instantiate from `spawn_card_info.card_scene`
2. `instance.set_stats(spawn_card_info)`
3. find first node in `Cards` group
4. add instance
5. place at `global_position + spawn_offset` (default `Vector2(0, 360)`)

After spawn:

- if a character is still stacked, restart timing for next card
- else cancel timing
