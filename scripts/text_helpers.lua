local TextHelpers = {}

---parse different variants of alpha like 80%, 80 or 0.8
---@param parameter any
---@param DEFAULT_ALPHA number
---@return number
function TextHelpers.parse_alpha_parameter(parameter, DEFAULT_ALPHA)
  if not parameter or parameter == "" then
    return DEFAULT_ALPHA
  end

  local text = parameter:match("%d+%.?%d*%%?")
  if not text then
    return DEFAULT_ALPHA
  end
  text = text:gsub("%%$", "")

  local value = tonumber(text)
  if not value then
    return -1
  end

  -- "80" means 80%, "0.8" means 0.8
  if value > 1 then
    value = value / 100
  end

  if value < 0 then
    value = 0
  elseif value > 1 then
    value = 1
  end

  return value
end

---Generates a 20-character fill bar for percent values 0..100
---@param percent number @expected 0 <= percent <= 100
---@return string
function TextHelpers.make_fill_bar(percent)
  --[[

Examples:
    0   -> ░░░░░░░░░░░░░░░░░░░░
    1   -> ▎░░░░░░░░░░░░░░░░░░░
    5   -> █░░░░░░░░░░░░░░░░░░░
    50  -> ██████████░░░░░░░░░░
    100 -> ████████████████████

used blocks:
    ░ = empty block U+2591 LIGHT SHADE
    ▎ = 1/5 block  U+258E LEFT ONE QUARTER BLOCK
    ▎ = 2/5 block  U+258C LEFT THREE EIGHTHS BLOCK
    ▌ = 3/5 block   U+258B LEFT FIVE EIGHTHS BLOCK
    ▊ = 4/5 block  U+258A LEFT THREE QUARTERS BLOCK
    █ = full block  U+2588 FULL BLOCK

]]

  percent = math.floor(percent or 0)

  if percent < 0 then
    percent = 0
  elseif percent > 100 then
    percent = 100
  end

  local width = 20
  local full_blocks = math.floor(percent / 5)
  local remainder = percent % 5

  local partial_blocks = {
    [0] = "",
    [1] = "▎",
    [2] = "▌",
    [3] = "▋",
    [4] = "▊",
  }

  if percent == 100 then
    return string.rep("█", width)
  end

  local bar = string.rep("█", full_blocks)
  bar = bar .. partial_blocks[remainder]

  local used_width = full_blocks
  if remainder > 0 then
    used_width = used_width + 1
  end

  bar = bar .. string.rep("░", width - used_width)

  return bar
end

---Generates a formatted percentage string with a fixed width for percent values 0..100
---@param percent number @expected 0 <= percent <= 100
---@return string
function TextHelpers.fixed_width_percent(percent)
  percent = math.floor(percent or 0)

  if percent < 0 then
    percent = 0
  elseif percent > 100 then
    percent = 100
  end

  local figure_space = " "
  local text = tostring(percent) .. "%"

  if percent < 10 then
    -- add two figure spaces for single-digit percentages
    text = figure_space .. figure_space .. text
  elseif percent < 100 then
    -- add one figure space for double-digit percentages
    text = figure_space .. text
  end

  return text
end

return TextHelpers
