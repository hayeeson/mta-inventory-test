local basew, baseh = 1920, 1080
local screen = Vector2(guiGetScreenSize())
local screenWidth, screenHeight = screen.x, screen.y
local scaleValue = math.min(screenWidth / basew, screenHeight / baseh)
local screenOffsetX = (screenWidth - (basew * scaleValue)) / 2
local screenOffsetY = (screenHeight - (baseh * scaleValue)) / 2

local function clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

function lerp(a, b, t)
    return a + (b - a) * t
end

function easeOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

-- Animations = {}

-- function Animate(id, target, speed)
--     if not Animations[id] then
--         Animations[id] = target
--     end

--     Animations[id] = lerp(Animations[id], target, speed)
--     return Animations[id]
-- end

Animations = {}
local AnimationsLastTick = {}

function Animate(id, target, speed)
    local now = getTickCount()

    if not Animations[id] then
        Animations[id] = target
        AnimationsLastTick[id] = now
        return Animations[id]
    end

    local delta = (now - (AnimationsLastTick[id] or now)) / 1000
    AnimationsLastTick[id] = now

    local t = 1 - math.exp(-speed * delta * 60)
    Animations[id] = lerp(Animations[id], target, t)

    return Animations[id]
end

local function fromcolor(color)
    local a = bitExtract(color, 24, 8) or 255
    local r = bitExtract(color, 16, 8) or 255
    local g = bitExtract(color, 8, 8) or 255
    local b = bitExtract(color, 0, 8) or 255
    return r, g, b, a
end

local Framework = {
    cache = {
        fonts = {},
        position = {},
        scale = {},
        roundedRectangles = {},
        lastTick = {},
        clearTimer = {}
    },
    client = {
        loaded = false,
        width = nil,
        height = nil
    },
    internal = {
        _fontReducer = 4,
        _fontSet = 1
    }
}

local function initializeFramework()
    Framework.client.loaded = true
    Framework.client.width, Framework.client.height = guiGetScreenSize()

    local ranges = {
        -- {1920, 1080, 9999, 9999, 1, 4},
        -- {1760, 990, 1920, 1080, 1, 4},
        -- {1680, 1050, 1760, 990, 1, 1},
        -- {1600, 900, 1680, 1050, 1, 4},
        -- {1366, 768, 1600, 900, 1, 4},
        -- {1280, 720, 1366, 768, 1, 4},
        -- {1152, 870, 1280, 720, 1, 3},
        -- {1152, 864, 1280, 720, 1, 3},
        -- {1128, 634, 1280, 720, 1, 3},
        -- {1024, 768, 1128, 634, 1, 3},
        -- {800, 600, 1024, 768, 1, 5},

        {1920, 1080, 9999, 9999, 1, 0},
        {1760, 990, 1920, 1080, 1, 0},
        {1680, 1050, 1760, 990, 1, 0},
        {1600, 900, 1680, 1050, 1, 0},
        {1366, 768, 1600, 900, 1, 0},
        {1280, 720, 1366, 768, 1, 0},
        {1152, 870, 1280, 720, 1, 0},
        {1152, 864, 1280, 720, 1, 0},
        {1128, 634, 1280, 720, 1, 0},
        {1024, 768, 1128, 634, 1, 0},
        {800, 600, 1024, 768, 1, 0},
    }

    for i, range in ipairs(ranges) do
        if Framework.client.width >= range[1] and Framework.client.height >= range[2] then
            Framework.internal._fontSet = range[5]
            Framework.internal._fontReducer = range[6]
            break
        end
    end
end

if not Framework.client.loaded then
    initializeFramework()
end

local function manageClearTimer(interface)
    if not Framework.cache.clearTimer[interface] then
        Framework.cache.clearTimer[interface] = setTimer(function()
            if Framework.cache.lastTick[interface] and (getTickCount() - Framework.cache.lastTick[interface] > 5000) then
                for k, v in pairs(Framework.cache.roundedRectangles) do
                    if isElement(v) then
                        destroyElement(v)
                    end
                end
                Framework.cache.roundedRectangles = {}
            end
        end, 1000, 0)
    end
    Framework.cache.lastTick[interface] = getTickCount()
end

local extraOffsetX = 0

function SetGlobalOffsetX(x)
    extraOffsetX = x
end

function Position(x, y, removeOffset)
    if not Framework.cache.position[x] then
        Framework.cache.position[x] = x * scaleValue
    end

    if not Framework.cache.position[y] then
        Framework.cache.position[y] = y * scaleValue
    end

    if removeOffset then
        return Framework.cache.position[x], Framework.cache.position[y]
    end

    return screenOffsetX + extraOffsetX + Framework.cache.position[x], screenOffsetY + Framework.cache.position[y]
end

