-- MoreRVers - hooks/menu.lua
-- Responsibilities:
--  - Display console-based toggle menu (F7 key)
--  - Handle number key inputs to toggle features and adjust multipliers
--  - Provide runtime configuration without restarting game

local M = {}

local showingMenu = false
local menuKeybind = nil

-- Display the menu in console
local function display_menu(mod)
  local serverMode = mod.Config.ControlMode or mod.Config.ServerMode or "Global"
  local speedStatus = mod.Config.SpeedBoostEnabled and "ENABLED" or "DISABLED"
  local speedMult = mod.Config.SpeedMultiplier or 2.0

  local vehicleStatus = mod.Config.VehicleSpeedEnabled and "ENABLED" or "DISABLED"
  local vehicleMult = mod.Config.VehicleSpeedMultiplier or 2.0

  local healStatus = mod.Config.InstantHealEnabled and "ENABLED" or "DISABLED"
  local healThreshold = (mod.Config.InstantHealThreshold or 0.10) * 100

  local throwStatus = mod.Config.ThrowDistanceMultiplier and (mod.Config.ThrowDistanceMultiplier > 1.0) and "ENABLED" or "DISABLED"
  local throwMult = mod.Config.ThrowDistanceMultiplier or 2.0

  print("")
  print("========================================")
  print("  MoreRVers Control Menu (v" .. mod.Version .. ")")
  print("========================================")
  print("")
  print("Server Mode: " .. serverMode)
  if serverMode == "Global" then
    print("  (Host controls ALL players)")
  else
    print("  (Each player controls themselves)")
  end
  print("  [F10] Toggle Control Mode")
  print("")
  print("Feature Status:")
  print(string.format("  [1] Speed Boost:      %s (%.1fx)", speedStatus, speedMult))
  print(string.format("  [2] Vehicle Speed:    %s (%.1fx)", vehicleStatus, vehicleMult))
  print(string.format("  [3] Instant Heal:     %s (threshold: %.0f%%)", healStatus, healThreshold))
  print(string.format("  [4] Throw Distance:   %s (%.1fx)", throwStatus, throwMult))
  print("")
  print("Multiplier Controls:")
  print("  [5] Increase Speed Multiplier (+0.5)")
  print("  [6] Decrease Speed Multiplier (-0.5)")
  print("  [7] Increase Vehicle Multiplier (+0.5)")
  print("  [8] Decrease Vehicle Multiplier (-0.5)")
  print("")
  print("  [9] Save Settings to Config")
  print("  [0] Close Menu")
  print("========================================")
  print("")
end

