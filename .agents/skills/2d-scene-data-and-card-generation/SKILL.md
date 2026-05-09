---
name: 2d-scene-data-and-card-generation
description: "Use for quickly understanding the legacy 2D card architecture, including scene data binding, real-time data updates, stack-triggered timers, random card generation, card crafting logic, card/script/resource/scene inheritance chains, and parent-relative feature deltas (what each card scene adds or removes)."
---

# 2D Scene Data And Card Generation Guide

## Minimal Loading Guide

Pick only relevant files under `references/`:
- Main scene business wiring: references/01-main-scene-wiring.md
- Base data ownership logic: references/02-base-data-ownership.md
- Card resource -> instancing mechanism: references/03-card-resource-instancing.md
- Data/UI/battle linked refresh chains: references/04-refresh-chains.md
- Stack trigger underlying principle: references/05-stack-trigger-mechanism.md
- Abyss scene random generation logic: references/06-abyss-scene-random-generation.md
- Small scene random generation logic: references/07-small-scene-random-generation.md
- Crafting-based card generation: references/08-craft-generation.md
- Inheritance chain and feature deltas: references/09-card-inheritance-and-feature-deltas.md

## Suggested Workflow

1. First read 01 and 02 to clarify the overall architecture and data source mapping relationship.
2. If the task is "what extends what / what each scene adds or removes", read 09 first.
3. Read the corresponding generation branch document in detail as needed:
   - Abyss scene: Refer to 06
   - Small scene: Refer to 07
   - Crafting gameplay: Refer to 08
4. If the UI display or values are not updated, read 04.
5. If the logic is related to dragging/stacking behavior, read 05.