function Scale(w, h)
    if not Framework.cache.scale[w] then
        Framework.cache.scale[w] = w * scaleValue
    end
    
    if not Framework.cache.scale[h] then
        Framework.cache.scale[h] = h * scaleValue
    end

    return Framework.cache.scale[w], Framework.cache.scale[h]
end

function LoadFont(name, size, ...)
    if not Framework.cache.fonts[name] then
        Framework.cache.fonts[name] = {}
    end

    if not Framework.cache.fonts[name][size] then
        Framework.cache.fonts[name][size] = dxCreateFont('assets/fonts/' .. name .. '.ttf', (size - Framework.internal._fontReducer) * scaleValue, ...)
    end

    return Framework.cache.fonts[name][size]
end

function Text(startX, startY, width, height, text, color, font, alignX, alignY, ...)
    local x, y = Position(startX, startY)
    local w, h = Scale(width, height)

    return dxDrawText(
        text, 
        x, 
        y, 
        w + (alignX ~= "left" and x or 0), 
        h + (alignY ~= "top" and y or 0), 
        color, 
        Framework.internal._fontSet, 
        isElement(font) and font or LoadFont(font.name, font.size, false, 'cleartype'), 
        alignX, 
        alignY, 
        ...
    )
end

function Rectangle(startX, startY, width, height, color, ...)
    local x, y = Position(startX, startY)
    local w, h = Scale(width, height)

    dxDrawRectangle(x, y, w, h, color, ...)
end

function Image(startX, startY, width, height, path, ...)
    local x, y = Position(startX, startY)
    local w, h = Scale(width, height)

    dxDrawImage(x, y, w, h, path, ...)
end

function RoundedRectangle(startX, startY, width, height, radius, fillColor, strokeColor, strokeWidth, strokeAlign, ...)
    local x, y = Position(startX, startY)
    local w, h = Scale(width, height)
    local scaledRadius = radius * scaleValue
    local scaledStrokeWidth = (strokeWidth or 0) * scaleValue
    local useStroke = strokeColor and strokeWidth and strokeWidth > 0

    if useStroke and strokeAlign == "outside" then
        local outerW = w + scaledStrokeWidth * 2
        local outerH = h + scaledStrokeWidth * 2
        local outerX = x - scaledStrokeWidth
        local outerY = y - scaledStrokeWidth
        local outerRadius = scaledRadius + scaledStrokeWidth
        local strokeId = string.format("stroke_out_%.0f_%.0f_%.0f_%.0f", outerW, outerH, outerRadius, scaledStrokeWidth)
        if not Framework.cache.roundedRectangles[strokeId] then
            local svg = string.format([[
                <svg width="%d" height="%d">
                    <rect width="%d" height="%d" x="0" y="0" rx="%d" ry="%d"
                          fill="none" stroke="#FFFFFF" stroke-width="%d"/>
                </svg>
            ]], outerW, outerH, outerW, outerH, outerRadius, outerRadius, scaledStrokeWidth * 2)
            Framework.cache.roundedRectangles[strokeId] = svgCreate(outerW, outerH, svg)
        end

        dxDrawImage(outerX, outerY, outerW, outerH, Framework.cache.roundedRectangles[strokeId], 0, 0, 0, strokeColor, ...)

        local fillId = string.format("fill_%.0f_%.0f_%.0f", w, h, scaledRadius)
        if not Framework.cache.roundedRectangles[fillId] then
            local svg = string.format([[
                <svg width="%d" height="%d">
                    <rect width="%d" height="%d" x="0" y="0" rx="%d" ry="%d" fill="#FFFFFF"/>
                </svg>
            ]], w, h, w, h, scaledRadius, scaledRadius)
            Framework.cache.roundedRectangles[fillId] = svgCreate(w, h, svg)
        end

        dxDrawImage(x, y, w, h, Framework.cache.roundedRectangles[fillId], 0, 0, 0, fillColor, ...)

    elseif useStroke then
        local strokeId = string.format("stroke_in_%.0f_%.0f_%.0f_%.0f", w, h, scaledRadius, scaledStrokeWidth)
        if not Framework.cache.roundedRectangles[strokeId] then
            local svg = string.format([[
                <svg width="%d" height="%d">
                    <rect width="%d" height="%d" x="0" y="0" rx="%d" ry="%d"
                          fill="#FFFFFF" stroke="none"/>
                </svg>
            ]], w, h, w, h, scaledRadius, scaledRadius)
            Framework.cache.roundedRectangles[strokeId] = svgCreate(w, h, svg)
        end

        dxDrawImage(x, y, w, h, Framework.cache.roundedRectangles[strokeId], 0, 0, 0, strokeColor, ...)

        local innerW = w - scaledStrokeWidth * 2
        local innerH = h - scaledStrokeWidth * 2
        local innerRadius = math.max(0, scaledRadius - scaledStrokeWidth)
        local fillId = string.format("fill_%.0f_%.0f_%.0f", innerW, innerH, innerRadius)
        if not Framework.cache.roundedRectangles[fillId] then
            local svg = string.format([[
                <svg width="%d" height="%d">
                    <rect width="%d" height="%d" x="0" y="0" rx="%d" ry="%d" fill="#FFFFFF"/>
                </svg>
            ]], innerW, innerH, innerW, innerH, innerRadius, innerRadius)
            Framework.cache.roundedRectangles[fillId] = svgCreate(innerW, innerH, svg)
        end
        dxDrawImage(x + scaledStrokeWidth, y + scaledStrokeWidth, innerW, innerH, Framework.cache.roundedRectangles[fillId], 0, 0, 0, fillColor, ...)
    else
        local fillId = string.format("fill_%.0f_%.0f_%.0f", w, h, scaledRadius)
        if not Framework.cache.roundedRectangles[fillId] then
            local svg = string.format([[
                <svg width="%d" height="%d">
                    <rect width="%d" height="%d" x="0" y="0" rx="%d" ry="%d" fill="#FFFFFF"/>
                </svg>
            ]], w, h, w, h, scaledRadius, scaledRadius)
            Framework.cache.roundedRectangles[fillId] = svgCreate(w, h, svg)
        end
        dxDrawImage(x, y, w, h, Framework.cache.roundedRectangles[fillId], 0, 0, 0, fillColor, ...)
    end

    manageClearTimer("roundedRectangles")
