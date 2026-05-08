# 08 Craft Generation

Script: `script_folder/card_craft_manager.gd`

This is another major 2D card creation path (not scene random spawn).

## Trigger Chain

- `Card.bestacked_on_me()` / `stop_stacking_on_me()`
- emits `Events.stack_changed(card)`
- `CraftManager` listens and evaluates current stack chain

## Recipe Resolve Flow

1. collect all `cardname` values in stack chain
2. sort names
3. match sorted key in `_recipe_map`
4. if recipe exists and has craft time, start `CardProgressBar`
5. on completion:
   - `queue_free()` material cards
   - instantiate result `card_info.card_scene`
   - call `set_stats(card_info)`
   - add to `Cards` group

## Recipe Data Source

- `CraftManager.craft_pools` is exported on `main.tscn`
- `_build_recipe_map()` loads resources from these pools
- only `ThingsCard` with `has_craft_recipe == true` are included
