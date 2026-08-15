# Changelog

## 1.0.0 — Full Release

Item Randomizer 1.0.0 provides persistent, progression-conscious randomization for Gen 1 and Gold item sources. Each save receives a stable mapping, so a pickup remains the same after leaving an area, saving, or reloading.

### Safe item pools

The randomizer excludes key items, HMs, non-tossable items, and other progression-sensitive rewards from its ordinary randomization pools. Source settings are independent, allowing a player to build an overworld-only, hidden-item-only, PC-only, or mixed run.

| Feature | What it does |
|---|---|
| Persistent mapping | Saves every generated replacement per playthrough. |
| Reduced low-value items | Lowers the weight of common status cures, X-items, Repels, standard Potions, Escape Ropes, Poké Dolls, and similar low-impact results. |
| Progression-weighted loot | Favors modest useful rewards early and stronger rewards later, while retaining a small chance of high-value early results. |
| Safe exclusions | Keeps key items, HMs, and non-tossable items outside ordinary item pools. |
| New Game PC | Replaces only the generated New Game PC item, never a continued save’s existing PC contents. |
| Protected PC reroll | Rerolls only the generated PC item, then permanently locks after that item is withdrawn. |

### Gen 1 Sources

Gen 1 supports visible overworld item balls, hidden Itemfinder rewards, and the optional New Game PC item. The original source controls and per-save behavior remain available in 1.0.0.

### Gold Sources

Gold adds separate, safe controls for its native item structures.

| Gold option | Effect |
|---|---|
| **GOLD BALL ITEMS** | Randomizes visible Gold item balls. |
| **GOLD FINDER ITEMS** | Randomizes Gold hidden item pickups. |
| **GOLD BERRY TREES** | Randomizes berry-tree rewards while leaving apricorn-tree behavior intact. |
| **GOLD GIFT ITEMS** | Randomizes eligible ordinary scripted item gifts. |
| **GOLD HELD ITEMS** | Randomizes eligible existing trainer held items without assigning items to originally itemless Pokémon. |
| **GOLD START PC** | Replaces the New Game PC item with a saved safe result. |
| **GOLD REROLL PC** | Rerolls only the generated Gold PC item until it is withdrawn. |

### Compatibility and quality

This release targets Mod API 2 and supports both Gen 1 and Gold. The release uses Gold’s nested map item records, hidden-item records, fruit-tree commands, and scripted gift commands while retaining the stable Gen 1 behavior. Mobile option labels are kept compact and source categories can be enabled independently.
