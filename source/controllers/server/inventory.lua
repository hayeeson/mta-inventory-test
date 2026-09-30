local VAR = {
    Action = {
        Id = 'inventory_action';
        CooldownMs = 500;
    };

    Send = {
        MaxDistance = 3;
        IdElementData = 'ID';
    };

    Drop = {
        LifetimeMs = 10 * 60 * 1000;
        DefaultModel = 1271;
        SpawnDistance = 0.8;
        SpawnHeightOffset = 0.85;
    };

    Pickup = {
        MaxDistance = 2.5;
        AnimationBlock = 'CARRY';
        AnimationName = 'liftup';
        AnimationMs = 1100;
        GiveItemAfterMs = 700;
    };

    DroppedItems = {};
    PickingUp = {};
};

local function canDoAction(player)
    local rateLimitId = GetPlayerRateLimitId(player);
    return rateLimitId ~= nil and CanExecute(rateLimitId, VAR.Action.Id, VAR.Action.CooldownMs);
end

local function getSlotItem(player, slotId)
    if not isInventorySlotValid(player, slotId) then return end

    local data = getInventoryData(player);
    return data and data.items[slotId];
end

local function clampAmount(value, maxAmount)
    value = math.floor(tonumber(value) or maxAmount);
    return math.max(1, math.min(value, maxAmount));
end

local function getPlayerByServerId(serverId)
    for _, otherPlayer in ipairs(getElementsByType('player')) do
        if tonumber(getElementData(otherPlayer, VAR.Send.IdElementData)) == serverId then
            return otherPlayer;
        end
    end
end

local function arePlayersClose(player, otherPlayer, maxDistance)
    local isSameWorld = getElementInterior(player) == getElementInterior(otherPlayer)
        and getElementDimension(player) == getElementDimension(otherPlayer);
    if not isSameWorld then return false end

    local playerX, playerY, playerZ = getElementPosition(player);
    local otherX, otherY, otherZ = getElementPosition(otherPlayer);
    return getDistanceBetweenPoints3D(playerX, playerY, playerZ, otherX, otherY, otherZ) <= maxDistance;
end

local function getRotationToPoint(fromX, fromY, toX, toY)
    local rotation = -math.deg(math.atan2(toX - fromX, toY - fromY));
    return rotation < 0 and rotation + 360 or rotation;
end

local function useItem(player, slotId)
    if not canDoAction(player) then 
        return false 
    end

    local slotItem = getSlotItem(player, slotId);
    if not slotItem then 
        return false 
    end

    local itemAction = ItemActions[slotItem.itemId];
    if not itemAction then 
        return false 
    end

    if itemAction(player, slotItem, slotId) then
        takeInventoryFromSlot(player, slotId, 1);
    end

    return true;
end

local function dropItem(player, slotId, dropAmount)
    if not canDoAction(player) or isPedInVehicle(player) then 
        return false 
    end

    local slotItem = getSlotItem(player, slotId);
    local itemConfig = slotItem and _SHARED.Items[slotItem.itemId];
    if not itemConfig then 
        return false 
    end

    dropAmount = clampAmount(dropAmount, slotItem.amount);
    local droppedItem = { itemId = slotItem.itemId, amount = dropAmount };
    if not takeInventoryFromSlot(player, slotId, dropAmount) then 
        return false 
    end

    local playerX, playerY, playerZ = getElementPosition(player);
    local _, _, playerRotation = getElementRotation(player);
    local dropX = playerX - math.sin(math.rad(playerRotation)) * VAR.Drop.SpawnDistance;
    local dropY = playerY + math.cos(math.rad(playerRotation)) * VAR.Drop.SpawnDistance;
    local dropZ = playerZ - VAR.Drop.SpawnHeightOffset;
    local droppedObject = createObject(itemConfig.dropModel or VAR.Drop.DefaultModel, dropX, dropY, dropZ);
    setElementInterior(droppedObject, getElementInterior(player));
    setElementDimension(droppedObject, getElementDimension(player));
    setElementCollisionsEnabled(droppedObject, false);

    VAR.DroppedItems[droppedObject] = droppedItem;
    setElementData(droppedObject, 'droppedItem', { itemId = droppedItem.itemId, amount = droppedItem.amount });

    setTimer(function()
        if isElement(droppedObject) then
            destroyElement(droppedObject);
        end
        VAR.DroppedItems[droppedObject] = nil;
    end, VAR.Drop.LifetimeMs, 1);
    return true;
end

local function sendItem(player, slotId, sendAmount, targetId)
    if not canDoAction(player) then 
        return false
    end

    local slotItem = getSlotItem(player, slotId);
    if not slotItem then 
        return false 
    end

    local receiver = targetId and getPlayerByServerId(targetId);
    if not receiver then
        Notify.server(player, 'Nenhum jogador encontrado com esse ID.', 'error');
        return false;
    end
    if receiver == player then
        Notify.server(player, 'Você não pode enviar um item para você mesmo.', 'error');
        return false;
    end
    if not arePlayersClose(player, receiver, VAR.Send.MaxDistance) then
        Notify.server(player, 'Esse jogador está longe demais.', 'error');
        return false;
    end

    sendAmount = clampAmount(sendAmount, slotItem.amount);

    local amountReceived = giveInventoryItem(receiver, slotItem.itemId, sendAmount);
    if amountReceived <= 0 then
        Notify.server(player, 'O jogador não tem espaço ou peso disponível.', 'error');
        return false;
    end

    takeInventoryFromSlot(player, slotId, amountReceived);

    local itemName = _SHARED.Items[slotItem.itemId].name;
    Notify.server(player, ('Você enviou %dx %s para %s.'):format(amountReceived, itemName, getPlayerName(receiver)), 'success');
    Notify.server(receiver, ('Você recebeu %dx %s de %s.'):format(amountReceived, itemName, getPlayerName(player)), 'success');
    return true;
