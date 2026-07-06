-- test_text_helpers.lua
--
-- Command line test harness for TextHelpers.
-- This file is not loaded by Factorio.
--
-- Usage:
--   lua test_text_helpers.lua args
--   lua test_text_helpers.lua bar
--   lua test_text_helpers.lua bar 20
--   lua test_text_helpers.lua bar 12 0 1 2 3 4 5 95 25 50 75 96 97 98 99 100

---@diagnostic disable-next-line: undefined-field
if package.config:sub(1, 1) == "\\" then
  -- Windows: switch console code page to UTF-8.
  -- Lua itself has no stdout encoding setting.
  ---@diagnostic disable-next-line: undefined-global
  os.execute("chcp 65001 > nul")
end

-- stylua: ignore
local parameter_test_cases = {
  { input = "",            w = nil,  a = nil },
  -- Positional Single Tests
  { input = "40",          w = 40,  a = nil },
  { input = "1",           w = 1,   a = nil },
  { input = ".5",          w = nil, a = 0.5 },
  { input = "50%",         w = nil, a = 0.5 },
  { input = "110%",        w = nil, a = 1   },

  -- Positional Combination Tests
  { input = "40 0.5",      w = 40,  a = 0.5 },
  { input = "40 50",       w = 40,  a = 0.5 },
  { input = "40 50%",      w = 40,  a = 0.5 },
  { input = "40 test 50%", w = 40,  a = 0.5 },

  -- Keyword Single Tests
  { input = "width=44",    w = 44,  a = nil },
  { input = "width=-44",   w = nil, a = nil },
  { input = "opacity=50",  w = nil, a = 0.5 },
  { input = "opacity=-50", w = nil, a = nil },
  { input = "opacity=50%", w = nil, a = 0.5 },
  { input = "opacity=0.5", w = nil, a = 0.5 },

  -- Order-Independent Combinations
  { input = "opacity=30 50", w = 50,  a = 0.3 },
  { input = "30 width=50",   w = 50,  a = 0.3 },
  { input = "width=40 .5",   w = 40,  a = 0.5 },
  { input = ".5 width=40",   w = 40,  a = 0.5 },

  -- Failsafe / Blocked Tests
  { input = "width=abc",   w = nil, a = nil },
  { input = "something",   w = nil, a = nil },
  { input = "1.50",        w = nil, a = nil },
  { input = "text110%",    w = nil, a = nil },
  { input = "40test 0.5",  w = nil, a = 0.5 },
  { input = "test40 0.5",  w = nil, a = 0.5 },
  { input = "40 test0.5",  w = 40,  a = nil },
  { input = "40 0.5test",  w = 40,  a = nil },
  { input = "40 test50",   w = 40,  a = nil },
  { input = "40 50test",   w = 40,  a = nil },
  { input = "-20 -10",     w = nil, a = nil },
  { input = "-20 -10%",    w = nil, a = nil },
}

local options = {
  width = tonumber(arg[2]) or 20,
}

local function load_text_helpers()
  -- Variant A: text_helpers.lua returns a module table.
  local ok, module = pcall(require, "scripts.text_helpers")
  if ok and type(module) == "table" then
    return module
  end

  -- Variant B: text_helpers.lua writes into global TextHelpers.
  _G.TextHelpers = _G.TextHelpers or {}

  local loaded_ok, load_error = pcall(dofile, "scripts/text_helpers.lua")
  if not loaded_ok then
    error("Could not load scripts/text_helpers.lua:\n" .. tostring(load_error))
  end

  if type(_G.TextHelpers) ~= "table" then
    error("scripts/text_helpers.lua did not return a module and did not define global TextHelpers")
  end

  return _G.TextHelpers
end

local TextHelpers = load_text_helpers()

if type(TextHelpers.make_fill_bar) ~= "function" then
  error("TextHelpers.make_fill_bar is not defined")
end

local function collect_percent_values()
  if #arg >= 3 then
    local values = {}

    for i = 3, #arg do
      local value = tonumber(arg[i])
      if value == nil then
        error("Invalid percent value: " .. tostring(arg[i]))
      end

      values[#values + 1] = value
    end

    return values
  end

  return {}
end

local function print_bar(percent)
  local bar = TextHelpers.make_fill_bar(percent, options)
  local percentstring = TextHelpers.fixed_width_percent(percent)
  print(string.format("%s |%s|", percentstring, bar))
end

if #arg >= 1 and arg[1] == "bar" then
  print(string.format("Testing TextHelpers.make_fill_bar(width=%d)", options.width))
  print("")

  local show_only = collect_percent_values()
  if #show_only > 0 then
    print("Only userdefined values:")
    print("")
    for _, percent in ipairs(show_only) do
      print_bar(percent)
    end
  else
    print("Full 0..100 table:")
    print("")
    for percent = 0, 100 do
      print_bar(percent)
    end
  end
elseif #arg >= 1 and arg[1] == "args" then
  -- 1. Dynamic Padding Calculation
  local max_len = 0
  for _, case in ipairs(parameter_test_cases) do
    if #case.input > max_len then
      max_len = #case.input
    end
  end

  -- 2. Test Execution Loop
  print(string.format("%-" .. max_len .. "s | %-13s | %-13s | RESULT", "TEST INPUT", "WIDTH (W)", "ALPHA (A)"))
  print(string.rep("-", max_len + 45))

  local total_passed = 0

  for _, case in ipairs(parameter_test_cases) do
    local result = TextHelpers.parse_numerical_parameter(case.input)

    -- Validate if width and alpha match exactly what we expected
    local width_pass = (result.width == case.w)
    local alpha_pass = (result.alpha == case.a)

    local status = "FAIL ❌"
    if width_pass and alpha_pass then
      status = "PASS ✅"
      total_passed = total_passed + 1
    end

    -- Block output generation
    local w_str = string.format("%-3s (exp:%-3s)", tostring(result.width), tostring(case.w))
    local a_str = string.format("%-3s (exp:%-3s)", tostring(result.result or result.alpha), tostring(case.a))

    print(string.format("%-" .. max_len .. "s | %-12s | %-12s | %s", case.input, w_str, a_str, status))
  end

  print(string.rep("-", max_len + 45))
  print(string.format("Result: %d/%d Tests Passed.", total_passed, #parameter_test_cases))
end
