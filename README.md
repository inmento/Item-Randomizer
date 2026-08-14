# Item Randomizer

Item Randomizer creates a **persistent per-save mapping** for visible overworld item balls, hidden Itemfinder discoveries, and optionally the one item in the player’s PC on a New Game. This first public release keeps the generated pools progression-safe: key items, HMs, non-tossable items, and their original sources remain vanilla.

## Options

| Option | Default | Effect |
|---|---:|---|
| **REDUCE LOW-VALUE ITEMS** | On | Strongly reduces status cures, X-items, Repels, standard Potions, Escape Ropes, Poké Dolls, and comparable low-value rewards in weighted mode. |
| **PROGRESSION-WEIGHTED LOOT** | On | Uses the source location’s estimated game progression. Early locations favor modest but useful items; later locations increasingly favor stronger rewards. Every tier keeps a small chance of a high-tier reward. |
| **RANDOMIZE OVERWORLD BALLS** | On | Includes visible map-object item balls. |
| **RANDOMIZE ITEMFINDER ITEMS** | On | Includes hidden Itemfinder discoveries. |
| **RANDOMIZE NEW GAME PC** | On | Replaces the default New Game PC Potion with one safe generated item. It never changes a continued save’s PC contents during ordinary mapping projection. |
| **REROLL NEW GAME PC ITEM** | Off | One-shot test/action control. Turn it on to reroll only the generated New Game PC item. Turn it off and on again for another reroll. |

The source toggles are independent. For an **overworld-only** run, leave **RANDOMIZE OVERWORLD BALLS** on and switch Itemfinder Items and New Game PC off. For an **Itemfinder-only** run, do the reverse.

## Progression-weighted loot

The weighted generator assigns each visible or hidden source an approximate game-progress tier from its map. Pallet, Viridian, Viridian Forest, Routes 1–3, Pewter, and Mt. Moon are early-tier locations. Cerulean/Vermilion areas are early-mid tier; Rock Tunnel, Lavender, and Celadon form the middle tier; Fuchsia/Saffron/Safari/Silph areas are late-mid tier; and Cinnabar, Seafoam, Victory Road, Indigo Plateau, and Cerulean Cave are late-tier locations.

This is deliberately **weighted, not locked**. An early Viridian Forest pickup is much more likely to be a modest useful item, but it can still roll a Rare Candy or other premium safe item. Conversely, late-game sources remain capable of producing ordinary rewards.

## Safety rules

The mod excludes key items, HMs, non-tossable items, and all of their original map/hidden-item sources from randomization. This avoids granting progression-critical items early and prevents the randomizer from removing the originals that the story needs. Shops, scripted gifts, gym rewards, trainer rewards, hidden coins, static Pokémon, and encounters are also outside the mod’s scope.

## PC reroll safeguard

**REROLL NEW GAME PC ITEM** is available only while the generated starting item remains in the PC. The moment that generated item is withdrawn, the mod permanently locks PC rerolls for that save. Depositing the item back later does not reopen the feature. This lets you reroll safely at the beginning, but prevents PC storage from becoming an item-generation loop after the reward has entered play. A successful reroll updates only the PC starting item and its saved mapping; it does not reroll overworld or Itemfinder placements.

## Persistence

The mod stores its setting snapshot and placements when a save first receives a mapping. Continuing the save restores the same placements. Changing settings afterward does not silently alter an established run. The PC reroll is the sole intentional exception and only changes the protected New Game PC source.

If the mod is first enabled on an existing save, it creates safe placements for uncollected enabled visible/hidden sources. It leaves existing PC contents untouched.

## Install

Import `item_randomizer-0.0.1.zip` using Gen 1 Recomp’s **Import mod .zip** action. Alternatively, extract it so the final structure is exactly:

```text
mods/
└── item_randomizer/
    ├── manifest.json
    ├── main.lua
    └── README.md
```

Do not leave the ZIP unopened in the `mods/` folder, and do not nest a second parent folder between `item_randomizer/` and `manifest.json`.

## Compatibility

This mod changes item placement data at runtime. It is independent of Gym Leader Shuffle and Starter Picker and may be enabled alongside them.

## Verification status

The manifest has been checked as valid JSON, `main.lua` has passed offline Lua syntax validation, and an isolated harness verifies key/HM exclusion, protected PC reroll persistence, permanent withdrawal locking, and mapping projection. It has not been run against a player-imported game in this environment.
