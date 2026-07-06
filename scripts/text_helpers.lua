local TextHelpers = {}

---Sanitizes the alpha parameter.
---@param alpha_param string
---@return number|nil
local function sanitize_alpha_parameter(alpha_param)
  -- remove the optional %
  alpha_param = alpha_param:gsub("%%$", "")
  alpha = tonumber(alpha_param)

  -- failsafe if conversion fails
  if not alpha then
    return nil
  end

  if alpha > 100 then -- If alpha is greater than 100%
    alpha = 100
  elseif alpha < 0 then -- Pure failsafe; our pattern matcher prevents negative numbers anyway
    alpha = 0
  end

  -- "80" represents 80% => 0.8, "0.8" remains 0.8
  if alpha > 1 then
    alpha = alpha / 100
  end

  return alpha
end

---parse numerical parameters alpha and width
---@param parameter any
---@return table
function TextHelpers.parse_numerical_parameter(parameter)
  if not parameter or parameter == "" then
    return { alpha = nil, width = nil }
  end

  -- Pure patterns without anchors
  local raw_width = "%d+"
  local raw_alpha_a = "0?%.%d+"
  local raw_alpha_b = "%d+%%?"

  local pattern_width_name = "width"
  local pattern_alpha_name = "opacity"

  -- Step 1: Collect all space-separated tokens
  local tokens = {}
  for token in parameter:gmatch("%S+") do
    table.insert(tokens, token)
  end

  -- Step 2: Extract values by searching for Keywords FIRST
  local alpha_str, width_str = nil, nil
  local unassigned_tokens = {}

  for _, token in ipairs(tokens) do
    if token:match("^" .. pattern_width_name .. "=" .. raw_width .. "$") then
      width_str = token:match(raw_width)
    elseif token:match("^" .. pattern_alpha_name .. "=" .. raw_alpha_a .. "$") then
      alpha_str = token:match(raw_alpha_a)
    elseif token:match("^" .. pattern_alpha_name .. "=" .. raw_alpha_b .. "$") then
      alpha_str = token:match(raw_alpha_b)
    else
      -- If it's not a keyword, we save it for positional matching
      table.insert(unassigned_tokens, token)
    end
  end

  -- Step 3: Handle positional pure numbers if keywords weren't used
  -- This preserves your original exact 4-case logic if the user just types numbers
  local positional_index = 1

  -- If width keyword wasn't used, look at the positional tokens
  if not width_str then
    for i = positional_index, #unassigned_tokens do
      local token = unassigned_tokens[i]
      if token:match("^" .. raw_width .. "$") then
        width_str = token
        positional_index = i + 1
        break
      end
    end
  end

  -- If alpha keyword wasn't used, look at the remaining positional tokens
  if not alpha_str then
    for i = positional_index, #unassigned_tokens do
      local token = unassigned_tokens[i]
      if token:match("^" .. raw_alpha_a .. "$") or token:match("^" .. raw_alpha_b .. "$") then
        alpha_str = token
        break
      end
    end
  end

  -- Step 4: Final validation and sanitization
  -- If width_str exists, convert to number, otherwise it stays nil
  local width = width_str and tonumber(width_str) or nil
  
  -- If alpha_str exists, sanitize it, otherwise it stays nil
  local alpha = alpha_str and sanitize_alpha_parameter(alpha_str) or nil

  return { alpha = alpha, width = width }
end


---@type table<integer, string>
local PARTIAL_BLOCKS = {
  [1] = "▏", -- 1/8
  [2] = "▎", -- 2/8
  [3] = "▍", -- 3/8
  [4] = "▌", -- 4/8
  [5] = "▋", -- 5/8
  [6] = "▊", -- 6/8
  [7] = "▉", -- 7/8
}

---Clamps a percentage value to the inclusive range 0..100.
---@param percent number
---@return integer
local function clamp_percent(percent)
  percent = math.floor(percent or 0)

  if percent < 0 then
    return 0
  end

  if percent > 100 then
    return 100
  end

  return percent
end

---Clamps the visible bar width to at least 1 character.
---@param width integer
---@return integer
local function clamp_width(width)
  if width < 1 then
    return 1
  end

  return math.floor(width)
end

