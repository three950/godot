# 01 Main Scene Wiring

## Scope

`main.tscn` is the current 2D gameplay host scene (`Node2D` root).

## Important Nodes

- `UI_Layer` (`presentation/ui_layer.tscn` + `presentation/ui_stats_manager.gd`)
  - Reads `base_data/game_stats.tres`
  - Shows food, coins, depth, day progress
  - Plays BGM
- `CraftManager` (`script_folder/card_craft_manager.gd`)
  - Listens to stack changes and runs crafting
- `BattleManager` (`script_folder/battle_manager.gd`)
  - Listens to battle start requests
- Initial 2D cards (character/enemy/item/equipment/resource)
  - Scene instances bound to `.tres` resources
- Abyss scene cards (`assets/AbyssLayer/Scene.tscn` + `assets/AbyssLayer/Scene.gd`)
  - `main.tscn` sets `scene` and global `cardpool`
- Small scene cards (`assets/小场景/Small_Scene.tscn` + `assets/小场景/Small_Scene.gd`)
  - `main.tscn` sets `scene`
  - Spawn pool is read from `scene.card_pool`

## Abyss vs Small Scene

- Abyss `Scene`
  - Uses node-exported `cardpool: CardPool`
  - Flow: weighted random type -> random card in that type
- Small `Small_Scene`
  - Uses `scene: SceneCardPool` resource-owned `card_pool`
  - Flow: direct `scene.card_pool.pick_random()`
