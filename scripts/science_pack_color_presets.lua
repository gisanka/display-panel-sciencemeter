ColorHelpers = require("scripts.color_helpers")

-- like to have a preset for your modpack, too?
-- let me know via factorio-forums/github!

local presets = {}
local merged_presets = {}

local preset_modules = {
  "scripts.templates.vanilla",
  "scripts.templates.krastorio2",
  "scripts.templates.space_exploration",
  "scripts.templates.pyanodons",
  "scripts.templates.nullius",
  "scripts.templates.ultracube",
}

local function merge_preset_module(module_name)
  local ok, module_presets = pcall(require, module_name)

  if not ok or type(module_presets) ~= "table" then
    return
  end

  for prototype_name, color in pairs(module_presets) do
    if merged_presets[prototype_name] == nil then
      merged_presets[prototype_name] = color
    end
  end
end

for _, module_name in ipairs(preset_modules) do
  merge_preset_module(module_name)
end

---returns a preset if found, otherwise nil
---@param prototype_name any
---@return Color.0|[number, number, number, number]|nil
function presets.get(prototype_name)
  local color = merged_presets[prototype_name]
  if color then
    return ColorHelpers.color_to_0_1(color)
  else
    return nil
  end
end

return presets
