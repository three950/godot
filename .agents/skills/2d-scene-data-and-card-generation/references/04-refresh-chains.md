# 04 Refresh Chains

## A. Card Visual Refresh

Base card script: `assets/card.gd`

```gdscript
func _update_card_display() -> void:
	var resource = get_card_resource()
	if resource == null:
		return
	name = resource.name
	cardname = resource.name
	if card_label:
		card_label.text = resource.name
	if card_texture:
		card_texture.texture = resource.portrait
```

Subtype scripts override resource getter and call display refresh after `set_stats(...)`.

General flow:

`set_stats(resource)` -> save exported field -> if ready, call local update -> delegate to `Card._update_card_display()`.

## B. Global UI Refresh (`GameStats`)

- `GameStats` setters call `emit_changed()`.
- `presentation/ui_stats_manager.gd` connects:
  - `game_stats.changed -> _update_stats`
  - `Events.food_need_update -> _on_food_need_update`
  - `Events.food_have_update -> _on_food_have_update`

Flow:

Events -> mutate `game_stats` -> `emit_changed()` -> `_update_stats()` -> refresh labels.

Time progression is in `_process(delta)`:

- accumulate `elapsed_time`
- when `elapsed_time >= game_stats.time * 60`
  - reset elapsed
  - `game_stats.days += 1`
  - `GameStats.changed` triggers UI update

## C. Battle Attribute Refresh

- Base: `assets/人物与敌人/battle/res_battle_states.gd` (`BattleStates`)
- Custom signal: `stats_changed`
- Setters for `HP`, `MAX_HP`, `ATK`, `DEF`, `speed` emit `stats_changed`
- `BattleCard`/`Enemy`/`Character` connect this signal to UI stat update

Battle stats refresh path is custom `stats_changed`, not `Resource.changed`.
