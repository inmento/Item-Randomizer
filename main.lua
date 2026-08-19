-- Item Randomizer
-- Gen 1 Recomp mod API 2
--
-- Randomizes safe visible item balls, hidden Itemfinder pickups, and the New
-- Game PC item. Story-critical key items and HMs remain at their vanilla
-- locations. Weighted mode favors modest rewards early and stronger rewards
-- later, while always retaining a small chance of an early lucky find.

return function(mod)
  -- The selected game version is established before mods load. Use the engine's
  -- version source of truth rather than inferring a generation from data shape.
  local GameVersion = require("src.core.GameVersion")
  local playing = GameVersion.get()
  local function isGen2(_)
    return playing == "gold"
  end

  -- Crystal 251 is optional. The integration path reads only the merged live
  -- registries and never makes the overhaul a dependency for ordinary runs.
  local function crystal251Active()
    if isGen2() or type(mod.find) ~= "function" then return false end
    local ok, handle = pcall(mod.find, mod, "CRYSTAL_251")
    local exports = ok and type(handle) == "table" and handle.exports or nil
    return type(exports) == "table" and tonumber(exports.dexSize) == 251
  end

  if isGen2() then
    local STATE_KEY = "gold_item_mapping"
    local VERSION = 1
    local SOURCES, SOURCE_BY_KEY = nil, nil
    local baseline, baselineCaptured = {}, false
    local mapping

    mod.options:define({
      { key = "gold_less_junk", label = "GOLD LESS JUNK", type = "toggle", default = true },
      { key = "gold_ball_items", label = "GOLD BALL ITEMS", type = "toggle", default = false },
      { key = "gold_finder_items", label = "GOLD FINDER ITEMS", type = "toggle", default = false },
      { key = "gold_berry_trees", label = "GOLD BERRY TREES", type = "toggle", default = false },
      { key = "gold_gift_items", label = "GOLD GIFT ITEMS", type = "toggle", default = false },
      { key = "gold_held_items", label = "GOLD HELD ITEMS", type = "toggle", default = false },
      { key = "gold_held_item_mode", label = "GOLD HOLD MODE", type = "choice", default = "SAFE_ANY",
        choices = {
          { "SAFE HELD ITEMS", "SAFE_ANY" },
          { "USEFUL HELD ITEMS", "USEFUL" },
          { "NO HELD ITEMS", "NONE" },
        } },
      { key = "gold_shop_items", label = "GOLD SHOPS", type = "toggle", default = false },
      { key = "gold_pc_item", label = "GOLD START PC", type = "toggle", default = false },
      { key = "pc_start_choice", label = "GOLD PC ITEM", type = "choice", default = "RANDOM",
        choices = {
          { "RANDOM (1 ITEM)", "RANDOM" },
          { "5 GREAT BALLS", "GREAT_BALL" },
          { "5 RARE CANDIES", "RARE_CANDY" },
          { "5 POTIONS", "POTION" },
          { "5 ANTIDOTES", "ANTIDOTE" },
          { "5 ESCAPE ROPES", "ESCAPE_ROPE" },
          { "5 BASIC ITEMS", "BASIC" },
          { "NO ITEM", "NONE" },
        } },
      { key = "gold_reroll_pc", label = "GOLD REROLL PC", type = "toggle", default = false },
      { key = "gold_shop_preview", label = "GOLD SHOP PREVIEW", type = "toggle", default = false },
      { key = "gold_pc_status", label = "GOLD PC STATUS", type = "toggle", default = false },
    })

    local function mapsOf(game)
      local data = game and game.data or {}
      return data.gen2Maps or data.maps or {}
    end

    local function itemIdByIndex(game, index)
      for itemId, item in pairs(game and game.data and game.data.items or {}) do
        if type(itemId) == "string" and type(item) == "table" and item.index == index then
          return itemId
        end
      end
      return nil
    end

    local function itemIndex(game, itemId)
      local item = game and game.data and game.data.items and game.data.items[itemId]
      return type(item) == "table" and item.index or nil
    end

    local function safeItem(game, itemId)
      local item = game and game.data and game.data.items and game.data.items[itemId]
      if type(item) ~= "table" then return false end
      if item.keyItem or item.canToss == false or item.tossable == false then return false end
      if item.isMail or item.mail or item.pocket == "KEY_ITEM" then return false end
      if tostring(itemId):match("^HM_") then return false end
      if type(item.machine) == "table" and item.machine.kind == "HM" then return false end
      return item.index ~= nil
    end

    local function safeItemPool(game)
      local pool = {}
      for itemId, item in pairs(game and game.data and game.data.items or {}) do
        if safeItem(game, itemId) then
          local weight = 1
          if mod.options:get("gold_less_junk") then
            local name = tostring(itemId)
            if name:find("HEAL") or name:find("X_") or name == "POTION" or name == "REPEL" then
              weight = 0
            end
          end
          if weight > 0 then pool[#pool + 1] = itemId end
        end
      end
      table.sort(pool)
      return pool
    end

    local function randomFrom(pool)
      if #pool == 0 then return nil end
      if love and love.math and love.math.random then return pool[love.math.random(#pool)] end
      return pool[math.random(#pool)]
    end

    local GOLD_SHOP_JUNK = {
      ANTIDOTE = true, AWAKENING = true, BURN_HEAL = true, ICE_HEAL = true,
      PARLYZ_HEAL = true, POKE_DOLL = true, REPEL = true, GUARD_SPEC = true,
      X_ACCURACY = true, X_ATTACK = true, X_DEFEND = true, X_SPECIAL = true,
      X_SPEED = true, FLOWER_MAIL = true, SURF_MAIL = true,
    }
    local goldShopPriceBaseline, goldShopPricesCaptured = {}, false

    local function goldShopPool(game)
      local pool = {}
      for _, itemId in ipairs(safeItemPool(game)) do
        if not GOLD_SHOP_JUNK[itemId] then pool[#pool + 1] = itemId end
      end
      return pool
    end

    local function goldShopTier(martId)
      martId = math.max(0, math.floor(tonumber(martId) or 0))
      if martId <= 3 then return 1 end
      if martId <= 8 then return 2 end
      if martId <= 15 then return 3 end
      if martId <= 23 then return 4 end
      return 5
    end

    local function goldShopWeight(game, itemId, tier)
      local item = game and game.data and game.data.items and game.data.items[itemId] or {}
      local price = math.max(1, tonumber(item and item.price) or 1)
      local quality = price >= 5000 and 5 or price >= 2500 and 4
        or price >= 1000 and 3 or price >= 400 and 2 or 1
      local weight = ({
        { 34, 13, 4, 1, 1 }, { 25, 16, 7, 2, 1 },
        { 17, 16, 10, 4, 2 }, { 10, 14, 13, 7, 4 },
        { 6, 10, 14, 11, 8 },
      })[tier][quality] or 1
      if mod.options:get("gold_less_junk") and GOLD_SHOP_JUNK[itemId] then return 0 end
      return weight
    end

    local function weightedGoldShopItem(game, martId, pool, used)
      local total, entries = 0, {}
      local tier = goldShopTier(martId)
      for _, itemId in ipairs(pool or {}) do
        local weight = goldShopWeight(game, itemId, tier)
        if weight > 0 and not (used and used[itemId]) then
          total = total + weight
          entries[#entries + 1] = { id = itemId, limit = total }
        end
      end
      if total == 0 then return randomFrom(pool or {}) end
      local roll = love and love.math and love.math.random and love.math.random(total)
        or math.random(total)
      for _, entry in ipairs(entries) do
        if roll <= entry.limit then return entry.id end
      end
      return entries[#entries].id
    end

    local function goldMartTable(game)
      return game and game.world and game.world.marts
        or game and game.data and game.data.gen2Marts
    end

    local function goldShopMapping(game, current, martId, count)
      current.shops = current.shops or {}
      local key = "standard:" .. tostring(martId)
      local stored = current.shops[key]
      if type(stored) == "table" and type(stored.stock) == "table"
        and #stored.stock == count then return stored end
      local pool, stock, used = goldShopPool(game), {}, {}
      for index = 1, count do
        stock[index] = weightedGoldShopItem(game, martId, pool, used)
        used[stock[index]] = true
      end
      stored = { stock = stock, prices = {} }
      for index, itemId in ipairs(stock) do
        local base = math.max(1, tonumber(game.data.items[itemId] and game.data.items[itemId].price) or 1)
        local factor = 70 + (love and love.math and love.math.random and love.math.random(61) or math.random(61))
        stored.prices[index] = math.max(1, math.floor(base * factor / 100))
      end
      current.shops[key] = stored
      mod.save:set(STATE_KEY, current)
      return stored
    end

    local function restoreGoldShopPrices(game)
      if not goldShopPricesCaptured then return end
      for itemId, price in pairs(goldShopPriceBaseline) do
        local item = game and game.data and game.data.items and game.data.items[itemId]
        if item then item.price = price end
      end
      goldShopPriceBaseline, goldShopPricesCaptured = {}, false
    end

    local function applyGoldShop(game, martId)
      local marts = goldMartTable(game)
      local lists = marts and (marts.lists or marts)
      local original = lists and lists[(tonumber(martId) or 0) + 1]
      if type(original) ~= "table" or #original == 0 then return false end
      local current = mapping(game)
      local shop = goldShopMapping(game, current, martId, #original)
      local stock = {}
      for index, itemId in ipairs(shop.stock) do
        stock[index] = itemId
        local item = game.data.items[itemId]
        if item then
          if not goldShopPricesCaptured then goldShopPricesCaptured = true end
          if goldShopPriceBaseline[itemId] == nil then goldShopPriceBaseline[itemId] = item.price end
          item.price = math.max(1, math.floor(tonumber(shop.prices[index]) or item.price or 1))
        end
      end
      for index = #lists[(tonumber(martId) or 0) + 1], 1, -1 do
        lists[(tonumber(martId) or 0) + 1][index] = nil
      end
      for index, itemId in ipairs(stock) do lists[(tonumber(martId) or 0) + 1][index] = itemId end
      return true
    end

    local function buildSources(game)
      if SOURCES then return SOURCES end
      local out = {}
      for mapId, map in pairs(mapsOf(game)) do
        for arrayIndex, object in ipairs(map.objects or {}) do
          local item = object.itemball and object.itemball.item
          if itemIdByIndex(game, item) and safeItem(game, itemIdByIndex(game, item)) then
            out[#out + 1] = {
              key = "ball:" .. mapId .. ":" .. tostring(object.index or arrayIndex),
              kind = "ball", mapId = mapId, objectIndex = object.index or arrayIndex,
              original = item,
            }
          end
        end
        for eventIndex, event in ipairs(map.bgEvents or {}) do
          local item = event.hiddenItem and event.hiddenItem.item
          if itemIdByIndex(game, item) and safeItem(game, itemIdByIndex(game, item)) then
            out[#out + 1] = {
              key = "finder:" .. mapId .. ":" .. tostring(eventIndex),
              kind = "finder", mapId = mapId, eventIndex = eventIndex, original = item,
            }
          end
        end
      end
      out[#out + 1] = { key = "pc:new", kind = "pc", original = nil }
      table.sort(out, function(a, b) return a.key < b.key end)
      SOURCES, SOURCE_BY_KEY = out, {}
      for _, source in ipairs(out) do SOURCE_BY_KEY[source.key] = source end
      return out
    end

    mapping = function(game)
      buildSources(game)
      local current = mod.save:get(STATE_KEY)
      if type(current) == "table" and current.version == VERSION
        and type(current.placements) == "table" then
        -- Shop state was added after the original Gold mapping schema. Add it
        -- lazily so established field, berry, gift, held-item, and PC results
        -- remain untouched on existing saves.
        if type(current.shops) ~= "table" then
          current.shops = {}
          mod.save:set(STATE_KEY, current)
        end
        return current
      end
      local pool = safeItemPool(game)
      current = { version = VERSION, placements = {}, fruitTrees = {}, gifts = {}, held = {}, shops = {}, pcPlaced = false, pcLocked = false }
      for _, source in ipairs(SOURCES) do
        current.placements[source.key] = randomFrom(pool)
      end
      mod.save:set(STATE_KEY, current)
      return current
    end

    local function findBall(game, source)
      local map = mapsOf(game)[source.mapId]
      for arrayIndex, object in ipairs(map and map.objects or {}) do
        if (object.index or arrayIndex) == source.objectIndex then return object end
      end
      return nil
    end

    local function findFinder(game, source)
      local map = mapsOf(game)[source.mapId]
      return map and map.bgEvents and map.bgEvents[source.eventIndex] or nil
    end

    local function captureBaseline(game)
      if baselineCaptured then return end
      for _, source in ipairs(buildSources(game)) do
        if source.kind == "ball" then
          local object = findBall(game, source)
          baseline[source.key] = object and object.itemball and object.itemball.item
        elseif source.kind == "finder" then
          local event = findFinder(game, source)
          baseline[source.key] = event and event.hiddenItem and event.hiddenItem.item
        end
      end
      baselineCaptured = true
    end

    local function applyMapSources(game)
      local current = mapping(game)
      captureBaseline(game)
      for _, source in ipairs(SOURCES) do
        local original = baseline[source.key]
        local enabled = (source.kind == "ball" and mod.options:get("gold_ball_items"))
          or (source.kind == "finder" and mod.options:get("gold_finder_items"))
        local chosen = current.placements[source.key]
        local chosenIndex = itemIndex(game, chosen)
        if source.kind == "ball" then
          local object = findBall(game, source)
          if object and object.itemball then object.itemball.item = enabled and chosenIndex or original end
        elseif source.kind == "finder" then
          local event = findFinder(game, source)
          if event and event.hiddenItem then event.hiddenItem.item = enabled and chosenIndex or original end
        end
      end
    end

    local BERRY_TREES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 24, 25, 26, 27, 28, 29, 30 }
    local function fruitTreeFor(current, scriptKey)
      local tree = current.fruitTrees[scriptKey]
      if tree then return tree end
      tree = randomFrom(BERRY_TREES)
      current.fruitTrees[scriptKey] = tree
      mod.save:set(STATE_KEY, current)
      return tree
    end

    local function giftItemFor(game, current, key)
      local item = current.gifts[key]
      if safeItem(game, item) then return item end
      item = randomFrom(safeItemPool(game))
      current.gifts[key] = item
      mod.save:set(STATE_KEY, current)
      return item
    end

    local function heldItemFor(game, current, key)
      local mode = mod.options:get("gold_held_item_mode") or "SAFE_ANY"
      if mode == "NONE" then return nil end
      local item = current.held[key]
      local live = game and game.data and game.data.items and game.data.items[item]
      if safeItem(game, item) and live and live.heldEffect and live.heldEffect ~= "HELD_NONE" then
        return item
      end
      local pool = {}
      for _, candidate in ipairs(safeItemPool(game)) do
        local def = game and game.data and game.data.items and game.data.items[candidate]
        local useful = not GOLD_SHOP_JUNK[candidate]
          and (tonumber(def and def.price) or 0) >= 100
        if def and def.heldEffect and def.heldEffect ~= "HELD_NONE"
          and (mode ~= "USEFUL" or useful) then
          pool[#pool + 1] = candidate
        end
      end
      item = randomFrom(pool)
      if item then
        current.held[key] = item
        mod.save:set(STATE_KEY, current)
      end
      return item
    end

    local GOLD_BASIC_PC_ITEMS = { "POKE_BALL", "POTION", "ANTIDOTE", "ESCAPE_ROPE", "REPEL" }

    local function manualGoldPcBundle(game, choice)
      if choice == "NONE" then return nil, 0 end
      if choice == "BASIC" then
        local pool = {}
        for _, itemId in ipairs(GOLD_BASIC_PC_ITEMS) do
          if safeItem(game, itemId) then pool[#pool + 1] = itemId end
        end
        if #pool == 0 then return nil, nil end
        return randomFrom(pool), 5
      end
      if choice and choice ~= "RANDOM" and safeItem(game, choice) then
        return choice, 5
      end
      return nil, nil
    end

    local function setPcForNewGame(game, save)
      if not mod.options:get("gold_pc_item") then return end
      local current = mapping(game)
      if current.pcPlaced then return end
      local choice = mod.options:get("pc_start_choice") or "RANDOM"
      local item, quantity = manualGoldPcBundle(game, choice)
      if quantity == nil then
        choice, item, quantity = "RANDOM", current.placements["pc:new"], 1
      end
      if quantity > 0 and not safeItem(game, item) then return end
      -- Gold starts with an empty item PC. Seed one generated stack when its
      -- actual new-save event fires, then use this saved source for rerolls.
      save.pcItems = {}
      if quantity > 0 then save.pcItems[item] = quantity end
      current.placements["pc:new"] = item
      current.pcChoice, current.pcQuantity = choice, quantity
      current.pcPlaced, current.pcLocked = true, false
      mod.save:set(STATE_KEY, current)
    end

    local function pcStillContains(save, item, quantity)
      quantity = math.max(0, math.floor(tonumber(quantity) or 1))
      if quantity == 0 then return type(save and save.pcItems) == "table" and next(save.pcItems) == nil end
      if type(save and save.pcItems) ~= "table" or save.pcItems[item] ~= quantity then return false end
      local count = 0
      for _ in pairs(save.pcItems) do count = count + 1 end
      return count == 1
    end

    local function lockPc(game)
      local current = mapping(game)
      if not current.pcPlaced or current.pcLocked then return current.pcLocked end
      local item = current.placements["pc:new"]
      if not pcStillContains(game and game.save, item, current.pcQuantity) then
        current.pcLocked = true
        mod.save:set(STATE_KEY, current)
      end
      return current.pcLocked
    end

    local function rerollPc(game)
      local current = mapping(game)
      if not current.pcPlaced or lockPc(game) then return end
      local old = current.placements["pc:new"]
      if not pcStillContains(game and game.save, old, current.pcQuantity) then return end
      local pool = safeItemPool(game)
      local replacement = old
      for _ = 1, 24 do
        replacement = randomFrom(pool)
        if replacement and replacement ~= old then break end
      end
      if replacement and replacement ~= old then
        current.placements["pc:new"] = replacement
        current.pcChoice, current.pcQuantity = "RANDOM", 1
        game.save.pcItems = { [replacement] = 1 }
        mod.save:set(STATE_KEY, current)
      end
    end

    mod.hooks:wrap("save.new_game", function(next, save)
      save = next(save)
      setPcForNewGame(mod.game, save)
      return save
    end)

    mod.events:on("game.ready", function(event) applyMapSources((event and event.game) or mod.game) end)
    mod.events:on("save.created", function(event)
      local game = (event and event.game) or mod.game
      setPcForNewGame(game, (event and event.save) or (game and game.save))
      applyMapSources(game)
    end)
    mod.events:on("save.loaded", function(event) applyMapSources((event and event.game) or mod.game) end)
    mod.events:on("screen.popped", function() lockPc(mod.game) end)

    local function resetGoldAction(key)
      local game = mod.game
      local stores = {
        game and game.mods and game.mods.modOptions,
        game and game.save and game.save.options and game.save.options.modOptions,
      }
      for _, store in ipairs(stores) do
        local bucket = store and store[mod.id]
        if bucket then bucket[key] = false end
      end
    end

    local function showGoldDiagnostic(game, text)
      local TextBox = require("src.render.TextBox")
      if game and game.stack then game.stack:push(TextBox.new(game, text)) end
    end

    local function goldShopPreview(game)
      local current, pages = mapping(game), {}
      for key, shop in pairs((current and current.shops) or {}) do
        if type(shop) == "table" and type(shop.stock) == "table" then
          local rows = { "SHOP " .. tostring(key) }
          for index, itemId in ipairs(shop.stock) do
            local item = game and game.data and game.data.items and game.data.items[itemId] or {}
            rows[#rows + 1] = string.format("%d. %s %d", index, item.name or itemId,
              math.max(0, math.floor(tonumber(shop.prices and shop.prices[index]) or 0)))
          end
          pages[#pages + 1] = table.concat(rows, "\n")
        end
      end
      table.sort(pages)
      showGoldDiagnostic(game, #pages > 0 and table.concat(pages, "\f")
        or "NO RANDOMIZED\nSHOPS YET")
    end

    local function goldPcStatus(game)
      local current = mapping(game)
      local status
      if not mod.options:get("gold_pc_item") then
        status = "START PC ITEM\nDISABLED"
      elseif not current.pcPlaced then
        status = "START PC ITEM\nWAITING FOR NEW GAME"
      elseif current.pcLocked then
        status = "PC REROLL\nLOCKED AFTER WITHDRAWAL"
      elseif pcStillContains(game and game.save, current.placements["pc:new"], current.pcQuantity) then
        status = string.format("PC REROLL READY\n%s x%d", tostring(current.placements["pc:new"]),
          math.max(0, math.floor(tonumber(current.pcQuantity) or 0)))
      else
        status = "PC REROLL\nUNAVAILABLE"
      end
      showGoldDiagnostic(game, status)
    end

    mod.events:on("mod.options_changed", function(event)
      local changed = type(event and event.mod) == "table" and event.mod.id or event and event.mod
      if changed ~= mod.id then return end
      if event.key == "gold_reroll_pc" and event.value then
        resetGoldAction(event.key)
        rerollPc(mod.game)
      elseif event.key == "gold_shop_preview" and event.value then
        resetGoldAction(event.key)
        goldShopPreview(mod.game)
      elseif event.key == "gold_pc_status" and event.value then
        resetGoldAction(event.key)
        goldPcStatus(mod.game)
      end
      if event.key == "gold_ball_items" or event.key == "gold_finder_items" then applyMapSources(mod.game) end
      if event.key == "gold_shop_items" and event.value ~= true then restoreGoldShopPrices(mod.game) end
    end)
    mod.events:on("script.ended", function(event)
      restoreGoldShopPrices((event and event.ctx and event.ctx.game) or mod.game)
    end)

    mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
      if not isGen2() then return next(ctx, name, args, cmd) end
      local game, current = mod.game, mapping(mod.game)
      if name == "pokemart" and mod.options:get("gold_shop_items") and cmd then
        local martType = cmd.martType or cmd.dialog or (args and args[1]) or 0
        local martId = cmd.mart or cmd.martId
        if martId == nil and args then martId = (args[2] or 0) + (args[3] or 0) * 0x100 end
        if martType == 0 or martType == "STANDARD" then applyGoldShop(game, martId or 0) end
      end
      if name == "fruittree" and mod.options:get("gold_berry_trees") and ctx and ctx.scriptKey then
        local rewritten = {}
        for key, value in pairs(cmd or {}) do rewritten[key] = value end
        rewritten.args = { fruitTreeFor(current, ctx.scriptKey) }
        return next(ctx, name, rewritten.args, rewritten)
      end
      if (name == "giveitem" or name == "verbosegiveitem") and mod.options:get("gold_gift_items")
        and ctx and ctx.scriptKey and cmd and safeItem(game, itemIdByIndex(game, cmd.item)) then
        local rewritten = {}
        for key, value in pairs(cmd) do rewritten[key] = value end
        local item = giftItemFor(game, current, ctx.scriptKey .. ":" .. name .. ":" .. tostring(cmd.item))
        rewritten.item = itemIndex(game, item)
        return next(ctx, name, args, rewritten)
      end
      return next(ctx, name, args, cmd)
    end)

    mod.hooks:wrap("trainer.party", function(next, trainerClass, partyIndex, party)
      party = next(trainerClass, partyIndex, party)
      if not mod.options:get("gold_held_items") then return party end
      local game, current, out = mod.game, mapping(mod.game), {}
      for i, mon in ipairs(party or {}) do
        local copy = {}
        for key, value in pairs(mon) do copy[key] = value end
        if copy.item and safeItem(game, copy.item) then
          copy.item = heldItemFor(game, current, tostring(trainerClass) .. ":" .. tostring(partyIndex) .. ":" .. tostring(i))
        end
        out[i] = copy
      end
      return out
    end)

    return
  end

  local MOD_STATE_KEY = "item_mapping"
  local MAPPING_VERSION = 3
  local PC_SEED_REVISION = 2

  -- `mod.game` resolves the engine singleton in a live boot, but keeping the
  -- most recent lifecycle payload makes an option action reliable during UI
  -- transitions as well. The reference is never saved; only the mapping is.
  local activeGame = nil

  local function rememberActiveGame(game)
    if game and game.save then activeGame = game end
    return activeGame
  end

  local function liveGame()
    local game = mod.game
    if game and game.save then return rememberActiveGame(game) end
    return activeGame
  end

  local LOW_VALUE_ITEMS = {
    ANTIDOTE = true, AWAKENING = true, BURN_HEAL = true, BRN_HEAL = true,
    ESCAPE_ROPE = true, GUARD_SPEC = true, ICE_HEAL = true,
    PARLYZ_HEAL = true, POKE_DOLL = true, POTION = true, REPEL = true,
    X_ACCURACY = true, X_ATTACK = true, X_DEFEND = true, X_SPEED = true,
    X_SPECIAL = true,
  }

  -- Price alone cannot distinguish rare rewards such as Rare Candy from a
  -- basic item reliably, so these items explicitly occupy the top pool tier.
  local PREMIUM_ITEMS = {
    MASTER_BALL = true, MAX_REVIVE = true, NUGGET = true, PP_UP = true,
    RARE_CANDY = true, ULTRA_BALL = true,
  }

  local function isRealItem(itemId)
    return type(itemId) == "string"
      and itemId ~= ""
      and itemId ~= "0"
      and itemId ~= "ITEM_NONE"
  end

  local function sortSources(sources)
    table.sort(sources, function(a, b) return a.key < b.key end)
  end

  mod.options:define({
    {
      key = "lesser_bad_items",
      label = "LESS JUNK",
      type = "toggle",
      default = true,
    },
    {
      key = "progression_weighted_loot",
      label = "PROGRESS LOOT",
      type = "toggle",
      default = true,
    },
    {
      key = "overworld_items",
      label = "SHUFFLE BALLS",
      type = "toggle",
      default = true,
    },
    {
      key = "itemfinder_items",
      label = "SHUFFLE FINDER",
      type = "toggle",
      default = true,
    },
    {
      key = "gift_items",
      label = "SHUFFLE GIFTS",
      type = "toggle",
      default = true,
    },
    {
      key = "randomize_shops",
      label = "SHUFFLE SHOPS",
      type = "toggle",
      default = false,
    },
    {
      key = "starting_pc_item",
      label = "NEW GAME PC",
      type = "toggle",
      default = true,
    },
    {
      key = "reroll_pc_item",
      label = "REROLL PC ITEM",
      type = "toggle",
      default = false,
    },
    {
      key = "shop_preview",
      label = "OPEN SHOP PREVIEW",
      type = "toggle",
      default = false,
    },
    {
      key = "pc_reroll_status",
      label = "PC REROLL STATUS",
      type = "toggle",
      default = false,
    },
  })

  local function optionSnapshot()
    return {
      lesser_bad_items = mod.options:get("lesser_bad_items") and true or false,
      progression_weighted_loot = mod.options:get("progression_weighted_loot") and true or false,
      overworld_items = mod.options:get("overworld_items") and true or false,
      itemfinder_items = mod.options:get("itemfinder_items") and true or false,
      gift_items = mod.options:get("gift_items") and true or false,
      starting_pc_item = mod.options:get("starting_pc_item") and true or false,
    }
  end

  local function copyOptions(options)
    return {
      lesser_bad_items = options.lesser_bad_items and true or false,
      progression_weighted_loot = options.progression_weighted_loot and true or false,
      overworld_items = options.overworld_items and true or false,
      itemfinder_items = options.itemfinder_items and true or false,
      gift_items = options.gift_items ~= false,
      starting_pc_item = options.starting_pc_item and true or false,
    }
  end

  local function sameOptions(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    return a.lesser_bad_items == b.lesser_bad_items
      and a.progression_weighted_loot == b.progression_weighted_loot
      and a.overworld_items == b.overworld_items
      and a.itemfinder_items == b.itemfinder_items
      and a.gift_items == b.gift_items
      and a.starting_pc_item == b.starting_pc_item
  end

  -- Collect the exact source locations from merged content. Another content
  -- mod's ordinary item balls and hidden items join this list automatically.
  local function collectSources()
    local sources = {}
    for mapId, map in mod.content.maps:each() do
      for arrayIndex, object in ipairs(map.objects or {}) do
        if isRealItem(object.item) then
          local objectIndex = object.index or arrayIndex
          sources[#sources + 1] = {
            key = "visible:" .. mapId .. ":" .. tostring(objectIndex),
            kind = "visible", mapId = mapId, objectIndex = objectIndex,
            original = object.item,
          }
        end
      end
    end

    local hiddenItems = mod.content.field:get("hiddenItems") or {}
    for mapId, entries in pairs(hiddenItems) do
      for hiddenIndex, entry in ipairs(entries or {}) do
        if isRealItem(entry.item) then
          sources[#sources + 1] = {
            key = "hidden:" .. mapId .. ":" .. tostring(entry.x)
              .. ":" .. tostring(entry.y) .. ":" .. tostring(hiddenIndex),
            kind = "hidden", mapId = mapId, hiddenIndex = hiddenIndex,
            x = entry.x, y = entry.y, original = entry.item,
          }
        end
      end
    end

    -- SaveData seeds this as { POTION = 1 } on a New Game. Existing PC storage
    -- is never projected or overwritten by ordinary mapping application.
    sources[#sources + 1] = {
      key = "pc:new_game", kind = "pc", original = "POTION", quantity = 1,
    }
    sortSources(sources)
    return sources
  end

  local SOURCES, SOURCE_BY_KEY, ITEM_INFO, SAFE_ITEMS = {}, {}, {}, {}

  -- Crystal 251 introduces mail, machine items, and evolution/progression
  -- items to the live Gen 1 registry. The ordinary randomizer remains usable
  -- without it, while an active Crystal import simply extends these filters.
  local CRYSTAL_PROGRESSION_ITEMS = {
    KINGS_ROCK=true, METAL_COAT=true, DRAGON_SCALE=true, SUN_STONE=true,
    UP_GRADE=true,
  }

  -- Key items, HMs, mail, non-tossable records, and Crystal's single-player
  -- evolution/progression items stay out of generated pools. Keep their
  -- original locations so neither story flow nor item-based evolution access
  -- is disturbed.
  local function isUnsafeProgressionItem(itemId)
    local item = ITEM_INFO[itemId]
    if not item then return true end
    if item.keyItem or item.tossable == false or item.canToss == false then return true end
    if item.isMail or item.mail or item.pocket == "KEY_ITEM" then return true end
    if itemId:match("^HM_") then return true end
    if type(item.machine) == "table" and item.machine.kind == "HM" then return true end
    if crystal251Active() and CRYSTAL_PROGRESSION_ITEMS[itemId] then return true end
    return false
  end

  local function rebuildContentViews()
    SOURCES = collectSources()
    SOURCE_BY_KEY = {}
    for _, source in ipairs(SOURCES) do SOURCE_BY_KEY[source.key] = source end
    ITEM_INFO = {}
    for itemId, item in mod.content.items:each() do ITEM_INFO[itemId] = item end
    SAFE_ITEMS = {}
    for itemId, _ in pairs(ITEM_INFO) do
      if isRealItem(itemId) and not isUnsafeProgressionItem(itemId) then
        SAFE_ITEMS[#SAFE_ITEMS + 1] = itemId
      end
    end
    table.sort(SAFE_ITEMS)
  end

  rebuildContentViews()

  local function sourceEnabled(source, options)
    if source.kind == "visible" then return options.overworld_items end
    if source.kind == "hidden" then return options.itemfinder_items end
    if source.kind == "pc" then return options.starting_pc_item end
    return false
  end

  -- A key-item source is deliberately absent from the selected source list.
  -- Its vanilla data remains restored in-place, preserving story progression.
  local function selectedSources(options)
    local selected = {}
    for _, source in ipairs(SOURCES) do
      if sourceEnabled(source, options)
        and not isUnsafeProgressionItem(source.original) then
        selected[#selected + 1] = source
      end
    end
    return selected
  end

  local function shuffle(values)
    for i = #values, 2, -1 do
      local j = love.math.random(i)
      values[i], values[j] = values[j], values[i]
    end
  end

  local function sourceProgressTier(source)
    if source.kind == "pc" then return 1 end
    local mapId = source.mapId or ""

    if mapId:find("CERULEAN_CAVE") or mapId:find("VICTORY_ROAD")
      or mapId:find("INDIGO") or mapId:find("SEAFOAM")
      or mapId:find("CINNABAR") or mapId == "ROUTE_23" then
      return 5
    end
    if mapId:find("FUCHSIA") or mapId:find("SAFFRON")
      or mapId:find("SAFARI") or mapId:find("SILPH")
      or mapId == "ROUTE_12" or mapId == "ROUTE_13" or mapId == "ROUTE_14"
      or mapId == "ROUTE_15" or mapId == "ROUTE_16" or mapId == "ROUTE_17"
      or mapId == "ROUTE_18" or mapId == "ROUTE_19" or mapId == "ROUTE_20" then
      return 4
    end
    if mapId:find("CELADON") or mapId:find("LAVENDER")
      or mapId:find("ROCK_TUNNEL") or mapId:find("POKEMON_TOWER")
      or mapId == "ROUTE_7" or mapId == "ROUTE_8" or mapId == "ROUTE_9"
      or mapId == "ROUTE_10" or mapId == "ROUTE_11" then
      return 3
    end
    if mapId:find("CERULEAN") or mapId:find("VERMILION")
      or mapId:find("SS_ANNE") or mapId == "ROUTE_4" or mapId == "ROUTE_5"
      or mapId == "ROUTE_6" then
      return 2
    end
    -- Pallet, Viridian Forest, Routes 1–3, Pewter, and Mt. Moon are tier 1.
    return 1
  end

  local function itemQualityTier(itemId)
    local item = ITEM_INFO[itemId] or {}
    if PREMIUM_ITEMS[itemId] then return 5 end
    if type(item.machine) == "table" then return 4 end
    local price = tonumber(item.price) or 0
    if price >= 3000 then return 4 end
    if price >= 1000 then return 3 end
    if price >= 500 then return 2 end
    return 1
  end

  -- Index is source progression (1 early through 5 late); inner values are
  -- candidate quality tiers. Even tier 1 has a nonzero high-tier weight, so a
  -- Viridian Forest Rare Candy streak is unlikely but possible.
  local QUALITY_WEIGHTS = {
    { 32, 14, 5, 1, 1 },
    { 24, 16, 7, 2, 1 },
    { 16, 16, 10, 4, 2 },
    { 10, 14, 13, 7, 4 },
    { 6, 10, 14, 11, 8 },
  }

  local function weightedSafeItem(source, options, recent)
    local tierWeights = QUALITY_WEIGHTS[sourceProgressTier(source)]
    local total = 0
    local entries = {}
    for _, itemId in ipairs(SAFE_ITEMS) do
      local weight = tierWeights[itemQualityTier(itemId)] or 1
      if options.lesser_bad_items and LOW_VALUE_ITEMS[itemId] then
        weight = math.max(1, math.floor(weight / 4))
      end
      -- A soft penalty discourages one area from becoming a stack of the same
      -- reward without making any safe outcome impossible.
      local repeats = recent and (recent[itemId] or 0) or 0
      if repeats > 0 then weight = math.max(1, math.floor(weight / (1 + repeats * 3))) end
      total = total + weight
      entries[#entries + 1] = { itemId = itemId, limit = total }
    end
    if total == 0 then return nil end

    local roll = love.math.random(total)
    for _, entry in ipairs(entries) do
      if roll <= entry.limit then return entry.itemId end
    end
    return entries[#entries].itemId
  end

  local function itemForSource(source, options, recent)
    if options.progression_weighted_loot then
      return weightedSafeItem(source, options, recent)
    end
    return SAFE_ITEMS[love.math.random(#SAFE_ITEMS)]
  end

  local ensureMapping
  local SHOP_EXCLUDED = {
    ANTIDOTE = true, AWAKENING = true, BURN_HEAL = true, BRN_HEAL = true,
    ICE_HEAL = true, PARLYZ_HEAL = true, POKE_DOLL = true, REPEL = true,
    GUARD_SPEC = true, X_ACCURACY = true, X_ATTACK = true, X_DEFEND = true,
    X_SPEED = true, X_SPECIAL = true,
  }
  local shopPriceBaseline, shopPricesCaptured = {}, false
  local shopBaselines, shopBaselinesCaptured = {}, false

  local function randomInt(maximum)
    if maximum <= 1 then return 1 end
    if love and love.math and love.math.random then return love.math.random(maximum) end
    return math.random(maximum)
  end

  local function copyArray(rows)
    local out = {}
    for index, value in ipairs(rows or {}) do out[index] = value end
    return out
  end

  local function shopTable(game)
    return game and game.data and (game.data.text_pointers or game.data.textPointers) or {}
  end

  local function captureShopBaselines(game)
    if shopBaselinesCaptured then return end
    for mapId, entries in pairs(shopTable(game)) do
      for textConst, entry in pairs(entries or {}) do
        if type(entry) == "table" and type(entry.mart) == "table" and #entry.mart > 0 then
          shopBaselines[mapId .. ":" .. textConst] = copyArray(entry.mart)
        end
      end
    end
    shopBaselinesCaptured = true
  end

  local function shopSource(mapId)
    return { kind = "shop", mapId = mapId or "" }
  end

  local function chooseShopItem(source, options, used)
    local candidate
    for _ = 1, 48 do
      candidate = itemForSource(source, options)
      if candidate and not SHOP_EXCLUDED[candidate] and not used[candidate] then return candidate end
    end
    for _, itemId in ipairs(SAFE_ITEMS) do
      if not SHOP_EXCLUDED[itemId] and not used[itemId] then return itemId end
    end
    return candidate
  end

  local function shopPrice(itemId)
    local base = math.max(1, tonumber(ITEM_INFO[itemId] and ITEM_INFO[itemId].price) or 1)
    return math.max(1, math.floor(base * (70 + randomInt(61) - 1) / 100))
  end

  local function shopRecord(mapping, mapId, textConst, original)
    mapping.shops = mapping.shops or { gen1 = {} }
    mapping.shops.gen1 = mapping.shops.gen1 or {}
    local key = tostring(mapId) .. ":" .. tostring(textConst)
    local record = mapping.shops.gen1[key]
    if type(record) == "table" and type(record.stock) == "table"
      and #record.stock == #original and type(record.prices) == "table" then
      return record
    end
    local options, used = mapping.options, {}
    record = { stock = {}, prices = {}, firstShop = mapId == "VIRIDIAN_MART" }
    for index = 1, #original do
      local itemId
      if record.firstShop and index == 1 and not used.POKE_BALL and not isUnsafeProgressionItem("POKE_BALL") then
        itemId = "POKE_BALL"
      else
        itemId = chooseShopItem(shopSource(mapId), options, used)
      end
      used[itemId] = true
      record.stock[index] = itemId
      record.prices[index] = shopPrice(itemId)
    end
    mapping.shops.gen1[key] = record
    mod.save:set(MOD_STATE_KEY, mapping)
    return record
  end

  local function restoreShopPrices(game)
    if not shopPricesCaptured then return end
    for itemId, price in pairs(shopPriceBaseline) do
      local item = game and game.data and game.data.items and game.data.items[itemId]
      if item then item.price = price end
    end
    shopPriceBaseline, shopPricesCaptured = {}, false
  end

  local function affordableBallPrice(game, record)
    local money = math.max(0, math.floor(tonumber(game and game.save and game.save.money) or 0))
    if money == 0 then
      record.ballPrice = 0
      return 0
    end
    local previous, price = record.ballPrice, money
    for _ = 1, 16 do
      price = randomInt(money + 1) - 1
      if price ~= previous then break end
    end
    record.ballPrice = price
    return price
  end

  local function applyGen1Shop(game, mapId, textConst, entry)
    if not (game and entry and type(entry.mart) == "table") then return false end
    captureShopBaselines(game)
    local original = shopBaselines[tostring(mapId) .. ":" .. tostring(textConst)]
    if type(original) ~= "table" or #original == 0 then return false end
    local mapping = ensureMapping()
    local record = shopRecord(mapping, mapId, textConst, original)
    restoreShopPrices(game)
    for index = #entry.mart, 1, -1 do entry.mart[index] = nil end
    for index, itemId in ipairs(record.stock) do
      entry.mart[index] = itemId
      local item = game.data.items and game.data.items[itemId]
      if item then
        shopPricesCaptured = true
        if shopPriceBaseline[itemId] == nil then shopPriceBaseline[itemId] = item.price end
        local price = record.prices[index]
        if record.firstShop and index == 1 and itemId == "POKE_BALL" then
          price = affordableBallPrice(game, record)
          mod.save:set(MOD_STATE_KEY, mapping)
        end
        item.price = math.max(0, math.floor(tonumber(price) or item.price or 1))
      end
    end
    return true
  end

  local function applyGen1MapShops(game, mapId)
    if not mod.options:get("randomize_shops") then return end
    local entries = shopTable(game)[mapId]
    for textConst, entry in pairs(entries or {}) do
      if type(entry) == "table" and type(entry.mart) == "table" then
        applyGen1Shop(game, mapId, textConst, entry)
      end
    end
  end

  local function makeMapping(options)
    local selected = selectedSources(options)
    local placements = {}

    if options.progression_weighted_loot then
      local recentByArea = {}
      for _, source in ipairs(selected) do
        local area = source.mapId or source.kind
        local recent = recentByArea[area] or {}
        local itemId = itemForSource(source, options, recent)
        placements[source.key] = itemId
        if itemId then recent[itemId] = (recent[itemId] or 0) + 1 end
        recentByArea[area] = recent
      end
    else
      -- Non-weighted mode preserves the original source-item permutation,
      -- excluding only unsafe progression items and their source locations.
      local items = {}
      for i, source in ipairs(selected) do items[i] = source.original end
      shuffle(items)
      for i, source in ipairs(selected) do placements[source.key] = items[i] end
    end

    return {
      version = MAPPING_VERSION,
      options = copyOptions(options),
      placements = placements,
      pcRerolls = 0,
      pcRerollLocked = false,
      gifts = {},
      shops = { gen1 = {} },
    }
  end

  local function validMapping(mapping)
    if type(mapping) ~= "table" or mapping.version ~= MAPPING_VERSION
      or type(mapping.placements) ~= "table" or type(mapping.options) ~= "table" then
      return false
    end
    for _, source in ipairs(selectedSources(mapping.options)) do
      local itemId = mapping.placements[source.key]
      local intentionallyEmptyPc = source.kind == "pc" and mapping.pcChoice == "NONE"
      if not intentionallyEmptyPc
        and (not isRealItem(itemId) or isUnsafeProgressionItem(itemId)) then
        return false
      end
    end
    return true
  end

  ensureMapping = function()
    local currentOptions = optionSnapshot()
    local mapping = mod.save:get(MOD_STATE_KEY)
    if validMapping(mapping) then
      -- Shop layouts are generated lazily on each save’s first enabled mart
      -- visit. Keeping them outside the field-item option snapshot lets a
      -- player enable the new shop option without disturbing an established
      -- item-ball, hidden-item, gift, or PC mapping.
      if type(mapping.shops) ~= "table" then
        mapping.shops = { gen1 = {} }
        mod.save:set(MOD_STATE_KEY, mapping)
      elseif type(mapping.shops.gen1) ~= "table" then
        mapping.shops.gen1 = {}
        mod.save:set(MOD_STATE_KEY, mapping)
      end
      if not sameOptions(mapping.options, currentOptions) then
        mod.log:warn("Item Randomizer settings changed after this save's mapping was created; keeping the saved mapping")
      end
      return mapping
    end

    mapping = makeMapping(currentOptions)
    mod.save:set(MOD_STATE_KEY, mapping)
    mod.log:info("Created a safe per-save item mapping across %d selected sources",
      #selectedSources(currentOptions))
    return mapping
  end

  local ROUTE1_POTION_GIFT = {
    key = "gift:route_1:potion_sample",
    kind = "gift",
    mapId = "ROUTE_1",
    original = "POTION",
  }

  local function route1PotionGift(game, ow, npc, done)
    local mapping = ensureMapping()
    local options = copyOptions(mapping.options or optionSnapshot())
    local itemId = "POTION"
    if options.gift_items then
      itemId = mapping.gifts and mapping.gifts[ROUTE1_POTION_GIFT.key]
      if not isRealItem(itemId) or isUnsafeProgressionItem(itemId) then
        itemId = itemForSource(ROUTE1_POTION_GIFT, options)
        mapping.gifts = mapping.gifts or {}
        mapping.gifts[ROUTE1_POTION_GIFT.key] = itemId
        mod.save:set(MOD_STATE_KEY, mapping)
      end
    end

    local t = game and game.data and game.data.text or {}
    local itemDef = game and game.data and game.data.items and game.data.items[itemId]
    local itemName = itemDef and itemDef.name or itemId
    local playerName = game and game.save and game.save.player and game.save.player.name or ""
    local function fillText(label, fallback)
      local value = t[label] or fallback
      value = value:gsub("{PLAYER}", playerName)
      value = value:gsub("{RAM:[^}]*}", itemName)
      return value
    end
    local function show(label, fallback, callback)
      local TextBox = require("src.render.TextBox")
      game.stack:push(TextBox.new(game, fillText(label, fallback), callback))
    end
    local flags = game.save.flags or {}
    if flags.EVENT_GOT_POTION_SAMPLE then
      show("_Route1Youngster1AlsoGotPokeballsText", "It's a useful item, isn't it?", done)
      return
    end
    local Bag = require("src.inventory.Bag")
    if not Bag.add(game.save, itemId, 1) then
      show("_Route1Youngster1NoRoomText", "You have no room for this item!", done)
      return
    end
    flags.EVENT_GOT_POTION_SAMPLE = true
    show("_Route1Youngster1GotPotionText", "{PLAYER} received\\n{RAM:}!", done)
  end

  mod.content.map_scripts:register("ROUTE_1", {
    priority = 120,
    talk = {
      TEXT_ROUTE1_YOUNGSTER1 = route1PotionGift,
    },
  })

  local function findVisible(data, source)
    local map = data.maps and data.maps[source.mapId]
    for arrayIndex, object in ipairs(map and map.objects or {}) do
      if (object.index or arrayIndex) == source.objectIndex then return object end
    end
    return nil
  end

  local function findHidden(data, source)
    local entries = data.field and data.field.hiddenItems
      and data.field.hiddenItems[source.mapId]
    local indexed = entries and entries[source.hiddenIndex]
    if indexed and indexed.x == source.x and indexed.y == source.y then return indexed end
    for _, entry in ipairs(entries or {}) do
      if entry.x == source.x and entry.y == source.y then return entry end
    end
    return nil
  end

  -- Data tables are shared by future map loads. Capture their merged baseline
  -- once, restore it before each projection, then apply only this save's
  -- stored placements. This prevents a prior save's mapping leaking to another.
  local baseline, baselineCaptured = {}, false

  local function captureBaseline(game)
    if baselineCaptured then return end
    local data = game and game.data
    if not data then return end
    for _, source in ipairs(SOURCES) do
      if source.kind == "visible" then
        local object = findVisible(data, source)
        if object then baseline[source.key] = object.item end
      elseif source.kind == "hidden" then
        local entry = findHidden(data, source)
        if entry then baseline[source.key] = entry.item end
      end
    end
    baselineCaptured = true
  end

  local function restoreBaseline(data)
    for _, source in ipairs(SOURCES) do
      local original = baseline[source.key]
      if original then
        if source.kind == "visible" then
          local object = findVisible(data, source)
          if object then object.item = original end
        elseif source.kind == "hidden" then
          local entry = findHidden(data, source)
          if entry then entry.item = original end
        end
      end
    end
  end

  local function applyMapping(game, mapping)
    local data = game and game.data
    if not data or not validMapping(mapping) then return 0 end
    captureBaseline(game)
    restoreBaseline(data)

    local applied = 0
    for _, source in ipairs(selectedSources(mapping.options)) do
      local itemId = mapping.placements[source.key]
      if source.kind == "visible" then
        local object = findVisible(data, source)
        if object then object.item = itemId; applied = applied + 1 end
      elseif source.kind == "hidden" then
        local entry = findHidden(data, source)
        if entry then entry.item = itemId; applied = applied + 1 end
      end
    end
    return applied
  end

  local function setPcContents(save, itemId, quantity)
    if not save then return false end
    save.pcItems = {}
    if isRealItem(itemId) and (tonumber(quantity) or 0) > 0 then
      save.pcItems[itemId] = math.floor(quantity)
    end
    return true
  end

  local function pcStoredItem(mapping)
    return mapping and mapping.placements and mapping.placements["pc:new_game"]
  end

  local function pcStoredQuantity(mapping)
    return math.max(0, math.floor(tonumber(mapping and mapping.pcQuantity) or 1))
  end

  local function pcContainsOnly(save, expectedItem, expectedQuantity)
    local pcItems = save and save.pcItems
    if type(pcItems) ~= "table" then return false end
    expectedQuantity = math.max(0, math.floor(tonumber(expectedQuantity) or 0))
    if expectedQuantity == 0 then return next(pcItems) == nil end
    if pcItems[expectedItem] ~= expectedQuantity then return false end
    local count = 0
    for _ in pairs(pcItems) do count = count + 1 end
    return count == 1
  end

  local function pcLooksFresh(save)
    local pcItems = save and save.pcItems
    if type(pcItems) ~= "table" or next(pcItems) == nil then return true end
    return pcItems.POTION == 1 and next(pcItems, "POTION") == nil
  end

  local function initializeNewGamePc(save, mapping)
    if not (save and validMapping(mapping) and mapping.options.starting_pc_item) then return false end
    mapping.pcChoice = "RANDOM"
    mapping.pcQuantity = 1
    local itemId = pcStoredItem(mapping)
    if not isRealItem(itemId) then return false end
    setPcContents(save, itemId, 1)
    mapping.pcInitialized = true
    mapping.pcSeedRevision = PC_SEED_REVISION
    mod.save:set(MOD_STATE_KEY, mapping)
    return true
  end

  -- The save hook is the normal placement path. This narrow retry covers a
  -- fresh save whose PC UI was constructed before that hook was observed; it
  -- only replaces the native single Potion or an empty fresh PC, never an
  -- established player's stored items.
  local function refreshFreshNewGamePc(save, mapping)
    if mapping and not mapping.pcRerollLocked and not mapping.pcInitialized and pcLooksFresh(save) then
      return initializeNewGamePc(save, mapping)
    end
    return false
  end

  -- `save.created` exposes the newly built save directly. Older builds only
  -- looked through `mod.game`, which can still point at the previous runtime
  -- during the New Game transition. Repair that narrow case only for a fresh,
  -- never-rerolled PC; established storage remains untouched.
  local function ensureFreshPcSeed(save, mapping)
    if not (save and validMapping(mapping) and mapping.options.starting_pc_item)
      or mapping.pcRerollLocked or not pcLooksFresh(save) then
      return false
    end
    if mapping.pcSeedRevision == PC_SEED_REVISION
      and pcContainsOnly(save, pcStoredItem(mapping), pcStoredQuantity(mapping)) then
      return false
    end
    if (tonumber(mapping.pcRerolls) or 0) ~= 0 then return false end
    return initializeNewGamePc(save, mapping)
  end

  -- A generic screen close is not evidence of a PC withdrawal: fades and
  -- ordinary menus close screens too. Lock only when the player actually
  -- requests a reroll after an initialized generated item is no longer there.
  local function lockPcRerollAfterUnavailableAttempt(game, mapping)
    if not (game and game.save and validMapping(mapping))
      or mapping.pcRerollLocked or not mapping.pcInitialized then
      return false
    end
    if pcContainsOnly(game.save, pcStoredItem(mapping), pcStoredQuantity(mapping)) then
      return false
    end
    mapping.pcRerollLocked = true
    mod.save:set(MOD_STATE_KEY, mapping)
    mod.log:info("PC rerolls permanently locked: generated starting item is no longer in the PC")
    return true
  end

  local function canRefreshPcChoice(game, mapping)
    if not (game and game.save and validMapping(mapping)) then return false end
    if mapping.pcRerollLocked then return false end
    return pcContainsOnly(game.save, pcStoredItem(mapping), pcStoredQuantity(mapping))
      or (not mapping.pcInitialized and pcLooksFresh(game.save))
  end

  -- PC rerolls are intentionally narrow: they only replace the generated
  -- random starting item while the PC still contains its generated contents.
  local function rerollNewGamePc()
    local game = liveGame()
    local mapping = ensureMapping()
    if game and game.save then ensureFreshPcSeed(game.save, mapping) end
    local source = SOURCE_BY_KEY["pc:new_game"]
    if (mapping.pcChoice and mapping.pcChoice ~= "RANDOM") then
      mod.log:warn("Choose RANDOM (1 ITEM) before using the New Game PC reroll")
      return false
    end
    if not canRefreshPcChoice(game, mapping) then
      lockPcRerollAfterUnavailableAttempt(game, mapping)
      mod.log:warn("PC reroll is unavailable because the generated item is no longer in the PC")
      return false
    end
    local oldItem = pcStoredItem(mapping)
    local replacement = nil
    for _ = 1, 24 do
      local candidate = itemForSource(source, mapping.options)
      if candidate and candidate ~= oldItem then replacement = candidate; break end
    end
    if not replacement then
      for _, candidate in ipairs(SAFE_ITEMS) do
        if candidate ~= oldItem then replacement = candidate; break end
      end
    end
    if not replacement then
      mod.log:warn("PC reroll failed: no different safe item is available")
      return false
    end
    mapping.placements[source.key] = replacement
    mapping.pcChoice, mapping.pcQuantity = "RANDOM", 1
    mapping.pcInitialized = true
    mapping.pcRerolls = (tonumber(mapping.pcRerolls) or 0) + 1
    setPcContents(game.save, replacement, 1)
    mod.save:set(MOD_STATE_KEY, mapping)
    mod.log:info("Rerolled New Game PC item (%d)", mapping.pcRerolls)
    return true
  end

  -- New Game is the only normal time to replace the default PC Potion.
  mod.hooks:wrap("save.new_game", function(next, save)
    save = next(save)
    initializeNewGamePc(save, ensureMapping())
    return save
  end)

  local function resetGen1Action(key)
    local game = liveGame()
    local stores = {
      game and game.mods and game.mods.modOptions,
      game and game.save and game.save.options and game.save.options.modOptions,
    }
    for _, store in ipairs(stores) do
      local bucket = store and store[mod.id]
      if bucket then bucket[key] = false end
    end
  end

  local function showGen1Diagnostic(game, text)
    local TextBox = require("src.render.TextBox")
    if game and game.stack then game.stack:push(TextBox.new(game, text)) end
  end

  local function gen1ShopPreview(game)
    local mapping, pages = ensureMapping(), {}
    for key, shop in pairs(((mapping.shops or {}).gen1) or {}) do
      if type(shop) == "table" and type(shop.stock) == "table" then
        local rows = { "SHOP " .. tostring(key) }
        for index, itemId in ipairs(shop.stock) do
          local item = ITEM_INFO[itemId] or {}
          rows[#rows + 1] = string.format("%d. %s %d", index, item.name or itemId,
            math.max(0, math.floor(tonumber(shop.prices and shop.prices[index]) or 0)))
        end
        pages[#pages + 1] = table.concat(rows, "\n")
      end
    end
    table.sort(pages)
    showGen1Diagnostic(game, #pages > 0 and table.concat(pages, "\f")
      or "NO RANDOMIZED\nSHOPS YET")
  end

  local function gen1PcStatus(game)
    local mapping = ensureMapping()
    local text
    if not mapping.options.starting_pc_item then
      text = "NEW GAME PC\nDISABLED"
    elseif mapping.pcRerollLocked then
      text = "PC REROLL\nLOCKED AFTER WITHDRAWAL"
    elseif not mapping.pcInitialized then
      text = "PC REROLL\nWAITING FOR NEW GAME"
    elseif pcContainsOnly(game and game.save, pcStoredItem(mapping), pcStoredQuantity(mapping)) then
      text = string.format("PC REROLL READY\n%s x%d", tostring(pcStoredItem(mapping)),
        pcStoredQuantity(mapping))
    else
      text = "PC REROLL\nUNAVAILABLE"
    end
    showGen1Diagnostic(game, text)
  end

  local function activateCurrentSave(game, explicitSave)
    game = rememberActiveGame(game)
    local mapping = ensureMapping()
    local save = explicitSave or (game and game.save)
    if save then
      ensureFreshPcSeed(save, mapping)
      refreshFreshNewGamePc(save, mapping)
    end
    local applied = applyMapping(game, mapping)
    mod.log:info("Applied safe item mapping to %d selected visible/hidden sources", applied)
  end

  mod.events:on("game.ready", function(event)
    -- Other content mods may register safe items or map sources after this mod
    -- has initialized. Rebuild from the effective merged registry before
    -- applying the current save mapping; authored foreign item records remain
    -- untouched and the existing safety filter still excludes progression data.
    rebuildContentViews()
    if crystal251Active() then
      mod.log:info("Item Randomizer: Crystal 251 detected; filtering imported mail, machines, and progression items")
    end
    activateCurrentSave(event.game)
  end)
  mod.events:on("save.created", function(event)
    activateCurrentSave(event.game or mod.game, event.save)
  end)
  mod.events:on("save.loaded", function(event)
    activateCurrentSave(event.game or mod.game)
  end)
  mod.events:on("map.entered", function(event)
    local game = rememberActiveGame((event and event.game) or mod.game)
    applyGen1MapShops(game, event and event.mapId)
  end)

  -- Generic mart clerks open the current map’s text-pointer stock directly;
  -- scripted marts route through this command. Cover both paths so every Gen 1
  -- shelf receives the same persistent saved layout.
  mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
    if name == "open_mart" and mod.options:get("randomize_shops") then
      local game = rememberActiveGame(ctx and ctx.game or mod.game)
      local overworld = ctx and ctx.overworld
      local map = overworld and overworld.map
      local mapId = map and map.def and map.def.label
      local textConst = args and args[1]
      local entry = game and game.data and type(game.data.textEntry) == "function"
        and game.data:textEntry(mapId, textConst)
        or (shopTable(game)[mapId] and shopTable(game)[mapId][textConst])
      applyGen1Shop(game, mapId, textConst, entry)
    end
    return next(ctx, name, args, cmd)
  end)

  mod.events:on("mod.options_changed", function(event)
    -- ManagerState emits `mod` as an ID string; accept an object for forward
    -- compatibility with other event producers.
    local changedModId = type(event.mod) == "table" and event.mod.id or event.mod
    if changedModId ~= mod.id then return end
    if event.key == "randomize_shops" and event.value ~= true then
      restoreShopPrices(liveGame())
    end
    if event.key == "reroll_pc_item" and event.value then
      resetGen1Action(event.key)
      rerollNewGamePc()
    elseif event.key == "shop_preview" and event.value then
      resetGen1Action(event.key)
      gen1ShopPreview(liveGame())
    elseif event.key == "pc_reroll_status" and event.value then
      resetGen1Action(event.key)
      gen1PcStatus(liveGame())
    end
  end)
end
