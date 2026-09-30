local VAR = {
    Slots = {
        SlotsUnlocked = 10;
        SlotsLocked = 20;
        MaxSlotsInScreen = 30;
        MaxSlotsInRow = 5;
        Positions = {
            SlotWidth = 68;
            SlotHeight = 68;
            SlotX = 800;
            SlotY = 376;
            SlotSpacing = 8;
        };
        Scrollbar = {
            X = 1182;
            Width = 4;
        };
    };
    Hotbar = {
        FirstSlotId = 100;
        SlotCount = 5;
        SlotY = 255;
    };
    Categories = {
        initial = 'user';
        Button = {
            X = 750;
            Width = 35;
            Height = 38;
        };
        List = {
            {id = 'user', iconX = 761, iconY = 516, iconWidth = 14, iconHeight = 18};
            {id = 'food', iconX = 758, iconY = 554, iconWidth = 18, iconHeight = 18};
            {id = 'weapon', iconX = 757, iconY = 592, iconWidth = 21.3, iconHeight = 18.3};
            {id = 'others', iconX = 757, iconY = 630, iconWidth = 20, iconHeight = 20};
        };
    };
    Weight = {
        BarX = { 800, 894, 988, 1083 };
    };
    ContextMenu = {
        Width = 120;
        OptionHeight = 30;
        Padding = 4;
        Options = {
            { id = 'use',  label = 'Usar' };
            { id = 'drop', label = 'Dropar' };
            { id = 'send', label = 'Enviar' };
        };
    };
    Pickup = {
        Key = 'j';
        PromptDistance = 2;
        ScanIntervalMs = 150;
        Prompt = {X = 830; Y = 900; Width = 260; Height = 48;};
    };
    LockedModal = {
        X = 829;
        Y = 700;
        Width = 315;
        Height = 88;
    };
    State = {
        isOpen = false;
        fade = 0;
        items = {};
        carriedWeight = 0;
        selectedCategory = nil;
        hoveredSlot = nil;
        hoveredCategory = nil;
        draggedSlot = nil;
        tooltipItemId = nil;
        contextSlot = nil;
        contextMenuX = 0;
        contextMenuY = 0;
        hoveredContextOption = nil;
        nearbyDrop = nil;
        promptItemId = nil;
        promptAmount = 1;
        pickupLockedUntil = 0;
        hoveredModalButton = nil;
        scrollRow = 0;
        hoveredLockedModal = false;
        hoveredPurchaseButton = nil;
        sendModal = {
            isOpen = false;
            slotId = nil;
            itemId = nil;
            amount = 1;
            nearbyIds = {};
            inputElement = nil;
        };
        purchaseModal = {
            isOpen = false;
            busyUntil = 0;
            errorText = nil;
        };
    };
    ItemTextures = {};
    SendModal = {
        InputId = 'inventory_send_id';
        MaxIdLength = 5;
        IdElementData = 'ID';
        NearbyDistance = 3;
        Width = 380;
        Height = 210;
        Buttons = {
            { id = 'cancel',  label = 'Cancelar' };
            { id = 'confirm', label = 'Enviar' };
        };
    };
    PurchaseModal = {
        Width = 380;
        Height = 250;
        RequestTimeoutMs = 3000;
        Buttons = {
            { id = 'cancel',  label = 'Cancelar' };
            { id = 'confirm', label = 'Comprar' };
        };
    };
};

VAR.State.selectedCategory = VAR.Categories.initial;

local function getItemTexture(itemId)
    if VAR.ItemTextures[itemId] == nil then
        VAR.ItemTextures[itemId] = dxCreateTexture(getItemImage(itemId), 'argb', true, 'clamp') or false;
    end
    return VAR.ItemTextures[itemId];
end

local function fadedColor(alpha, red, green, blue)
    local finalAlpha = math.max(0, math.min(255, alpha * VAR.State.fade));
    return tocolor(red or 255, green or 255, blue or 255, finalAlpha);
end

local function pColor(alpha, red, green, blue)
    return tocolor(red or 255, green or 255, blue or 255, math.max(0, math.min(255, alpha)));
end

local function isItemVisible(itemConfig)
    return (itemConfig.type or 'user') == VAR.State.selectedCategory;
end

local function getVisibleSlotItem(slotId)
    local slotItem = VAR.State.items[slotId];
    local itemConfig = slotItem and _SHARED.Items[slotItem.itemId];
    
    if not itemConfig then 
        return 
    end

    if slotId > VAR.Hotbar.FirstSlotId or isItemVisible(itemConfig) then
        return slotItem;
    end
end

local function getCursorInDesign()
    local relativeX, relativeY = getCursorPosition();

    if not relativeX then 
        return 
    end

    local screenWidth, screenHeight = GetScreenSize();
    local scale = GetScaleValue();
    local offsetX = (screenWidth - 1920 * scale) / 2;
    local offsetY = (screenHeight - 1080 * scale) / 2;
    return (relativeX * screenWidth - offsetX) / scale, (relativeY * screenHeight - offsetY) / scale;
end

