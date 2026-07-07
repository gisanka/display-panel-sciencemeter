-- like to have a preset for your modpack, too?
-- let me know via factorio-forums/github!

local presets = {}

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
    if presets[prototype_name] == nil then
      presets[prototype_name] = color
    end
  end
end

for _, module_name in ipairs(preset_modules) do
  merge_preset_module(module_name)
end

return presets
