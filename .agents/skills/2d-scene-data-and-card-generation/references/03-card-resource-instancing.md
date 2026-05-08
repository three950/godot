# 03 Card Resource Instancing

## Common Pattern

Most card resources inherit from `CardInfo` (directly or indirectly) and export `card_scene: PackedScene`.

Runtime spawning usually follows the same path:

```gdscript
var instance = spawn_card_info.card_scene.instantiate()
instance.set_stats(spawn_card_info)
```

No manual `match type` scene switch is required when resources are configured correctly.

## Typical Resource Classes

- `CharacterCard` -> battle card scene
- `EnemyCard` -> enemy card scene
- `ItemCard` -> item card scene
- `ResourceCard` -> resource card scene
- `EquipmentCard` -> equipment card scene
- `RemainsCard` -> remains card scene
- `SceneCard` -> abyss scene card scene
- `SceneCardPool` -> small scene card scene

## Minimum Requirements for New Spawnable Cards

1. Resource extends `CardInfo` lineage.
2. `type` is set correctly.
3. `card_scene` points to a valid `PackedScene`.
4. The card scene script implements `set_stats(...)` and refreshes display.
