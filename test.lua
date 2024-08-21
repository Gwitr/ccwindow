local MonitorScreen = require"monitorscreen".MonitorScreen
local ds = require"displayserver"

local display = ds.Display(MonitorScreen "left")
print("Resolution:", display.screen:width(), display.screen:height())

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

local cm = {}
for i = 0,15 do local c=math.floor(i/15*255) cm[1+i]={c,c,c} end
for panelid = 0,1 do
  local panelRect = {20 + panelid * 23, 4 + panelid * 24, 45, 45}
  local panel = ds.Window(display, display.root, panelRect, panelWndFunc)
  if panelid == 0 then panel:setColorMap(display:allocColorMap(cm)) end
  for buttonid = 0, 24 do
    local buttonRect = {2+buttonid%5*8,2+math.floor(buttonid/5)*8,7,7}
    ds.Window(display, panel, buttonRect, buttonWndFunc)
  end
end

while true do
  display:pullEvent()
end
