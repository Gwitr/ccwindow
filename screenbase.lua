local utils = require"utils"

local Screen = utils.Class()
Screen:abstractMethod "width"
Screen:abstractMethod "height"
Screen:abstractMethod "normalizeEvent"
Screen:abstractMethod "optimizedDims"
Screen:abstractMethod "optimizeImage"
Screen:abstractMethod "pixelBlitOptimized"
Screen:abstractMethod "pixelDrawLine"
Screen:abstractMethod "pixelFillRect"
Screen:abstractMethod "setColorMap"

return {Screen=Screen}
