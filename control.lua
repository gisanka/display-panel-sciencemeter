local TextHelpers = require("scripts.text_helpers")
local DisplayPanelApi = require("__display-panel__.public_api")

local DEFAULT_ALPHA = 0.75
local DEFAULT_WIDTH = 7

---Finds the category of a prototype name (e.g., "item", "fluid", "recipe")
---@param name PrototypeName The internal prototype name to check
---@return string|nil category The type category or nil if not found
local function determine_prototype_category(name)
  -- 1. Check if it is an item
  if prototypes.item[name] then
    return "item"
  end

  -- 2. Check if it is a fluid
  if prototypes.fluid[name] then
    return "fluid"
  end

  -- 3. Check if it is a virtual signal (A-Z, colors, numbers, wildcards)
  if prototypes.virtual_signal[name] then
    return "virtual"
  end

  -- 4. Check if it is a recipe
  if prototypes.recipe[name] then
    return "recipe"
  end

  -- 5. Check if it is a technology
  if prototypes.technology[name] then
    return "technology"
  end

  return nil -- Not found anywhere
end

---------------------------------------------------------------------------------------------------

---adds type for signals
---@param prototype_name PrototypeName
---@return table|nil
local function signal(prototype_name)
  local signal_type = determine_prototype_category(prototype_name)
  if not signal_type then
    return nil
  end
  return {
    type = signal_type,
    name = prototype_name,
  }
end

---------------------------------------------------------------------------------------------------

---filters out hidden entities and blueprint parameters
---@param prototype any
---@return boolean
local function is_real(prototype)
  return prototype and prototype.valid and not prototype.hidden and not prototype.parameter
end

---make sure current modpack has display-panel prototypes
---@return boolean
local function has_display_panel_prototype()
  return prototypes.entity["display-panel"] ~= nil
end

---------------------------------------------------------------------------------------------------

---only add prototype_name to result if not already in seen
---@param result table
---@param seen table
---@param prototype_name PrototypeName
local function add_unique(result, seen, prototype_name)
  if seen[prototype_name] then
    return
  end

  if not determine_prototype_category(prototype_name) then
    return
  end

  seen[prototype_name] = true
  table.insert(result, prototype_name)
end

---------------------------------------------------------------------------------------------------

---Collects all science packs (searches for labs and their inputs)
---@return table
local function collect_science_pack_names()
  local result = {}
  local seen = {}

  for _, entity in pairs(prototypes.entity) do
    if entity.type == "lab" and entity.lab_inputs and #entity.lab_inputs > 0 then
      for _, science_pack in ipairs(entity.lab_inputs) do
        if is_real(prototypes.item[science_pack]) then
          add_unique(result, seen, science_pack)
        end
      end
    end
  end

  return result
end

---------------------------------------------------------------------------------------------------

---gets the sort keys out of the prototype data
---@param prototype_name PrototypeName
---@return table
local function get_item_sort_key(prototype_name)
  local prototype = prototypes.item[prototype_name]

  if not prototype then
    return {
      group_order = "zzzz",
      group_name = "zzzz",
      subgroup_order = "zzzz",
      subgroup_name = "zzzz",
      item_order = "zzzz",
      prototype_name = prototype_name,
    }
  end

  return {
    group_order = prototype.group and prototype.group.order or "",
    group_name = prototype.group and prototype.group.name or "",
    subgroup_order = prototype.subgroup and prototype.subgroup.order or "",
    subgroup_name = prototype.subgroup and prototype.subgroup.name or "",
    item_order = prototype.order or "",
    prototype_name = prototype.name,
  }
end

---------------------------------------------------------------------------------------------------

---helper function to compare item sort keys
---@param a table
---@param b table
---@return boolean
local function compare_item_sort_keys(a, b)
  if a.group_order ~= b.group_order then
    return a.group_order < b.group_order
  end
  if a.group_name ~= b.group_name then
    return a.group_name < b.group_name
  end
  if a.subgroup_order ~= b.subgroup_order then
    return a.subgroup_order < b.subgroup_order
  end
  if a.subgroup_name ~= b.subgroup_name then
    return a.subgroup_name < b.subgroup_name
  end
  if a.item_order ~= b.item_order then
    return a.item_order < b.item_order
  end

  return a.prototype_name < b.prototype_name
end

---------------------------------------------------------------------------------------------------

