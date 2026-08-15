local callbacks, store = { events = {}, hooks = {} }, {}
local optionValues = {
  lesser_bad_items = true, progression_weighted_loot = true,
  overworld_items = true, itemfinder_items = true, starting_pc_item = true,
  reroll_pc_item = false, randomize_held_items = true, randomize_overworld_berries = true,
}
love = { math = { random = function(n) return n end } }

local itemRecords = {
  POTION = { index = 18, price = 300, canToss = true, heldEffect = "HELD_NONE" },
  BERRY = { index = 173, price = 10, canToss = true, heldEffect = "HELD_BERRY" },
  BERRY_JUICE = { index = 139, price = 100, canToss = true, heldEffect = "HELD_BERRY" },
  BICYCLE = { index = 7, pocket = "KEY_ITEM", canToss = false, heldEffect = "HELD_NONE" },
  HM01 = { index = 250, pocket = "TM_HM", canToss = true, heldEffect = "HELD_NONE" },
}
local maps = {
  ROUTE_29 = { objects = { { index = 1, item = 18 }, { index = 2, item = 7 } } },
}
local mod = {
  id = "item_randomizer",
  game = { data = { gen2Maps = maps, items = itemRecords }, save = { pcItems = { POTION = 1 }, inventory = {} } },
  content = {
    maps = { each = function() return pairs(maps) end },
    items = { each = function() return pairs(itemRecords) end },
  },
  options = { define = function(_, schema) callbacks.schema = schema end, get = function(_, key) return optionValues[key] end },
  save = { get = function(_, key) return store[key] end, set = function(_, key, value) store[key] = value end },
  hooks = { wrap = function(_, name, fn) callbacks.hooks[name] = fn end },
  events = { on = function(_, name, fn) callbacks.events[name] = fn end },
  log = { info = function() end, warn = function() end },
}

assert(loadfile("/home/ubuntu/item_randomizer/main.lua"))()(mod)
assert(#callbacks.schema == 8, "Gold item options missing")
callbacks.hooks["save.new_game"](function(save) return save end, mod.game.save)
callbacks.events["game.ready"]({ game = mod.game })
local mapping = assert(store.item_mapping, "Gold mapping missing")
assert(mapping.version == 4, "Gold mapping schema is not v4")
assert(type(maps.ROUTE_29.objects[1].item) == "number", "Gold visible item was not stored as a numeric item index")
assert(maps.ROUTE_29.objects[2].item == 7, "Gold key item source changed")

local original = { tree = 1 }
local rewritten
callbacks.hooks["script.command"](function(_, _, _, cmd) rewritten = cmd; return cmd end,
  { generation = 2, mapId = "ROUTE_29" }, "fruittree", { 1 }, original)
assert(rewritten and type(rewritten.tree) == "number", "Gold berry tree command was not rewritten")
assert(rewritten.tree ~= 17 and rewritten.tree ~= 18 and rewritten.tree ~= 19,
  "Gold berry tree was redirected to an apricorn tree")

local party = callbacks.hooks["trainer.party"](function(_, _, base) return base end,
  "FALKNER", "FALKNER1", { { species = "PIDGEY", level = 7, item = "BERRY" } })
assert(party[1].item == "BERRY" or party[1].item == "BERRY_JUICE", "Gold held item was not randomized from safe held candidates")
print("gold item randomizer harness: valid")
