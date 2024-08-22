local utils = require"utils"

local Screen = utils.Class()
Screen:abstractMethod "width"
Screen:abstractMethod "height"
Screen:abstractMethod "normalizeEvent"
Screen:abstractMethod "optimizedDims"
Screen:abstractMethod "optimizeImage"
Screen:abstractMethod "blitOptimized"
Screen:abstractMethod "drawLine"
Screen:abstractMethod "fillRect"
Screen:abstractMethod "plotPixel"
Screen:abstractMethod "setColorMap"

return {Screen=Screen}