---sorts science packs by their prototype sort order
---@param science_pack_names table
---@return table
local function sort_science_pack_names(science_pack_names)
  table.sort(science_pack_names, function(a, b)
    local key_a = get_item_sort_key(a)
    local key_b = get_item_sort_key(b)

    return compare_item_sort_keys(key_a, key_b)
  end)

  return science_pack_names
end

---------------------------------------------------------------------------------------------------

---collects science pack names and sorts them in semantic order
---@return table
local function get_sorted_science_pack_names()
  return sort_science_pack_names(collect_science_pack_names())
end

---------------------------------------------------------------------------------------------------

---Creates blueprint book and iterates over science packs to fill book
---@param player LuaPlayer
---@param generation_options GenerationOptions
local function create_sciencemeter_book(player, generation_options)
  if not player or not player.valid then
    return
  end

  --------------------------

  -- 1. STAGE: Start a fresh book building session for this player in the Core Mod
  -- This will trigger create_active_book_session_structure() and handle the 'or nil' state safely
  remote.call("display_panel_book", "start", player.index)

  -- 2. STAGE: Gather our specific science packs and queue them into the book
  local prototype_names = get_sorted_science_pack_names()

  for i, prototype_name in ipairs(prototype_names) do
    blueprints_created = i
    local options = {
      prototype = signal(prototype_name),
      bar_width = generation_options.width,
      alpha = generation_options.alpha,
      icon = signal(prototype_name),
    }
    local panel_config = DisplayPanelApi.new_meter(options--[[@as DisplayPanelOptions]])

    -- Add this specific page to the player's active session queue
    remote.call("display_panel_book", "add", player.index, panel_config)
  end

  local book_preview_icons = {
    {
      index = 1,
      signal = signal("display-panel"),
    },
  }
  for i = 1, math.min(3, #prototype_names) do
    book_preview_icons[#book_preview_icons + 1] = {
      index = i + 1,
      signal = signal(prototype_names[i]),
    }
  end

  local opacity_percent = generation_options.alpha * 100
  local options_output_string = "(bar width: " .. generation_options.width .. " | opacity: " .. opacity_percent .. "%)"

  local book_label = "Sciencemeter display panels " .. options_output_string
  local book_description = "Generated by display panel sciencemeter mod from current science pack prototypes."

  -- 3. STAGE: Finish the book session and deliver the physical item into the player's hand
  local success =
    remote.call("display_panel_book", "finish", player.index, book_label, book_description, book_preview_icons)

  if success then
    player.print("Science-Meter blueprint book generated and placed in your cursor!")
  else
    player.print("Failed to generate book. Ensure your science pack list is not empty.")
  end
end

---------------------------------------------------------------------------------------------------

---initiates process
local function handle_book_command(command)
  if not command.player_index then
    game.print("This command must be run by a player.")
    return
  end

  local player = game.players[command.player_index]
  if not player or not player.valid then
    return
  end

  if not has_display_panel_prototype() then
    player.print("Display panel prototype is not available. Cannot create sciencemeter blueprints.")
    return
  end

  local generation_options = TextHelpers.parse_numerical_parameter(command.parameter)
  local defaults_used = {}

  -- If width was not provided or was invalid, fallback to default
  if not generation_options.width then
    generation_options.width = DEFAULT_WIDTH
    table.insert(defaults_used, "width = " .. generation_options.width)
  end

  if generation_options.width > 24 then
    generation_options.width = 24
    player.print("Factorio only supports bars up to width 24")
  end

  -- If alpha was not provided or was invalid, fallback to default
  if not generation_options.alpha then
    generation_options.alpha = DEFAULT_ALPHA
    table.insert(defaults_used, "alpha = " .. generation_options.alpha)
  end

  -- Print the message to the player if any defaults were applied
  if #defaults_used > 0 then
    local default_fallbacks = table.concat(defaults_used, " | ")
    player.print("Using default values: " .. default_fallbacks)
  end

  -- Rainbow fallback flag (safe against nil command.parameter)
  generation_options.force_rainbow_fallback = command.parameter and command.parameter:find("rainbow") ~= nil

  create_sciencemeter_book(player, generation_options)
end

---------------------------------------------------------------------------------------------------

---add console command for main functionality
commands.add_command(
  "sciencemeter-book",
  "Create a blueprint book. Optionally specify bar width and opacity with 'width=10 opacity=0.75",
  handle_book_command
)