end

function GetScaleValue()
    return scaleValue
end

function GetScreenSize()
    return screenWidth, screenHeight
end

function PositionStretch(x, y)
    return x * (screenWidth / basew), y * (screenHeight / baseh)
end

function ScaleStretch(w, h)
    return w * (screenWidth / basew), h * (screenHeight / baseh)
end

-- sem offset
function ImageFull(startX, startY, width, height, path, ...)
    local x, y = PositionStretch(startX, startY)
    local w, h = ScaleStretch(width, height)
    dxDrawImage(x, y, w, h, path, ...)
end

function HoverEffect(id, x, y, w, h, opts) -- id ('icon_car', 'btn_confirmar')
    opts = opts or {}

    local isSelected = opts.selected or false
    local isHovered = isMouseOverButton(x, y, w, h)
    local isClicked = isHovered and getKeyState('mouse1')
    local alphaNormal   = opts.alphaNormal   or 90
    local alphaHover    = opts.alphaHover    or 200
    local alphaSelected = opts.alphaSelected or 255

    local targetAlpha
    if isSelected then
        targetAlpha = alphaSelected
    elseif isHovered then
        targetAlpha = alphaHover
    else
        targetAlpha = alphaNormal
    end

    local scaleNormal = opts.scaleNormal or 1.0
    local scaleActive = opts.scaleActive or 1.15
    local targetScale = (isSelected or isHovered) and scaleActive or scaleNormal
    local speed = opts.speed or 0.15
    local alpha = Animate(id .. '_alpha', targetAlpha, speed)
    local scale = Animate(id .. '_scale', targetScale, speed)
    local colorNormal = opts.colorNormal or {255, 255, 255}
    local colorSelected = opts.colorSelected or {72, 145, 255}
    local targetColorT = isSelected and 1 or 0
    local colorT = Animate(id .. '_colorT', targetColorT, speed)
    local r = lerp(colorNormal[1], colorSelected[1], colorT)
    local g = lerp(colorNormal[2], colorSelected[2], colorT)
    local b = lerp(colorNormal[3], colorSelected[3], colorT)

    return {
        alpha = alpha,
        scale = scale,
        r = r, g = g, b = b,
        isHovered = isHovered,
        isClicked = isClicked,
        isSelected = isSelected,
    }
end

function ClearAnimation(id)
    Animations[id .. '_alpha'] = nil
    Animations[id .. '_scale'] = nil
end


local ScrollState = {}
local activeScrollAreas = {}

local function getScrollState(id)
    if not ScrollState[id] then
        ScrollState[id] = { offset = 0, dragging = false }
    end
    return ScrollState[id]
end