local function getContextMenuHeight()
    local menu = VAR.ContextMenu;
    return menu.OptionHeight * #menu.Options + menu.Padding * 2;
end

local function getShopConfig()
    return _SHARED.Inventory.SlotShop;
end

local function canBuyMoreSlots()
    return VAR.Slots.SlotsUnlocked < _SHARED.Inventory.MaxSlots;
end

local function getTotalSlots()
    local shop = getShopConfig();
    local wanted = math.max(VAR.Slots.MaxSlotsInScreen, VAR.Slots.SlotsUnlocked + shop.SlotsPerPurchase);
    return math.min(_SHARED.Inventory.MaxSlots, wanted);
end

local function getCurrencyBalance()
    return tonumber(getElementData(localPlayer, getShopConfig().CurrencyElementData)) or 0;
end

local function formatAmount(value)
    return string.format('%d', math.floor(value or 0));
end

local function getInventorySlotPosition(viewIndex)
    local positions = VAR.Slots.Positions;
    local column = (viewIndex - 1) % VAR.Slots.MaxSlotsInRow;
    local row = math.floor((viewIndex - 1) / VAR.Slots.MaxSlotsInRow);
    local slotX = positions.SlotX + (positions.SlotWidth + positions.SlotSpacing) * column;
    local slotY = positions.SlotY + (positions.SlotHeight + positions.SlotSpacing) * row;
    return slotX, slotY;
end

local function getHotbarSlotPosition(hotbarIndex)
    local positions = VAR.Slots.Positions;
    local slotX = positions.SlotX + (positions.SlotWidth + positions.SlotSpacing) * (hotbarIndex - 1);
    return slotX, VAR.Hotbar.SlotY;
end

local function drawSlot(slotId, slotX, slotY, hotbarNumber)
    local state = VAR.State;
    local slotWidth = VAR.Slots.Positions.SlotWidth;
    local slotHeight = VAR.Slots.Positions.SlotHeight;

    Image(slotX, slotY, slotWidth, slotHeight, IMG.slots, 0, 0, 0, fadedColor(255));

    local hover = HoverEffect('slot_' .. slotId, slotX, slotY, slotWidth, slotHeight, {
        alphaNormal = 0,
        alphaHover = 40,
        alphaSelected = 40,
        scaleNormal = 1,
        scaleActive = 1.08,
        speed = 0.2,
    });

    if hover.isHovered then
        state.hoveredSlot = slotId;
    end

    Image(slotX, slotY, slotWidth, slotHeight, IMG.slots, 0, 0, 0, fadedColor(hover.alpha));

    if hotbarNumber then
        Text(slotX, slotY, slotWidth, slotHeight, hotbarNumber, fadedColor(20), FONT.hotbar_number, 'center', 'center');
    end

    local slotItem = state.items[slotId];

    if not slotItem or state.draggedSlot == slotId then 
        return 
    end

    local itemConfig = _SHARED.Items[slotItem.itemId];
    local itemTexture = getItemTexture(slotItem.itemId);

    if not itemConfig or not itemTexture then 
        return 
    end

    local isVisible = hotbarNumber ~= nil or isItemVisible(itemConfig);
    local itemAlpha = Animate('item_alpha_' .. slotId, isVisible and 255 or 0, 0.15);
    
    if itemAlpha < 1 then 
        return 
    end

    local iconSize = (slotWidth - 20) * hover.scale;
    local iconX = slotX + (slotWidth - iconSize) / 2;
    local iconY = slotY + (slotHeight - iconSize) / 2;

    Image(iconX, iconY, iconSize, iconSize, itemTexture, 0, 0, 0, fadedColor(itemAlpha));

    if slotItem.amount > 1 then
        Text(slotX, slotY, slotWidth - 6, slotHeight - 4, 'x' .. slotItem.amount, fadedColor(itemAlpha), FONT.r_14, 'right', 'bottom');
    end
end

local function drawBackground()
    ImageFull(0, 0, 1920, 1080, IMG.background, 0, 0, 0, fadedColor(255));
end

local function drawCategories()
    local state = VAR.State;
    local button = VAR.Categories.Button;

    Image(750, 501, 35, 164, IMG.categories.background, 0, 0, 0, fadedColor(25));

    local selectedIndex = 1;
    for index, category in ipairs(VAR.Categories.List) do
        if category.id == state.selectedCategory then
            selectedIndex = index;
        end
    end

    local indicatorY = Animate('category_indicator_y', 518 + button.Height * (selectedIndex - 1), 0.15);
    Image(748, indicatorY, 4, 14, IMG.categories.effect, 0, 0, 0, fadedColor(255));

    for _, category in ipairs(VAR.Categories.List) do
        local hover = HoverEffect('category_' .. category.id, button.X, category.iconY - 10, button.Width, button.Height, {
            selected = state.selectedCategory == category.id,
            alphaNormal = 110,
            alphaHover = 200,
            alphaSelected = 255,
            scaleNormal = 1,
            scaleActive = 1.08,
            colorSelected = { 255, 255, 255 },
        });

        if hover.isHovered then
            state.hoveredCategory = category.id;
        end

        local iconWidth = category.iconWidth * hover.scale;
        local iconHeight = category.iconHeight * hover.scale;
        local iconX = category.iconX - (iconWidth - category.iconWidth) / 2;
        local iconY = category.iconY - (iconHeight - category.iconHeight) / 2;

        Image(iconX, iconY, iconWidth, iconHeight, IMG.categories.icons[category.id], 0, 0, 0, fadedColor(hover.alpha, hover.r, hover.g, hover.b));
    end
