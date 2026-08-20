local callbacks = { events = {}, hooks = {} }

package.preload["src.core.GameVersion"] = function()
  return {
    get = function() return "silver" end,
    generation = function(id)
      assert(id == "silver", "Item Randomizer must classify the active Silver version")
      return 2
    end,
  }
end
package.preload["src.render.TextBox"] = function()
  return { new = function(_, text) return { text = text } end }
end

local options = {
  gold_less_junk = true,
  gold_ball_items = false,
  gold_finder_items = false,
  gold_berry_trees = false,
  gold_gift_items = false,
  gold_held_items = false,
  gold_held_item_mode = "SAFE_ANY",
  gold_shop_items = false,
  gold_pc_item = false,
  pc_start_choice = "RANDOM",
  gold_reroll_pc = false,
  gold_shop_preview = false,
  gold_pc_status = false,
}
local game = {
  data = { gen2Maps = {}, items = {}, gen2Marts = { lists = {} } },
  save = { pcItems = {}, inventory = {} },
  stack = { push = function() end },
}
local mod = {
  id = "item_randomizer",
  game = game,
  options = {
    define = function(_, schema) callbacks.schema = schema end,
    get = function(_, key) return options[key] end,
  },
  save = { get = function() return nil end, set = function() end },
  hooks = { wrap = function(_, name, fn) callbacks.hooks[name] = fn end },
  events = { on = function(_, name, fn) callbacks.events[name] = fn end },
  log = { info = function() end, warn = function() end },
}

assert(loadfile("main.lua"))()(mod)
assert(callbacks.schema[1].key == "gold_less_junk"
  and callbacks.schema[8].key == "gold_shop_items",
  "Silver must register the Gen 2 item-randomization option set")
assert(callbacks.hooks["script.command"], "Silver must register the Gen 2 script command hook")
assert(callbacks.hooks["trainer.party"], "Silver must register the Gen 2 held-item hook")
assert(callbacks.events["game.ready"], "Silver must register the Gen 2 projection lifecycle hook")

print("Silver Item Randomizer routing harness: valid")
