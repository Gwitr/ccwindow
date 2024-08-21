local function pairsToTable(inp)
    local tab = {}
    for key, value in pairs(inp) do tab[key] = value end
    return tab
end

local function call_base(self, ...)
    local instance = self:allocate(...)
    instance:initialize(...)
    return instance
end

local function minf(tab, key)
    local minv, minobj, mini = math.huge, nil, 0
    for i, v in ipairs(tab) do
        if key(v) < minv then
            minv = key(v, i)
            minobj = v
            mini = i
        end
    end
    return minobj, mini
end

local Class = {__call=call_base}
Class.__index = Class
setmetatable(Class, {__call=call_base})
function Class:allocate(base)
    local instance = {class=base or self, abstract_methods={}, __call=call_base}
    instance.__index = instance
    setmetatable(instance, instance.class)
    function instance:allocate()
        local instance = {class=self}
        for name, default in pairs(self.abstract_methods) do
            if self[name] == default then
                error("cannot instantiate class with abstract method " .. name)
            end
        end
        setmetatable(instance, self)
        return instance
    end
    return instance
end
function Class:initialize(base)
end
function Class:abstractMethod(name)
    self[name] = function() error("call of abstract method " .. name) end
    self.abstract_methods[name] = self[name]
end

Point = Class()
function Point:initialize(coords)
    if coords.class == Point then
        self.x = coords.x
        self.y = coords.y
    else
        local coords_arr = pairsToTable(coords)
        self.x = math.floor(coords_arr[1])
        self.y = math.floor(coords_arr[2])
    end
end

function Point:copy()
    return Point{self.x, self.y}
end

function Point:mag()
    return math.sqrt(math.pow(self.x, 2) + math.pow(self.y, 2))
end

function Point:__tostring()
    return ("Point{%d, %d}"):format(self.x, self.y)
end

function Point:__add(other)
    return Point{self.x + other.x, self.y + other.y}
end

function Point:__sub(other)
    return Point{self.x - other.x, self.y - other.y}
end

function Point:__mul(other)
    return Point{self.x * other, self.y * other}
end

function Point:__div(other)
    return Point{self.x / other, self.y / other}
end

local function rangeOverlap(x1, x2, y1, y2)
    if not (x1 <= y2 and y1 <= x2) then return false end
    local omin = math.max(x1, y1)
    local omax = math.min(x2, y2)
    if omin > omax then return true, omax, omin end
    return true, omin, omax
end

Rectangle = Class()
function Rectangle:initialize(tab)
    if tab.class == Rectangle then
        self.tl = tab.tl:copy()
        self.br = tab.br:copy()
    else
        tab = pairsToTable(tab)
        if #tab == 2 then
            self.tl = Point(tab[1])
            self.br = Point(tab[2])
        elseif #tab == 4 then
            self.tl = Point{tab[1], tab[2]}
            self.br = Point{tab[1]+tab[3]-1, tab[2]+tab[4]-1}
        else
            error("invalid argument to constructor")
        end
    end
end

function Rectangle:__tostring()
    return ("Rectangle{%s, %s}"):format(self.tl, self.br):gsub("Point", "")
end

function Rectangle:size(value)
    if value == nil then return Point{self:w(), self:h()} end
    self.br = self.tl + Point(value) - Point{1, 1}
end

function Rectangle:w(value)
    if value == nil then return self.br.x - self.tl.x + 1 end
    self.br.x = self.tl.x + value - 1
end

function Rectangle:h(value)
    if value == nil then return self.br.y - self.tl.y + 1 end
    self.br.y = self.tl.y + value - 1
end

function Rectangle:sizing()
    return {self.tl.x, self.tl.y, self:size().x, self:size().y}
end

function Rectangle:copy()
    return Rectangle(self)
end

function Rectangle:checkPointOverlap(point)
    point = Point(point)
    return self.tl.x <= point.x and point.x <= self.br.x and self.tl.y <= point.y and point.y <= self.br.y
end

