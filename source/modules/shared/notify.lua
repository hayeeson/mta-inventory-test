-- Notify = {
--     server = function(player, message, type)
--         type = type or "info"
--         message = message or ""
--         print("Infobox para "..getPlayerName(player)..": [" ..tostring(type) .."] " ..tostring(message))
--     end,

--     client = function(player, message, type)
--         type = type or "info"
--         message = message or ""
--         print("Infobox para " .. getPlayerName(player) .. ": [" .. tostring(type) .. "] " .. tostring(message))
--     end
-- }

Notify = {
    server = function(player, message, type)
        type = type or 'info';
        message = message or '';
        outputChatBox(tostring(message), player);
    end;

    client = function(player, message, type)
        type = type or 'info';
        message = message or '';
        outputChatBox(tostring(message));
    end;
};