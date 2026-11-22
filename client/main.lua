--[[
    w_mining — Client (100% w_lib interfaces & world helpers)
    Uses w.prompt.at, w.blip, lib.registerContext, lib.inputDialog, lib.alertDialog, lib.progressBar, lib.skillCheck, lib.notify.
]]

local blips = {}
local campPrompts = {}
local nodePrompts = {}
local nodeObjects = {}
local campNpcs = {}
local wildPrompt = nil
local nearbyWildRock = nil
local busy = false

local wildRockHashes = {}
for i = 1, #Config.WildRockModels do
    wildRockHashes[joaat(Config.WildRockModels[i])] = true
end

local restrictedTownHashes = {}
for i = 1, #Config.RestrictedTowns do
    restrictedTownHashes[joaat(Config.RestrictedTowns[i])] = true
end

local function notify(msg, kind)
    lib.notify({ description = msg, type = kind or 'inform' })
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(25) end
    return HasModelLoaded(hash) and hash or nil
end

local function canPlayerMine(ped)
    return not (IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) or IsPedFalling(ped)
        or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) or IsEntityInWater(ped)
        or IsPedClimbing(ped) or not IsPedOnFoot(ped))
end

local function isInRestrictedTown(coords)
    local town = Citizen.InvokeNative(0x43AD8FC02B429D33, coords.x, coords.y, coords.z, 1)
    return town and restrictedTownHashes[town] == true
end

local function removeAttachedPickaxes(ped)
    local model = joaat(Config.PickaxeModel or 'p_pickaxe01x')
    for _, obj in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(obj) == model and IsEntityAttachedToEntity(obj, ped) then
            SetEntityAsMissionEntity(obj, true, true)
            DeleteObject(obj)
        end
    end
end

local function findNearbyWildRock(coords)
    if not Config.AllowWildRocks or isInRestrictedTown(coords) then return nil end
    local itemSet = CreateItemset(true)
    local size = Citizen.InvokeNative(0x59B57C4B06531E1E, coords, 1.8, itemSet, 3, Citizen.ResultAsInteger())
    local found = nil
    for i = 0, size - 1 do
        local ent = GetIndexedItemInItemset(i, itemSet)
        if wildRockHashes[GetEntityModel(ent)] then
            local pos = GetEntityCoords(ent)
            found = {
                key    = ('wild:%d:%d'):format(math.floor(pos.x / 3), math.floor(pos.y / 3)),
                coords = pos,
                kind   = 'ore',
            }
            break
        end
    end
    if IsItemsetValid(itemSet) then DestroyItemset(itemSet) end
    return found
end

local function attemptMine(nodeKey, kind, coords)
    if busy then return end
    local ped = PlayerPedId()
    if not canPlayerMine(ped) then return end

    local ok, reason, extra = w.callback.await(WMining.CB.CAN_MINE, false, nodeKey, kind, coords)
    if not ok then
        if reason == 'no_pickaxe' then
            notify(locale('err_no_pickaxe'), 'error')
        elseif reason == 'cooldown' then
            notify(locale('err_cooldown', tonumber(extra) or 10), 'warning')
        elseif reason == 'too_far' then
            notify(locale('err_too_far'), 'error')
        else
            notify(locale('err_failed'), 'error')
        end
        return
    end

    busy = true
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    local pickaxeObj = nil
    if IsPedMale(ped) then
        TaskStartScenarioInPlace(ped, joaat(Config.MiningScenario or 'WORLD_HUMAN_PICKAXE_WALL'), 0, true, false, false, false)
    else
        local hash = loadModel(Config.PickaxeModel or 'p_pickaxe01x')
        if hash then
            local c = GetEntityCoords(ped)
            pickaxeObj = CreateObject(hash, c.x, c.y, c.z, true, true, false)
            AttachEntityToEntity(pickaxeObj, ped, GetEntityBoneIndexByName(ped, 'SKEL_R_Finger00'),
                -0.35, -0.21, -0.39, -8.0, 47.0, 11.0, true, false, true, false, 0, true)
            SetModelAsNoLongerNeeded(hash)
        end
        if pcall(lib.requestAnimDict, Config.MiningAnimDict) then
            TaskPlayAnim(ped, Config.MiningAnimDict, Config.MiningAnimClip, 3.0, 3.0, -1, 1, 0, false, false, false)
        end
    end

    local bonusStrike = false
    if Config.UseSkillCheck then
        bonusStrike = lib.skillCheck({ 'easy', 'medium' }, { 'w', 'a', 's', 'd' }) == true
    end

    local done = lib.progressBar({
        duration = Config.MineDurationMs or 6500,
        label = locale('progress_mining'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true, car = true },
    })

    ClearPedTasksImmediately(ped)
    if pickaxeObj and DoesEntityExist(pickaxeObj) then DeleteEntity(pickaxeObj) end
    removeAttachedPickaxes(ped)

    if not done then
        busy = false
        notify(locale('err_cancelled'), 'warning')
        return
    end

    local ok2, res = w.callback.await(WMining.CB.FINISH_MINE, false, nodeKey, bonusStrike)
    busy = false

    if not ok2 then
        notify(locale(res == 'cant_carry' and 'err_cant_carry' or 'err_failed'), 'error')
        return
    end

    if res.summary and res.summary ~= '' then
        notify(locale(res.bonus and 'mined_bonus' or 'mined_reward', res.summary), 'success')
    end
    if res.broke then
        notify(locale('pickaxe_broke'), 'warning')
    end
