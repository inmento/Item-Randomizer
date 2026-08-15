# Item Randomizer

> **AI assisted; not AI created.**

Item Randomizer creates a persistent per-save item mapping for Gen 1 and Gold. It supports independent source categories, progression-conscious item weighting, and safeguards that keep key items, HMs, non-tossable items, and other progression-sensitive rewards outside ordinary item pools.

## Install

Import the `item_randomizer-1.0.2.zip` release archive through Gen 1 Recomp’s **Import mod .zip** action. The archive extracts directly to an `item_randomizer/` folder containing `manifest.json` and `main.lua`.

## Features

Visible item balls, hidden Itemfinder rewards, and the optional New Game PC item can be enabled independently. Once a save receives its mapping, that mapping remains stable across map changes, saves, and reloads.

**Reduced Low-Value Items** lowers the weight of common low-impact rewards. **Progression-Weighted Loot** favors modest useful items early and stronger rewards later, while always retaining a small chance of premium results. The generator is weighted rather than locked, so surprising early rewards remain possible.

In **Gen 1**, the New Game PC feature replaces only the generated starting PC item. If a fresh save still has its untouched native Potion or an empty PC after startup, the mod retries that placement without changing an established PC. **NEW GAME PC ITEM** can choose five Great Balls, Rare Candies, Potions, Antidotes, Escape Ropes, or a five-item basic mix; it also supports an intentional **NO ITEM** result. **RANDOM (1 ITEM)** preserves the original randomized starting-item behavior. The random reroll affects only that generated result and permanently locks after the generated contents are withdrawn, preventing storage from becoming a repeatable item-generation loop.

## Gold

Gold adds native support for visible item balls, hidden item records, berry trees, eligible ordinary scripted gifts, eligible existing held items, and the protected New Game PC reroll.

Berry-tree handling preserves apricorn trees. Held-item handling affects only Pokémon that originally held an item; it does not assign an item to an itemless Pokémon. Scripted gifts use the same safe item rules as other enabled sources.

## Compatibility

Item Randomizer targets Mod API 2 and supports Gen 1 and Gold. It can be used alongside Gym Leader Shuffle and Starter Picker. See [CHANGELOG.md](CHANGELOG.md) for the complete release feature list and safety rules.

## Credits

Thanks to [Wes Kestis](https://github.com/weskestis), creator of the [RBY Randomizer — Kanto Ascendent Compatible](https://github.com/weskestis/RBY-Randomizer-Kanto-Ascendent-Compatible), for granting permission to review the Randomizer and build compatible behavior.
