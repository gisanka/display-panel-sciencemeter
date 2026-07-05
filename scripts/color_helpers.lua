local ColorHelpers = {}

---Converts HSV to RGB coordinates
---@param h number
---@param s number
---@param v number
---@return table
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
    r = math.floor((r + m) * 255 + 0.5),
    g = math.floor((g + m) * 255 + 0.5),
    b = math.floor((b + m) * 255 + 0.5),
  }
end

---Will divide HSV spectrum into $count indexable segments
---@param index number
---@param count number
---@return table
function ColorHelpers.rainbow_color(index, count)
  if count <= 1 then
    return { r = 255, g = 80, b = 80 }
  end

  local hue = ((index - 1) / count) * 360
  return hsv_to_rgb(hue, 0.85, 0.95)
end

---returns true if rgb is using 0 - 255 scale
---@param color any
---@return boolean
local function color_uses_255_scale(color)
  local r = color.r or color[1] or 0
  local g = color.g or color[2] or 0
  local b = color.b or color[3] or 0

  return r > 1 or g > 1 or b > 1
end

---helper function to convert color channel to 0-255 scale if needed
---@param value any
---@param uses_255_scale boolean
---@param alpha? number
---@return integer
local function color_channel_to_255(value, uses_255_scale, alpha)
  if value == nil then
    return 255
  end

  if alpha == nil then
    alpha = 1
  end

  if uses_255_scale then
    return math.floor(value * alpha + 0.5)
  end

  return math.floor(value * 255 * alpha + 0.5)
end

---takes a number and returns a two-digit hex string, rounding to the nearest integer
---@param value number
---@return string
local function byte_to_hex(value)
  return string.format("%02X", math.floor(value))
end

---converts color to a,r,g,b string
---@param color table
---@param options table
---@return string
function ColorHelpers.print_item_rich_text_color(color, options)
  local alpha = options and options.alpha

  if not color then
    return "#FFFFFFFF"
  end

  local uses_255_scale = color_uses_255_scale(color)

  -- Factorio rich text alpha expects premultiplied RGB.
  local a = color_channel_to_255(alpha, false)
  local r = color_channel_to_255(color.r or color[1], uses_255_scale, alpha)
  local g = color_channel_to_255(color.g or color[2], uses_255_scale, alpha)
  local b = color_channel_to_255(color.b or color[3], uses_255_scale, alpha)

  return "#" .. byte_to_hex(a) .. byte_to_hex(r) .. byte_to_hex(g) .. byte_to_hex(b)
end

return ColorHelpers