end

-- Mining Camp & Smelting Furnace Menus
local function openCampMenu(camp)
    if busy or not camp then return end
    local state = w.callback.await(WMining.CB.GET_CAMP, false, camp.id)
    if not state then
        notify(locale('err_failed'), 'error')
        return
    end

    local options = {
        {
            title = locale('opt_smelt'),
            description = locale('opt_smelt_desc'),
            icon = 'fire',
            event = WMining.EV.OPEN_SMELT,
            args = { campId = camp.id, recipes = state.recipes or {} },
        },
        {
            title = locale('opt_crush', state.rockCount or 0),
            description = locale('opt_crush_desc'),
            icon = 'hammer',
            event = WMining.EV.DO_CRUSH,
            args = { campId = camp.id, max = state.rockCount or 0 },
        },
        {
            title = locale('opt_wash', state.nuggetCount or 0),
            description = locale('opt_wash_desc'),
            icon = 'droplet',
            event = WMining.EV.DO_WASH,
            args = { campId = camp.id, max = state.nuggetCount or 0 },
        },
        {
            title = locale('opt_sell'),
            description = locale('opt_sell_desc', state.totalSellCount or 0),
            icon = 'sack-dollar',
            event = WMining.EV.OPEN_SELL,
            args = { campId = camp.id, items = state.sellItems or {} },
        },
    }

    if (state.totalSellCount or 0) > 0 and (state.totalSellValue or 0) > 0 then
        options[#options + 1] = {
            title = locale('opt_sell_all', state.totalSellValue),
            description = locale('opt_sell_all_desc'),
            icon = 'coins',
            event = WMining.EV.SELL_ALL,
            args = { campId = camp.id, totalValue = state.totalSellValue },
        }
    end

    if Config.Shop and Config.Shop.enabled and state.shopItems and #state.shopItems > 0 then
        options[#options + 1] = {
            title = locale('opt_shop'),
            description = locale('opt_shop_desc'),
            icon = 'basket-shopping',
            event = WMining.EV.OPEN_SHOP,
            args = { campId = camp.id, shopItems = state.shopItems },
        }
    end

    lib.registerContext({
        id = WMining.MENU.CAMP_MAIN,
        title = locale('camp_menu_title', locale(camp.label or camp.id)),
        options = options,
    })
    lib.showContext(WMining.MENU.CAMP_MAIN)
end

AddEventHandler(WMining.EV.OPEN_SMELT, function(args)
    if type(args) ~= 'table' then return end
    local options = {}
    for i = 1, #(args.recipes or {}) do
        local r = args.recipes[i]
        options[#options + 1] = {
            title = r.outputLabel,
            description = locale('smelt_recipe_desc', r.reqText, r.maxCraftable),
            icon = 'fire-flame-curved',
            disabled = (r.maxCraftable or 0) < 1,
            event = WMining.EV.DO_SMELT,
            args = { campId = args.campId, recipeId = r.id, label = r.outputLabel, max = r.maxCraftable },
        }
    end

    lib.registerContext({
        id = WMining.MENU.SMELT,
        title = locale('smelt_menu_title'),
        menu = WMining.MENU.CAMP_MAIN,
        options = options,
    })
    lib.showContext(WMining.MENU.SMELT)
end)

