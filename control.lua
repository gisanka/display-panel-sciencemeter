local TextHelpers = require("scripts.text_helpers")
local ColorHelpers = require("scripts.color_helpers")
local SciencePackColorPresets = require("scripts.science_pack_color_presets")

local DEFAULT_ALPHA = 0.75
local DEFAULT_WIDTH = 20

-- automatic debug detection:
-- if file dev_marker.lua exists, dev-shortcut will be created
-- VERBOSE will automatically be if debug adapter is connected or setting is set to true
local VERBOSE = (__DebugAdapter ~= nil) or (prototypes.custom_input["display-panel-sciencemeter-dev-marker"] ~= nil)

local function debug_print(player, message)
  if VERBOSE and player then
    player.print(message)
  end
end

---create localization structure
---@return table
local function create_localization_structure()
  return {
    pending = false,
    remaining = 0,
    total = 0,
    localization_requests = {},
    translated_names = {},
    generation_options = nil,
  }
end

---to be used for resetting localization
local function reset_localization()
  storage.sciencemeter_localization = {}
end

---localization access wrapper
---@param player_index any
---@param create_if_missing any
---@return table|unknown
local function access_localization(player_index, create_if_missing)
  if not storage.sciencemeter_localization then
    if create_if_missing then
      storage.sciencemeter_localization = {}
    else
      return nil
    end
  end

  if not storage.sciencemeter_localization[player_index] and create_if_missing then
    storage.sciencemeter_localization[player_index] = create_localization_structure()
  end

  return storage.sciencemeter_localization[player_index]
end

---failsafe command to reset localization state for a player
local function reset_localization_requests(command)
  if not command.player_index then
    return
  end

  local localization = access_localization(command.player_index)
  if not localization then
    return
  end

  localization.pending = false
  localization.remaining = 0
  localization.total = 0
  localization.localization_requests = {}

  local player = game.get_player(command.player_index)
  if player then
    player.print("Display panel sciencemeter localization state reset.")
  end
end

---adds type item for signals
---@param item_name string
---@return table
local function item(item_name)
  return {
    type = "item",
    name = item_name,
  }
end

---filters out hidden entities and blueprint parameters
---@param prototype any
---@return boolean
local function is_real(prototype)
  return prototype and prototype.valid and not prototype.hidden and not prototype.parameter
end

---make sure current modpack has display-panel prototypes
---@return boolean
local function has_display_panel_prototypes()
  return prototypes.entity["display-panel"] and prototypes.item["display-panel"]
end

---only add item_name to result if not already in seen
---@param result table
---@param seen table
---@param item_name string
local function add_unique(result, seen, item_name)
  if seen[item_name] then
    return
  end

  if not prototypes.item[item_name] then
    return
  end

  seen[item_name] = true
  table.insert(result, item_name)
end

---Collects all science packs (searches for labs and their inputs)
---@return table
local function collect_science_pack_names()
  local result = {}
  local seen = {}

  for _, entity in pairs(prototypes.entity) do
    if entity.type == "lab" and entity.lab_inputs and #entity.lab_inputs > 0 then
      for _, item_name in ipairs(entity.lab_inputs) do
        if is_real(prototypes.item[item_name]) then
          add_unique(result, seen, item_name)
        end
      end
    end
  end

  return result
end

---gets the sort keys out of the prototype data
---@param item_name any
---@return table
local function get_item_sort_key(item_name)
  local prototype = prototypes.item[item_name]

  if not prototype then
    return {
      group_order = "zzzz",
      group_name = "zzzz",
      subgroup_order = "zzzz",
      subgroup_name = "zzzz",
      item_order = "zzzz",
      item_name = item_name,
    }
  end

  return {
    group_order = prototype.group and prototype.group.order or "",
    group_name = prototype.group and prototype.group.name or "",
    subgroup_order = prototype.subgroup and prototype.subgroup.order or "",
    subgroup_name = prototype.subgroup and prototype.subgroup.name or "",
    item_order = prototype.order or "",
    item_name = prototype.name,
  }
end

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

  return a.item_name < b.item_name
end

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

---collects science pack names and sorts them in semantic order
---@return table
local function get_sorted_science_pack_names()
  return sort_science_pack_names(collect_science_pack_names())
end

