# Changelog

## 1.0.7 — Route 1 Story Gift

This release adds the Gen 1 Route 1 Potion-sample reward to **RANDOMIZE STORY ITEM GIFTS**. The one-time `TEXT_ROUTE1_YOUNGSTER1` reward guarded by `EVENT_GOT_POTION_SAMPLE` is now assigned through the existing persistent, progression-weighted safe-item mapping rather than remaining outside the source catalog.

Key items, HMs, and other progression-sensitive records remain excluded. Disabling the option keeps the native Potion reward unchanged. The change is intentionally Gen 1-only: Gold retains its separate scripted-gift, berry-tree, trainer-held-item, and PC-item controls.