end

-- ===== pegar do chão =====

local function pickupNearestItem(player)
    if isPedInVehicle(player) or isPedDead(player) then 
        return false 
    end

    if VAR.PickingUp[player] then 
        return false 
    end

    if not getInventoryData(player) then 
        return false 
    end

    local playerX, playerY, playerZ = getElementPosition(player);
    local interior, dimension = getElementInterior(player), getElementDimension(player);
    local nearestObject, nearestDistance = nil, VAR.Pickup.MaxDistance;

    for droppedObject, droppedItem in pairs(VAR.DroppedItems) do
        local isAvailable = isElement(droppedObject)
            and not droppedItem.reservedBy
            and getElementInterior(droppedObject) == interior
            and getElementDimension(droppedObject) == dimension;

        if isAvailable then
            local objectX, objectY, objectZ = getElementPosition(droppedObject);
            local distance = getDistanceBetweenPoints3D(playerX, playerY, playerZ, objectX, objectY, objectZ);
            if distance <= nearestDistance then
                nearestObject, nearestDistance = droppedObject, distance;
            end
        end
    end

    if not nearestObject then 
        return false 
    end

    local droppedItem = VAR.DroppedItems[nearestObject];

    if getInventoryAddableAmount(player, droppedItem.itemId, droppedItem.amount) <= 0 then
        Notify.server(player, 'Sem espaço ou peso disponível para pegar este item.', 'error');
        return false;
    end

    VAR.PickingUp[player] = true;
    droppedItem.reservedBy = player;

    local objectX, objectY = getElementPosition(nearestObject);
    setPedRotation(player, getRotationToPoint(playerX, playerY, objectX, objectY));
    setPedAnimation(player, VAR.Pickup.AnimationBlock, VAR.Pickup.AnimationName, VAR.Pickup.AnimationMs, false, false, false, false);
    triggerClientEvent(player, 'inventory:pickupStarted', resourceRoot, VAR.Pickup.AnimationMs);

    setTimer(function()
        local isItemStillThere = isElement(nearestObject) and VAR.DroppedItems[nearestObject] == droppedItem;

        if isItemStillThere and isElement(player) and not isPedDead(player) then
            local amountPickedUp = giveInventoryItem(player, droppedItem.itemId, droppedItem.amount);
            droppedItem.amount = droppedItem.amount - amountPickedUp;

            if droppedItem.amount <= 0 then
                destroyElement(nearestObject);
                VAR.DroppedItems[nearestObject] = nil;
            else
                setElementData(nearestObject, 'droppedItem', { itemId = droppedItem.itemId, amount = droppedItem.amount });
            end
        end
        droppedItem.reservedBy = nil;
    end, VAR.Pickup.GiveItemAfterMs, 1);
    setTimer(function()
        VAR.PickingUp[player] = nil;
    end, VAR.Pickup.AnimationMs, 1);
    return true;
end

addEvent('inventory:use', true);
addEventHandler('inventory:use', resourceRoot, function(slotId)
    useItem(client, tonumber(slotId));
end);

addEvent('inventory:drop', true);
addEventHandler('inventory:drop', resourceRoot, function(slotId, dropAmount)
    dropItem(client, tonumber(slotId), tonumber(dropAmount));
end);

addEvent('inventory:send', true);
addEventHandler('inventory:send', resourceRoot, function(slotId, sendAmount, targetId)
    sendItem(client, tonumber(slotId), tonumber(sendAmount), tonumber(targetId));
end);

addEvent('inventory:pickup', true);
addEventHandler('inventory:pickup', resourceRoot, function()
    pickupNearestItem(client);
end);

addEventHandler('onPlayerQuit', root, function()
    VAR.PickingUp[source] = nil;
end);

function giveItem(player, itemId, amount)
    return giveInventoryItem(player, tonumber(itemId), math.floor(tonumber(amount) or 1));
end

function removeItem(player, itemId, amount)
    return takeInventoryItem(player, tonumber(itemId), math.floor(tonumber(amount) or 1));
end

function getItemAmount(player, itemId)
    return getInventoryItemCount(player, tonumber(itemId));
end

function hasItem(player, itemId, amount)
    return getInventoryItemCount(player, tonumber(itemId)) >= (amount or 1);
end

-- addCommandHandler('daritem', function(player, _, itemId, amount)
--     if not hasObjectPermissionTo(player, 'function.kickPlayer', false) then return end

--     local amountGiven = giveItem(player, itemId, amount);
--     outputChatBox('Itens adicionados: ' .. amountGiven, player);
-- end);

-- addCommandHandler('darcoins', function(player, _, amount)
--     if not hasObjectPermissionTo(player, 'function.kickPlayer', false) then return end

--     amount = tonumber(amount);
--     if not amount then
--         outputChatBox('Uso: /darcoins [quantidade]', player, 255, 100, 100);
--         return;
--     end

--     local shop = _SHARED.Inventory.SlotShop;
--     local newBalance = math.max(0, (tonumber(getElementData(player, shop.CurrencyElementData)) or 0) + amount);

--     setElementData(player, shop.CurrencyElementData, newBalance);
--     outputChatBox(('Saldo de %s: %d'):format(shop.CurrencyName, newBalance), player, 100, 255, 100);
-- end);