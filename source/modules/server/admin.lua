local VAR = {
    Permission = 'function.kickPlayer';
    IdElementData = 'ID';
};

local function isAdmin(player)
    return hasObjectPermissionTo(player, VAR.Permission, false);
end

local function findPlayerById(serverId)
    if not serverId then 
        return
    end

    for _, otherPlayer in ipairs(getElementsByType('player')) do
        if tonumber(getElementData(otherPlayer, VAR.IdElementData)) == serverId then
            return otherPlayer;
        end
    end
end

local function toPositiveInteger(value)
    value = tonumber(value);
    if not value or value ~= math.floor(value) or value < 1 then 
        return 
    end
    return value;
end

local function getItemName(itemId)
    local itemConfig = _SHARED.Items[itemId];
    return itemConfig and itemConfig.name or ('Item ' .. tostring(itemId));
end

local function logAction(admin, message)
    local adminId = getElementData(admin, VAR.IdElementData) or '?';
    outputServerLog(('[INVENTORY][ADMIN] %s (ID %s): %s'):format(getPlayerName(admin), tostring(adminId), message));
end

local function getTarget(admin, idArgument)
    local serverId = toPositiveInteger(idArgument);
    local target = findPlayerById(serverId);

    if not target then
        Notify.server(admin, 'Nenhum jogador encontrado com esse ID.', 'error');
        return;
    end

    if not getInventoryData(target) then
        Notify.server(admin, 'O inventário desse jogador ainda não carregou.', 'error');
        return;
    end
    return target, serverId;
end

local function adminCommand(name, handler)
    addCommandHandler(name, function(admin, _, ...)
        if not isAdmin(admin) then 
            return 
        end
        handler(admin, ...);
    end);
end

adminCommand(_SHARED.Commands.GiveItem, function(admin, idArgument, itemArgument, amountArgument)
    local itemId = toPositiveInteger(itemArgument);
    local amount = amountArgument and toPositiveInteger(amountArgument) or 1;

    if not idArgument or not itemId or not amount then
        Notify.server(admin, 'Uso: /giveitem [id] [itemId] [quantidade]', 'info');
        return;
    end

    if not _SHARED.Items[itemId] then
        Notify.server(admin, 'Esse item não existe. Use /itens para ver a lista.', 'error');
        return;
    end

    local target, serverId = getTarget(admin, idArgument);
    if not target then 
        return 
    end

    local added = giveInventoryItem(target, itemId, amount);

    if added <= 0 then
        Notify.server(target, 'Nenhum item foi adicionado: o jogador estava sem espaço ou peso.', 'error');
        return;
    end

    local itemName = getItemName(itemId);
    Notify.server(admin, ('Voce deu %dx %s para o ID %d.'):format(added, itemName, serverId), 'info');

    if added < amount then
        Notify.server(target, ('A administração deu %d de %d (espaço ou peso).'):format(added, amount), 'info');
    end

    Notify.server(target, ('Você recebeu %dx %s da administração.'):format(added, itemName), 'info');
    logAction(admin, ('giveitem ID %d item %d x%d'):format(serverId, itemId, added));
end);

adminCommand(_SHARED.Commands.RemoveItem, function(admin, idArgument, itemArgument, amountArgument)
    local itemId = toPositiveInteger(itemArgument);
    local amount = amountArgument and toPositiveInteger(amountArgument) or 1;

    if not idArgument or not itemId or not amount then
        Notify.server(admin, 'Uso: /removeitem [id] [itemId] [quantidade]', 'info');
        return;
    end

    local target, serverId = getTarget(admin, idArgument);
    if not target then 
        return 
    end

    local currentAmount = getInventoryItemCount(target, itemId);

    if currentAmount < 1 then
        Notify.server(admin, 'O jogador nao tem esse item.', 'error');
        return;
    end

    local amountToRemove = math.min(amount, currentAmount);

    if not takeInventoryItem(target, itemId, amountToRemove) then
        Notify.server(target, 'Nenhum item foi removido: o jogador estava sem espaço ou peso.', 'error');
        return;
    end

    local itemName = getItemName(itemId);
    Notify.server(admin, ('A administração removeu %dx %s do ID %d.'):format(amountToRemove, itemName, serverId), 'info');
    Notify.server(target, ('A administração removeu %dx %s do seu inventário.'):format(amountToRemove, itemName), 'info');
    logAction(admin, ('removeitem ID %d item %d x%d'):format(serverId, itemId, amountToRemove));
end);