---fills in the actual displayed bar with the percentage
---output has fixed width so that on zooming out it will stay aligned
---@param item_name string
---@param percent number
---@param options table
---@return string
local function display_panel_text(item_name, color, percent, options)
  local hexcolor = ColorHelpers.print_item_rich_text_color(color, options)
  local bar = TextHelpers.make_fill_bar(percent)
  local percent_text = TextHelpers.fixed_width_percent(percent)

  return "[font=default]"
    .. "[color="
    .. hexcolor
    .. "]"
    .. "[item="
    .. item_name
    .. "] "
    .. bar
    .. " [/color] "
    .. percent_text
    .. "[/font]"
end

---add decision logic for the display panel which line to show
---@param item_name string
---@param options table
---@return table
local function display_panel_parameters(item_name, color, options)
  local parameters = {}

  for percent = 0, 100 do
    local comparator = "≤"
    -- skipping 49 as it is negligible (and we only have 100 entries available)
    if percent ~= 49 then
      if percent == 100 then
        comparator = "≥"
      end

      table.insert(parameters, {
        icon = item(item_name),
        text = display_panel_text(item_name, color, percent, options),
        condition = {
          first_signal = item(item_name),
          comparator = comparator,
          constant = percent,
        },
      })
    end
  end

  return parameters
end

---adds general data for the display panel entity
---@param item_name string
---@param color table
---@param options table
---@return table
local function display_panel_entity(item_name, color, options)
  return {
    {
      entity_number = 1,
      name = "display-panel",
      position = {
        x = 0,
        y = 0,
      },
      direction = 8,
      control_behavior = {
        parameters = display_panel_parameters(item_name, color, options),
      },
      always_show = true,
    },
  }
end

---adds blueprint for item_name to blueprint_stack, with label and description using translated_name
---@param blueprint_stack any
---@param item_name string
---@param translated_name string
---@param color table
---@param options table
local function setup_sciencemeter_blueprint(blueprint_stack, item_name, translated_name, color, options)
  -- first set blueprint entity
  blueprint_stack.set_blueprint_entities(display_panel_entity(item_name, color, options))

  -- After entity is set, label and description can be filled
  blueprint_stack.label = translated_name
  blueprint_stack.blueprint_description = "Sciencemeter for " .. translated_name

  blueprint_stack.preview_icons = {
    {
      index = 1,
      signal = item(item_name),
    },
  }
end