function Scrollbar(id, x, y, trackHeight, totalItems, visibleItems, opts)
    opts = opts or {}
    local state = getScrollState(id)
    local trackWidth = opts.trackWidth or 6
    local radius = opts.radius or trackWidth / 2
    local trackColor = opts.trackColor or tocolor(255, 255, 255, 25)
    local speed = opts.speed or 0.2
    local maxOffset = math.max(0, totalItems - visibleItems)

    if maxOffset <= 0 then
        state.offset = 0
        return 0
    end

    state.offset = clamp(state.offset, 0, maxOffset)

    local thumbHeightRatio = visibleItems / totalItems
    local thumbHeight = math.max(trackHeight * thumbHeightRatio, 20)
    local scrollableSpace = trackHeight - thumbHeight
    local scrollRatio = state.offset / maxOffset
    local thumbY = y + scrollableSpace * scrollRatio
    local isHoveredThumb = isMouseOverButton(x, thumbY, trackWidth, thumbHeight)

    if isHoveredThumb and getKeyState('mouse1') and not state.dragging then
        state.dragging = true
        local _, my = getCursorPosition()
        local _, screenH = GetScreenSize()
        state.dragStartMouseY = my * screenH
        state.dragStartThumbY = thumbY
    end

    if state.dragging and not getKeyState('mouse1') then
        state.dragging = false
    end

    if state.dragging then
        local _, my = getCursorPosition()
        local _, screenH = GetScreenSize()
        local mouseY = my * screenH
        local deltaY = mouseY - state.dragStartMouseY
        local newThumbY = clamp(state.dragStartThumbY + deltaY, y, y + scrollableSpace)
        local newRatio = scrollableSpace > 0 and ((newThumbY - y) / scrollableSpace) or 0
        state.offset = clamp(math.floor(newRatio * maxOffset + 0.5), 0, maxOffset)
    end

    local alphaTarget = (isHoveredThumb or state.dragging) and 180 or 100
    local thumbAlpha = Animate(id .. '_thumb_alpha', alphaTarget, speed)
    local thumbColor = opts.thumbColor and tocolor(opts.thumbColor[1], opts.thumbColor[2], opts.thumbColor[3], thumbAlpha) or tocolor(255, 255, 255, thumbAlpha)

    RoundedRectangle(x, y, trackWidth, trackHeight, radius, trackColor)
    RoundedRectangle(x, thumbY, trackWidth, thumbHeight, radius, thumbColor)

    return state.offset
end

function RegisterScrollArea(id, areaX, areaY, areaW, areaH, totalItems, visibleItems)
    activeScrollAreas[id] = { x = areaX, y = areaY, w = areaW, h = areaH, total = totalItems, visible = visibleItems }
end

function ResetScroll(id)
    local state = getScrollState(id)
    state.offset = 0
end

bindKey("mouse_wheel_up", "down", function()
    for id, area in pairs(activeScrollAreas) do
        if isMouseOverButton(area.x, area.y, area.w, area.h) then
            local state = getScrollState(id)
            state.offset = clamp(state.offset - 1, 0, math.max(0, area.total - area.visible))
        end
    end
end)

bindKey("mouse_wheel_down", "down", function()
    for id, area in pairs(activeScrollAreas) do
        if isMouseOverButton(area.x, area.y, area.w, area.h) then
            local state = getScrollState(id)
            state.offset = clamp(state.offset + 1, 0, math.max(0, area.total - area.visible))
        end
    end
end)

-- INPUT 
local Inputs = {}
local activeInput = nil

function CreateInput(id, x, y, width, height, masked)

    if Inputs[id] and isElement(Inputs[id]) then
        return Inputs[id]
    end

    local input = guiCreateEdit(0, 0, 1, 1, "", false)

    guiSetAlpha(input, 0)
    guiSetVisible(input, false)
    guiSetProperty(input, "AlwaysOnTop", "True")

    if masked then
        guiEditSetMasked(input, true)
    end

    Inputs[id] = input

    return input
end

function SetInputFocus(id)
    local input = Inputs[id]

    if not input or not isElement(input) then
        return false
    end

    for _, element in pairs(Inputs) do
        if isElement(element) then
            guiSetVisible(element, false)
        end
    end

    guiSetVisible(input, true)
    guiBringToFront(input)
    guiFocus(input)

    activeInput = id

    local text = guiGetText(input) or ""
    guiEditSetCaretIndex(input, utf8.len(text) or 0)

    return true
end

function GetInputText(id)
    local input = Inputs[id]

    if not input or not isElement(input) then
        return ""
    end

    return guiGetText(input) or ""
end

function SetInputText(id, text)
    local input = Inputs[id]

    if not input or not isElement(input) then
        return false
    end

    guiSetText(input, text or "")

    local value = guiGetText(input) or ""
    guiEditSetCaretIndex(input, utf8.len(value) or 0)
    return true
end

function ClearInput(id)
    return SetInputText(id, "")
end

function GetActiveInput()
    return activeInput
end

function DestroyInput(id)
    local input = Inputs[id]

    if input and isElement(input) then
        destroyElement(input)
    end

    Inputs[id] = nil

    if activeInput == id then
        activeInput = nil
    end

    return true
end

function DestroyAllInputs()
    for id, input in pairs(Inputs) do
        if isElement(input) then
            destroyElement(input)
        end
    end

    Inputs = {}
    activeInput = nil
end