function Rectangle:overlapArea(other)
    other = Rectangle(other)
    local overlap, xos, xoe, yos, yoe
    overlap, xos, xoe = rangeOverlap(self.tl.x, self.br.x, other.tl.x, other.br.x)
    if not overlap then return end
    overlap, yos, yoe = rangeOverlap(self.tl.y, self.br.y, other.tl.y, other.br.y)
    if not overlap then return end
    return Rectangle{{xos, yos}, {xoe, yoe}}
end

function Rectangle:subtractFrom(...)
    local newrects = {}
    for _, rect in ipairs{...} do
        rect = rect:copy()
        local overlap = self:overlapArea(rect)
        if overlap == nil then
            table.insert(newrects, rect)
        else
            if overlap.tl.x > rect.tl.x then
                table.insert(newrects, Rectangle{rect.tl, Point{overlap.tl.x - 1, rect.br.y}})
                rect.tl.x = overlap.tl.x
            end
            if overlap.tl.y > rect.tl.y then
                table.insert(newrects, Rectangle{rect.tl, Point{rect.br.x, overlap.tl.y - 1}})
                rect.tl.y = overlap.tl.y
            end
            if overlap.br.x < rect.br.x then
                table.insert(newrects, Rectangle{{overlap.br.x + 1, rect.tl.y}, rect.br})
                rect.br.x = overlap.br.x
            end
            if overlap.br.y < rect.br.y then
                table.insert(newrects, Rectangle{{rect.tl.x, overlap.br.y + 1}, rect.br})
                rect.br.y = overlap.br.y
            end
        end
    end
    return newrects
end

Screen = Class()
Screen:abstractMethod "width"
Screen:abstractMethod "height"
Screen:abstractMethod "normalizeEvent"
Screen:abstractMethod "optimizedDims"
Screen:abstractMethod "optimizeImage"       -- takes 2 arguments - an image, as a string of RGB triplets, and its width. Returns an implementation-defined value that is to be treated as opaque.
Screen:abstractMethod "pixelBlitOptimized"
Screen:abstractMethod "pixelDrawLine"
Screen:abstractMethod "pixelFillRect"
Screen:abstractMethod "setColorMap"

MonitorScreen = Class(Screen)
function MonitorScreen:initialize(side)
    self.side = side
    self.monitor = peripheral.wrap(side)
    self.monitor.clear()
    self.monitor.setTextScale(0.5)
    self.pixelbuffer = {}
    for i=1,self:height() do
        table.insert(self.pixelbuffer, ("f"):rep(self:width()))
    end
end

local COLORIDS = {0x1, 0x2, 0x4, 0x8, 0x10, 0x20, 0x40, 0x80, 0x100, 0x200, 0x400, 0x800, 0x1000, 0x2000, 0x4000, 0x8000}

function MonitorScreen:setColorMap(colormap)
    for i=1,16 do
        self.monitor:setPaletteColour(COLORIDS[i], colormap[i])
    end
end

function MonitorScreen:getColorMap()
    local cm = {}
    for i=1,16 do
        table.insert(cm, self.monitor:getPaletteColour(COLORIDS[i]))
    end
    return cm
end

function MonitorScreen:normalizeEvent(event, ...)
    local args = {...}
    if event == "monitor_touch" and args[1] == self.side then
        event = "touch"
        args = {Point{args[2] - 1, args[3] * 2 - 2}}
    end
    return event, table.unpack(args)
end

function MonitorScreen:width()  return ({self.monitor.getSize()})[1] end
function MonitorScreen:height() return ({self.monitor.getSize()})[2] * 2 end

local COLORMAP = {
    ["0"] = {0xF0, 0xF0, 0xF0}, ["1"] = {0xF2, 0xB2, 0x33}, ["2"] = {0xE5, 0x7F, 0xD8}, ["3"] = {0x99, 0xB2, 0xF2},
    ["4"] = {0xDE, 0xDE, 0x6C}, ["5"] = {0x7F, 0xCC, 0x19}, ["6"] = {0xF2, 0xB2, 0xCC}, ["7"] = {0x4C, 0x4C, 0x4C},
    ["8"] = {0x99, 0x99, 0x99}, ["9"] = {0x4C, 0x99, 0xB2}, ["a"] = {0xB2, 0x66, 0xE5}, ["b"] = {0x33, 0x66, 0xCC},
    ["c"] = {0x7F, 0x66, 0x4C}, ["d"] = {0x57, 0xA6, 0x4E}, ["e"] = {0xCC, 0x4C, 0x4C}, ["f"] = {0x19, 0x19, 0x19}
}
local CHARMAP = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}