---Creates blueprint book and iterates over science packs to fill book
---@param player any
---@param translated_names any
---@param options table
local function create_sciencemeter_book(player, translated_names, options)
  if not player or not player.valid then
    return
  end

  if not player.clear_cursor() then
    player.print("Could not clear cursor. Please call the command again with an empty cursor.")
    return
  end

  local book = player.cursor_stack
  if not book or not book.valid then
    player.print("Could not access cursor stack. Please call the command again with an empty cursor.")
    return
  end

  if not book.set_stack({ name = "blueprint-book", count = 1 }) then
    player.print("Could not create blueprint book. Please call the command again with an empty cursor.")
    return
  end

  local opacity_percent = options.alpha * 100

  book.label = "Sciencemeter display panels (" .. opacity_percent .. "% opacity)"
  book.blueprint_description = "Generated by display panel sciencemeter mod from current science pack prototypes."

  -- Build preview icons locally and assign once.
  -- Mutating book.preview_icons directly does not work for blueprint books
  local preview_icons = {
    {
      index = 1,
      signal = item("display-panel"),
    },
  }

  local item_names = get_sorted_science_pack_names()
  for i = 1, math.min(3, #item_names) do
    preview_icons[#preview_icons + 1] = {
      index = i + 1,
      signal = item(item_names[i]),
    }
  end

  -- only set once and without abstraction!
  book.preview_icons = preview_icons

  local book_inventory = book.get_inventory(defines.inventory.item_main)
  if not book_inventory or not book_inventory.valid then
    player.print("Could not access blueprint book inventory.")
    return
  end

  local created = 0
  local no_template_available = false
  local templates_found = 0

  for _, item_name in ipairs(item_names) do
    local inserted = book_inventory.insert({ name = "blueprint", count = 1 })
    if inserted == 0 then
      player.print("Could not insert blueprint for " .. item_name)
    else
      -- Blueprints are not stackable, so the current item count points to the newly inserted blueprint
      local blueprint_stack = book_inventory[book_inventory.get_item_count()]
      local translated_name = translated_names[item_name] or item_name
      local color = nil
      if SciencePackColorPresets[item_name] and not options.use_rainbow_fallback then
        color = SciencePackColorPresets[item_name]
        templates_found = templates_found + 1
      else
        no_template_available = true
        color = ColorHelpers.rainbow_color(created + 1, #item_names)
      end

      setup_sciencemeter_blueprint(blueprint_stack, item_name, translated_name, color, options)
      created = created + 1
    end
  end

  player.print(
    "Created science meter display book with " .. created .. " blueprints and " .. opacity_percent .. "% opacity."
  )
  if no_template_available then
    player.print(
      "Rainbow fallback was used for colors because no (complete) template was available or user requested it."
    )
    if templates_found > 0 then
      player.print("Templates were found for " .. templates_found .. " science packs.")
      book.label = book.label .. " - partial rainbow fallback"
    else
      book.label = book.label .. " - rainbow fallback"
    end
  end
end

---request missing translations for science packs or create blueprint book when all translations are already received
---@param player any
---@param alpha number
---@param use_rainbow_fallback boolean
local function handle_sciencemeter_translations(player, alpha, use_rainbow_fallback)
  local item_names = get_sorted_science_pack_names()

  local localization = access_localization(player.index, true)

  if localization.pending then
    player.print("Translation requests are still pending. The blueprint book will be created in your hand shortly.")
    return
  end

  localization.total = 0
  localization.localization_requests = {}
  localization.remaining = 0
  localization.generation_options = {
    alpha = alpha,
    use_rainbow_fallback = use_rainbow_fallback,
  }

  for _, item_name in ipairs(item_names) do
    localization.total = localization.total + 1
    if localization.translated_names[item_name] == nil then
      -- request translation for this item
      local prototype = prototypes.item[item_name]
      local request_id = player.request_translation(prototype.localised_name)

      if request_id then
        localization.pending = true
        localization.remaining = localization.remaining + 1
        localization.localization_requests[request_id] = item_name
      else
        localization.translated_names[item_name] = item_name
      end
    end
  end

  if localization.remaining == 0 then
    localization.pending = false
    -- all translations were already available, create the blueprint book
    create_sciencemeter_book(player, localization.translated_names, localization.generation_options)
    return
  end
end
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
---initiates process - sort-of-main()-function
local function handle_book_command(command)
  if not command.player_index then
    game.print("This command must be run by a player.")
    return
  end

  local player = game.get_player(command.player_index)
  if not player or not player.valid then
    return
  end

  if not has_display_panel_prototypes() then
    player.print("Display panel prototype is not available. Cannot create sciencemeter blueprints.")
    return
  end

  local alpha = TextHelpers.parse_alpha_parameter(command.parameter, DEFAULT_ALPHA)

  if alpha == -1 then
    player.print(
      "Invalid alpha value. Use for example /sciencemeter-book or /sciencemeter-book 75 or /sciencemeter-book 0.75."
    )
    return
  end

  local use_rainbow_fallback = command.parameter and string.find(command.parameter, "rainbow") ~= nil

  handle_sciencemeter_translations(player, alpha, use_rainbow_fallback)
end

-- stylua: ignore
-- add console command for main functionality
commands.add_command(
  "sciencemeter-book",
  "Create a blueprint book. Optionally specify alpha value for the bar color, e.g. 75 or 0.75.",
  handle_book_command)

-- stylua: ignore
-- add failsafe console command to reset localization handling
commands.add_command(
  "sciencemeter-reset",
  "Reset pending localization requests.",
  reset_localization_requests)

---store localized names in volatile memory
---@param event EventData.on_string_translated
script.on_event(defines.events.on_string_translated, function(event)
  local localization = access_localization(event.player_index)

  if not localization then
    return
  end

  -- remember the translated name for the science packs
  local item_name = localization.localization_requests[event.id]
  if not item_name then
    return
  end

  -- store localized name or fallback to untranslated name if translation failed
  if event.translated then
    localization.translated_names[item_name] = event.result
  else
    localization.translated_names[item_name] = item_name
  end

  -- remove the request from the pending list and decrement remaining count
  localization.localization_requests[event.id] = nil
  localization.remaining = localization.remaining - 1

  if localization.remaining > 0 then
    return
  end

  -- all translations have been received, create the blueprint book
  localization.pending = false
  localization.localization_requests = {}
  localization.remaining = 0

  local player = game.get_player(event.player_index)
  create_sciencemeter_book(player, localization.translated_names, localization.generation_options)
end)

---Throw away translated name when locale changed
---@param event EventData.on_player_locale_changed
script.on_event(defines.events.on_player_locale_changed, function(event)
  reset_localization()
end)

---Throw away translated names when a mod was updated or removed
script.on_configuration_changed(function(event)
  reset_localization()
end)
