local is_dev, _ = pcall(require, "dev_marker")

if is_dev then
  -- use this as bridge to control.lua to indicate development environment
  data:extend({
    {
      type = "custom-input",
      name = "display-panel-sciencemeter-dev-marker",
      key_sequence = "",
    },
  })
end