AddEventHandler(WMining.EV.DO_SMELT, function(args)
    if busy or type(args) ~= 'table' then return end
    local max = math.min(args.max or 0, Config.MaxBatch or 25)
    if max < 1 then
        notify(locale('err_no_materials'), 'error')
        return
    end

    local qty = 1
    if max > 1 then
        local input = lib.inputDialog(locale('qty_dialog_title', args.label), {
            { type = 'number', label = locale('qty_dialog_label', max), default = 1, min = 1, max = max },
        })
        if not input or not tonumber(input[1]) then return end
        qty = math.floor(tonumber(input[1]))
    end
    if qty < 1 then return end

    busy = true
    local done = lib.progressBar({
        duration = math.min((Config.SmeltMsPerBar or 2500) * qty, 15000),
        label = locale('progress_smelting', qty, args.label),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = { dict = Config.CraftAnimDict, clip = Config.CraftAnimClip, flag = 27 },
    })
    if not done then
        busy = false
        notify(locale('err_cancelled'), 'warning')
        return
    end

    local ok, res = w.callback.await(WMining.CB.SMELT, false, args.campId, args.recipeId, qty)
    busy = false

    if not ok then
        if res == 'cant_carry' then
            notify(locale('err_cant_carry'), 'error')
        elseif res == 'no_materials' then
            notify(locale('err_no_materials'), 'error')
        elseif res == 'too_far' then
            notify(locale('err_too_far'), 'error')
        else
            notify(locale('err_failed'), 'error')
        end
        return
    end

    notify(locale('smelted_done', res.count, args.label), 'success')
end)

AddEventHandler(WMining.EV.DO_CRUSH, function(args)
    if busy or type(args) ~= 'table' then return end
    local max = math.min(args.max or 0, Config.MaxBatch or 25)
    if max < 1 then
        notify(locale('err_no_rocks'), 'warning')
        return
    end

    local qty = max
    if max > 1 then
        local input = lib.inputDialog(locale('opt_crush', max), {
            { type = 'number', label = locale('qty_dialog_label', max), default = max, min = 1, max = max },
        })
        if not input or not tonumber(input[1]) then return end
        qty = math.floor(tonumber(input[1]))
    end
    if qty < 1 then return end

    busy = true
    local done = lib.progressBar({
        duration = math.min((Config.CrushMsPerRock or 1500) * qty, 12000),
        label = locale('progress_crushing', qty),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = { dict = Config.CraftAnimDict, clip = Config.CraftAnimClip, flag = 27 },
    })
    if not done then
        busy = false
        return
    end

    local ok, res = w.callback.await(WMining.CB.CRUSH_ROCK, false, args.campId, qty)
    busy = false

    if not ok then
        notify(locale(res == 'cant_carry' and 'err_cant_carry' or (res == 'too_far' and 'err_too_far' or 'err_failed')), 'error')
        return
    end
    notify(locale('crushed_done', res.crushed, res.summary or ''), 'success')
end)

AddEventHandler(WMining.EV.DO_WASH, function(args)
    if busy or type(args) ~= 'table' then return end
    local max = math.min(args.max or 0, Config.MaxBatch or 25)
    if max < 1 then
        notify(locale('err_no_nuggets'), 'warning')
        return
    end

    local qty = max
    if max > 1 then
        local input = lib.inputDialog(locale('opt_wash', max), {
            { type = 'number', label = locale('qty_dialog_label', max), default = max, min = 1, max = max },
        })
        if not input or not tonumber(input[1]) then return end
        qty = math.floor(tonumber(input[1]))
    end
    if qty < 1 then return end

    busy = true
    local done = lib.progressBar({
        duration = math.min((Config.WashMsPerNugget or 1800) * qty, 12000),
        label = locale('progress_washing', qty),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = { dict = Config.CraftAnimDict, clip = Config.CraftAnimClip, flag = 27 },
    })
    if not done then
        busy = false
        return
    end

    local ok, res = w.callback.await(WMining.CB.WASH_GOLD, false, args.campId, qty)
    busy = false

    if not ok then
        notify(locale(res == 'cant_carry' and 'err_cant_carry' or (res == 'too_far' and 'err_too_far' or 'err_failed')), 'error')
        return
    end
    notify(locale('washed_done', res.count, res.count), 'success')
end)

AddEventHandler(WMining.EV.OPEN_SELL, function(args)
    if type(args) ~= 'table' then return end
    local items = args.items or {}
    if #items == 0 then
        notify(locale('err_bag_empty'), 'inform')
        return
    end

    local options = {}
    for i = 1, #items do
        local row = items[i]
        options[#options + 1] = {
            title = ('%s  —  $%.2f'):format(row.label, row.price),
            description = locale('sell_item_desc', row.count, row.price),
            icon = 'gem',
            event = WMining.EV.SELL_ONE,
            args = { campId = args.campId, item = row.item, label = row.label, max = row.count },
        }
    end

    lib.registerContext({
        id = WMining.MENU.SELL,
        title = locale('sell_menu_title'),
        menu = WMining.MENU.CAMP_MAIN,
        options = options,
    })
    lib.showContext(WMining.MENU.SELL)
end)

