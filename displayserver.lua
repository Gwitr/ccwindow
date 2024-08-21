local utils = require "utils"

Point = utils.Class()
function Point:initialize(coords)
  if coords.class == Point then
    self.x = coords.x
    self.y = coords.y
  else
    local coords_arr = utils.pairsToTable(coords)
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

Rectangle = utils.Class()
function Rectangle:initialize(tab)
  if tab.class == Rectangle then
    self.tl = tab.tl:copy()
    self.br = tab.br:copy()
  else
    tab = utils.pairsToTable(tab)
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

-- TODO: Non-constant color depth
Display = utils.Class()
function Display:initialize(screen)
  local baseColormapKey = {}
  self.colormaps = {
    [baseColormapKey]=screen:getColorMap(),
    count=1,
    baseKey=baseColormapKey
  }
  self.screen = screen
  self.root = Window(self, nil, {0, 0, screen:width() - 2, screen:height() - 2}, function(event, ...)
    if event == "redraw"
      then self.screen.pixelFillRect(..., 15)
    end
  end, false)
  self.root.isFocused = true
  self.focused = self.root
end

function Display:mapImage(image, mapping)
  local newimg = ""
  for i=1,#image do
    local hi = math.floor(image:byte(i) / 16)
    local lo = image:byte(i) % 16
    newimg = newimg .. string.char((mapping[1+hi]-1)*16+mapping[1+lo]-1)
  end
  return newimg
end

function Display:allocColorMap(palette)
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
    local _, j = utils.minf(avgRGB, function(rgb)
      if rgb == false then return 20000000 end
      return math.pow(rgb[1] - palette[i][1], 2) + math.pow(rgb[2] - palette[i][2], 2) + math.pow(rgb[3] - palette[i][3], 2)
    end)
    colormap[j] = {palette[i][1], palette[i][2], palette[i][3]}
    avgRGB[j] = false
    mapping[i] = j
  end
  local cmKey = {}  -- opaque reference
  self.colormaps[cmKey] = colormap
  self.colormaps.count = self.colormaps.count + 1

  return cmKey, mapping
end

function Display:deallocColorMap(key)
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

BoxedPainter = utils.Class()
function BoxedPainter:initialize(screen, offset, rect)
  self.screen = screen
  self.offset = Point(offset)
  self.rect = Rectangle(rect)
end

function BoxedPainter:pixelBlitOptimized(optimized, pos, region)
  local imgsize = self.screen:optimizedDims(optimized)
  local pos = Point(pos) + self.offset
  local region
  if region == nil then
    region = Rectangle{{0, 0}, imgsize}
  else
    region = region.copy()
  end

  if pos.x < self.rect.tl.x then
    region.tl.x = region.tl.x + self.rect.tl.x - pos.x
    pos.x = self.rect.tl.x
  end
  if pos.y < self.rect.tl.y then
    region.tl.y = region.tl.y + self.rect.tl.y - pos.y
    pos.y = self.rect.tl.y
  end
  if pos.x + region.br.x > self.rect.br.x then
    region.br.x = self.rect.br.x - pos.x
  end
  if pos.y + region.br.y > self.rect.br.y then
    region.br.y = self.rect.br.y - pos.y
  end

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
  local a  = norm((ep.y - sp.y) / (ep.x - sp.x), 100000000)
  local b, b_over_a = sp.y - a * sp.x, sp.y * inva - sp.x

  local base_intersect_points = {
    Point{self.rect.tl.y * inva - b_over_a, self.rect.tl.y},
    Point{self.rect.br.y * inva - b_over_a, self.rect.br.y},
    Point{self.rect.tl.x, a * self.rect.tl.x + b},
    Point{self.rect.br.x, a * self.rect.br.x + b}
  }
  local intersect_points = {}
  for _, v in ipairs(base_intersect_points) do
    if boundRect:checkPointOverlap(v) then table.insert(intersect_points, v) end
  end
  if #intersect_points == 0 then return end
  local fuck = "possible:"
  for _, v in ipairs(intersect_points) do fuck = fuck .. " " .. tostring(v) end

  if not boundRect:checkPointOverlap(sp) then
    sp = utils.minf(intersect_points, function(v) return (v-sp):mag() end)
  end
  if not boundRect:checkPointOverlap(ep) then
    ep = utils.minf(intersect_points, function(v) return (v-ep):mag() end)
  end

  self.screen:pixelDrawLine(sp, ep, color)
end

function BoxedPainter:pixelFillRect(rect, color)
  rect = Rectangle(rect)
  local overlap = self.rect:overlapArea{rect.tl + self.offset, rect.br + self.offset}
  if overlap ~= nil then self.screen:pixelFillRect(overlap, color) end
end

Window = utils.Class()
function Window:initialize(display, parent, rect, wndFunc, focus)
  if focus == nil then focus = true end
  self.display = display
  self.parent = parent
  self.rect = Rectangle(rect)
  self.wndFunc = wndFunc
  self.windows = {}
  if self.parent == nil then
    self.colormap = self.display.colormaps.baseKey
  else
    self.colormap = self.parent.colormap
  end
--  print("colormap:", self.colormap)
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
  self.display.screen:setColorMap(
    self.display.colormaps[self.colormap])
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
  for wnd in self.display.root:childWindowsUnder(
    self.parent:rectToWorld(clipped_rect)) do
    if wnd == self then break end
    rects = self:rectToLocal(
      wnd.parent:rectToWorld(wnd:getClippedRect())
    ):subtractFrom(table.unpack(rects))
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

function Window:rectToLocal(rect)
  rect = Rectangle(rect)
  return Rectangle{self:pointToLocal(rect.tl),
    self:pointToLocal(rect.br)}
end

function Window:rectToWorld(rect)
  rect = Rectangle(rect)
  return Rectangle{self:pointToWorld(rect.tl),
    self:pointToWorld(rect.br)}
end

function Window:childWindowsUnder(rect)
  rect = Rectangle(rect)
  return coroutine.wrap(function()
    for i=#self.windows,1,-1 do
      local wnd = self.windows[i]
      if rect:overlapArea(wnd:getClippedRect()) ~= nil then
        local local_rect = wnd:rectToLocal(rect)
        local rects = {rect:copy()}
        for subwnd in wnd:childWindowsUnder(local_rect) do
          rects = wnd.parent:rectToLocal(
            subwnd.parent:rectToWorld(
              subwnd:getClippedRect()
            )
          ):subtractFrom(table.unpack(rects))
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
  return BoxedPainter(self.display.screen, self.parent:pointToWorld(self.rect.tl), self:rectToWorld(redraw_rect))
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

function Window:setColorMap(cmkey)
  self.colormap = cmkey
  if self.isFocused then
    self.display.screen:setColorMap(self.display.colormaps[self.colormap])
  end
end

function Window:changeParent(newParent)
  local rect = self:rectToWorld(self.rect)
  for i, x in ipairs(self.parent.windows) do
    if x == self then
      table.remove(self.parent.windows, i)
      break
    end
  end
  local oldParent = self.parent
  self.parent = newParent
  table.insert(self.parent.windows, self)
  oldParent:redraw{0, 0, oldParent.rect:w(), oldParent.rect:h()}
  self:redraw{0, 0, self.rect:w(), self.rect:h()}
end

return {Window=Window, Display=Display, Point=Point, Rectangle=Rectangle}
