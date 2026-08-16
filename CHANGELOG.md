# Changelog

## 1.0.9 — Crystal-Safe Loot and Item Controls

Item Randomizer now recognizes **Crystal 251** as an optional Red, Blue, and Yellow overhaul. When it is active, generated item pools are built from the merged live registry and exclude imported mail, machines, HMs, key items, non-tossable items, and Crystal’s single-player evolution/progression items. Crystal 251 is not required; normal Gen 1 and Gold behavior remains standalone.

Progression-weighted mapping now applies a soft per-area duplicate penalty. Repeated rewards remain possible, including a lucky early high-value result, but identical items are less likely to fill a single area.

Gen 1 adds read-only **OPEN SHOP PREVIEW** and **PC REROLL STATUS** actions. Gold adds **GOLD SHOP PREVIEW** and **GOLD PC REROLL STATUS**. These displays expose saved state for testing without changing placements, inventories, shop layouts, or PC contents.

Gold also adds **GOLD HELD ITEM MODE**. Players can choose safe held items, useful held items, or no randomized held items. Mail, machines, key/progression items, unsafe records, and no-effect held items are excluded.

Gen 1 and Gold regression harnesses, package validation, linting, and Gen 2 safety checks passed.