AddEventHandler(WMining.EV.SELL_ONE, function(args)
    if busy or type(args) ~= 'table' then return end
    local qty = args.max or 1
    if qty > 1 then
        local input = lib.inputDialog(locale('qty_dialog_title', args.label), {
            { type = 'number', label = locale('qty_dialog_label', qty), default = qty, min = 1, max = qty },
        })
        if not input or not tonumber(input[1]) then return end
        qty = math.floor(tonumber(input[1]))
    end
    if qty < 1 then return end

    busy = true
    local ok, res = w.callback.await(WMining.CB.SELL_ITEM, false, args.campId, args.item, qty)
    busy = false

    if not ok then
        notify(locale(res == 'too_far' and 'err_too_far' or 'err_failed'), 'error')
        return
    end
    notify(locale('sold_item', res.count, args.label, res.payout), 'success')
end)

AddEventHandler(WMining.EV.SELL_ALL, function(args)
    if busy or type(args) ~= 'table' then return end
    local confirm = lib.alertDialog({
        header = locale('confirm_sell_all_header'),
        content = locale('confirm_sell_all_body', args.totalValue or 0),
        cancel = true,
        labels = { confirm = locale('btn_confirm'), cancel = locale('btn_cancel') },
    })
    if confirm ~= 'confirm' then return end

    busy = true
    local ok, res = w.callback.await(WMining.CB.SELL_ALL, false, args.campId)
    busy = false

    if not ok then
        notify(locale(res == 'too_far' and 'err_too_far' or 'err_failed'), 'error')
        return
    end
    notify(locale('sold_all', res.totalCount, res.totalPayout), 'success')
end)

AddEventHandler(WMining.EV.OPEN_SHOP, function(args)
    if type(args) ~= 'table' then return end
    local options = {}
    for i = 1, #(args.shopItems or {}) do
        local s = args.shopItems[i]
        options[#options + 1] = {
            title = ('%s  —  $%.2f'):format(s.label, s.price),
            description = locale('shop_item_desc', s.price, s.count),
            icon = 'cart-shopping',
            event = WMining.EV.BUY_ITEM,
            args = { campId = args.campId, index = s.index, label = s.label },
        }
    end

    lib.registerContext({
        id = WMining.MENU.SHOP,
        title = locale('shop_menu_title'),
        menu = WMining.MENU.CAMP_MAIN,
        options = options,
    })
    lib.showContext(WMining.MENU.SHOP)
end)

AddEventHandler(WMining.EV.BUY_ITEM, function(args)
    if busy or type(args) ~= 'table' then return end
    busy = true
    local ok, res, extra = w.callback.await(WMining.CB.BUY_SUPPLY, false, args.campId, args.index)
    busy = false

    if not ok then
        if res == 'not_enough_money' then
            notify(locale('err_not_enough_money', tonumber(extra) or 0), 'error')
        elseif res == 'cant_carry' then
            notify(locale('err_cant_carry'), 'error')
        elseif res == 'too_far' then
            notify(locale('err_too_far'), 'error')
        else
            notify(locale('err_failed'), 'error')
        end
        return
    end
    notify(locale('bought_supply', res.count, args.label, res.price), 'success')
end)

-- Cleanup helper
local function cleanup()
    if wildPrompt and wildPrompt.remove then wildPrompt.remove() end
    wildPrompt = nil

    for i = 1, #campPrompts do
        if campPrompts[i] and campPrompts[i].remove then campPrompts[i].remove() end
    end
    campPrompts = {}

    for id, pr in pairs(nodePrompts) do
        if pr and pr.remove then pr.remove() end
        nodePrompts[id] = nil
    end

    for id, obj in pairs(nodeObjects) do
        if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
        nodeObjects[id] = nil
    end

    for i = 1, #blips do
        if blips[i] then w.blip.remove(blips[i]) end
    end
    blips = {}

    for id, npc in pairs(campNpcs) do
        if npc and DoesEntityExist(npc) then DeleteEntity(npc) end
        campNpcs[id] = nil
    end
end

