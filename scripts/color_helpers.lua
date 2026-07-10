flib_math = require("__flib__.math")

local ColorHelpers = {}

---------------------------------------------------------------------------------------------------

local function scale_255_to_0_1(x)
  if x == nil then
    return nil
  end
  return flib_math.clamp(x / 255, 0, 1)
end

---------------------------------------------------------------------------------------------------

---Converts HSV to RGB coordinates
---@param h number
---@param s number
---@param v number
---@return Color
local function hsv_to_rgb(h, s, v)
  local c = v * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local m = v - c

  local r, g, b

  if h < 60 then
    r, g, b = c, x, 0
  elseif h < 120 then
    r, g, b = x, c, 0
  elseif h < 180 then
    r, g, b = 0, c, x
  elseif h < 240 then
    r, g, b = 0, x, c
  elseif h < 300 then
    r, g, b = x, 0, c
  else
    r, g, b = c, 0, x
  end

  return {
    r = (r + m),
    g = (g + m),
    b = (b + m),
  }
end

---------------------------------------------------------------------------------------------------

---Will divide HSV spectrum into $count indexable segments
---@param index number
---@param count number
---@return Color
function ColorHelpers.rainbow_color(index, count)
  if count <= 1 then
    return { r = scale_255_to_0_1(255), g = scale_255_to_0_1(80), b = scale_255_to_0_1(80) }
  end

  local hue = ((index - 1) / count) * 360
  return hsv_to_rgb(hue, 0.85, 0.95)
end

---------------------------------------------------------------------------------------------------

---returns true if rgb is using 0 - 255 scale
---@param color Color
---@return boolean
local function color_uses_255_scale(color)
  local r = color.r or 0
  local g = color.g or 0
  local b = color.b or 0
  local a = color.a or 1

  return r > 1 or g > 1 or b > 1 or a > 1
end

---------------------------------------------------------------------------------------------------

---helper function to convert color channel to 0-255 scale if needed
---@param value number
---@param uses_255_scale boolean
---@param alpha? number
---@return integer
local function color_channel_to_255_and_premultiply_alpha(value, uses_255_scale, alpha)
  if value == nil then
    return 255
  end

  if alpha == nil then
    alpha = 1
  end
  if alpha > 1 then
    alpha = scale_255_to_0_1(alpha) or 1
  end

  if uses_255_scale then
    return flib_math.round(value * alpha)
  end

  return flib_math.round(value * 255 * alpha)
end

---------------------------------------------------------------------------------------------------

---takes a number and returns a two-digit hex string, rounding to the nearest integer
---@param value integer
---@return string
local function byte_to_hex(value)
  return string.format("%02X", math.floor(value))
end

---------------------------------------------------------------------------------------------------

---helper function to convert color into 0-1 scale if needed
---@param color Color
---@return Color|nil
function ColorHelpers.color_to_0_1(color)
  if color == nil then
    return nil
  end

  if color_uses_255_scale(color) then
    return {
      r = scale_255_to_0_1(color.r) or 0,
      g = scale_255_to_0_1(color.g) or 0,
      b = scale_255_to_0_1(color.b) or 0,
      a = scale_255_to_0_1(color.a) or 1,
    }
  else
    return {
      r = flib_math.clamp(color.r or 0, 0, 255) or 0,
      g = flib_math.clamp(color.g or 0, 0, 255) or 0,
      b = flib_math.clamp(color.b or 0, 0, 255) or 0,
      a = flib_math.clamp(color.a or 1, 0, 255) or 1,
    }
  end
end

---------------------------------------------------------------------------------------------------

---converts color to #AARRGGBB string
---@param color Color
---@param options GenerationOptions
---@return string
function ColorHelpers.rich_text_color_string(color, options)
  local alpha = options and options.alpha

  if not color then
    return "#FF000000"
  end

  local uses_255_scale = color_uses_255_scale(color)

  -- Factorio rich text alpha expects premultiplied RGB.
  local a = color_channel_to_255_and_premultiply_alpha(alpha, false)
  local r = color_channel_to_255_and_premultiply_alpha(color.r or color[1], uses_255_scale, alpha)
  local g = color_channel_to_255_and_premultiply_alpha(color.g or color[2], uses_255_scale, alpha)
  local b = color_channel_to_255_and_premultiply_alpha(color.b or color[3], uses_255_scale, alpha)

  return "#" .. byte_to_hex(a) .. byte_to_hex(r) .. byte_to_hex(g) .. byte_to_hex(b)
end

---------------------------------------------------------------------------------------------------

return ColorHelpers
