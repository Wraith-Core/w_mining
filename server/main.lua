--[[
    w_mining — Server Authority
    Validates pickaxe ownership, node cooldowns, proximity, weighted ore rolls, rock crushing, gold washing, and smelting.
]]

local WCore = exports.w_core:GetCoreObject()

local nodeCooldowns = {}
local pendingMine = {}
local lastActionAt = {}

local mineNodeMap = {}
for i = 1, #Config.MineNodes do
    mineNodeMap[Config.MineNodes[i].id] = Config.MineNodes[i]
end

local recipeMap = {}
for i = 1, #Config.SmeltRecipes do
    recipeMap[Config.SmeltRecipes[i].id] = Config.SmeltRecipes[i]
end

local sellKeys = {}
for itemName in pairs(Config.SellPrices) do
    sellKeys[#sellKeys + 1] = itemName
end
table.sort(sellKeys)

local function round2(v)
    return math.floor((tonumber(v) or 0) * 100 + 0.5) / 100
end

local function getItemLabel(itemName)
    local defs = exports.w_lib:InvItems() or {}
    local def = defs[itemName]
    if def and def.label then
        if type(def.label) == 'table' then
            return def.label[GetConvar('w_lib:locale', 'ar')] or def.label.en or def.label.ar or itemName
        end
        return tostring(def.label)
    end
    return itemName
end

local function pickWeighted(pool)
    local total = 0
    for i = 1, #pool do total = total + (pool[i].weight or 1) end
    if total <= 0 then return pool[1] end
    local roll = math.random() * total
    local acc = 0
    for i = 1, #pool do
        acc = acc + (pool[i].weight or 1)
        if roll <= acc then return pool[i] end
    end
    return pool[#pool]
end

local function findCamp(id)
    for i = 1, #Config.Camps do
        if Config.Camps[i].id == id then return Config.Camps[i] end
    end
    return nil
end

local function isNearCamp(src, campId)
    local c = findCamp(campId)
    if not c then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = vec3(c.coords.x, c.coords.y, c.coords.z)
    return #(GetEntityCoords(ped) - pos) <= (Config.ServerMaxDistance or 8.0)
end

local function payPlayer(player, amount, reason)
    amount = round2(amount)
    if amount <= 0 then return true end
    local account = Config.Account == 'bank' and 'bank' or 'cash'
    local cid = tostring(player.PlayerData.citizenid or '')
    if GetResourceState('w_centralbank') == 'started' then
        return exports.w_lib:EconAdjustPlayer(cid, account, amount, reason) == true
    end
    return player.Functions.AddMoney(account, amount, reason) == true
end

local function chargePlayer(player, amount, reason)
    amount = round2(amount)
    if amount <= 0 then return true end
    local account = Config.Account == 'bank' and 'bank' or 'cash'
    local cid = tostring(player.PlayerData.citizenid or '')
    if GetResourceState('w_centralbank') == 'started' then
        return exports.w_lib:EconAdjustPlayer(cid, account, -amount, reason) == true
    end
    return player.Functions.RemoveMoney(account, amount, reason) == true
end

local function throttled(src, ms)
    local now = GetGameTimer()
    if lastActionAt[src] and (now - lastActionAt[src]) < (ms or 450) then return true end
    lastActionAt[src] = now
    return false
end

-- Mining authorization
w.callback.register(WMining.CB.CAN_MINE, function(source, nodeKey, kind, coords)
    if type(nodeKey) ~= 'string' or nodeKey == '' then return false, 'invalid' end

    local pickaxe = Config.PickaxeItem or 'pickaxe'
    if (tonumber(exports.w_lib:InvGetItemCount(source, pickaxe)) or 0) < 1 then
        return false, 'no_pickaxe'
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, 'invalid' end
    local pedCoords = GetEntityCoords(ped)

    local mineNode = mineNodeMap[nodeKey]
    if mineNode then
        if #(pedCoords - mineNode.coords) > (Config.ServerMaxDistance or 8.0) then
            return false, 'too_far'
        end
        kind = mineNode.kind
    elseif not Config.AllowWildRocks or nodeKey:sub(1, 5) ~= 'wild:' then
        return false, 'invalid'
    elseif type(coords) == 'vector3' and #(pedCoords - coords) > (Config.ServerMaxDistance or 8.0) then
        return false, 'too_far'
    end

    local now = os.time()
    local cdUntil = nodeCooldowns[nodeKey] or 0
    if cdUntil > now then
        return false, 'cooldown', cdUntil - now
    end

    pendingMine[source] = {
        nodeKey   = nodeKey,
        kind      = kind == 'salt' and 'salt' or 'ore',
        startedAt = GetGameTimer(),
    }
    return true
end)

-- Complete mining & roll ore rewards
w.callback.register(WMining.CB.FINISH_MINE, function(source, nodeKey, bonusStrike)
    local session = pendingMine[source]
    pendingMine[source] = nil
    if not session or session.nodeKey ~= nodeKey then return false, 'invalid' end

    local minMs = math.floor((Config.MineDurationMs or 6500) * 0.65)
    if (GetGameTimer() - session.startedAt) < minMs then
        return false, 'too_fast'
    end

    local pickaxe = Config.PickaxeItem or 'pickaxe'
    if (tonumber(exports.w_lib:InvGetItemCount(source, pickaxe)) or 0) < 1 then
        return false, 'no_pickaxe'
    end

    local pool = session.kind == 'salt' and Config.SaltDrops or Config.OreDrops
    local entry = pickWeighted(pool)
    local amount = math.random(entry.min or 1, entry.max or 2)
    if bonusStrike then amount = amount + 1 end

    if not exports.w_lib:InvCanCarry(source, entry.item, amount) then
        return false, 'cant_carry'
    end

    if not exports.w_lib:InvAddItem(source, entry.item, amount) then
        return false, 'add_failed'
    end

    nodeCooldowns[nodeKey] = os.time() + (Config.NodeCooldownSec or 75)

    local rewards = { ('%dx %s'):format(amount, getItemLabel(entry.item)) }

    -- Rare gem roll (higher chance on perfect skill check)
    local gemChance = (Config.GemChance or 6) * (bonusStrike and 1.75 or 1.0)
    if Config.Gems and #Config.Gems > 0 and (math.random() * 100.0) <= gemChance then
        local gem = pickWeighted(Config.Gems)
        if gem and exports.w_lib:InvCanCarry(source, gem.item, 1) then
            if exports.w_lib:InvAddItem(source, gem.item, 1) then
                rewards[#rewards + 1] = ('1x %s'):format(getItemLabel(gem.item))
            end
        end
    end

    -- Optional pickaxe wear / breakage
    local broke = false
    local breakPct = tonumber(Config.PickaxeBreakChance) or 0
    if breakPct > 0 and math.random(1, 100) <= breakPct then
        if exports.w_lib:InvRemoveItem(source, pickaxe, 1) then
            broke = true
        end
    end

    return true, {
        summary = table.concat(rewards, ', '),
        bonus   = bonusStrike == true,
        broke   = broke,
    }
end)

-- Camp menu state
w.callback.register(WMining.CB.GET_CAMP, function(source, campId)
    if not isNearCamp(source, campId) then return nil end

    local recipes = {}
    for i = 1, #Config.SmeltRecipes do
        local r = Config.SmeltRecipes[i]
        local maxCraft = Config.MaxBatch or 25
        local reqParts = {}
        for j = 1, #r.inputs do
            local inp = r.inputs[j]
            local have = tonumber(exports.w_lib:InvGetItemCount(source, inp.item)) or 0
            local can = math.floor(have / inp.amount)
            if can < maxCraft then maxCraft = can end
            reqParts[#reqParts + 1] = ('%dx %s'):format(inp.amount, getItemLabel(inp.item))
        end
        recipes[#recipes + 1] = {
            id           = r.id,
            outputLabel  = getItemLabel(r.output),
            reqText      = table.concat(reqParts, ' + '),
            maxCraftable = math.max(0, maxCraft),
        }
    end

    local sellItems = {}
    local totalSellCount = 0
    local totalSellValue = 0.0
    for i = 1, #sellKeys do
        local itemName = sellKeys[i]
        local price = round2(Config.SellPrices[itemName] or 0)
        local count = tonumber(exports.w_lib:InvGetItemCount(source, itemName)) or 0
        if count > 0 and price > 0 then
            sellItems[#sellItems + 1] = {
                item  = itemName,
                label = getItemLabel(itemName),
                count = count,
                price = price,
            }
            totalSellCount = totalSellCount + count
            totalSellValue = totalSellValue + (count * price)
        end
    end

    local shopItems = {}
    if Config.Shop and Config.Shop.enabled then
        for i = 1, #Config.Shop.items do
            local s = Config.Shop.items[i]
            shopItems[#shopItems + 1] = {
                index = i,
                item  = s.item,
                label = getItemLabel(s.item),
                price = round2(s.price or 0),
                count = s.count or 1,
            }
        end
    end

    return {
        recipes        = recipes,
        rockCount      = tonumber(exports.w_lib:InvGetItemCount(source, 'rock')) or 0,
        nuggetCount    = tonumber(exports.w_lib:InvGetItemCount(source, 'goldnugget')) or 0,
        sellItems      = sellItems,
        totalSellCount = totalSellCount,
        totalSellValue = round2(totalSellValue),
        shopItems      = shopItems,
    }
end)

-- Smelt recipe batch
w.callback.register(WMining.CB.SMELT, function(source, campId, recipeId, qty)
    if throttled(source, 500) then return false, 'throttled' end
    if not isNearCamp(source, campId) then return false, 'too_far' end

    local recipe = type(recipeId) == 'string' and recipeMap[recipeId]
    if not recipe then return false, 'invalid' end

    qty = math.floor(tonumber(qty) or 0)
    if qty < 1 or qty > (Config.MaxBatch or 25) then return false, 'invalid' end

    -- Verify all inputs first
    for i = 1, #recipe.inputs do
        local inp = recipe.inputs[i]
        local need = inp.amount * qty
        if (tonumber(exports.w_lib:InvGetItemCount(source, inp.item)) or 0) < need then
            return false, 'no_materials'
        end
    end

    local outCount = (recipe.count or 1) * qty
    if not exports.w_lib:InvCanCarry(source, recipe.output, outCount) then
        return false, 'cant_carry'
    end

    -- Atomic removal with rollback
    local removed = {}
    for i = 1, #recipe.inputs do
        local inp = recipe.inputs[i]
        local need = inp.amount * qty
        if not exports.w_lib:InvRemoveItem(source, inp.item, need) then
            for j = 1, #removed do
                exports.w_lib:InvAddItem(source, removed[j].item, removed[j].amount)
            end
            return false, 'no_materials'
        end
        removed[#removed + 1] = { item = inp.item, amount = need }
    end

    if not exports.w_lib:InvAddItem(source, recipe.output, outCount) then
        for j = 1, #removed do
            exports.w_lib:InvAddItem(source, removed[j].item, removed[j].amount)
        end
        return false, 'add_failed'
    end

    return true, { count = outCount }
end)

-- Crush raw rocks into ores & gems
w.callback.register(WMining.CB.CRUSH_ROCK, function(source, campId, qty)
    if throttled(source, 500) then return false, 'throttled' end
    if not isNearCamp(source, campId) then return false, 'too_far' end

    qty = math.floor(tonumber(qty) or 0)
    if qty < 1 or qty > (Config.MaxBatch or 25) then return false, 'invalid' end

    local have = tonumber(exports.w_lib:InvGetItemCount(source, 'rock')) or 0
    if have < qty then qty = have end
    if qty < 1 then return false, 'no_rocks' end

    if not exports.w_lib:InvRemoveItem(source, 'rock', qty) then
        return false, 'remove_failed'
    end

    local totals = {}
    for _ = 1, qty do
        local drop = pickWeighted(Config.CrushDrops)
        local amt = math.random(drop.min or 1, drop.max or 2)
        totals[drop.item] = (totals[drop.item] or 0) + amt

        if Config.Gems and #Config.Gems > 0 and (math.random() * 100.0) <= (Config.GemChance or 6) then
            local gem = pickWeighted(Config.Gems)
            if gem then totals[gem.item] = (totals[gem.item] or 0) + 1 end
        end
    end

    local parts = {}
    for itemName, count in pairs(totals) do
        if exports.w_lib:InvAddItem(source, itemName, count) then
            parts[#parts + 1] = ('%dx %s'):format(count, getItemLabel(itemName))
        end
    end

    return true, { crushed = qty, summary = table.concat(parts, ', ') }
end)

-- Wash gold nuggets into washed_gold
w.callback.register(WMining.CB.WASH_GOLD, function(source, campId, qty)
    if throttled(source, 500) then return false, 'throttled' end
    if not isNearCamp(source, campId) then return false, 'too_far' end

    qty = math.floor(tonumber(qty) or 0)
    if qty < 1 or qty > (Config.MaxBatch or 25) then return false, 'invalid' end

    local have = tonumber(exports.w_lib:InvGetItemCount(source, 'goldnugget')) or 0
    if have < qty then qty = have end
    if qty < 1 then return false, 'no_nuggets' end

    if not exports.w_lib:InvCanCarry(source, 'washed_gold', qty) then
        return false, 'cant_carry'
    end

    if not exports.w_lib:InvRemoveItem(source, 'goldnugget', qty) then
        return false, 'remove_failed'
    end

    if not exports.w_lib:InvAddItem(source, 'washed_gold', qty) then
        exports.w_lib:InvAddItem(source, 'goldnugget', qty)
        return false, 'add_failed'
    end

    return true, { count = qty }
end)

-- Sell single mineral / ingot
w.callback.register(WMining.CB.SELL_ITEM, function(source, campId, itemName, qty)
    if throttled(source, 400) then return false, 'throttled' end
    if not isNearCamp(source, campId) then return false, 'too_far' end
    local price = type(itemName) == 'string' and tonumber(Config.SellPrices[itemName])
    if not price or price <= 0 then return false, 'invalid' end

    qty = math.floor(tonumber(qty) or 0)
    if qty < 1 then return false, 'invalid' end

    local player = WCore.Functions.GetPlayer(source)
    if not player then return false, 'unavailable' end

    local have = tonumber(exports.w_lib:InvGetItemCount(source, itemName)) or 0
    if have < qty then qty = have end
    if qty < 1 then return false, 'empty' end

    if not exports.w_lib:InvRemoveItem(source, itemName, qty) then
        return false, 'remove_failed'
    end

    local payout = round2(price * qty)
    if not payPlayer(player, payout, ('mining:sell:%s'):format(itemName)) then
        exports.w_lib:InvAddItem(source, itemName, qty)
        return false, 'pay_failed'
    end

    return true, { count = qty, payout = payout }
end)

-- Sell all minerals / gems / ingots
w.callback.register(WMining.CB.SELL_ALL, function(source, campId)
    if throttled(source, 800) then return false, 'throttled' end
    if not isNearCamp(source, campId) then return false, 'too_far' end

    local player = WCore.Functions.GetPlayer(source)
    if not player then return false, 'unavailable' end

    local removed = {}
    local totalCount = 0
    local totalPayout = 0.0

    for i = 1, #sellKeys do
        local itemName = sellKeys[i]
        local price = tonumber(Config.SellPrices[itemName]) or 0
        local count = tonumber(exports.w_lib:InvGetItemCount(source, itemName)) or 0
        if count > 0 and price > 0 then
            if exports.w_lib:InvRemoveItem(source, itemName, count) then
                removed[#removed + 1] = { item = itemName, count = count }
                totalCount = totalCount + count
                totalPayout = totalPayout + (count * price)
            end
        end
    end

    if totalCount == 0 then return false, 'empty' end
    totalPayout = round2(totalPayout)

    if not payPlayer(player, totalPayout, 'mining:sell_all') then
        for i = 1, #removed do
            exports.w_lib:InvAddItem(source, removed[i].item, removed[i].count)
        end
        return false, 'pay_failed'
    end

    return true, { totalCount = totalCount, totalPayout = totalPayout }
end)

-- Buy pickaxe
w.callback.register(WMining.CB.BUY_SUPPLY, function(source, campId, index)
    if throttled(source, 400) then return false, 'throttled' end
    if not isNearCamp(source, campId) then return false, 'too_far' end
    if not (Config.Shop and Config.Shop.enabled) then return false, 'disabled' end

    index = tonumber(index)
    local entry = index and Config.Shop.items[index]
    if not entry then return false, 'invalid' end

    local player = WCore.Functions.GetPlayer(source)
    if not player then return false, 'unavailable' end

    local count = entry.count or 1
    local price = round2(entry.price or 0)

    if not exports.w_lib:InvCanCarry(source, entry.item, count) then
        return false, 'cant_carry'
    end

    if not chargePlayer(player, price, ('mining:buy:%s'):format(entry.item)) then
        return false, 'not_enough_money', price
    end

    if not exports.w_lib:InvAddItem(source, entry.item, count) then
        payPlayer(player, price, 'mining:buy_refund')
        return false, 'add_failed'
    end

    return true, { count = count, price = price }
end)

AddEventHandler('playerDropped', function()
    pendingMine[source] = nil
    lastActionAt[source] = nil
end)
