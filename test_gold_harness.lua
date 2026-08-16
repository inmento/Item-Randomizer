local callbacks, store = { events = {}, hooks = {} }, {}
package.preload["src.core.GameVersion"] = function()
  return { get = function() return "gold" end }
end
package.preload["src.render.TextBox"] = function()
  return { new = function(_, text) return { text=text } end }
end

local options = {
  gold_less_junk = true,
  gold_ball_items = true,
  gold_finder_items = true,
  gold_berry_trees = true,
  gold_gift_items = true,
  gold_held_items = true,
  gold_held_item_mode = "SAFE_ANY",
  gold_shop_items = true,
  gold_pc_item = true,
  pc_start_choice = "RANDOM",
  gold_reroll_pc = false,
  gold_shop_preview = false,
  gold_pc_status = false,
}

love = { math = { random = function(n) return n end } }

local items = {
  POKE_BALL = { index = 4, price = 200, pocket = "ITEM", canToss = true },
  POTION = { index = 18, price = 300, pocket = "ITEM", canToss = true },
  BERRY = { index = 173, price = 20, pocket = "ITEM", canToss = true, heldEffect="HELD_BERRY" },
  BERRY_JUICE = { index = 139, price = 100, pocket = "ITEM", canToss = true, heldEffect="HELD_RECOVER" },
  GREAT_BALL = { index = 2, price = 600, pocket = "ITEM", canToss = true },
  SUPER_POTION = { index = 17, price = 700, pocket = "ITEM", canToss = true },
  RARE_CANDY = { index = 20, price = 4800, pocket = "ITEM", canToss = true },
  BICYCLE = { index = 7, pocket = "KEY_ITEM", canToss = false },
  HM_01 = { index = 250, pocket = "TM_HM", canToss = false,
    machine = { kind = "HM" } },
  FLOWER_MAIL = { index = 201, price = 50, pocket = "ITEM", canToss = true, isMail = true },
}

local maps = {
  ROUTE_29 = {
    objects = {
      { index = 1, itemball = { item = 18 } },
      { index = 2, itemball = { item = 7 } },
    },
    bgEvents = { { hiddenItem = { item = 18 } } },
  },
}

local save = { pcItems = {}, inventory = {} }
local marts = { lists = { { "POTION", "ANTIDOTE" } } }
local openedText
local game = {
  data = { gen2Maps = maps, items = items, gen2Marts = marts }, save = save,
  stack = { push = function(_, box) openedText = box and box.text end },
}
local mod = {
  id = "item_randomizer",
  game = game,
  options = {
    define = function(_, schema) callbacks.schema = schema end,
    get = function(_, key) return options[key] end,
  },
  save = {
    get = function(_, key) return store[key] end,
    set = function(_, key, value) store[key] = value end,
  },
  hooks = { wrap = function(_, name, fn) callbacks.hooks[name] = fn end },
  events = { on = function(_, name, fn) callbacks.events[name] = fn end },
  log = { info = function() end, warn = function() end },
}

assert(loadfile("main.lua"))()(mod)
assert(#callbacks.schema == 13, "Gold held-item policy and diagnostic options were not registered")
callbacks.hooks["save.new_game"](function(value) return value end, save)
callbacks.events["game.ready"]({ game = game })

local mapping = assert(store.gold_item_mapping, "Gold mapping was not stored")
assert(mapping.version == 1 and mapping.placements, "current Gold mapping schema is invalid")
assert(type(maps.ROUTE_29.objects[1].itemball.item) == "number",
  "Gold visible item was not projected as a numeric item index")
assert(maps.ROUTE_29.objects[2].itemball.item == 7,
  "Gold key-item source changed")
assert(type(maps.ROUTE_29.bgEvents[1].hiddenItem.item) == "number",
  "Gold hidden item was not projected as a numeric item index")
assert(next(save.pcItems) ~= nil, "Gold New Game PC item was not initialized")

callbacks.hooks["script.command"](function(_, _, _, finalCmd)
  return finalCmd
end, { scriptKey = "CHERRYGROVE_MART" }, "pokemart", { 0, 0, 0 },
  { martType = 0, mart = 0 })
local shop = marts.lists[1]
local shopState = mapping.shops and mapping.shops["standard:0"]
assert(shopState and #shopState.stock == #shop and shop[1] == shopState.stock[1],
  "Gold shop mapping was not persisted and projected")
for _, itemId in ipairs(shop) do
  assert(itemId ~= "BICYCLE" and itemId ~= "HM_01" and itemId ~= "FLOWER_MAIL", "Gold shop contained an unsafe item")
  assert(items[itemId] and items[itemId].price >= 1, "Gold shop price was not applied")
end
local firstStock = shop[1]
callbacks.hooks["script.command"](function(_, _, _, finalCmd)
  return finalCmd
end, { scriptKey = "CHERRYGROVE_MART" }, "pokemart", { 0, 0, 0 },
  { martType = 0, mart = 0 })
assert(marts.lists[1][1] == firstStock, "Gold shop inventory was rerolled on revisit")
callbacks.events["mod.options_changed"]({ mod="item_randomizer", key="gold_shop_preview", value=true })
assert(openedText and openedText:find("SHOP standard:0", 1, true),
  "Gold shop preview did not expose the saved shop mapping")
callbacks.events["mod.options_changed"]({ mod="item_randomizer", key="gold_pc_status", value=true })
assert(openedText and openedText:find("PC REROLL READY", 1, true),
  "Gold PC diagnostic did not report the initialized generated item")
callbacks.events["script.ended"]({ ctx = { game = game } })
assert(items.POTION.price == 300, "Gold shared item price was not restored after the mart closed")

local berryCommand
callbacks.hooks["script.command"](function(_, _, args, cmd)
  berryCommand = cmd
  return cmd
end, { scriptKey = "ROUTE_29:berry" }, "fruittree", { 1 }, { args = { 1 } })
assert(berryCommand and type(berryCommand.args[1]) == "number",
  "Gold berry-tree command was not rewritten")
assert(berryCommand.args[1] ~= 17 and berryCommand.args[1] ~= 18
  and berryCommand.args[1] ~= 19,
  "Gold berry tree was redirected to an apricorn tree")

local giftCommand
callbacks.hooks["script.command"](function(_, _, args, cmd)
  giftCommand = cmd
  return cmd
end, { scriptKey = "ELM_LAB:gift" }, "giveitem", { 18 }, { item = 18 })
assert(giftCommand and type(giftCommand.item) == "number" and giftCommand.item ~= 7,
  "Gold scripted gift was not randomized to a safe item index")

local party = callbacks.hooks["trainer.party"](function(_, _, base) return base end,
  "FALKNER", 1, { { species = "PIDGEY", level = 7, item = "BERRY" } })
assert(party[1].item and party[1].item ~= "BICYCLE" and party[1].item ~= "HM_01"
  and items[party[1].item].heldEffect,
  "Gold held item was not randomized from safe effective held candidates")
options.gold_held_item_mode = "NONE"
local noItemParty = callbacks.hooks["trainer.party"](function(_, _, base) return base end,
  "BUGSY", 1, { { species = "SCYTHER", level = 14, item = "BERRY" } })
assert(noItemParty[1].item == nil, "Gold no-held-item mode did not remove the randomized held item")

print("gold item randomizer safety, berry, gift, held-item, and PC harness: valid")
