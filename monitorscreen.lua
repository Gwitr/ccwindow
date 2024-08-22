local utils = require"utils"

local MonitorScreen = utils.Class(Screen)

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

local COLORIDS = {
  0x1, 0x2, 0x4, 0x8, 0x10, 0x20, 0x40, 0x80, 0x100,
  0x200, 0x400, 0x800, 0x1000, 0x2000, 0x4000, 0x8000
}

function MonitorScreen:setColorMap(colormap)
  for i=1,16 do
    self.monitor.setPaletteColor(COLORIDS[i],
      table.unpack(utils.map(colormap[i], function(v)
        return v/255 end)))
  end
end

function MonitorScreen:getColorMap()
  local cm = {}
  for i=1,16 do
    table.insert(cm, utils.map({self.monitor.getPaletteColour(COLORIDS[i])},
      function(v) return math.floor(v*255) end))
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

function MonitorScreen:width() return ({self.monitor.getSize()})[1] end
function MonitorScreen:height() return ({self.monitor.getSize()})[2] * 2 end

local CHARMAP = {"0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"}

function MonitorScreen:optimizedDims(optimized)
  return Point(optimized.w, optimized.h)
end
function MonitorScreen:optimizeImage(image, width)
  local huh = ""
  for i=1,#image,1 do
    local lo = CHARMAP[1+image:byte(i)%16]
    local hi = CHARMAP[1+math.floor(image:byte(i)/16)]
    huh = huh .. hi .. lo
  end
  return {huh=huh, w=width, h=#image*2/width}
end

function MonitorScreen:blitOptimized(optimized, pos, region)
  region = Rectangle(region or {0, 0, optimized.w, optimized.h})

  local sx, lx = region.tl.x, region:w()
  for y = math.max(region.tl.y, 0), math.min(region.br.y, optimized.h-1) do
    self.pixelbuffer[pos.y+y+1] =
      self.pixelbuffer[pos.y+y+1]:sub(1, pos.x) ..
      optimized.huh:sub(1 + sx + y*optimized.w, sx + y*optimized.w + lx) ..
      self.pixelbuffer[pos.y+y+1]:sub(pos.x+lx+1)
    self:flushPixelBuffer(pos.x, pos.x+lx-1, pos.y+y)
  end
end

function MonitorScreen:plotPixel(loc, color)
  self:fillRect(Rectangle{loc, loc}, color)
end

function MonitorScreen:drawLine(sp, ep, color)
  if sp.y == ep.y or sp.x == ep.x then
    if sp.x > ep.x or sp.y > ep.y then
      return self:fillRect(Rectangle{ep, sp}, color)
    end
    return self:fillRect(Rectangle{sp, ep}, color)
  end

  -- TOOD: fixme this is LAZYYY like yeah it "works" but come on
  local dvec = (ep - sp) * 10000
  local itercnt = math.ceil(dvec:mag() / 10000) + 1
  dvec = dvec / itercnt
  local pos = sp:copy() * 10000
  for i=1,itercnt do
    self:plotPixel(pos / 10000, color)
    pos = pos + dvec
  end
end

function MonitorScreen:flushPixelBuffer(x1, x2, y)
  self.monitor.setCursorPos(1 + x1, 1 + math.floor(y / 2))
  self.monitor.blit(("\x8f"):rep(x2-x1+1),
    self.pixelbuffer[y-y%2+1]:sub(1+x1, 1+x2),
    self.pixelbuffer[y-y%2+2]:sub(1+x1, 1+x2))
end

function MonitorScreen:fillRect(rect, color)
  for y=rect.tl.y,rect.br.y do
    self.pixelbuffer[1+y] =
      self.pixelbuffer[1+y]:sub(1,rect.tl.x) ..
      CHARMAP[color]:rep(rect.br.x - rect.tl.x + 1) ..
      self.pixelbuffer[1+y]:sub(rect.br.x+2)
    self:flushPixelBuffer(rect.tl.x, rect.br.x, y)
  end
end

return {MonitorScreen=MonitorScreen}
