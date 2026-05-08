# 05 Stack Trigger Mechanism

All regular 2D cards are based on `assets/card.gd`.

## Core Fields And Signals

- `overlapping_cards`: candidate stack targets detected by dragging/falling card
- `follow_target`: parent card being followed
- `children_card`: child card stacked on current card
- `stack_state`: stack state marker
- `stacking_on_you(children)`: notify parent when a child stacks on it
- `stop_stacking_on_you()`: notify parent when child is picked up
- `array_changed()`: local stack structure changed
- `Events.stack_changed(card)`: global stack change for crafting listeners

## Release To Stack Flow

- On drag release, `assets/card-states/card_falling.gd` picks the nearest valid target.
- Then `stack_on_card(target_card)` is called.
- It sets follow relation and emits stack signals.

## `bestacked_on_me()` Effects

`Card.bestacked_on_me()` usually does:

1. set `children_card`
2. disable base card stack detector area
3. emit `array_changed()`
4. emit global `Events.stack_changed(self)`

`Scene` overrides this and then starts/updates spawn timing logic.