adminCommand(_SHARED.Commands.ResetInventory, function(admin, idArgument, resetSlotsArgument)
    if not idArgument then
        Notify.server(admin, 'Resetar slots: /resetinv [id] slots', 'info');
        return;
    end

    local target, serverId = getTarget(admin, idArgument);
    if not target then 
        return 
    end

    local resetSlots = resetSlotsArgument == 'slots';

    if not clearInventory(target, resetSlots) then
        Notify.server(admin, 'Não foi possível resetar o inventário.', 'error');
        return;
    end

    Notify.server(admin, ('Inventário do ID %d resetado%s.'):format(serverId, resetSlots and ' (slots voltaram ao padrão)' or ''), 'info');
    Notify.server(target, 'Seu inventário foi resetado pela administração.', 'info');
    logAction(admin, ('resetinv ID %d (slots: %s)'):format(serverId, tostring(resetSlots)));
end);

adminCommand(_SHARED.Commands.ViewInventory, function(admin, idArgument)
    if not idArgument then
        Notify.server(admin, 'Uso: /verinv [id]', 'info');
        return;
    end

    local target, serverId = getTarget(admin, idArgument);
    if not target then 
        return 
    end

    local data = getInventoryData(target);

    local slotIds = {};
    for slotId in pairs(data.items) do
        slotIds[#slotIds + 1] = slotId;
    end
    table.sort(slotIds);

    Notify.server(admin, ('Inventário do ID %d: %d/%d slots liberados, %d slots ocupados.'):format(serverId, data.unlockedSlots, _SHARED.Inventory.MaxSlots, #slotIds), 'info');

    for _, slotId in ipairs(slotIds) do
        local slotItem = data.items[slotId];
        Notify.server(admin, ('  [slot %d] %s (id %d) x%d'):format(slotId, getItemName(slotItem.itemId), slotItem.itemId, slotItem.amount), 'info');
    end

    if #slotIds == 0 then
        Notify.server(admin, ' (vazio)', 'info');
    end
end);

adminCommand(_SHARED.Commands.SetSlots, function(admin, idArgument, amountArgument)
    local amount = toPositiveInteger(amountArgument);

    if not idArgument or not amount then
        Notify.server(admin, 'Uso: /setslots [id] [quantidade]', 'info');
        return;
    end

    local target, serverId = getTarget(admin, idArgument);
    if not target then 
        return 
    end

    if not setInventoryUnlockedSlots(target, amount) then
        Notify.server(admin, 'Não foi possível: ainda tem item nos slots que seriam removidos.', 'error');
        return;
    end

    savePlayerInventory(target);

    local finalAmount = getInventoryData(target).unlockedSlots;
    Notify.server(admin, ('O ID %d agora tem %d slots.'):format(serverId, finalAmount, _SHARED.Inventory.MaxSlots), 'info');
    logAction(admin, ('setslots ID %d -> %d'):format(serverId, finalAmount));
end);

adminCommand(_SHARED.Commands.GiveCoins, function(admin, idArgument, amountArgument)
    local amount = tonumber(amountArgument);

    if not idArgument or not amount or amount == 0 then
        Notify.server(admin, 'Uso: /givecoins [id] [quantidade] (negativo remove)', 'info');
        return;
    end

    local serverId = toPositiveInteger(idArgument);
    local target = findPlayerById(serverId);

    if not target then
        Notify.server(admin, 'Nenhum jogador encontrado com esse ID.', 'error');
        return;
    end

    local shop = _SHARED.Inventory.SlotShop;
    local currentBalance = tonumber(getElementData(target, shop.CurrencyElementData)) or 0;
    local newBalance = math.max(0, currentBalance + amount);

    setElementData(target, shop.CurrencyElementData, newBalance);

    Notify.server(admin, ('Saldo do ID %d: %d %s.'):format(serverId, newBalance, shop.CurrencyName), 'info');
    Notify.server(target, ('Seu saldo de %s agora é %d.'):format(shop.CurrencyName, newBalance), 'info');
    logAction(admin, ('givecoins ID %d %+d (saldo %d)'):format(serverId, amount, newBalance));
end);

adminCommand(_SHARED.Commands.Itens, function(admin)
    local itemIds = {};
    for itemId in pairs(_SHARED.Items) do
        itemIds[#itemIds + 1] = itemId;
    end
    table.sort(itemIds);

    Notify.server(admin, #itemIds .. ' itens disponíveis.', 'info');
    for _, itemId in ipairs(itemIds) do
        outputChatBox(('  [%d] %s'):format(itemId, getItemName(itemId)), admin);
    end
end);