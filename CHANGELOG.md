# Changelog

## 1.0.7 — Route 1 Story Gift

The Gen 1 Item Randomizer now includes the early Route 1 Potion-sample reward in **RANDOMIZE STORY ITEM GIFTS**. The source is the one-time `TEXT_ROUTE1_YOUNGSTER1` reward guarded by `EVENT_GOT_POTION_SAMPLE`, not an overworld ball or Itemfinder pickup, so it was previously outside the randomizer’s source catalog.

The replacement is generated once per save through the existing progression-weighted safe-item system. Key items, HMs, and other unsafe progression records remain excluded, while the early-game weighting still allows a small chance of a stronger reward. Turning the new option off leaves the native Potion gift unchanged. Gen 2 behavior is unchanged.

## 1.0.6 — Gen 1 Reroll Event Restoration

This patch restores the direct PC-reroll event sequence from the first confirmed working implementation. Later builds attempted to clear the option and close the mod menu from inside the same synchronous option-change event. That extra manager-state mutation was not part of the proven action path and could prevent the reroll from completing in the live menu.

The Gen 1 action now performs only the safe PC replacement during its option-change event. After each reroll, turn the toggle back Off and then On again for another reroll. The fresh-PC seeding repair from 1.0.5, safe-item filtering, and withdrawal lock remain in place.

## 1.0.5 — Gen 1 PC Seeding Hotfix

This patch fixes the remaining Gen 1 PC reroll failure. The previous build could receive a fresh-save lifecycle event while its live game reference still pointed at an earlier runtime, leaving the native PC Potion in place even though the mapping existed. The reroll correctly refused to replace a PC that did not contain its generated item, which made the toggle appear nonfunctional.

The new build seeds the generated PC item through the explicit fresh-save payload, repairs only untouched empty/native-Potion PCs from affected saves, and leaves established PC storage alone. The reroll action still resets itself to OFF and remains permanently locked only after the generated item has truly been removed from the PC.

## 1.0.4 — Gen 1 Reroll Hotfix and Gen 2 Stability

Gen 1 **REROLL NEW GAME PC ITEM** now reliably performs its one-shot action: it changes the still-stored generated PC item, writes the toggle back to OFF, and returns from Mods and the Start menu to the overworld. The reroll is no longer permanently disabled by an unrelated fade or screen close before the fresh PC item has been initialized. A permanent lock is recorded only when a player deliberately attempts a reroll after the initialized generated contents have left the PC.

Item Randomizer now reads the engine’s active `GameVersion.get()` value to choose its Gen 1 or Gold branch before registering generation-specific options and behavior. Gen 1 retains the protected random PC reroll without showing the Gold-only manual PC selector; Gold retains its dedicated PC selection and reroll options.

## 1.0.3 — Gen 1 PC Reroll Action Fix

Gen 1 no longer treats every screen close, fade, or ordinary menu transition as proof that the generated PC item was withdrawn. This prevents fresh saves from being permanently locked before their PC item has been initialized.

**REROLL NEW GAME PC ITEM** remains visible in Gen 1 and is now a complete one-shot action: turn it ON to reroll the generated PC item, reset the option to OFF immediately, and return from **Mods** and the Gen 1 Start menu to the overworld. The permanent lock is now recorded only if the player deliberately tries to reroll after the initialized generated PC contents are no longer present.

The manual **GOLD PC ITEM** selector remains Gold-only and does not appear in the Gen 1 options list.

## 1.0.2 — Gen 1 PC Refresh and Reroll Fix

Gen 1 now retries the New Game PC placement only when the PC still has its untouched native Potion or is empty. This corrects a missed fresh-save placement without replacing the contents of an established PC.

The Gen 1 PC reroll toggle now starts OFF, performs a one-shot reroll when enabled, immediately returns to OFF, and permanently locks after the generated contents are withdrawn. The manual PC-item selector is no longer included in the Gen 1 schema.

The manual **GOLD PC ITEM** selector is available only in Gold, where it offers a random one-item result, five Great Balls, Rare Candies, Potions, Antidotes, Escape Ropes, a basic five-item mix, or no item. Gold’s existing random PC behavior remains the default.

## 1.0.1 — Gold PC Item Fix

Gold now receives a generated starting PC item when **GOLD START PC** is enabled. Gold’s native New Game PC begins empty, so the mod now seeds its saved safe item through Gold’s new-save event rather than relying on the Gen 1-style New Game hook.

The generated PC item can be rerolled with **GOLD REROLL PC** while it remains in the PC. Once that item is withdrawn, rerolls permanently lock for the save as intended.

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
