local callbacks = { events = {}, hooks = {} }
package.preload["src.core.GameVersion"] = function()
  return { get = function() return "red" end }
end
local store = {}
local optionValues = {
  lesser_bad_items = true,
  progression_weighted_loot = true,
  overworld_items = true,
  itemfinder_items = true,
  starting_pc_item = true,
  reroll_pc_item = false,
}

-- Deterministic highest-ticket selection: the test checks safety and state
-- transitions rather than probability distribution.
love = { math = { random = function(n) return n end } }

local maps = {
  VIRIDIAN_FOREST = {
    objects = {
      { index = 1, item = "POTION" },
      { index = 2, item = "BICYCLE" },
      { index = 3, item = "HM_01" },
    },
  },
}
local hiddenItems = {
  VIRIDIAN_FOREST = { { x = 2, y = 3, item = "ANTIDOTE" } },
}
local itemRecords = {
  POTION = { price = 300, tossable = true },
  ANTIDOTE = { price = 100, tossable = true },
  SUPER_POTION = { price = 700, tossable = true },
  RARE_CANDY = { price = 4800, tossable = true },
  BICYCLE = { keyItem = true, tossable = false },
  HM_01 = { machine = { kind = "HM", number = 1 }, tossable = false },
}

local mod = {
  id = "item_randomizer",
  content = {
    maps = { each = function() return pairs(maps) end },
    field = { get = function(_, key) if key == "hiddenItems" then return hiddenItems end end },
    items = { each = function() return pairs(itemRecords) end },
  },
  options = {
    define = function(_, schema) callbacks.schema = schema end,
    get = function(_, key) return optionValues[key] end,
  },
  save = {
    get = function(_, key) return store[key] end,
    set = function(_, key, value) store[key] = value end,
  },
  hooks = { wrap = function(_, name, fn) callbacks.hooks[name] = fn end },
  events = { on = function(_, name, fn) callbacks.events[name] = fn end },
  log = { info = function() end, warn = function() end },
}

local entry = assert(loadfile("/home/ubuntu/item_randomizer/main.lua"))
entry()(mod)
assert(#callbacks.schema == 6, "six safe-weighted randomizer options were not defined")

local save = { pcItems = { POTION = 1 }, modData = {}, inventory = {} }
callbacks.hooks["save.new_game"](function(s) return s end, save)
local game = { save = save, data = { maps = maps, field = { hiddenItems = hiddenItems } } }
mod.game = game
callbacks.events["game.ready"]({ game = game })

local mapping = store.item_mapping
assert(mapping and mapping.version == 3 and mapping.placements, "v3 mapping was not stored")
for _, itemId in pairs(mapping.placements) do
  assert(itemId ~= "BICYCLE" and itemId ~= "HM_01", "unsafe key/HM item entered a generated placement")
end
assert(maps.VIRIDIAN_FOREST.objects[2].item == "BICYCLE", "key-item source was changed")
assert(maps.VIRIDIAN_FOREST.objects[3].item == "HM_01", "HM source was changed")
assert(next(save.pcItems) ~= nil, "New Game PC item was not initialized")

local oldPcItem = mapping.placements["pc:new_game"]
-- The mod API resolves mod.game lazily. A transient nil during the options
-- transition must not prevent the reroll from using the last game.ready save.
mod.game = nil
callbacks.events["mod.options_changed"]({
  mod = "item_randomizer", key = "reroll_pc_item", value = true,
})
mapping = store.item_mapping
local newPcItem = mapping.placements["pc:new_game"]
assert(mapping.pcRerolls == 1, "PC reroll count was not saved")
assert(newPcItem ~= oldPcItem, "PC reroll returned the same item and appeared to do nothing")
assert(save.pcItems[newPcItem] == 1, "PC reroll did not replace the generated starting item")
assert(newPcItem ~= "BICYCLE" and newPcItem ~= "HM_01", "PC reroll produced an unsafe item")

-- An ordinary screen close is not a withdrawal. The patch deliberately does
-- not subscribe a broad screen-close lock handler at all.
assert(callbacks.events["screen.popped"] == nil,
  "an unrelated screen-close handler can lock the PC reroll")
mapping = store.item_mapping
assert(mapping.pcRerollLocked ~= true, "the PC reroll was locked before withdrawal")

-- Withdrawing the generated item locks rerolls only when a reroll is attempted.
save.pcItems[newPcItem] = nil
callbacks.events["mod.options_changed"]({
  mod = "item_randomizer", key = "reroll_pc_item", value = true,
})
mapping = store.item_mapping
assert(mapping.pcRerollLocked == true, "an unavailable reroll after withdrawal did not permanently lock")

-- Depositing the item back later cannot reopen the feature.
save.pcItems[newPcItem] = 1
callbacks.events["mod.options_changed"]({
  mod = "item_randomizer", key = "reroll_pc_item", value = true,
})
assert(mapping.pcRerolls == 1, "permanently locked PC reroll was re-enabled")
assert(save.pcItems[newPcItem] == 1, "locked PC reroll modified the re-deposited item")

print("item randomizer safety, weighting, and permanent PC reroll lock harness: valid")
