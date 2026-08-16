# Changelog

## 1.0.8 — Shop Randomization

This release adds optional persistent shop randomization for **Gen 1** and **Gold**. Each enabled shop receives a saved weighted inventory that remains stable through map changes, saves, reloads, and repeat visits. Item selection respects shop progression, avoids key items, HMs, non-tossable records, and low-value junk, while preserving a small chance of a stronger result.

Gen 1 adds **RANDOMIZE SHOP INVENTORIES**. Gold adds **GOLD RANDOMIZE SHOPS** for standard marts. Shop prices are generated with each saved shop layout and are applied only while the relevant mart is open. Existing map pickups, hidden finds, berries, gifts, trainer held items, and protected New Game PC behavior remain unchanged.
