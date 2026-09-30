function isMouseOverButton(bx, by, bw, bh)
    local cx, cy = getCursorPosition()
    if not cx then return false end
    local sw, sh = GetScreenSize()
    local mx, my = cx * sw, cy * sh
    local x, y = Position(bx, by)
    local w, h = Scale(bw, bh)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end