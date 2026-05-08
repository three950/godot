---
name: 2d-to-3d-keypoints
description:  Use when implementing  2D-to-3D task
---

# 2D to 3D Key Points
1. When cards are stacked, apply an upward Y-axis offset of 0.03 to the root node; the original Y offset logic is converted to and maintained as the Z-axis offset.

2. When a card leaves the stack and becomes a standalone card, reset its base Y-axis coordinate to prevent floating caused by residual height offset.

3. When the parent card enters the falling state, send a stop-follow command to all child cards, ensuring the **in-stack dragging state** can reliably revert to the **normal stacked state**.
