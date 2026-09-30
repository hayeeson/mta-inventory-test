local VAR = {
    FileName = 'inventory.db';
    Connection = nil;
};

function connectInventoryDatabase()
    local connection = dbConnect('sqlite', VAR.FileName);

    if not connection then
        print('[INVENTORY] Não foi possível conectar ao SQLite.');
        return false;
    end

    dbExec(connection, [[
        CREATE TABLE IF NOT EXISTS inventory_owners (
            owner TEXT PRIMARY KEY,
            unlocked_slots INTEGER NOT NULL
        )
    ]]);

    dbExec(connection, [[
        CREATE TABLE IF NOT EXISTS inventory_items (
            owner TEXT NOT NULL,
            slot INTEGER NOT NULL,
            item_id INTEGER NOT NULL,
            amount INTEGER NOT NULL,
            PRIMARY KEY (owner, slot)
        )
    ]]);

    VAR.Connection = connection;
    print('[INVENTORY] Conectado ao SQLite com sucesso.');
    return true;
end

function loadInventoryData(owner, callback)
    local connection = VAR.Connection;

    if not connection then
        callback(nil);
        return;
    end

    local query = [[
        SELECT o.unlocked_slots, i.slot, i.item_id, i.amount
        FROM inventory_owners o
        LEFT JOIN inventory_items i ON i.owner = o.owner
        WHERE o.owner = ?
    ]];

    dbQuery(function(queryHandle)
        local rows = dbPoll(queryHandle, 0);

        if not rows then
            callback(nil);
            return;
        end

        local result = { exists = #rows > 0, unlockedSlots = nil, items = {} };

        for _, row in ipairs(rows) do
            result.unlockedSlots = tonumber(row.unlocked_slots);

            if row.slot and row.item_id then
                result.items[tonumber(row.slot)] = {
                    itemId = tonumber(row.item_id),
                    amount = tonumber(row.amount),
                };
            end
        end

        callback(result);
    end, connection, query, owner);
end

function saveInventoryData(owner, slots, unlockedSlots)
    local connection = VAR.Connection;
    if not connection then 
        return false 
    end

    dbExec(connection, 'INSERT OR REPLACE INTO inventory_owners (owner, unlocked_slots) VALUES (?, ?)', owner, unlockedSlots);

    local savedSlots = {};

    for slotId, slotItem in pairs(slots) do
        dbExec(connection, 'INSERT OR REPLACE INTO inventory_items (owner, slot, item_id, amount) VALUES (?, ?, ?, ?)', owner, slotId, slotItem.itemId, slotItem.amount);
        savedSlots[#savedSlots + 1] = math.floor(slotId);
    end

    if #savedSlots == 0 then
        dbExec(connection, 'DELETE FROM inventory_items WHERE owner = ?', owner);
    else
        dbExec(connection, 'DELETE FROM inventory_items WHERE owner = ? AND slot NOT IN (' .. table.concat(savedSlots, ',') .. ')', owner);
    end

    return true;
end