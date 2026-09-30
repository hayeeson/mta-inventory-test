_SHARED = {
    Inventory = {
        SlotShop = {
            SlotsPerPurchase = 5;
            Price = 30;
            CurrencyElementData = 'Coins';
            CurrencyName = 'Coins';
        };
        MaxWeight = 10;
        MaxSlots = 100;
        DefaultSlots = 5;
        HotbarFirstSlotId = 100;
        HotbarSlotCount = 5;
    };
    Commands = {
        GiveItem = 'giveitem';
        RemoveItem = 'removeitem';
        ResetInventory = 'resetinv';
        ViewInventory = 'verinv';
        SetSlots = 'setslots';
        GiveCoins = 'givecoins';
        Itens = 'itens';
    };
    Items = {
        [1] = {name = 'Hamburguer', desc = '', weight = 8, stack = 999, price = 2.5, type = 'food', lostonDeath = true};
        [2] = {name = 'Bandagem', desc = 'Cura 25 vida', weight = 0.2, stack = 5, price = 10, type = 'others', lostonDeath = true};
        [3] = {name = 'Coca-cola', desc = '', weight = 0.2, stack = 5, price = 10, type = 'food', lostonDeath = true};
        [4] = {name = 'M4', desc = '', weight = 5, stack = 5, price = 10, type = 'weapons', lostonDeath = true};
        [5] = {name = 'AK-47', desc = '', weight = 5, stack = 5, price = 10, type = 'weapons', lostonDeath = true};
    };
}

function getItemImage(itemId)
    return ('assets/images/items/%d.png'):format(itemId);
end