local function approxRGB(r, g, b)
    local mindiff = 200000
    local mincol
    for col, colrgb in pairs(COLORMAP) do
        local diff = (r - colrgb[1]) * (r - colrgb[1]) + (g - colrgb[2]) * (g - colrgb[2]) + (b - colrgb[3]) * (b - colrgb[3])
        if diff < mindiff then
            mindiff = diff
            mincol = col
        end
    end
    return mincol
end

function MonitorScreen:optimizedDims(optimized) return Point(optimized.w, optimized.h) end
function MonitorScreen:optimizeImage(image, width)
    local huh = ""
    for i=1,#image,3 do
        huh = huh .. approxRGB(("<BBB"):unpack(image:sub(i, i+2)))
    end
    return {huh=huh, w=width, h=#image/3/width}
end

function MonitorScreen:pixelBlitOptimized(optimized, pos, region)
    if region == nil then region = Rectangle{0, 0, optimized.w, optimized.h} else region = Rectangle(region) end

    for y = math.max(region.tl.y, 0), math.min(region.br.y, optimized.h-1) do
        self.pixelbuffer[pos.y+y+1] =
            self.pixelbuffer[pos.y+y+1]:sub(1, pos.x) ..
            optimized.huh:sub(1 + y*optimized.w, (y+1)*optimized.w) ..
            self.pixelbuffer[pos.y+y+1]:sub(pos.x+optimized.w+1)
        self:flushPixelBuffer(pos.x, pos.x+optimized.w-1, pos.y+y)
    end
end

function MonitorScreen:pixelPlot(loc, color)
    self:pixelFillRect(Rectangle{loc, loc}, color)
end

function MonitorScreen:pixelDrawLine(sp, ep, color)
    if sp.y == ep.y or sp.x == ep.x then
        if sp.x > ep.x or sp.y > ep.y then
            return self:pixelFillRect(Rectangle{ep, sp}, color)
        end
        return self:pixelFillRect(Rectangle{sp, ep}, color)
    end

    -- TOOD: fixme this is LAZYYY like yeah it "works" but come on
    local dvec = (ep - sp) * 10000
    local itercnt = math.ceil(dvec:mag() / 10000) + 1
    dvec = dvec / itercnt
    local pos = sp:copy() * 10000
    for i=1,itercnt do
        self:pixelPlot(pos / 10000, color)
        pos = pos + dvec
    end
end

function MonitorScreen:flushPixelBuffer(x1, x2, y)
    self.monitor.setCursorPos(1 + x1, 1 + math.floor(y / 2))
    if y % 2 == 1 then
        self.monitor.blit(("\x8f"):rep(x2-x1+1), self.pixelbuffer[y]:sub(1+x1, 1+x2), self.pixelbuffer[y+1]:sub(1+x1, 1+x2))
    else
        self.monitor.blit(("\x8f"):rep(x2-x1+1), self.pixelbuffer[y+1]:sub(1+x1, 1+x2), self.pixelbuffer[y+2]:sub(1+x1, 1+x2))
    end
end

function MonitorScreen:pixelFillRect(rect, color)
    for y=rect.tl.y,rect.br.y do
        self.pixelbuffer[1+y] =
            self.pixelbuffer[1+y]:sub(1,rect.tl.x) ..
            CHARMAP[color]:rep(rect.br.x - rect.tl.x + 1) ..
            self.pixelbuffer[1+y]:sub(rect.br.x+2)
        self:flushPixelBuffer(rect.tl.x, rect.br.x, y)
    end
end

-- TODO: Non-constant color depth
Display = Class()
function Display:initialize(screen)
    self.screen = screen
    self.root = Window(self, nil, {0, 0, screen:width() - 2, screen:height() - 2}, function(event, ...)
        if event == "redraw"
            then self.screen.pixelFillRect(..., approxRGB(0, 0, 0))
        end
    end, false)
    self.root.isFocused = true
    self.focused = self.root

    local baseColormapKey = {}
    self.colormaps = {[baseColormapKey]=screen:getColormap(), count=1, baseKey=baseColormapKey}
end

function Display:allocColormap(palette)
    -- TODO: Ensure black and white are always available

    local avgRGB = {}
    for i=1,16 do
        local avgR, avgG, avgB = 0, 0, 0
        for k, colormap in pairs(self.colormaps) do
            if type(k) ~= "string" then
                local r, g, b = table.unpack(colormap[i])
                avgR = avgR + r avgG = avgG + g avgB = avgB + b
            end
        end
        table.insert(avgRGB, {math.floor(avgR / self.colormaps.count), math.floor(avgG / self.colormaps.count), math.floor(avgB / self.colormaps.count)})
    end

    local colormap = {}
    local mapping = {}
    for i=1,16 do
        local _, j = minf(avgRGB, function(rgb)
            if rgb == nil then return 20000000 end
            return math.pow(rgb[1] - palette[i][1], 2) + math.pow(rgb[2] - palette[i][2], 2) + math.pow(rgb[3] - palette[i][3], 2)
        end)
        colormap[j] = {palette[i][0], palette[i][1], palette[i][2]}
        avgRGB[j] = nil
        mapping[i] = j
    end
    local cmKey = {}  -- opaque reference
    self.colormaps[cmKey] = colormap
    self.colormaps.count = self.colormaps.count + 1

    return cmKey, mapping
end

function Display:deallocColormap(key)
    self.colormaps[key] = nil
end

function Display:pullEvent()
    function normArg(wnd, arg)
        if type(wnd) == "table" and wnd.class == Point then return wnd:pointToLocal(arg) end
        return arg
    end
    local event = {self.screen:normalizeEvent(os.pullEvent())}
    if event[1] == "touch" or event[1] == "mousedown" then
        for wnd in self.root:childWindowsUnder{event[2], event[2] + Point{1, 1}} do
            wnd:focus()
            for subwnd in wnd:iterUp() do
                subwnd:wndFunc(event[1], normArg(wnd, event[2]))
            end
            break  -- only give the event to the topmost window
        end
    elseif event[1] == "key" or event[1] == "keyup" or event[1] == "mouseup" then
        for subwnd in self.focused:iterUp() do
            subwnd:wndFunc(event[1], normArg(wnd, event[2]))
        end
    elseif event[1] == "mousemove" then
        for wnd in self.root:childWindowsUnder{event[2], event[2] + Point{1, 1}} do
            wnd:wndFunc(event[1], normArg(wnd, event[2]))  -- TODO: Should the parents also receive mousemove?
        end
    end
    return event
end

BoxedPainter = Class()
function BoxedPainter:initialize(screen, offset, rect)
    self.screen = screen
    self.offset = Point(offset)
    self.rect = Rectangle(rect)
end

function BoxedPainter:pixelBlitOptimized(optimized, pos, region)
    local imgsize = self.screen:optimizedDims(optimized)
    local pos = Point(pos) + self.offset
    local region
    if region == nil then region = Rectangle{{0, 0}, imgsize} else region = region.copy() end

    if pos.x < self.rect.tl.x then region.tl.x = region.tl.x + self.rect.tl.x - pos.x pos.x = self.rect.tl.x end
    if pos.y < self.rect.tl.y then region.tl.y = region.tl.y + self.rect.tl.y - pos.y pos.y = self.rect.tl.y end
    if pos.x + region.br.x > self.rect.br.x then region.br.x = self.rect.br.x - pos.x end
    if pos.y + region.br.y > self.rect.br.y then region.br.y = self.rect.br.y - pos.y end

    self.screen:pixelBlitOptimized(optimized, pos, region)
end

function BoxedPainter:pixelDrawLine(sp, ep, color)
    local function norm(x, d)
        if x ~= x or x == math.huge or x == -math.huge then return d end
        return x
    end

    -- Avoid weird precision isseus
    local boundRect = self.rect:copy()
    boundRect.tl = boundRect.tl - Point{1, 1}
    boundRect.br = boundRect.br + Point{1, 1}

    sp, ep = Point(sp) + self.offset, Point(ep) + self.offset
    local inva = norm((ep.x - sp.x) / (ep.y - sp.y), 100000000)
    local a    = norm((ep.y - sp.y) / (ep.x - sp.x), 100000000)
    local b, b_over_a = sp.y - a * sp.x, sp.y * inva - sp.x

    local base_intersect_points = {
        Point{self.rect.tl.y * inva - b_over_a, self.rect.tl.y}, Point{self.rect.tl.x, a * self.rect.tl.x + b},
        Point{self.rect.br.y * inva - b_over_a, self.rect.br.y}, Point{self.rect.br.x, a * self.rect.br.x + b}
    }
    local intersect_points = {}
    for _, v in ipairs(base_intersect_points) do
        if boundRect:checkPointOverlap(v) then table.insert(intersect_points, v) end
    end
    if #intersect_points == 0 then return end
    local fuck = "possible:"
    for _, v in ipairs(intersect_points) do fuck = fuck .. " " .. tostring(v) end

    if not (boundRect:checkPointOverlap(sp)) then sp = minf(intersect_points, function(v) return (v-sp):mag() end) end
    if not (boundRect:checkPointOverlap(ep)) then ep = minf(intersect_points, function(v) return (v-ep):mag() end) end

    self.screen:pixelDrawLine(sp, ep, color)
end

function BoxedPainter:pixelFillRect(rect, color)
    rect = Rectangle(rect)
    local overlap = self.rect:overlapArea{rect.tl + self.offset, rect.br + self.offset}
    if overlap ~= nil then self.screen:pixelFillRect(overlap, color) end
end

Window = Class()
function Window:initialize(display, parent, rect, wndFunc, focus)
    if focus == nil then focus = true end
    self.display = display
    self.parent = parent
    self.rect = Rectangle(rect)
    self.wndFunc = wndFunc
    self.windows = {}
    self.isFocused = false
    if parent ~= nil then table.insert(parent.windows, self) end
    if focus then self:focus() end
end

function Window:iterUp()
    return coroutine.wrap(function()
        local wnd = self
        while wnd ~= nil do
            coroutine.yield(wnd)
            wnd = wnd.parent
        end
    end)
end

function Window:setGeometry(rect)
    local old_tl, old_br = self.parent:pointToWorld(self.rect.tl), self.parent:pointToWorld(self.rect.br)
    self.rect = Rectangle(rect)
    local windows = {}
    for wnd in self.display.root:childWindowsUnder{old_tl, old_br} do table.insert(windows, wnd) end
    for i=#windows,1,-1 do
        windows[i]:redraw{windows[i]:pointToLocal(old_tl), windows[i]:pointToLocal(old_br) + Point{1, 1}}
    end
    self:redraw{0, 0, self.rect:w(), self.rect:h()}
end

function Window:focus()
    if self.isFocused then return end
    self.isFocused = true
    local myParents = {}
    for wnd in self:iterUp() do
        if wnd ~= self then table.insert(myParents, wnd) end
    end
    if self.display.focused ~= nil then
        for wnd in self.display.focused:iterUp() do
            local s = true
            for _, wnd2 in ipairs(myParents) do
                if wnd == wnd2 then
                    s = false
                    break
                end
            end
            if s then wnd.isFocused = false end
        end
        self.display.focused:wndFunc("unfocus")
    end
    if self.parent.parent ~= nil then self.parent:focus() end
    self.display.focused = self
    self:moveTop()
    self:wndFunc("focus")
end

function Window:moveTop()
    if self.parent ~= nil then
        for i, x in ipairs(self.parent.windows) do
            if x == self then
                table.remove(self.parent.windows, i)
                break
            end
        end
        table.insert(self.parent.windows, self)
    end
    self:redraw{0, 0, self.rect:w(), self.rect:h()}
end

function Window:__tostring()
    return ("Window{x=%d, y=%d, w=%d, h=%d}"):format(self.rect.tl.x, self.rect.tl.y, self.rect.w, self.rect.h)
end

function Window:redraw(rect)
    rect = Rectangle(rect)
    local rects = self:overlapVisible(rect)
    for _, subrect in ipairs(rects) do
        self:wndFunc("redraw", subrect)
    end
    for _, subwnd in ipairs(self.windows) do
        subwnd:redraw{rect.tl - subwnd.rect.tl, rect.br - subwnd.rect.tl}
    end
end

function Window:overlapVisible(rect)
    rect = Rectangle(rect)
    local clipped_rect = self:getClippedRect()
    local local_clipped_rect = clipped_rect:copy()
    local_clipped_rect.tl = local_clipped_rect.tl - self.rect.tl
    local_clipped_rect.br = local_clipped_rect.br - self.rect.tl
    local_clipped_rect = local_clipped_rect:overlapArea(rect)
    if local_clipped_rect == nil then return {} end
    local rects = {local_clipped_rect}
    for wnd in self.display.root:childWindowsUnder{self.parent:pointToWorld(clipped_rect.tl), self.parent:pointToWorld(clipped_rect.br)} do
        if wnd == self then break end
        local sub_clipped_rect = wnd:getClippedRect()
        sub_clipped_rect = Rectangle{self:pointToLocal(wnd.parent:pointToWorld(sub_clipped_rect.tl)), self:pointToLocal(wnd.parent:pointToWorld(sub_clipped_rect.br))}
        rects = sub_clipped_rect:subtractFrom(table.unpack(rects))
    end
    return rects
end

function Window:getClippedRect()
    -- TODO: Do this recursively
    if self.parent == nil then return self.rect:copy() end
    return Rectangle{
        {math.max(self.rect.tl.x, 0), math.max(self.rect.tl.y, 0)},
        {math.min(self.rect.br.x, self.parent.rect:w()), math.min(self.rect.br.y, self.parent.rect:h())}
    }
end

function Window:pointToLocal(point)
    if self.parent == nil then return Point(point) end
    return self.parent:pointToLocal(Point(point) - self.rect.tl)
end

function Window:pointToWorld(point)
    if self.parent == nil then return Point(point) end
    local res = self.parent:pointToWorld(Point(point) + self.rect.tl)
    return res
end

function Window:childWindowsUnder(rect)
    rect = Rectangle(rect)
    return coroutine.wrap(function()
        for i=#self.windows,1,-1 do
            local wnd = self.windows[i]
            if rect:overlapArea(wnd:getClippedRect()) ~= nil then
                local local_rect = Rectangle{wnd:pointToLocal(rect.tl), wnd:pointToLocal(rect.br)}
                local rects = {rect:copy()}
                for subwnd in wnd:childWindowsUnder(local_rect) do
                    local subrect = subwnd:getClippedRect()
                    subrect = Rectangle{subwnd.parent:pointToWorld(subrect.tl), subwnd.parent:pointToWorld(subrect.br)}
                    subrect = Rectangle{wnd.parent:pointToLocal(subrect.tl), wnd.parent:pointToLocal(subrect.br)}
                    rects = subrect:subtractFrom(table.unpack(rects))
                    coroutine.yield(subwnd)
                end
                for _, subrect in ipairs(rects) do
                    if subrect:overlapArea(wnd.rect) then
                        coroutine.yield(wnd)
                        break
                    end
                end
            end
        end
    end)
end

function Window:getPainter(redraw_rect)
    return BoxedPainter(self.display.screen, self.parent:pointToWorld(self.rect.tl), {self:pointToWorld(redraw_rect.tl), self:pointToWorld(redraw_rect.br)})
end

function Window:destroy()
    for _, wnd in ipairs(self.windows) do
        wnd:destroy()
    end
    self:wndFunc("destroy")

    local oldrect = self.rect
    self.rect = Rectangle{-100000000, 1000000, 1, 1}
    for i, x in ipairs(self.parent.windows) do
        if x == self then
            table.remove(self.parent.windows, i)
            break
        end
    end
    self.parent:redraw(oldrect)
    self.parent = nil
    self.display = nil
end

function Window:changeParent(newParent)
    local rect = Rectangle{self:pointToWorld(self.rect.tl), self:pointToWorld(self.rect.br)}
    for i, x in ipairs(self.parent.windows) do
        if x == self then
            table.remove(self.parent.windows, i)
            break
        end
    end
    local oldParent = self.parent
    self.parent = newParent
    table.insert(self.parent.windows, self)
    oldParent:redraw{0, 0, oldParent.rect:w(), oldParent.rect:h()}  -- inefficient, but changing parents won't be done commonly
    self:redraw{0, 0, self.rect:w(), self.rect:h()}
end

local display = Display(MonitorScreen "left")
print("Resolution:", display.screen:width(), display.screen:height())

--[[
function panelWndFunc(wnd, event, ...)
    if event == "redraw" then
        local paint = wnd:getPainter(...)
        paint:pixelFillRect({{1, 1}, {wnd.rect:w()-1, wnd.rect:h()-1}}, 1)
        paint:pixelDrawLine({0, 0}, {wnd.rect:w(), 0}, 12)
        paint:pixelDrawLine({0, 0}, {0, wnd.rect:h()}, 12)
        paint:pixelDrawLine({wnd.rect:w(), wnd.rect:h()}, {wnd.rect:w(), 0}, 12)
        paint:pixelDrawLine({wnd.rect:w(), wnd.rect:h()}, {0, wnd.rect:h()}, 12)
    end
end

function buttonWndFunc(wnd, event, ...)
    if event == "redraw" then
        if wnd.color == nil then wnd.color = 4 end
        local paint = wnd:getPainter(...)
        paint:pixelFillRect({{1, 1}, {wnd.rect:w()-2, wnd.rect:h()-2}}, wnd.color)
        paint:pixelDrawLine({0, 0}, {wnd.rect:w()-1, 0}, 12)
        paint:pixelDrawLine({0, 0}, {0, wnd.rect:h()-1}, 12)
        paint:pixelDrawLine({wnd.rect:w()-1, wnd.rect:h()-1}, {wnd.rect:w()-1, 0}, 12)
        paint:pixelDrawLine({wnd.rect:w()-1, wnd.rect:h()-1}, {0, wnd.rect:h()-1}, 12)
    elseif event == "focus" then
        wnd.color = 5
        wnd:redraw{{0, 0}, wnd.rect:size()}
    elseif event == "unfocus" then
        wnd.color = 4
        wnd:redraw{{0, 0}, wnd.rect:size()}
    end
end

for panelid = 0, 1 do
    local panel = Window(display, display.root, {5 + panelid * 21, 4 + panelid * 22, 42, 42}, panelWndFunc)
    for buttonid = 0, 24 do
        Window(display, panel, {2 + buttonid % 5 * 8, 2 + math.floor(buttonid / 5) * 8, 7, 7}, buttonWndFunc)
    end
end
]]

function panelWndFunc(wnd, event, ...)
    if event == "redraw" then
        local rect = ...
        wnd.display.screen:pixelFillRect(Rectangle{wnd:pointToWorld(rect.tl), wnd:pointToWorld(rect.br)}, 1)
    end
end

local panel1 = Window(display, display.root, {10, 10, 50, 50}, panelWndFunc)
local panel2 = Window(display, display.root, {70, 10, 50, 50}, panelWndFunc)
local mobilePanel = Window(display, panel1, {15, 15, 20, 20}, function(wnd, event, ...)
    if event == "redraw" then
        local rect = ...
        wnd.display.screen:pixelFillRect(Rectangle{wnd:pointToWorld(rect.tl), wnd:pointToWorld(rect.br)}, 4)
    elseif event == "touch" then
        if wnd.parent == panel1 then wnd:changeParent(panel2) else wnd:changeParent(panel1) end
    end
end)

while true do display:pullEvent() end
