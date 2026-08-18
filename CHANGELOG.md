# Changelog

## 1.0.10 — Release metadata and clean package maintenance

Item Randomizer now declares its tested **Gen1Recomp API 2** compatibility floor (`>=0.1.99`) in the manifest, allowing the launcher and mod indexes to evaluate the release before installation.

The distributed ZIP has been rebuilt as a clean player package. It retains the mod, manifest, credits, and player documentation while excluding local regression harnesses and packaging metadata. No item pools, source toggles, PC rerolls, weighted progression, shops, berries, held items, gifts, or Crystal 251 behavior has changed.

The 1.0.10 source and final install archive pass current Gen1Recomp 0.2.3 validation, linting, Gen 2 compatibility checks, and the saved Gen 1 and Gold regression harnesses.
