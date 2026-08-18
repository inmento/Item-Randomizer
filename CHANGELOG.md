# Changelog

## 1.0.11 — Merged live-item compatibility

Item Randomizer now refreshes its safe item and source views whenever the game is ready, using the active **merged content registry** rather than refreshing only for a single named provider. This lets it recognize safe items and item sources supplied by compatible installed content mods while continuing to preserve their authored records.

The existing safety rules remain in force: key items, HMs, mail, machines, non-tossable items, and known Crystal 251 progression items remain outside generated pools. An explicit cross-mod regression check confirms that Gen 1 Shedinja’s non-tossable `WONDER GUARD` token cannot enter randomized pickups, shops, gifts, or PC rolls.

All existing item-pool toggles, PC rerolls and withdrawal lock behavior, weighted progression logic, shops, berries, held items, gifts, and Gold behavior remain unchanged.