---Returns how many percent values are represented by one compressed visual step.
---
---Every visual step gets at least one percent value.
---If percent values need to be merged because the bar is too short, the extra
---values are assigned from the top down. This keeps lower percentages more
---precise than higher percentages.
---
---Example:
---  99 percent values, 71 visual steps:
---    43 lower steps have size 1
---    28 upper steps have size 2
---
---With stronger compression:
---  all steps get size 2 first,
---  then upper steps start getting size 3, and so on.
---@param step_index integer
---@param interior_steps integer
---@param extra_percent_values integer
---@return integer
local function get_compressed_group_size(step_index, interior_steps, extra_percent_values)
  local base_extra = math.floor(extra_percent_values / interior_steps)
  local remainder_extra = extra_percent_values % interior_steps

  local group_size = 1 + base_extra

  if step_index > interior_steps - remainder_extra then
    group_size = group_size + 1
  end

  return group_size
end

---Maps a percentage value to a visual fill step.
---
---The visual fill step is measured in eighth-block units:
---  0 means empty
---  width * 8 means full
---
---If the selected width has enough visual states, the percent value is mapped
---directly. If the width is too small, 0% and 100% stay separate and 1..99%
---are compressed into the remaining steps.
---
---Compression prefers precision at the lower end of the bar. Higher values are
---merged first because the difference between 1% and 2% is usually more
---important than the difference between 96% and 97%.
---@param percent number
---@param width integer
---@return integer
local function percent_to_visual_step(percent, width)
  percent = clamp_percent(percent)
  width = clamp_width(width)

  local max_steps = width * 8

  if percent <= 0 then
    return 0
  end

  if percent >= 100 then
    return max_steps
  end

  -- Enough visual states: no compression needed.
  -- Use the full available width and eighth-block resolution.
  if max_steps >= 100 then
    return math.floor(percent * max_steps / 100 + 0.5)
  end

  -- Not enough visual states.
  -- Reserve:
  --   step 0         for 0%
  --   step max_steps for 100%
  --
  -- Compress only 1..99% into the remaining visual steps.
  local interior_steps = max_steps - 1
  local percent_values = 99

  if interior_steps <= 0 then
    return 0
  end

  local extra_percent_values = percent_values - interior_steps
  local consumed_percent_values = 0

  for step_index = 1, interior_steps do
    local group_size = get_compressed_group_size(step_index, interior_steps, extra_percent_values)

    consumed_percent_values = consumed_percent_values + group_size

    if percent <= consumed_percent_values then
      return step_index
    end
  end

  return interior_steps
end

---Converts a visual fill step to a Unicode block bar.
---
---The step is measured in eighth-block units:
---  0          -> fully empty
---  width * 8  -> fully full
---
---Intermediate values are rendered with Unicode left block elements.
---@param step integer
---@param width number
---@return string
local function visual_step_to_bar(step, width)
  width = clamp_width(width)

  local max_steps = width * 8

  if step <= 0 then
    return string.rep("░", width)
  end

  if step >= max_steps then
    return string.rep("█", width)
  end

  local full_blocks = math.floor(step / 8)
  local partial_step = step % 8

  local bar = string.rep("█", full_blocks)
  local used_width = full_blocks

  if partial_step > 0 and used_width < width then
    bar = bar .. PARTIAL_BLOCKS[partial_step]
    used_width = used_width + 1
  end

  if used_width < width then
    bar = bar .. string.rep("░", width - used_width)
  end

  return bar
end

---Generates a Unicode progress bar for a percentage value.
---
---The bar uses full blocks, empty blocks, and Unicode eighth-block partial
---characters. The default width is 20 characters.
---
---For short bars with fewer than 100 visual states, lower percentages keep a
---higher resolution than higher percentages. 0% and 100% are always rendered as
---separate states.
---@param percent integer @expected 0 <= percent <= 100
---@param options GenerationOptions
---@return string
function TextHelpers.make_fill_bar(percent, options)
  width = clamp_width(options.width)
  percent = clamp_percent(percent)

  local visual_step = percent_to_visual_step(percent, width)

  return visual_step_to_bar(visual_step, width)
end

---Generates a formatted percentage string with a fixed width for percent values 0..100
---@param percent integer @expected 0 <= percent <= 100
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