CreateThread(function()
    -- Camps & Smelting Furnaces
    for i = 1, #Config.Camps do
        local c = Config.Camps[i]
        local pos = vec3(c.coords.x, c.coords.y, c.coords.z)
        local name = locale(c.label or c.id)

        if Config.CampBlip and Config.CampBlip.enabled then
            blips[i] = w.blip.create(pos, name, Config.CampBlip.sprite, nil, nil, Config.CampBlip.scale)
        end

        campPrompts[i] = w.prompt.at({
            coords = pos,
            distance = Config.InteractDistance or 2.6,
            title = locale('prompt_camp_title', name),
            prompts = {
                {
                    key = Config.Key or 'J',
                    label = locale('prompt_camp_open'),
                    hold = false,
                    onComplete = function()
                        openCampMenu(c)
                    end,
                },
            },
            canInteract = function()
                return not busy
            end,
        })
    end

    -- Mine ore rock prompts
    for i = 1, #Config.MineNodes do
        local n = Config.MineNodes[i]
        nodePrompts[n.id] = w.prompt.at({
            coords = n.coords,
            distance = 2.4,
            title = locale('prompt_rock_title'),
            prompts = {
                {
                    key = Config.Key or 'J',
                    label = locale('prompt_mine_rock'),
                    hold = false,
                    onComplete = function()
                        attemptMine(n.id, n.kind, n.coords)
                    end,
                },
            },
            canInteract = function()
                return not busy and canPlayerMine(PlayerPedId())
            end,
        })
    end

    -- Dynamic wild rock prompt
    if Config.AllowWildRocks then
        wildPrompt = w.prompt.at({
            coords = vec3(0.0, 0.0, 0.0),
            distance = 2.4,
            title = locale('prompt_rock_title'),
            prompts = {
                {
                    key = Config.Key or 'J',
                    label = locale('prompt_mine_rock'),
                    hold = false,
                    onComplete = function()
                        if nearbyWildRock then
                            attemptMine(nearbyWildRock.key, nearbyWildRock.kind, nearbyWildRock.coords)
                        end
                    end,
                },
            },
            canInteract = function()
                return not busy and nearbyWildRock ~= nil and canPlayerMine(PlayerPedId())
            end,
        })
    end

    -- Stream camp NPCs, mine rock props, and scan wild rocks
    local spawnDist = Config.SpawnDistance or 80.0
    local despawnDist = spawnDist + 15.0
    while true do
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)

        -- Camp NPCs
        for i = 1, #Config.Camps do
            local c = Config.Camps[i]
            local pos = vec3(c.coords.x, c.coords.y, c.coords.z)
            local dist = #(pCoords - pos)
            local existing = campNpcs[c.id]

            if dist <= spawnDist and (not existing or not DoesEntityExist(existing)) then
                local hash = loadModel(c.model or 'u_m_m_bht_mineforeman')
                if hash then
                    local npc = CreatePed(hash, c.coords.x, c.coords.y, c.coords.z - 1.0, c.coords.w or 0.0, false, false, false, false)
                    if npc and npc ~= 0 then
                        Citizen.InvokeNative(0x283978A15512B2FE, npc, true)
                        PlaceEntityOnGroundProperly(npc, true)
                        FreezeEntityPosition(npc, true)
                        SetEntityInvincible(npc, true)
                        SetBlockingOfNonTemporaryEvents(npc, true)
                        campNpcs[c.id] = npc
                    end
                    SetModelAsNoLongerNeeded(hash)
                end
            elseif dist > despawnDist and existing then
                if DoesEntityExist(existing) then DeleteEntity(existing) end
                campNpcs[c.id] = nil
            end
        end

        -- Mine rock props
        for i = 1, #Config.MineNodes do
            local n = Config.MineNodes[i]
            local dist = #(pCoords - n.coords)
            local existing = nodeObjects[n.id]

            if dist <= spawnDist and (not existing or not DoesEntityExist(existing)) then
                local hash = loadModel(Config.RockModel or 'mp_sca_rock_grp_l_03')
                if hash then
                    local obj = CreateObject(hash, n.coords.x, n.coords.y, n.coords.z - 1.5, false, false, false)
                    if obj and obj ~= 0 then
                        FreezeEntityPosition(obj, true)
                        nodeObjects[n.id] = obj
                    end
                    SetModelAsNoLongerNeeded(hash)
                end
            elseif dist > despawnDist and existing then
                if DoesEntityExist(existing) then DeleteEntity(existing) end
                nodeObjects[n.id] = nil
            end
        end

        -- Wild rock scan
        if Config.AllowWildRocks and not busy and canPlayerMine(ped) then
            nearbyWildRock = findNearbyWildRock(pCoords)
            if nearbyWildRock and wildPrompt then
                wildPrompt.setCoords(nearbyWildRock.coords)
            end
        else
            nearbyWildRock = nil
        end

        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    cleanup()
end)
