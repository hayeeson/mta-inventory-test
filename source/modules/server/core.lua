local VAR = {
    PlayerInventories = {};
    BuyCooldown = {};
    BuyCooldownMs = 500;
};

local function isInteger(value)
    return type(value) == 'number' and value == math.floor(value) and math.abs(value) < 2147483647;
end

local function isValidAmount(value)
    return isInteger(value) and value >= 1;
end

local function isPlayer(element)
    return isElement(element) and getElementType(element) == 'player';
end

local function getStackLimit(itemId)
    local itemConfig = _SHARED.Items[itemId];
    return itemConfig and itemConfig.stack or 1;
end

local function getHotbarSlotIds()
    local settings = _SHARED.Inventory;
    local slotIds = {};

    for hotbarIndex = 1, settings.HotbarSlotCount do
        slotIds[hotbarIndex] = settings.HotbarFirstSlotId + hotbarIndex;
    end

    return slotIds;
end

local function getAllSlotIds(data)
    local slotIds = {};

    for slotNumber = 1, data.unlockedSlots do
        slotIds[#slotIds + 1] = slotNumber;
    end

    for _, hotbarSlotId in ipairs(getHotbarSlotIds()) do
        slotIds[#slotIds + 1] = hotbarSlotId;
    end

    return slotIds;
end

local function getOwnerKey(player)
    local account = getPlayerAccount(player);

    if account and not isGuestAccount(account) then
        return 'account:' .. getAccountName(account);
    end

    return 'serial:' .. getPlayerSerial(player);
end

local function isHotbarSlot(slotId)
    local settings = _SHARED.Inventory;
    return slotId > settings.HotbarFirstSlotId and slotId <= settings.HotbarFirstSlotId + settings.HotbarSlotCount;
end

local function isValidSlot(data, slotId)
    if not isInteger(slotId) then 
        return false 
    end

    if isHotbarSlot(slotId) then 
        return true 
    end

    return slotId >= 1 and slotId <= data.unlockedSlots;
end

local function getStackRoom(data, itemId, stackLimit)
    local room = 0;

    for slotNumber = 1, data.unlockedSlots do
        local slotItem = data.items[slotNumber];

        if not slotItem then
            room = room + stackLimit;
        elseif slotItem.itemId == itemId then
            room = room + math.max(0, stackLimit - slotItem.amount);
        end
    end

    for _, hotbarSlotId in ipairs(getHotbarSlotIds()) do
        local slotItem = data.items[hotbarSlotId];

        if slotItem and slotItem.itemId == itemId then
            room = room + math.max(0, stackLimit - slotItem.amount);
        end
    end

    return room;
end

local function calculateWeight(data)
    local totalWeight = 0;

    for _, slotItem in pairs(data.items) do
        local itemConfig = _SHARED.Items[slotItem.itemId];

        if itemConfig then
            totalWeight = totalWeight + (itemConfig.weight or 0) * slotItem.amount;
        end
    end

    return totalWeight;
end

function getInventoryData(player)
    local data = VAR.PlayerInventories[player];

    if data and data.loaded then
        return data;
    end
end

function syncPlayerInventory(player)
    local data = getInventoryData(player);
    if not data then 
        return 
    end

    triggerClientEvent(player, 'inventory:sync', resourceRoot, data.items, data.unlockedSlots, calculateWeight(data));
end

local function commitInventory(player)
    local data = VAR.PlayerInventories[player];
    if not data then return end

    data.dirty = true;
    syncPlayerInventory(player);
end

function getInventoryItemCount(player, itemId)
    if not isPlayer(player) then return 0 end

    local data = getInventoryData(player);
    if not data then return 0 end

    local total = 0;

    for _, slotItem in pairs(data.items) do
        if slotItem.itemId == itemId then
            total = total + slotItem.amount;
        end
    end

    return total;
end

local function getAddableAmount(player, itemId, amount)
    local data = getInventoryData(player);
    local itemConfig = _SHARED.Items[itemId];

    if not data or not itemConfig or not isValidAmount(amount) then
        return 0;
    end

    local room = getStackRoom(data, itemId, itemConfig.stack or 1);
    local unitWeight = itemConfig.weight or 0;

    if unitWeight > 0 then
        local freeWeight = math.max(0, _SHARED.Inventory.MaxWeight - calculateWeight(data));
        room = math.min(room, math.floor(freeWeight / unitWeight + 0.000001));
    end

    return math.min(amount, room);
end

function giveInventoryItem(player, itemId, amount)
    if not isPlayer(player) then return 0 end

    local data = getInventoryData(player);
    local addable = getAddableAmount(player, itemId, amount);

    if not data or addable < 1 then
        return 0;
    end

    local stackLimit = getStackLimit(itemId);
    local remaining = addable;

    for _, slotId in ipairs(getAllSlotIds(data)) do
        if remaining < 1 then break end

        local slotItem = data.items[slotId];

        if slotItem and slotItem.itemId == itemId and slotItem.amount < stackLimit then
            local moved = math.min(remaining, stackLimit - slotItem.amount);
            slotItem.amount = slotItem.amount + moved;
            remaining = remaining - moved;
        end
    end

    for slotNumber = 1, data.unlockedSlots do
        if remaining < 1 then break end

        if not data.items[slotNumber] then
            local moved = math.min(remaining, stackLimit);
            data.items[slotNumber] = { itemId = itemId, amount = moved };
            remaining = remaining - moved;
        end
    end

    commitInventory(player);
    return addable - remaining;
end

function takeInventoryItem(player, itemId, amount)
    if not isPlayer(player) then 
        return false 
    end

    local data = getInventoryData(player);
    if not data or not isValidAmount(amount) then 
        return false 
    end

    if getInventoryItemCount(player, itemId) < amount then 
        return false 
    end

    local remaining = amount;
    for _, slotId in ipairs(getAllSlotIds(data)) do
        if remaining < 1 then break end

        local slotItem = data.items[slotId];

        if slotItem and slotItem.itemId == itemId then
            local taken = math.min(remaining, slotItem.amount);
            slotItem.amount = slotItem.amount - taken;
            remaining = remaining - taken;

            if slotItem.amount < 1 then
                data.items[slotId] = nil;
            end
        end
    end
    commitInventory(player);
    return true;
end

function takeInventoryFromSlot(player, slotId, amount)
    local data = getInventoryData(player);

    if not data or not isValidSlot(data, slotId) or not isValidAmount(amount) then
        return false;
    end

    local slotItem = data.items[slotId];
    if not slotItem or slotItem.amount < amount then return false end

    slotItem.amount = slotItem.amount - amount;

    if slotItem.amount < 1 then
        data.items[slotId] = nil;
    end

    commitInventory(player);
    return true;
end

function moveInventoryItem(player, fromSlot, toSlot, amount)
    local data = getInventoryData(player);
    if not data or fromSlot == toSlot then 
        return false 
    end

    if not isValidSlot(data, fromSlot) or not isValidSlot(data, toSlot) then 
        return false 
    end

    if not isValidAmount(amount) then 
        return false 
    end

    local origin = data.items[fromSlot];
    if not origin or amount > origin.amount then 
        return false 
    end

    local target = data.items[toSlot];

    if not target then
        if amount == origin.amount then
            data.items[toSlot] = origin;
            data.items[fromSlot] = nil;
        else
            origin.amount = origin.amount - amount;
            data.items[toSlot] = { itemId = origin.itemId, amount = amount };
        end

    elseif target.itemId == origin.itemId then
        local moved = math.min(amount, getStackLimit(origin.itemId) - target.amount);
        if moved < 1 then return false end

        target.amount = target.amount + moved;
        origin.amount = origin.amount - moved;

        if origin.amount < 1 then
            data.items[fromSlot] = nil;
        end

    elseif amount == origin.amount then
        data.items[fromSlot], data.items[toSlot] = target, origin;
    else
        return false;
    end

    commitInventory(player);
    return true;
end

function setInventoryUnlockedSlots(player, amount)
    local data = getInventoryData(player);
    if not data or not isInteger(amount) then 
        return false 
    end

    amount = math.max(1, math.min(_SHARED.Inventory.MaxSlots, amount));

    for slotId in pairs(data.items) do
        if slotId > amount and not isHotbarSlot(slotId) then
            return false;
        end
    end

    data.unlockedSlots = amount;
    commitInventory(player);
    return true;
end

function removeInventoryDeathLosses(player)
    local data = getInventoryData(player);
    if not data then 
        return 0 
    end

    local lostStacks = 0;

    for slotId, slotItem in pairs(data.items) do
        local itemConfig = _SHARED.Items[slotItem.itemId];

        if itemConfig and itemConfig.lostonDeath then
            data.items[slotId] = nil;
            lostStacks = lostStacks + 1;
        end
    end

    if lostStacks > 0 then
        commitInventory(player);
    end

    return lostStacks;
end

function savePlayerInventory(player)
    local data = VAR.PlayerInventories[player];
    if not data or not data.loaded or not data.dirty then 
        return false 
    end

    if saveInventoryData(data.owner, data.items, data.unlockedSlots) then
        data.dirty = false;
        return true;
    end

    return false;
end

function loadPlayerInventory(player)
    local owner = getOwnerKey(player);
    local current = VAR.PlayerInventories[player];

    if current and current.owner == owner then 
        return 
    end

    if current then
        savePlayerInventory(player);
    end

    local data = {
        owner = owner;
        items = {};
        unlockedSlots = _SHARED.Inventory.DefaultSlots;
        loaded = false;
        dirty = false;
    };

    VAR.PlayerInventories[player] = data;

    loadInventoryData(owner, function(result)
        if VAR.PlayerInventories[player] ~= data or not isElement(player) then 
            return 
        end

        if not result then
            Notify.server(player, 'Não foi possível carregar seu inventário. Avise a administração.', 'error');
            return;
        end

        data.items = result.items;
        data.unlockedSlots = result.unlockedSlots or data.unlockedSlots;
        data.loaded = true;
        data.dirty = not result.exists;

        syncPlayerInventory(player);
    end);
end

function saveAllInventories()
    for player in pairs(VAR.PlayerInventories) do
        savePlayerInventory(player);
    end
end

function unloadPlayerInventory(player)
    savePlayerInventory(player);

    VAR.PlayerInventories[player] = nil;
    VAR.BuyCooldown[player] = nil;
end

local function buyInventorySlots(player)
    local function reply(success, message)
        triggerClientEvent(player, 'inventory:buySlotsResult', resourceRoot, success, message);
    end

    local data = getInventoryData(player);
    if not data then
        reply(false, 'Inventário ainda não carregado');
        return false;
    end

    local now = getTickCount();
    local lastBuy = VAR.BuyCooldown[player];
    if lastBuy and now - lastBuy < VAR.BuyCooldownMs then
        reply(false, 'Aguarde um instante');
        return false;
    end
    VAR.BuyCooldown[player] = now;

    local shop = _SHARED.Inventory.SlotShop;
    local newUnlockedSlots = data.unlockedSlots + shop.SlotsPerPurchase;

    if newUnlockedSlots > _SHARED.Inventory.MaxSlots then
        reply(false, 'Você já atingiu o limite de slots');
        return false;
    end

    local balance = tonumber(getElementData(player, shop.CurrencyElementData)) or 0;
    if balance < shop.Price then
        reply(false, 'Saldo insuficiente');
        return false;
    end

    if not setInventoryUnlockedSlots(player, newUnlockedSlots) then
        reply(false, 'Não foi possível liberar os slots');
        return false;
    end

    setElementData(player, shop.CurrencyElementData, balance - shop.Price);
    savePlayerInventory(player);
    reply(true);
    return true;
end

addEventHandler('onResourceStart', resourceRoot, function()
    if not connectInventoryDatabase() then 
        return 
    end

    for _, player in ipairs(getElementsByType('player')) do
        loadPlayerInventory(player);
    end

    setTimer(saveAllInventories, 30000, 0);
end);

addEventHandler('onResourceStop', resourceRoot, saveAllInventories);
addEventHandler('onPlayerJoin', root, function() loadPlayerInventory(source) end);
addEventHandler('onPlayerLogin', root, function() loadPlayerInventory(source) end);
addEventHandler('onPlayerLogout', root, function() loadPlayerInventory(source) end);
addEventHandler('onPlayerQuit', root, function() unloadPlayerInventory(source) end);

addEvent('inventory:request', true);
addEventHandler('inventory:request', resourceRoot, function()
    syncPlayerInventory(client);
end);

addEvent('inventory:move', true);
addEventHandler('inventory:move', resourceRoot, function(fromSlot, toSlot, amount)
    moveInventoryItem(client, tonumber(fromSlot), tonumber(toSlot), tonumber(amount));
end);

addEvent('inventory:buySlots', true);
addEventHandler('inventory:buySlots', resourceRoot, function()
    buyInventorySlots(client);
end);

addEventHandler('onPlayerWasted', root, function()
    removeInventoryDeathLosses(source);
end);

-- addCommandHandler('invdebug', function(player)
--     local data = VAR.PlayerInventories[player];
--     outputChatBox('existe: ' .. tostring(data ~= nil), player);
--     outputChatBox('loaded: ' .. tostring(data and data.loaded), player);
--     outputChatBox('owner: ' .. tostring(data and data.owner), player);
-- end);

function isInventorySlotValid(player, slotId)
    local data = getInventoryData(player);
    return data ~= nil and isValidSlot(data, slotId);
end

function getInventoryAddableAmount(player, itemId, amount)
    return getAddableAmount(player, itemId, amount);
end

function clearInventory(player, resetSlots)
    local data = getInventoryData(player);
    if not data then 
        return false 
    end

    data.items = {};

    if resetSlots then
        data.unlockedSlots = _SHARED.Inventory.DefaultSlots;
    end

    commitInventory(player);
    savePlayerInventory(player);
    return true;
end