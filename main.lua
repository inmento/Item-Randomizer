-- Item Randomizer
-- Gen 1 Recomp mod API 2
--
-- Randomizes safe visible item balls, hidden Itemfinder pickups, and the New
-- Game PC item. Story-critical key items and HMs remain at their vanilla
-- locations. Weighted mode favors modest rewards early and stronger rewards
-- later, while always retaining a small chance of an early lucky find.

return function(mod)
  local function isGen2(game)
    game = game or mod.game
    return game and game.data and game.data.gen2Maps ~= nil
  end

  if isGen2() then
    local STATE_KEY = "gold_item_mapping"
    local VERSION = 1
    local SOURCES, SOURCE_BY_KEY = nil, nil
    local baseline, baselineCaptured = {}, false

    mod.options:define({
      { key = "gold_less_junk", label = "GOLD LESS JUNK", type = "toggle", default = true },
      { key = "gold_ball_items", label = "GOLD BALL ITEMS", type = "toggle", default = false },
      { key = "gold_finder_items", label = "GOLD FINDER ITEMS", type = "toggle", default = false },
      { key = "gold_berry_trees", label = "GOLD BERRY TREES", type = "toggle", default = false },
      { key = "gold_gift_items", label = "GOLD GIFT ITEMS", type = "toggle", default = false },
      { key = "gold_held_items", label = "GOLD HELD ITEMS", type = "toggle", default = false },
      { key = "gold_pc_item", label = "GOLD START PC", type = "toggle", default = false },
      { key = "gold_reroll_pc", label = "GOLD REROLL PC", type = "toggle", default = false },
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
      if item.pocket == "KEY_ITEM" then return false end
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

    local function mapping(game)
      buildSources(game)
      local current = mod.save:get(STATE_KEY)
      if type(current) == "table" and current.version == VERSION
        and type(current.placements) == "table" then
        return current
      end
      local pool = safeItemPool(game)
      current = { version = VERSION, placements = {}, fruitTrees = {}, gifts = {}, held = {}, pcPlaced = false, pcLocked = false }
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
      local item = current.held[key]
      if safeItem(game, item) then return item end
      item = randomFrom(safeItemPool(game))
      current.held[key] = item
      mod.save:set(STATE_KEY, current)
      return item
    end

    local function setPcForNewGame(game, save)
      if not mod.options:get("gold_pc_item") then return end
      local current = mapping(game)
      if current.pcPlaced then return end
      local item = current.placements["pc:new"]
      if not safeItem(game, item) then return end
      -- Gold starts with an empty item PC. Seed one generated stack when its
      -- actual new-save event fires, then use this saved source for rerolls.
      save.pcItems = { [item] = 1 }
      current.pcPlaced, current.pcLocked = true, false
      mod.save:set(STATE_KEY, current)
    end

    local function pcStillContains(save, item)
      if type(save and save.pcItems) ~= "table" or save.pcItems[item] ~= 1 then return false end
      local count = 0
      for _ in pairs(save.pcItems) do count = count + 1 end
      return count == 1
    end

    local function lockPc(game)
      local current = mapping(game)
      if not current.pcPlaced or current.pcLocked then return current.pcLocked end
      local item = current.placements["pc:new"]
      if not pcStillContains(game and game.save, item) then
        current.pcLocked = true
        mod.save:set(STATE_KEY, current)
      end
      return current.pcLocked
    end

    local function rerollPc(game)
      local current = mapping(game)
      if not current.pcPlaced or lockPc(game) then return end
      local old = current.placements["pc:new"]
      if not pcStillContains(game and game.save, old) then return end
      local pool = safeItemPool(game)
      local replacement = old
      for _ = 1, 24 do
        replacement = randomFrom(pool)
        if replacement and replacement ~= old then break end
      end
      if replacement and replacement ~= old then
        current.placements["pc:new"] = replacement
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

    mod.events:on("mod.options_changed", function(event)
      local changed = type(event and event.mod) == "table" and event.mod.id or event and event.mod
      if changed ~= mod.id then return end
      if event.key == "gold_reroll_pc" and event.value then rerollPc(mod.game) end
      if event.key == "gold_ball_items" or event.key == "gold_finder_items" then applyMapSources(mod.game) end
    end)

    mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
      if not isGen2() then return next(ctx, name, args, cmd) end
      local game, current = mod.game, mapping(mod.game)
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
      label = "REDUCE LOW-VALUE ITEMS",
      type = "toggle",
      default = true,
    },
    {
      key = "progression_weighted_loot",
      label = "PROGRESSION-WEIGHTED LOOT",
      type = "toggle",
      default = true,
    },
    {
      key = "overworld_items",
      label = "RANDOMIZE OVERWORLD BALLS",
      type = "toggle",
      default = true,
    },
    {
      key = "itemfinder_items",
      label = "RANDOMIZE ITEMFINDER ITEMS",
      type = "toggle",
      default = true,
    },
    {
      key = "starting_pc_item",
      label = "RANDOMIZE NEW GAME PC",
      type = "toggle",
      default = true,
    },
    {
      key = "reroll_pc_item",
      label = "REROLL NEW GAME PC ITEM",
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
      starting_pc_item = mod.options:get("starting_pc_item") and true or false,
    }
  end

  local function copyOptions(options)
    return {
      lesser_bad_items = options.lesser_bad_items and true or false,
      progression_weighted_loot = options.progression_weighted_loot and true or false,
      overworld_items = options.overworld_items and true or false,
      itemfinder_items = options.itemfinder_items and true or false,
      starting_pc_item = options.starting_pc_item and true or false,
    }
  end

  local function sameOptions(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    return a.lesser_bad_items == b.lesser_bad_items
      and a.progression_weighted_loot == b.progression_weighted_loot
      and a.overworld_items == b.overworld_items
      and a.itemfinder_items == b.itemfinder_items
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

  local SOURCES = collectSources()
  local SOURCE_BY_KEY = {}
  for _, source in ipairs(SOURCES) do SOURCE_BY_KEY[source.key] = source end

  local ITEM_INFO = {}
  for itemId, item in mod.content.items:each() do ITEM_INFO[itemId] = item end

  -- Key items, HMs, and non-tossable records are progression-critical or
  -- otherwise unsuitable as random rewards. Keep their original sources and
  -- exclude them from every generated item pool.
  local function isUnsafeProgressionItem(itemId)
    local item = ITEM_INFO[itemId]
    if not item then return true end
    if item.keyItem or item.tossable == false then return true end
    if itemId:match("^HM_") then return true end
    if type(item.machine) == "table" and item.machine.kind == "HM" then return true end
    return false
  end

  local SAFE_ITEMS = {}
  for itemId, _ in pairs(ITEM_INFO) do
    if isRealItem(itemId) and not isUnsafeProgressionItem(itemId) then
      SAFE_ITEMS[#SAFE_ITEMS + 1] = itemId
    end
  end
  table.sort(SAFE_ITEMS)

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

  local function weightedSafeItem(source, options)
    local tierWeights = QUALITY_WEIGHTS[sourceProgressTier(source)]
    local total = 0
    local entries = {}
    for _, itemId in ipairs(SAFE_ITEMS) do
      local weight = tierWeights[itemQualityTier(itemId)] or 1
      if options.lesser_bad_items and LOW_VALUE_ITEMS[itemId] then
        weight = math.max(1, math.floor(weight / 4))
      end
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

  local function itemForSource(source, options)
    if options.progression_weighted_loot then
      return weightedSafeItem(source, options)
    end
    return SAFE_ITEMS[love.math.random(#SAFE_ITEMS)]
  end

  local function makeMapping(options)
    local selected = selectedSources(options)
    local placements = {}

    if options.progression_weighted_loot then
      for _, source in ipairs(selected) do
        placements[source.key] = itemForSource(source, options)
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
    }
  end

  local function validMapping(mapping)
    if type(mapping) ~= "table" or mapping.version ~= MAPPING_VERSION
      or type(mapping.placements) ~= "table" or type(mapping.options) ~= "table" then
      return false
    end
    for _, source in ipairs(selectedSources(mapping.options)) do
      local itemId = mapping.placements[source.key]
      if not isRealItem(itemId) or isUnsafeProgressionItem(itemId) then
        return false
      end
    end
    return true
  end

  local function ensureMapping()
    local currentOptions = optionSnapshot()
    local mapping = mod.save:get(MOD_STATE_KEY)
    if validMapping(mapping) then
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

  local function initializeNewGamePc(save, mapping)
    local itemId = mapping and mapping.placements and mapping.placements["pc:new_game"]
    if isRealItem(itemId) then save.pcItems = { [itemId] = 1 } end
  end

  local function pcContainsOnly(save, expectedItem)
    local pcItems = save and save.pcItems
    if type(pcItems) ~= "table" or pcItems[expectedItem] ~= 1 then return false end
    local count = 0
    for _ in pairs(pcItems) do count = count + 1 end
    return count == 1
  end

  -- This is checked on every screen close and again before a reroll. Once the
  -- generated item leaves the PC, the lock is stored permanently in mod save
  -- data, so depositing the item back later cannot re-enable rerolls.
  local function lockPcRerollAfterWithdrawal()
    local mapping = mod.save:get(MOD_STATE_KEY)
    local source = SOURCE_BY_KEY["pc:new_game"]
    local game = liveGame()
    if not (validMapping(mapping) and source and game and game.save)
      or mapping.pcRerollLocked then
      return false
    end
    local expectedItem = mapping.placements[source.key]
    if isRealItem(expectedItem)
      and not (game.save.pcItems and game.save.pcItems[expectedItem]) then
      mapping.pcRerollLocked = true
      mod.save:set(MOD_STATE_KEY, mapping)
      mod.log:info("PC rerolls permanently locked: the generated starting item was withdrawn")
      return true
    end
    return false
  end

  -- PC rerolls are intentionally narrow: they only replace the generated
  -- starting item while the PC still contains exactly that one generated copy.
  -- A withdrawal permanently locks the feature for this save.
  local function rerollNewGamePc()
    local game = liveGame()
    local mapping = ensureMapping()
    local source = SOURCE_BY_KEY["pc:new_game"]
    if lockPcRerollAfterWithdrawal() or mapping.pcRerollLocked then
      mod.log:warn("PC reroll is permanently disabled for this save because the starting item was withdrawn")
      return false
    end
    local oldItem = mapping.placements and mapping.placements[source.key]
    if not (game and game.save and source and oldItem) then
      mod.log:warn("PC reroll is unavailable without a generated New Game PC item")
      return false
    end
    if not pcContainsOnly(game.save, oldItem) then
      mod.log:warn("PC reroll refused: the PC must contain only its generated starting item")
      return false
    end

    -- A reroll must visibly change the PC item. Repeating a random result is
    -- technically possible, but feels broken and can make the action appear to
    -- do nothing. Retry the normal pool first, then choose another safe record
    -- deterministically if an unlucky or mocked RNG keeps returning oldItem.
    local replacement = nil
    for _ = 1, 24 do
      local candidate = itemForSource(source, mapping.options)
      if candidate and candidate ~= oldItem then
        replacement = candidate
        break
      end
    end
    if not replacement then
      for _, candidate in ipairs(SAFE_ITEMS) do
        if candidate ~= oldItem then
          replacement = candidate
          break
        end
      end
    end
    if not replacement then
      mod.log:warn("PC reroll failed: no different safe item is available")
      return false
    end
    mapping.placements[source.key] = replacement
    mapping.pcRerolls = (tonumber(mapping.pcRerolls) or 0) + 1
    mod.save:set(MOD_STATE_KEY, mapping)
    game.save.pcItems = { [replacement] = 1 }
    mod.log:info("Rerolled New Game PC item (%d)", mapping.pcRerolls)
    return true
  end

  -- New Game is the only normal time to replace the default PC Potion.
  mod.hooks:wrap("save.new_game", function(next, save)
    save = next(save)
    initializeNewGamePc(save, ensureMapping())
    return save
  end)

  local function activateCurrentSave(game)
    game = rememberActiveGame(game)
    local mapping = ensureMapping()
    local applied = applyMapping(game, mapping)
    mod.log:info("Applied safe item mapping to %d selected visible/hidden sources", applied)
  end

  mod.events:on("game.ready", function(event)
    activateCurrentSave(event.game)
  end)
  mod.events:on("save.created", function(event)
    activateCurrentSave(event.game or mod.game)
  end)
  mod.events:on("save.loaded", function(event)
    activateCurrentSave(event.game or mod.game)
  end)

  -- Player PC withdrawal removes the item before its menu/quantity state
  -- closes. Observing screen closes records that first removal immediately.
  mod.events:on("screen.popped", function()
    lockPcRerollAfterWithdrawal()
  end)

  mod.events:on("mod.options_changed", function(event)
    -- ManagerState emits `mod` as an ID string; accept an object for forward
    -- compatibility with other event producers.
    local changedModId = type(event.mod) == "table" and event.mod.id or event.mod
    if changedModId ~= mod.id then return end
    if event.key == "reroll_pc_item" and event.value then rerollNewGamePc() end
  end)
end