-- Handle menu key input
local function handle_menu_key(mod, key)
  if not showingMenu then
    return
  end
  
  -- Feature toggles
  if key == Key.NUM_ONE or key == Key.ONE then
    -- Toggle Speed Boost
    mod.Config.SpeedBoostEnabled = not mod.Config.SpeedBoostEnabled
    if mod.update_speed_boost then
      mod.update_speed_boost(mod.Config.SpeedBoostEnabled)
    end
    mod.Log("Speed Boost: " .. (mod.Config.SpeedBoostEnabled and "ENABLED" or "DISABLED"))
    display_menu(mod)
    
  elseif key == Key.NUM_TWO or key == Key.TWO then
    -- Toggle Vehicle Speed
    mod.Config.VehicleSpeedEnabled = not mod.Config.VehicleSpeedEnabled
    if mod.update_vehicle_speed then
      mod.update_vehicle_speed(mod.Config.VehicleSpeedEnabled)
    end
    mod.Log("Vehicle Speed: " .. (mod.Config.VehicleSpeedEnabled and "ENABLED" or "DISABLED"))
    display_menu(mod)
    
  elseif key == Key.NUM_THREE or key == Key.THREE then
    -- Toggle Instant Heal
    mod.Config.InstantHealEnabled = not mod.Config.InstantHealEnabled
    if mod.update_instant_heal then
      mod.update_instant_heal(mod.Config.InstantHealEnabled)
    end
    mod.Log("Instant Heal: " .. (mod.Config.InstantHealEnabled and "ENABLED" or "DISABLED"))
    display_menu(mod)
    
  elseif key == Key.NUM_FOUR or key == Key.FOUR then
    -- Toggle Throw Distance (enable/disable by setting multiplier to 1.0 or 2.0)
    if mod.Config.ThrowDistanceMultiplier and mod.Config.ThrowDistanceMultiplier > 1.0 then
      mod.Config.ThrowDistanceMultiplier = 1.0
      mod.Log("Throw Distance: DISABLED")
    else
      mod.Config.ThrowDistanceMultiplier = 2.0
      mod.Log("Throw Distance: ENABLED (2.0x)")
    end
    display_menu(mod)
    
  -- Multiplier adjustments
  elseif key == Key.NUM_FIVE or key == Key.FIVE then
    -- Increase Speed Multiplier
    local current = mod.Config.SpeedMultiplier or 2.0
    local new = math.min(current + 0.5, 5.0)
    mod.Config.SpeedMultiplier = new
    if mod.update_speed_multiplier then
      mod.update_speed_multiplier(new)
    end
    mod.Log(string.format("Speed Multiplier: %.1f -> %.1f", current, new))
    display_menu(mod)
    
  elseif key == Key.NUM_SIX or key == Key.SIX then
    -- Decrease Speed Multiplier
    local current = mod.Config.SpeedMultiplier or 2.0
    local new = math.max(current - 0.5, 0.5)
    mod.Config.SpeedMultiplier = new
    if mod.update_speed_multiplier then
      mod.update_speed_multiplier(new)
    end
    mod.Log(string.format("Speed Multiplier: %.1f -> %.1f", current, new))
    display_menu(mod)
    
  elseif key == Key.NUM_SEVEN or key == Key.SEVEN then
    -- Increase Vehicle Multiplier
    local current = mod.Config.VehicleSpeedMultiplier or 2.0
    local new = math.min(current + 0.5, 10.0)
    mod.Config.VehicleSpeedMultiplier = new
    if mod.update_vehicle_multiplier then
      mod.update_vehicle_multiplier(new)
    end
    mod.Log(string.format("Vehicle Multiplier: %.1f -> %.1f", current, new))
    display_menu(mod)
    
  elseif key == Key.NUM_EIGHT or key == Key.EIGHT then
    -- Decrease Vehicle Multiplier
    local current = mod.Config.VehicleSpeedMultiplier or 2.0
    local new = math.max(current - 0.5, 0.5)
    mod.Config.VehicleSpeedMultiplier = new
    if mod.update_vehicle_multiplier then
      mod.update_vehicle_multiplier(new)
    end
    mod.Log(string.format("Vehicle Multiplier: %.1f -> %.1f", current, new))
    display_menu(mod)
    
  elseif key == Key.NUM_NINE or key == Key.NINE then
    -- Save to config (optional - just log for now)
    mod.Log("Settings saved to memory (config file persistence not implemented)")
    display_menu(mod)
    
  elseif key == Key.NUM_ZERO or key == Key.ZERO then
    -- Close menu
    showingMenu = false
    print("")
    print("Menu closed. Press F7 to reopen.")
    print("")

  elseif key == Key.F10 then
    -- Toggle ControlMode (Global <-> Individual)
    local currentMode = mod.Config.ControlMode or mod.Config.ServerMode or "Global"
    if currentMode == "Global" then
      mod.Config.ControlMode = "Individual"
      mod.Config.ServerMode = "Individual"  -- Backward compatibility
      mod.Log("ControlMode: INDIVIDUAL (each player controls themselves)")
    else
      mod.Config.ControlMode = "Global"
      mod.Config.ServerMode = "Global"  -- Backward compatibility
      mod.Log("ControlMode: GLOBAL (host controls all players)")
    end
    display_menu(mod)
  end
end

-- Register menu keybinds
local function register_menu_keybinds(mod)
  local keybindString = mod.Config.MenuKeybind or "F7"
  
  if mod.string_to_key then
    menuKeybind = mod.string_to_key(keybindString)
  else
    mod.Warn("string_to_key helper not available; using F7")
    menuKeybind = Key.F7
  end
  
  -- Register F7 to toggle menu
  local ok, err = pcall(function()
    RegisterKeyBind(menuKeybind, function()
      showingMenu = not showingMenu
      if showingMenu then
        display_menu(mod)
      else
        print("")
        print("Menu closed.")
        print("")
      end
    end)
    
    mod.Log("Menu keybind registered: " .. keybindString)
  end)
  
  if not ok then
    mod.Warn("Failed to register menu keybind: " .. tostring(err))
    return false
  end
  
  -- Register number keys (only active when menu is showing)
  local numberKeys = {
    {Key.NUM_ONE, Key.ONE},
    {Key.NUM_TWO, Key.TWO},
    {Key.NUM_THREE, Key.THREE},
    {Key.NUM_FOUR, Key.FOUR},
    {Key.NUM_FIVE, Key.FIVE},
    {Key.NUM_SIX, Key.SIX},
    {Key.NUM_SEVEN, Key.SEVEN},
    {Key.NUM_EIGHT, Key.EIGHT},
    {Key.NUM_NINE, Key.NINE},
    {Key.NUM_ZERO, Key.ZERO},
  }
  
  for _, keyPair in ipairs(numberKeys) do
    for _, key in ipairs(keyPair) do
      local ok2, err2 = pcall(function()
        RegisterKeyBind(key, function()
          handle_menu_key(mod, key)
        end)
      end)

      if not ok2 then
        mod.Debug("Failed to register number key: " .. tostring(err2))
      end
    end
  end

  -- Register F10 key for ControlMode toggle
  local okM, errM = pcall(function()
    RegisterKeyBind(Key.F10, function()
      handle_menu_key(mod, Key.F10)
    end)
  end)

  if not okM then
    mod.Debug("Failed to register M key: " .. tostring(errM))
  end

  return true
end

function M.install_hooks(mod)
  mod.Log("Menu system initializing...")
  
  local ok, err = pcall(function()
    return register_menu_keybinds(mod)
  end)
  
  if not ok then
    mod.Warn("Failed to install menu hooks: " .. tostring(err))
    return false
  end
  
  mod.Log("Menu system ready. Press F7 to open menu.")
  
  return true
end

return M