end

local function drawWeight()
    local state = VAR.State;
    local barPositions = VAR.Weight.BarX;

    local maxWeight = _SHARED.Inventory.MaxWeight;
    local targetRatio = math.min(1, state.carriedWeight / maxWeight);
    local weightRatio = Animate('weight_ratio', targetRatio, 0.1);

    for segmentIndex, barX in ipairs(barPositions) do
        local segmentFill = math.max(0, math.min(1, weightRatio * #barPositions - (segmentIndex - 1)));

        Image(barX, 856, 89, 3, IMG.weight_bar, 0, 0, 0, fadedColor(40));
        if segmentFill > 0 then
            Image(barX, 856, 89 * segmentFill, 3, IMG.weight_bar, 0, 0, 0, fadedColor(255));
        end
    end

    local weightText = string.format('%.1f/%dkg', state.carriedWeight, maxWeight);
    Text(1083, 835, 89, 19, weightText, fadedColor(255), FONT.r_14, 'right', 'top');
end

local function drawHotbar()
    Image(800, 221, 372, 18, IMG.hotbar.header, 0, 0, 0, fadedColor(255));

    for hotbarIndex = 1, VAR.Hotbar.SlotCount do
        local slotX, slotY = getHotbarSlotPosition(hotbarIndex);
        drawSlot(VAR.Hotbar.FirstSlotId + hotbarIndex, slotX, slotY, tostring(hotbarIndex));
    end
end

local function drawSlots()
    local state = VAR.State;
    local slots = VAR.Slots;
    local positions = slots.Positions;
    local rowSize = slots.MaxSlotsInRow;
    local visibleRows = math.ceil(slots.MaxSlotsInScreen / rowSize);
    local totalSlots = getTotalSlots();
    local totalRows = math.ceil(totalSlots / rowSize);
    local areaWidth = (positions.SlotWidth + positions.SlotSpacing) * rowSize - positions.SlotSpacing;
    local areaHeight = (positions.SlotHeight + positions.SlotSpacing) * visibleRows - positions.SlotSpacing;

    Image(positions.SlotX, 342, 372, 18, IMG.inventory.slots_header, 0, 0, 0, fadedColor(255));
    RegisterScrollArea('inventory_slots', positions.SlotX, positions.SlotY, areaWidth, areaHeight, totalRows, visibleRows);
    local scrollRow = Scrollbar('inventory_slots', slots.Scrollbar.X, positions.SlotY, areaHeight, totalRows, visibleRows, {
        trackWidth = slots.Scrollbar.Width,
        trackColor = fadedColor(25),
        fade = state.fade,
    });

    if state.scrollRow ~= scrollRow then
        state.scrollRow = scrollRow;
        state.contextSlot = nil;
    end

    for viewIndex = 1, slots.MaxSlotsInScreen do
        local slotNumber = scrollRow * rowSize + viewIndex;
        if slotNumber <= totalSlots then
            local slotX, slotY = getInventorySlotPosition(viewIndex);

            if slotNumber > slots.SlotsUnlocked then
                Image(slotX, slotY, positions.SlotWidth, positions.SlotHeight, IMG.slots_lock, 0, 0, 0, fadedColor(255));
            else
                drawSlot(slotNumber, slotX, slotY);
            end
        end
    end
end

local function drawLockedSlotsModal()
    local state = VAR.State;
    local slots = VAR.Slots;
    local modal = VAR.LockedModal;
    state.hoveredLockedModal = false;
    local lastVisibleSlot = state.scrollRow * slots.MaxSlotsInRow + slots.MaxSlotsInScreen;
    
    if not canBuyMoreSlots() or slots.SlotsUnlocked >= lastVisibleSlot then 
        return 
    end

    local hover = HoverEffect('locked_modal', modal.X, modal.Y, modal.Width, modal.Height, {
        alphaNormal = 225,
        alphaHover = 255,
        alphaSelected = 255,
        scaleNormal = 1,
        scaleActive = 1,
        speed = 0.2,
    });

    local isBlocked = state.purchaseModal.isOpen or state.sendModal.isOpen;
    if hover.isHovered and not isBlocked then
        state.hoveredLockedModal = true;
        state.hoveredSlot = nil;
    end

    Image(modal.X, modal.Y, modal.Width, modal.Height, IMG.inventory.modal_block, 0, 0, 0, fadedColor(hover.alpha));
end

local function drawTooltip()
    local state = VAR.State;
    local hoveredItem = state.hoveredSlot and getVisibleSlotItem(state.hoveredSlot);
    local isTooltipVisible = hoveredItem and not state.draggedSlot and not state.contextSlot;

    if isTooltipVisible then
        state.tooltipItemId = hoveredItem.itemId;
    end

    local tooltipAlpha = Animate('tooltip_alpha', isTooltipVisible and 255 or 0, 0.25);
    local itemConfig = _SHARED.Items[state.tooltipItemId];
    
    if tooltipAlpha < 1 or not itemConfig then 
        return 
    end

    local cursorX, cursorY = getCursorInDesign();
    if not cursorX then 
        return 
    end

    local tooltipX, tooltipY = cursorX + 16, cursorY + 16;

    RoundedRectangle(tooltipX, tooltipY, 200, 64, 6, fadedColor(tooltipAlpha * 0.85, 0, 0, 0));
    Text(tooltipX + 8, tooltipY + 4, 184, 18, itemConfig.name, fadedColor(tooltipAlpha), FONT.r_14, 'left', 'top');
    Text(tooltipX + 8, tooltipY + 24, 184, 18, itemConfig.desc or '', fadedColor(tooltipAlpha * 0.55), FONT.r_14, 'left', 'top');
    Text(tooltipX + 8, tooltipY + 42, 184, 18, string.format('%.1fkg', itemConfig.weight or 0), fadedColor(tooltipAlpha * 0.55), FONT.r_14, 'left', 'top');
end

local function drawContextMenu()
    local state = VAR.State;
    local menu = VAR.ContextMenu;
    local menuAlpha = Animate('context_menu_alpha', state.contextSlot and 255 or 0, 0.3);
    state.hoveredContextOption = nil;
    
    if menuAlpha < 1 then 
        return 
    end

    local slideOffset = (255 - menuAlpha) / 255 * 8;
    local menuX = state.contextMenuX;
    local menuY = state.contextMenuY + slideOffset;

    RoundedRectangle(menuX, menuY, menu.Width, getContextMenuHeight(), 6, fadedColor(menuAlpha * 0.92, 12, 12, 12));

    for optionIndex, option in ipairs(menu.Options) do
        local optionX = menuX + menu.Padding;
        local optionY = menuY + menu.Padding + menu.OptionHeight * (optionIndex - 1);
        local optionWidth = menu.Width - menu.Padding * 2;

        local hover = HoverEffect('context_option_' .. option.id, optionX, optionY, optionWidth, menu.OptionHeight, {
            alphaNormal = 0,
            alphaHover = 30,
            alphaSelected = 30,
            scaleNormal = 1,
            scaleActive = 1,
            speed = 0.25,
        });

        if hover.isHovered and state.contextSlot then
            state.hoveredContextOption = option.id;
        end

        RoundedRectangle(optionX, optionY, optionWidth, menu.OptionHeight, 4, fadedColor(hover.alpha * menuAlpha / 255));

        local labelAlpha = menuAlpha / 255 * (170 + hover.alpha * 2.8);
        Text(optionX, optionY, optionWidth, menu.OptionHeight, option.label, fadedColor(labelAlpha), FONT.r_14, 'center', 'center');
    end
end

local function drawDraggedItem()
    local state = VAR.State;
    
    if not state.draggedSlot then 
        return 
    end

    local draggedItem = state.items[state.draggedSlot];
    local itemTexture = draggedItem and getItemTexture(draggedItem.itemId);
    local cursorX, cursorY = getCursorInDesign();
    
    if not itemTexture or not cursorX then 
        return 
    end

    local iconSize = VAR.Slots.Positions.SlotWidth - 20;
    Image(cursorX - iconSize / 2, cursorY - iconSize / 2, iconSize, iconSize, itemTexture, 0, 0, 0, fadedColor(210));
end

local function drawSendModal()
    local state = VAR.State;
    local modal = state.sendModal;
    local config = VAR.SendModal;
    local modalAlpha = Animate('send_modal_alpha', modal.isOpen and 255 or 0, 0.25);
    state.hoveredModalButton = nil;
    
    if modalAlpha < 1 then 
        return 
    end

    local visibility = modalAlpha / 255;
    local modalX = (1920 - config.Width) / 2;
    local modalY = (1080 - config.Height) / 2 + (1 - visibility) * 12;

    --Rectangle(0, 0, 1920, 1080, fadedColor(150 * visibility, 0, 0, 0));
    RoundedRectangle(modalX, modalY, config.Width, config.Height, 10, fadedColor(245 * visibility, 14, 14, 14), fadedColor(40 * visibility), 1);

    local itemConfig = _SHARED.Items[modal.itemId];
    local itemLabel = itemConfig and itemConfig.name or '';
    if modal.amount > 1 then
        itemLabel = itemLabel .. ' x' .. modal.amount;
    end

    Text(modalX + 24, modalY + 16, config.Width - 48, 22, 'Enviar item', fadedColor(255 * visibility), FONT.r_14, 'left', 'top');
    Text(modalX + 24, modalY + 40, config.Width - 48, 18, itemLabel, fadedColor(140 * visibility), FONT.r_14, 'left', 'top');

    local inputX, inputY = modalX + 24, modalY + 70;
    local inputWidth, inputHeight = config.Width - 48, 40;
    RoundedRectangle(inputX, inputY, inputWidth, inputHeight, 8, fadedColor(14 * visibility), fadedColor(70 * visibility), 1);

    local typedText = GetInputText(config.InputId);
    local caret = math.floor(getTickCount() / 500) % 2 == 0 and '|' or '';

    if typedText == '' then
        Text(inputX + 14, inputY, inputWidth - 28, inputHeight, 'ID do jogador', fadedColor(90 * visibility), FONT.r_14, 'left', 'center');
    end
    Text(inputX + 14, inputY, inputWidth - 28, inputHeight, typedText .. caret, fadedColor(255 * visibility), FONT.r_14, 'left', 'center');

    local nearbyText = 'Nenhum jogador próximo';
    if #modal.nearbyIds > 0 then
        nearbyText = 'Próximos: ' .. table.concat(modal.nearbyIds, ', ');
    end
    Text(inputX, inputY + inputHeight + 8, inputWidth, 18, nearbyText, fadedColor(120 * visibility), FONT.r_14, 'left', 'top');

    local buttonHeight = 40;
    local buttonY = modalY + config.Height - 16 - buttonHeight;
    local buttonWidth = (config.Width - 48 - 12) / #config.Buttons;

    for buttonIndex, button in ipairs(config.Buttons) do
        local isConfirm = button.id == 'confirm';
        local buttonX = modalX + 24 + (buttonWidth + 12) * (buttonIndex - 1);
        local hover = HoverEffect('send_modal_' .. button.id, buttonX, buttonY, buttonWidth, buttonHeight, {
            alphaNormal = isConfirm and 215 or 18,
            alphaHover = isConfirm and 255 or 45,
            alphaSelected = 255,
            scaleNormal = 1,
            scaleActive = 1,
            speed = 0.25,
        });

        if hover.isHovered and modal.isOpen then
            state.hoveredModalButton = button.id;
        end

        RoundedRectangle(buttonX, buttonY, buttonWidth, buttonHeight, 8, fadedColor(hover.alpha * visibility));

        local labelColor = isConfirm and fadedColor(255 * visibility, 20, 20, 20) or fadedColor(255 * visibility);
        Text(buttonX, buttonY, buttonWidth, buttonHeight, button.label, labelColor, FONT.r_14, 'center', 'center');
    end
end

local function isPurchaseBusy()
    return VAR.State.purchaseModal.busyUntil > getTickCount();
end

local function drawPurchaseModal()
    local state = VAR.State;
    local modal = state.purchaseModal;
    local config = VAR.PurchaseModal;
    local shop = getShopConfig();
    local modalAlpha = Animate('purchase_modal_alpha', modal.isOpen and 255 or 0, 0.25);
    state.hoveredPurchaseButton = nil;
    
    if modalAlpha < 1 then 
        return 
    end

    local visibility = modalAlpha / 255;
    local modalX = (1920 - config.Width) / 2;
    local modalY = (1080 - config.Height) / 2 + (1 - visibility) * 12;
    local contentX = modalX + 24;
    local contentWidth = config.Width - 48;

    RoundedRectangle(modalX, modalY, config.Width, config.Height, 10, fadedColor(245 * visibility, 14, 14, 14), fadedColor(40 * visibility), 1);

    local balance = getCurrencyBalance();
    local canAfford = balance >= shop.Price;
    local currentSlots = VAR.Slots.SlotsUnlocked;
    local newSlots = currentSlots + shop.SlotsPerPurchase;

    Text(contentX, modalY + 16, contentWidth, 22, 'Comprar slots', fadedColor(255 * visibility), FONT.r_14, 'left', 'top');
    Text(contentX, modalY + 40, contentWidth, 18, string.format('Desbloquear +%d slots no inventário', shop.SlotsPerPurchase), fadedColor(140 * visibility), FONT.r_14, 'left', 'top');

    local boxY = modalY + 72;
    local boxHeight = 100;
    RoundedRectangle(contentX, boxY, contentWidth, boxHeight, 8, fadedColor(14 * visibility), fadedColor(70 * visibility), 1);

    local rows = {
        { 'Slots', string.format('%d  >  %d', currentSlots, newSlots), 255 };
        { 'Preço', formatAmount(shop.Price) .. ' ' .. shop.CurrencyName, 255 };
        { 'Seu saldo', formatAmount(balance) .. ' ' .. shop.CurrencyName, canAfford and 255 or 0 };
    };

    for rowIndex, row in ipairs(rows) do
        local rowY = boxY + 10 + (rowIndex - 1) * 28;
        Text(contentX + 14, rowY, contentWidth - 28, 20, row[1], fadedColor(120 * visibility), FONT.r_14, 'left', 'top');

        local valueColor = fadedColor(255 * visibility);
        if row[3] == 0 then
            valueColor = fadedColor(255 * visibility, 255, 90, 90);
        end
        Text(contentX + 14, rowY, contentWidth - 28, 20, row[2], valueColor, FONT.r_14, 'right', 'top');
    end

    local statusText = modal.errorText;
    if not statusText and not canAfford then
        statusText = 'Saldo insuficiente';
    end
    if statusText then
        Text(contentX, boxY + boxHeight + 8, contentWidth, 18, statusText, fadedColor(255 * visibility, 255, 90, 90), FONT.r_14, 'left', 'top');
    end

    local isBusy = isPurchaseBusy();
    local confirmEnabled = canAfford and not isBusy;
    local buttonHeight = 40;
    local buttonY = modalY + config.Height - 16 - buttonHeight;
    local buttonWidth = (config.Width - 48 - 12) / #config.Buttons;

    for buttonIndex, button in ipairs(config.Buttons) do
        local isConfirm = button.id == 'confirm';
        local buttonX = contentX + (buttonWidth + 12) * (buttonIndex - 1);
        local normalAlpha = isConfirm and (confirmEnabled and 215 or 60) or 18;
        local hoverAlpha = isConfirm and (confirmEnabled and 255 or 60) or 45;
        local hover = HoverEffect('purchase_modal_' .. button.id, buttonX, buttonY, buttonWidth, buttonHeight, {
            alphaNormal = normalAlpha,
            alphaHover = hoverAlpha,
            alphaSelected = 255,
            scaleNormal = 1,
            scaleActive = 1,
            speed = 0.25,
        });

        if hover.isHovered and modal.isOpen then
            state.hoveredPurchaseButton = button.id;
        end

        RoundedRectangle(buttonX, buttonY, buttonWidth, buttonHeight, 8, fadedColor(hover.alpha * visibility));

        local label = button.label;
        if isConfirm and isBusy then
            label = 'Comprando...';
        end

        local labelColor = isConfirm and fadedColor(255 * visibility, 20, 20, 20) or fadedColor(255 * visibility);
        Text(buttonX, buttonY, buttonWidth, buttonHeight, label, labelColor, FONT.r_14, 'center', 'center');
    end
end

function InventoryCreateUI()
    local state = VAR.State;

    state.fade = Animate('inventory_fade', state.isOpen and 1 or 0, 0.15);
    
    if state.fade < 0.01 then 
        return 
    end

    state.hoveredSlot = nil;
    state.hoveredCategory = nil;

    drawBackground();
    drawCategories();
    drawWeight();
    drawHotbar();
    drawSlots();
    drawLockedSlotsModal();
    drawTooltip();
    drawContextMenu();
    drawDraggedItem();
    drawSendModal();
    drawPurchaseModal();
end
addEventHandler('onClientRender', root, InventoryCreateUI);

local function scanNearbyDrop()
    local state = VAR.State;
    state.nearbyDrop = nil;

    if isPedInVehicle(localPlayer) or isPedDead(localPlayer) then 
        return 
    end

    local playerX, playerY, playerZ = getElementPosition(localPlayer);
    local nearestDistance = VAR.Pickup.PromptDistance;

    for _, droppedObject in ipairs(getElementsByType('object', root, true)) do
        local dropInfo = getElementData(droppedObject, 'droppedItem');

        if dropInfo then
            local objectX, objectY, objectZ = getElementPosition(droppedObject);
            local distance = getDistanceBetweenPoints3D(playerX, playerY, playerZ, objectX, objectY, objectZ);

            if distance <= nearestDistance then
                nearestDistance = distance;
                state.nearbyDrop = { object = droppedObject, itemId = dropInfo.itemId, amount = dropInfo.amount };
            end
        end
    end
end
setTimer(scanNearbyDrop, VAR.Pickup.ScanIntervalMs, 0);

local function drawPickupPrompt()
    local state = VAR.State;
    local prompt = VAR.Pickup.Prompt;
    local isPickingUp = getTickCount() < state.pickupLockedUntil;
    local shouldShow = state.nearbyDrop and not state.isOpen and not isPickingUp;

    if shouldShow then
        state.promptItemId = state.nearbyDrop.itemId;
        state.promptAmount = state.nearbyDrop.amount;
    end

    local promptAlpha = Animate('pickup_prompt_alpha', shouldShow and 255 or 0, 0.2);
    local itemConfig = _SHARED.Items[state.promptItemId];
    
    if promptAlpha < 1 or not itemConfig then 
        return 
    end

    local slideOffset = (255 - promptAlpha) / 255 * 10;
    local promptX = prompt.X;
    local promptY = prompt.Y + slideOffset;

    RoundedRectangle(promptX, promptY, prompt.Width, prompt.Height, 8, pColor(promptAlpha * 0.85, 0, 0, 0));

    local keySize = 32;
    local keyX = promptX + 8;
    local keyY = promptY + (prompt.Height - keySize) / 2;
    RoundedRectangle(keyX, keyY, keySize, keySize, 6, pColor(promptAlpha * 0.95));
    Text(keyX, keyY, keySize, keySize, string.upper(VAR.Pickup.Key), pColor(promptAlpha, 20, 20, 20), FONT.r_14, 'center', 'center');

    local itemLabel = itemConfig.name;
    
    if state.promptAmount > 1 then
        itemLabel = itemLabel .. ' x' .. state.promptAmount;
    end

    local textX = keyX + keySize + 10;
    local textWidth = prompt.Width - (textX - promptX) - 8;
    Text(textX, promptY + 6, textWidth, 18, 'Pressione ' .. string.upper(VAR.Pickup.Key) .. ' para pegar', pColor(promptAlpha * 0.6), FONT.r_14, 'left', 'top');
    Text(textX, promptY + 24, textWidth, 18, itemLabel, pColor(promptAlpha), FONT.r_14, 'left', 'top');
end
addEventHandler('onClientRender', root, drawPickupPrompt);

local function getNearbyPlayerIds()
    local nearbyIds = {};
    local playerX, playerY, playerZ = getElementPosition(localPlayer);

    for _, otherPlayer in ipairs(getElementsByType('player', root, true)) do
        local otherId = getElementData(otherPlayer, VAR.SendModal.IdElementData);

        if otherPlayer ~= localPlayer and otherId then
            local otherX, otherY, otherZ = getElementPosition(otherPlayer);
            local distance = getDistanceBetweenPoints3D(playerX, playerY, playerZ, otherX, otherY, otherZ);

            if distance <= VAR.SendModal.NearbyDistance then
                nearbyIds[#nearbyIds + 1] = tostring(otherId);
            end
        end
    end
    return nearbyIds;
end

local function closeSendModal()
    local modal = VAR.State.sendModal;
    
    if not modal.isOpen then 
        return 
    end

    modal.isOpen = false;
    modal.inputElement = nil;
    DestroyInput(VAR.SendModal.InputId);
    guiSetInputEnabled(false);
end

local function openSendModal(slotId, amount)
    local slotItem = VAR.State.items[slotId];
    
    if not slotItem then 
        return 
    end

    local modal = VAR.State.sendModal;
    modal.slotId = slotId;
    modal.itemId = slotItem.itemId;
    modal.amount = amount;
    modal.nearbyIds = getNearbyPlayerIds();
    modal.isOpen = true;

    modal.inputElement = CreateInput(VAR.SendModal.InputId, 0, 0, 1, 1, false);
    guiEditSetMaxLength(modal.inputElement, VAR.SendModal.MaxIdLength);
    ClearInput(VAR.SendModal.InputId);
    SetInputFocus(VAR.SendModal.InputId);
    guiSetInputEnabled(true);
end

local function confirmSendModal()
    local modal = VAR.State.sendModal;
    local targetId = tonumber(GetInputText(VAR.SendModal.InputId));
    
    if not targetId then 
        return 
    end

    triggerServerEvent('inventory:send', resourceRoot, modal.slotId, modal.amount, targetId);
    closeSendModal();
end

local function closePurchaseModal()
    local modal = VAR.State.purchaseModal;
    modal.isOpen = false;
    modal.busyUntil = 0;
    modal.errorText = nil;
end

local function openPurchaseModal()
    local state = VAR.State;
    if not canBuyMoreSlots() or state.sendModal.isOpen then 
        return 
    end

    local modal = state.purchaseModal;
    modal.isOpen = true;
    modal.busyUntil = 0;
    modal.errorText = nil;
    state.contextSlot = nil;
end

local function confirmPurchaseModal()
    local modal = VAR.State.purchaseModal;
    local shop = getShopConfig();

    if isPurchaseBusy() then return end

    if getCurrencyBalance() < shop.Price then
        modal.errorText = 'Saldo insuficiente';
        return;
    end

    modal.errorText = nil;
    modal.busyUntil = getTickCount() + VAR.PurchaseModal.RequestTimeoutMs;
    triggerServerEvent('inventory:buySlots', resourceRoot);
end

local function runContextOption(optionId, slotId)
    local slotItem = VAR.State.items[slotId];
    if not slotItem then 
        return 
    end

    local amount = getKeyState('lshift') and 1 or slotItem.amount;

    if optionId == 'use' then
        triggerServerEvent('inventory:use', resourceRoot, slotId);
    elseif optionId == 'drop' then
        triggerServerEvent('inventory:drop', resourceRoot, slotId, amount);
    elseif optionId == 'send' then
        openSendModal(slotId, amount);
    end
end

addEvent('inventory:sync', true);
addEventHandler('inventory:sync', resourceRoot, function(items, unlockedSlots, carriedWeight)
    local state = VAR.State;
    state.items = items;
    state.carriedWeight = carriedWeight;
    VAR.Slots.SlotsUnlocked = unlockedSlots;

    if state.sendModal.isOpen and not items[state.sendModal.slotId] then
        closeSendModal();
    end

    if state.draggedSlot and not items[state.draggedSlot] then
        state.draggedSlot = nil;
    end
    if state.contextSlot and not items[state.contextSlot] then
        state.contextSlot = nil;
    end
end);

addEvent('inventory:buySlotsResult', true);
addEventHandler('inventory:buySlotsResult', resourceRoot, function(success, message)
    local modal = VAR.State.purchaseModal;
    modal.busyUntil = 0;

    if success then
        closePurchaseModal();
    else
        modal.errorText = message or 'Não foi possível concluir a compra';
    end
end);

addEvent('inventory:pickupStarted', true);
addEventHandler('inventory:pickupStarted', resourceRoot, function(animationMs)
    VAR.State.pickupLockedUntil = getTickCount() + animationMs;
end);

addEventHandler('onClientClick', root, function(button, buttonState)
    local state = VAR.State;
    if not state.isOpen then 
        return 
    end

    if state.purchaseModal.isOpen then
        if button == 'left' and buttonState == 'down' then
            if state.hoveredPurchaseButton == 'confirm' then
                confirmPurchaseModal();
            elseif state.hoveredPurchaseButton == 'cancel' then
                closePurchaseModal();
            end
        end
        return;
    end

    if state.sendModal.isOpen then
        if button == 'left' and buttonState == 'down' then
            if state.hoveredModalButton == 'confirm' then
                confirmSendModal();
            elseif state.hoveredModalButton == 'cancel' then
                closeSendModal();
            end
        end
        return;
    end

    local hoveredSlot = state.hoveredSlot;

    if button == 'left' and buttonState == 'down' then
        local clickedOption = state.hoveredContextOption;
        if clickedOption then
            runContextOption(clickedOption, state.contextSlot);
            state.contextSlot = nil;
            return;
        end

        state.contextSlot = nil;

        if state.hoveredLockedModal then
            openPurchaseModal();
            return;
        end

        if state.hoveredCategory then
            state.selectedCategory = state.hoveredCategory;
        elseif hoveredSlot and getVisibleSlotItem(hoveredSlot) then
            state.draggedSlot = hoveredSlot;
        end

    elseif button == 'left' and buttonState == 'up' then
        local originSlot = state.draggedSlot;
        state.draggedSlot = nil;

        local draggedItem = originSlot and state.items[originSlot];
        local isTargetHidden = hoveredSlot and state.items[hoveredSlot] and not getVisibleSlotItem(hoveredSlot);
        if draggedItem and hoveredSlot and hoveredSlot ~= originSlot and not isTargetHidden then
            local moveAmount = draggedItem.amount;
            if getKeyState('lshift') and moveAmount > 1 then
                moveAmount = math.ceil(moveAmount / 2);
            end
            triggerServerEvent('inventory:move', resourceRoot, originSlot, hoveredSlot, moveAmount);
        end

    elseif button == 'right' and buttonState == 'down' then
        if hoveredSlot and getVisibleSlotItem(hoveredSlot) then
            local cursorX, cursorY = getCursorInDesign();
            state.contextSlot = hoveredSlot;
            state.contextMenuX = math.min(cursorX, 1920 - VAR.ContextMenu.Width - 10);
            state.contextMenuY = math.min(cursorY, 1080 - getContextMenuHeight() - 10);
        else
            state.contextSlot = nil;
        end
    end
end);

for hotbarIndex = 1, VAR.Hotbar.SlotCount do
    bindKey(tostring(hotbarIndex), 'down', function()
        if isChatBoxInputActive() or isConsoleActive() then 
            return 
        end
        triggerServerEvent('inventory:use', resourceRoot, VAR.Hotbar.FirstSlotId + hotbarIndex);
    end);
end

bindKey(VAR.Pickup.Key, 'down', function()
    if isChatBoxInputActive() or isConsoleActive() then 
        return 
    end

    if not VAR.State.nearbyDrop then 
        return 
    end

    triggerServerEvent('inventory:pickup', resourceRoot);
end);

addEventHandler('onClientGUIChanged', root, function()
    local modal = VAR.State.sendModal;
    if not modal.isOpen or source ~= modal.inputElement then 
        return 
    end

    local typedText = guiGetText(source);
    local digitsOnly = typedText:gsub('%D', '');
    if digitsOnly ~= typedText then
        SetInputText(VAR.SendModal.InputId, digitsOnly);
    end
end);

addEventHandler('onClientKey', root, function(key, isPressed)
    if not isPressed then 
        return 
    end

    local state = VAR.State;
    local isConfirmKey = key == 'enter' or key == 'num_enter';

    if state.sendModal.isOpen then
        if isConfirmKey then
            confirmSendModal();
        elseif key == 'escape' then
            closeSendModal();
        end
    elseif state.purchaseModal.isOpen then
        if isConfirmKey then
            confirmPurchaseModal();
        elseif key == 'escape' then
            closePurchaseModal();
        end
    end
end);

function toggleInventory(shouldOpen)
    local state = VAR.State;

    if shouldOpen == nil then
        shouldOpen = not state.isOpen;
    end
    if shouldOpen == state.isOpen then 
        return 
    end

    state.isOpen = shouldOpen;
    state.draggedSlot = nil;
    state.contextSlot = nil;
    closeSendModal();
    closePurchaseModal();
    showCursor(shouldOpen);

    if shouldOpen then
        triggerServerEvent('inventory:request', resourceRoot);
    end
end
bindKey('k', 'down', function() toggleInventory() end);