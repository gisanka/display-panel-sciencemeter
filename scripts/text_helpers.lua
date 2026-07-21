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
    ---@cast alpha number
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

return TextHelpers
