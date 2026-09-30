local VAR = {
    lastExecution = {};
    windowCalls = {};
    playerRateLimitIds = {};
    nextRateLimitId = 1;
    Defaults = {
        CooldownMs = 1000;
        MaxCalls = 5;
        WindowMs = 10000;
        MaxAgeMs = 300000;
        CleanupIntervalMs = 60000;
    };
};

function GetPlayerRateLimitId(player)
    if not isElement(player) then
        return nil;
    end;

    if VAR.playerRateLimitIds[player] then
        return VAR.playerRateLimitIds[player];
    end;

    local id = VAR.nextRateLimitId;
    VAR.nextRateLimitId = VAR.nextRateLimitId + 1;
    VAR.playerRateLimitIds[player] = id;

    return id;
end;

function CanExecute(id, action, cooldownMs)
    if type(id) ~= 'number' or type(action) ~= 'string' then
        return false;
    end;

    cooldownMs = cooldownMs or VAR.Defaults.CooldownMs;

    local key = id .. ':' .. action;
    local now = getTickCount();
    local last = VAR.lastExecution[key];

    if last and (now - last) < cooldownMs then
        return false;
    end;

    VAR.lastExecution[key] = now;

    return true;
end;

function CanExecuteWindow(id, action, maxCalls, windowMs)
    if type(id) ~= 'number' or type(action) ~= 'string' then
        return false;
    end;

    maxCalls = maxCalls or VAR.Defaults.MaxCalls;
    windowMs = windowMs or VAR.Defaults.WindowMs;

    local key = id .. ':' .. action;
    local now = getTickCount();

    if not VAR.windowCalls[key] then
        VAR.windowCalls[key] = {};
    end;

    local calls = VAR.windowCalls[key];

    for i = #calls, 1, -1 do
        if (now - calls[i]) > windowMs then
            table.remove(calls, i);
        end;
    end;

    if #calls >= maxCalls then
        return false;
    end;

    table.insert(calls, now);

    return true;
end;

function ResetRateLimit(id, action)
    if type(id) ~= 'number' then
        return;
    end;

    if action then
        local key = id .. ':' .. action;

        VAR.lastExecution[key] = nil;
        VAR.windowCalls[key] = nil;

        return;
    end;

    for key in pairs(VAR.lastExecution) do
        if key:match('^' .. id .. ':') then
            VAR.lastExecution[key] = nil;
        end;
    end;

    for key in pairs(VAR.windowCalls) do
        if key:match('^' .. id .. ':') then
            VAR.windowCalls[key] = nil;
        end;
    end;
end;

addEventHandler('onPlayerQuit', root, function()
    VAR.playerRateLimitIds[source] = nil;
end);

setTimer(function()
    local now = getTickCount();
    local maxAge = VAR.Defaults.MaxAgeMs;

    for key, timestamp in pairs(VAR.lastExecution) do
        if (now - timestamp) > maxAge then
            VAR.lastExecution[key] = nil;
        end;
    end;

    for key, calls in pairs(VAR.windowCalls) do
        if #calls == 0 or (now - calls[#calls]) > maxAge then
            VAR.windowCalls[key] = nil;
        end;
    end;
end, VAR.Defaults.CleanupIntervalMs, 0);