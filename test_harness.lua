local callbacks = { events = {}, hooks = {} }
package.preload["src.core.GameVersion"] = function()
  return {
    get = function() return "red" end,
    generation = function(id) return (id == "gold" or id == "silver") and 2 or 1 end,
  }
end
package.preload["src.render.TextBox"] = function()
  return { new = function(_, _, _, done) return { done = done } end }
end
package.preload["src.inventory.Bag"] = function()
  return { add = function(save, item, quantity)
    save.inventory[item] = (save.inventory[item] or 0) + quantity
    return true
  end }
end
local store = {}
local optionValues = {
  lesser_bad_items = true,
  progression_weighted_loot = true,
  overworld_items = true,
  itemfinder_items = true,
  starting_pc_item = true,
  gift_items = true,
  reroll_pc_item = false,
  randomize_shops = true,
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
  POKE_BALL = { price = 200, tossable = true },
  POTION = { price = 300, tossable = true },
  ANTIDOTE = { price = 100, tossable = true },
  SUPER_POTION = { price = 700, tossable = true },
  RARE_CANDY = { price = 4800, tossable = true },
  BICYCLE = { keyItem = true, tossable = false },
  HM_01 = { machine = { kind = "HM", number = 1 }, tossable = false },
  FLOWER_MAIL = { price = 50, tossable = true, isMail = true },
  KINGS_ROCK = { price = 100, tossable = true },
  WONDER_GUARD = { price = 0, tossable = false },
}

local mod = {
  id = "item_randomizer",
  find = function(_, id)
    if id == "CRYSTAL_251" then return { exports={ dexSize=251 } } end
  end,
  content = {
    maps = { each = function() return pairs(maps) end },
    field = { get = function(_, key) if key == "hiddenItems" then return hiddenItems end end },
    items = { each = function() return pairs(itemRecords) end },
    map_scripts = {
      register = function(_, mapId, contribution)
        callbacks.mapScripts = callbacks.mapScripts or {}
        callbacks.mapScripts[mapId] = contribution
      end,
    },
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

local entry = assert(loadfile("main.lua"))
entry()(mod)
assert(#callbacks.schema == 10, "preview and PC diagnostic options were not defined")
assert(callbacks.mapScripts.ROUTE_1
  and callbacks.mapScripts.ROUTE_1.talk.TEXT_ROUTE1_YOUNGSTER1,
  "Route 1 Potion gift was not registered")

itemRecords.POTION.name = "Potion"
itemRecords.ANTIDOTE.name = "Antidote"
itemRecords.SUPER_POTION.name = "Super Potion"
itemRecords.RARE_CANDY.name = "Rare Candy"
local save = {
  pcItems = { POTION = 1 }, modData = {}, inventory = {}, flags = {},
  player = { name = "RED" },
}
callbacks.hooks["save.new_game"](function(s) return s end, save)
local textPointers = {
  VIRIDIAN_MART = { TEXT_VIRIDIANMART_CLERK = { mart = { "POTION", "ANTIDOTE" } } },
  PEWTER_MART = { TEXT_PEWTERMART_CLERK = { mart = { "POTION", "SUPER_POTION" } } },
}
local game = {
  save = save, data = {
    maps = maps, field = { hiddenItems = hiddenItems }, items = itemRecords,
    text = {}, text_pointers = textPointers,
  }, stack = { push = function() end },
}
mod.game = game
callbacks.events["game.ready"]({ game = game })

local mapping = store.item_mapping
assert(mapping and mapping.version == 3 and mapping.placements, "v3 mapping was not stored")
for _, itemId in pairs(mapping.placements) do
  assert(itemId ~= "BICYCLE" and itemId ~= "HM_01" and itemId ~= "FLOWER_MAIL"
    and itemId ~= "KINGS_ROCK" and itemId ~= "WONDER_GUARD",
    "unsafe Crystal/key/HM/Wonder Guard item entered a generated placement")
end
assert(maps.VIRIDIAN_FOREST.objects[2].item == "BICYCLE", "key-item source was changed")
assert(maps.VIRIDIAN_FOREST.objects[3].item == "HM_01", "HM source was changed")
assert(next(save.pcItems) ~= nil, "New Game PC item was not initialized")

-- Read-only diagnostics must not regenerate field or shop mappings.
callbacks.events["mod.options_changed"]({ mod="item_randomizer", key="pc_reroll_status", value=true })
callbacks.events["mod.options_changed"]({ mod="item_randomizer", key="shop_preview", value=true })

save.money = 500
callbacks.events["map.entered"]({ game = game, mapId = "VIRIDIAN_MART" })
local firstShop = textPointers.VIRIDIAN_MART.TEXT_VIRIDIANMART_CLERK.mart
local firstShopPrice = itemRecords.POKE_BALL.price
assert(firstShop[1] == "POKE_BALL", "first Gen 1 shop did not stock Poké Balls first")
assert(firstShopPrice >= 0 and firstShopPrice <= 500, "first-shop Poké Ball price was not affordable")
local storedFirstShop = store.item_mapping.shops.gen1["VIRIDIAN_MART:TEXT_VIRIDIANMART_CLERK"]
assert(storedFirstShop and storedFirstShop.stock[1] == "POKE_BALL", "first shop mapping was not saved")
save.money = 200
callbacks.events["map.entered"]({ game = game, mapId = "VIRIDIAN_MART" })
assert(firstShop[1] == "POKE_BALL" and firstShop[2] == storedFirstShop.stock[2],
  "first-shop stock changed after it was generated")
assert(itemRecords.POKE_BALL.price >= 0 and itemRecords.POKE_BALL.price <= 200,
  "first-shop Poké Ball did not refresh to the current affordable amount")
callbacks.events["map.entered"]({ game = game, mapId = "PEWTER_MART" })
local pewterFirst = textPointers.PEWTER_MART.TEXT_PEWTERMART_CLERK.mart[1]
callbacks.events["map.entered"]({ game = game, mapId = "PEWTER_MART" })
assert(textPointers.PEWTER_MART.TEXT_PEWTERMART_CLERK.mart[1] == pewterFirst,
  "ordinary Gen 1 shop inventory was rerolled on revisit")

local giftDone = false
callbacks.mapScripts.ROUTE_1.talk.TEXT_ROUTE1_YOUNGSTER1(
  game, {}, {}, function() giftDone = true end)
local giftMapping = store.item_mapping
local giftItem = giftMapping.gifts and giftMapping.gifts["gift:route_1:potion_sample"]
assert(giftItem == "RARE_CANDY" or giftItem == "SUPER_POTION" or giftItem == "POTION"
  or giftItem == "ANTIDOTE", "Route 1 reward was not assigned a safe weighted item")
assert(save.inventory[giftItem] == 1, "Route 1 reward was not added to the bag")
assert(save.flags.EVENT_GOT_POTION_SAMPLE == true, "Route 1 reward flag was not set")

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
