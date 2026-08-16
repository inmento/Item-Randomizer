local callbacks, store = { events = {}, hooks = {} }, {}
package.preload["src.core.GameVersion"] = function()
  return { get = function() return "gold" end }
end

local options = {
  gold_less_junk = true,
  gold_ball_items = true,
  gold_finder_items = true,
  gold_berry_trees = true,
  gold_gift_items = true,
  gold_held_items = true,
  gold_pc_item = true,
  pc_start_choice = "RANDOM",
  gold_reroll_pc = false,
}

love = { math = { random = function(n) return n end } }

local items = {
  POTION = { index = 18, pocket = "ITEM", canToss = true },
  BERRY = { index = 173, pocket = "ITEM", canToss = true },
  BERRY_JUICE = { index = 139, pocket = "ITEM", canToss = true },
  GREAT_BALL = { index = 2, pocket = "ITEM", canToss = true },
  BICYCLE = { index = 7, pocket = "KEY_ITEM", canToss = false },
  HM_01 = { index = 250, pocket = "TM_HM", canToss = false,
    machine = { kind = "HM" } },
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
local game = { data = { gen2Maps = maps, items = items }, save = save }
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
assert(#callbacks.schema == 9, "current Gold option schema was not registered")
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
assert(party[1].item and party[1].item ~= "BICYCLE" and party[1].item ~= "HM_01",
  "Gold held item was not randomized from safe held candidates")

print("gold item randomizer safety, berry, gift, held-item, and PC harness: valid")
