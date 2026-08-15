# Item Randomizer

> **AI assisted; not AI created.**

Item Randomizer creates a persistent per-save item mapping for Gen 1 and Gold. It supports independent source categories, progression-conscious item weighting, and safeguards that keep key items, HMs, non-tossable items, and other progression-sensitive rewards outside ordinary item pools.

## Install

Import the `item_randomizer-1.0.1.zip` release archive through Gen 1 Recomp’s **Import mod .zip** action. The archive extracts directly to an `item_randomizer/` folder containing `manifest.json` and `main.lua`.

## Features

Visible item balls, hidden Itemfinder rewards, and the optional New Game PC item can be enabled independently. Once a save receives its mapping, that mapping remains stable across map changes, saves, and reloads.

**Reduced Low-Value Items** lowers the weight of common low-impact rewards. **Progression-Weighted Loot** favors modest useful items early and stronger rewards later, while always retaining a small chance of premium results. The generator is weighted rather than locked, so surprising early rewards remain possible.

The New Game PC feature replaces only the generated starting PC item. Its reroll action affects only that generated result and permanently locks after the item is withdrawn, preventing storage from becoming a repeatable item-generation loop.

## Gold

Gold adds native support for visible item balls, hidden item records, berry trees, eligible ordinary scripted gifts, eligible existing held items, and the protected New Game PC reroll.

Berry-tree handling preserves apricorn trees. Held-item handling affects only Pokémon that originally held an item; it does not assign an item to an itemless Pokémon. Scripted gifts use the same safe item rules as other enabled sources.

## Compatibility

Item Randomizer targets Mod API 2 and supports Gen 1 and Gold. It can be used alongside Gym Leader Shuffle and Starter Picker. See [CHANGELOG.md](CHANGELOG.md) for the complete release feature list and safety rules.
