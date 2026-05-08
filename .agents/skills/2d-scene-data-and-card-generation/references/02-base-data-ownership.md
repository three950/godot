# 02 Base Data Ownership

## Core Data Under `base_data/`

- `base_data/CardInfo.gd` (`class_name CardInfo`)
  - Base card resource with `name`, `portrait`, `text`, stack flag, and `type` enum
- `base_data/card_pool/CardPool.gd` (`class_name CardPool`)
  - Global pool resource wrapper over `Array[CardInfo]`
  - Provides random type selection and type-filtered random card
- `base_data/card_pool/card_pool.tres`
  - Actual global pool content
- `base_data/game_stats.gd` / `.tres` (`class_name GameStats`)
  - Global runtime state: time/day/coins/food/current layer/max layer
- `base_data/battle_stats.gd` / `.tres` (`class_name BattleState`)
  - Stage state resource for normal/battle phases

## Type Field Is the Main Selector

- `CardInfo.type` is the key field for spawn filtering.
- `CardPool.get_cards_by_type(type)` filters `card_pool` by `type`, then picks one randomly.
