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
  print("Speed Multiplier Controls:")
  print("  [5] +0.5  [6] -0.5  (fine control)")
  print("  [7] +5.0  [8] -5.0  (medium control)")
  print("  [Q] +10.0 [W] -10.0 (large control)")
  print("")
  print("Vehicle Multiplier Controls:")
  print("  [A] +0.5  [S] -0.5  (fine control)")
  print("  [D] +5.0  [F] -5.0  (medium control)")
  print("  [E] +10.0 [R] -10.0 (large control)")
  print("")
  print("Other:")
  print("  [9] Save Settings  [0] Close Menu")
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
    -- Increase Speed Multiplier (+5.0 - medium control)
    local current = mod.Config.SpeedMultiplier or 2.0
    local new = math.min(current + 5.0, 100.0)
    mod.Config.SpeedMultiplier = new
    if mod.update_speed_multiplier then
      mod.update_speed_multiplier(new)
    end
    mod.Log(string.format("Speed Multiplier: %.1f -> %.1f (+5.0)", current, new))
    display_menu(mod)
    
  elseif key == Key.NUM_EIGHT or key == Key.EIGHT then
    -- Decrease Speed Multiplier (-5.0 - medium control)
    local current = mod.Config.SpeedMultiplier or 2.0
    local new = math.max(current - 5.0, 0.5)
    mod.Config.SpeedMultiplier = new
    if mod.update_speed_multiplier then
      mod.update_speed_multiplier(new)
    end
    mod.Log(string.format("Speed Multiplier: %.1f -> %.1f (-5.0)", current, new))
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

  -- Larger Speed Multiplier Controls
  elseif key == Key.Q then
    -- Speed +10.0 (large control)
    local current = mod.Config.SpeedMultiplier or 2.0
    local new = math.min(current + 10.0, 100.0)
    mod.Config.SpeedMultiplier = new
    if mod.update_speed_multiplier then
      mod.update_speed_multiplier(new)
    end
    mod.Log(string.format("Speed Multiplier: %.1f -> %.1f (+10.0)", current, new))
    display_menu(mod)

  elseif key == Key.W then
    -- Speed -10.0 (large control)
    local current = mod.Config.SpeedMultiplier or 2.0
    local new = math.max(current - 10.0, 0.5)
    mod.Config.SpeedMultiplier = new
    if mod.update_speed_multiplier then
      mod.update_speed_multiplier(new)
    end
    mod.Log(string.format("Speed Multiplier: %.1f -> %.1f (-10.0)", current, new))
    display_menu(mod)

  -- Vehicle Multiplier Controls (moved to letter keys)
  elseif key == Key.A then
    -- Vehicle +0.5 (fine control)
    local current = mod.Config.VehicleSpeedMultiplier or 2.0
    local new = math.min(current + 0.5, 100.0)
    mod.Config.VehicleSpeedMultiplier = new
    if mod.update_vehicle_multiplier then
      mod.update_vehicle_multiplier(new)
    end
    mod.Log(string.format("Vehicle Multiplier: %.1f -> %.1f", current, new))
    display_menu(mod)

  elseif key == Key.S then
    -- Vehicle -0.5 (fine control)
    local current = mod.Config.VehicleSpeedMultiplier or 2.0
    local new = math.max(current - 0.5, 0.5)
    mod.Config.VehicleSpeedMultiplier = new
    if mod.update_vehicle_multiplier then
      mod.update_vehicle_multiplier(new)
    end
    mod.Log(string.format("Vehicle Multiplier: %.1f -> %.1f", current, new))
    display_menu(mod)

  elseif key == Key.D then
    -- Vehicle +5.0 (medium control)
    local current = mod.Config.VehicleSpeedMultiplier or 2.0
    local new = math.min(current + 5.0, 100.0)
    mod.Config.VehicleSpeedMultiplier = new
    if mod.update_vehicle_multiplier then
      mod.update_vehicle_multiplier(new)
    end
    mod.Log(string.format("Vehicle Multiplier: %.1f -> %.1f (+5.0)", current, new))
    display_menu(mod)

  elseif key == Key.F then
    -- Vehicle -5.0 (medium control)
    local current = mod.Config.VehicleSpeedMultiplier or 2.0
    local new = math.max(current - 5.0, 0.5)
    mod.Config.VehicleSpeedMultiplier = new
    if mod.update_vehicle_multiplier then
      mod.update_vehicle_multiplier(new)
    end
    mod.Log(string.format("Vehicle Multiplier: %.1f -> %.1f (-5.0)", current, new))
    display_menu(mod)

  elseif key == Key.E then
    -- Vehicle +10.0 (large control)
    local current = mod.Config.VehicleSpeedMultiplier or 2.0
    local new = math.min(current + 10.0, 100.0)
    mod.Config.VehicleSpeedMultiplier = new
    if mod.update_vehicle_multiplier then
      mod.update_vehicle_multiplier(new)
    end
    mod.Log(string.format("Vehicle Multiplier: %.1f -> %.1f (+10.0)", current, new))
    display_menu(mod)

  elseif key == Key.R then
    -- Vehicle -10.0 (large control)
    local current = mod.Config.VehicleSpeedMultiplier or 2.0
    local new = math.max(current - 10.0, 0.5)
    mod.Config.VehicleSpeedMultiplier = new
    if mod.update_vehicle_multiplier then
      mod.update_vehicle_multiplier(new)
    end
    mod.Log(string.format("Vehicle Multiplier: %.1f -> %.1f (-10.0)", current, new))
    display_menu(mod)

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
    mod.Debug("Failed to register F10 key: " .. tostring(errM))
  end

  -- Register letter keys for larger increments (Q, W, E, R, A, S, D, F)
  local letterKeys = {Key.Q, Key.W, Key.E, Key.R, Key.A, Key.S, Key.D, Key.F}

  for _, key in ipairs(letterKeys) do
    local okLetter, errLetter = pcall(function()
      RegisterKeyBind(key, function()
        handle_menu_key(mod, key)
      end)
    end)

    if not okLetter then
      mod.Debug("Failed to register letter key: " .. tostring(errLetter))
    end
  end

  return true
end

-- Helper function to parse boolean values (accepts 0/1, true/false, on/off, yes/no)
local function parse_boolean(value)
  if not value then return nil end
  local str = tostring(value):lower()
  if str == "1" or str == "true" or str == "on" or str == "yes" or str == "enabled" then
    return true
  elseif str == "0" or str == "false" or str == "off" or str == "no" or str == "disabled" then
    return false
  end
  return nil
end

-- Register console commands for direct control
local function register_console_commands(mod)
  -- ============================================
  -- Speed Boost Commands
  -- ============================================
  
  -- MoreRVers.SetSpeed <value>
  RegisterConsoleCommandHandler("MoreRVers.SetSpeed", function(FullCommand, Parameters)
    local value = tonumber(Parameters[1])
    if not value then
      mod.Warn("Usage: MoreRVers.SetSpeed <value> (range: 0.5-100, e.g., MoreRVers.SetSpeed 50)")
      return
    end

    -- Clamp to reasonable range
    value = math.max(0.5, math.min(value, 100.0))
    mod.Config.SpeedMultiplier = value

    if mod.update_speed_multiplier then
      mod.update_speed_multiplier(value)
    end

    mod.Log(string.format("Speed Multiplier set to: %.1fx", value))
  end)

  -- MoreRVers.GetSpeed
  RegisterConsoleCommandHandler("MoreRVers.GetSpeed", function(FullCommand, Parameters)
    local enabled = mod.Config.SpeedBoostEnabled and "ENABLED" or "DISABLED"
    local multiplier = mod.Config.SpeedMultiplier or 2.0
    mod.Log(string.format("Speed Boost: %s (Multiplier: %.1fx)", enabled, multiplier))
  end)

  -- MoreRVers.ToggleSpeed
  RegisterConsoleCommandHandler("MoreRVers.ToggleSpeed", function(FullCommand, Parameters)
    mod.Config.SpeedBoostEnabled = not mod.Config.SpeedBoostEnabled
    if mod.update_speed_boost then
      mod.update_speed_boost(mod.Config.SpeedBoostEnabled)
    end
    mod.Log("Speed Boost: " .. (mod.Config.SpeedBoostEnabled and "ENABLED" or "DISABLED"))
  end)

  -- ============================================
  -- Vehicle Speed Commands
  -- ============================================
  
  -- MoreRVers.SetVehicle <value>
  RegisterConsoleCommandHandler("MoreRVers.SetVehicle", function(FullCommand, Parameters)
    local value = tonumber(Parameters[1])
    if not value then
      mod.Warn("Usage: MoreRVers.SetVehicle <value> (range: 0.5-100, e.g., MoreRVers.SetVehicle 20)")
      return
    end

    -- Clamp to reasonable range
    value = math.max(0.5, math.min(value, 100.0))
    mod.Config.VehicleSpeedMultiplier = value

    if mod.update_vehicle_multiplier then
      mod.update_vehicle_multiplier(value)
    end

    mod.Log(string.format("Vehicle Multiplier set to: %.1fx", value))
  end)

  -- MoreRVers.GetVehicle
  RegisterConsoleCommandHandler("MoreRVers.GetVehicle", function(FullCommand, Parameters)
    local enabled = mod.Config.VehicleSpeedEnabled and "ENABLED" or "DISABLED"
    local multiplier = mod.Config.VehicleSpeedMultiplier or 2.0
    mod.Log(string.format("Vehicle Speed: %s (Multiplier: %.1fx)", enabled, multiplier))
  end)

  -- MoreRVers.ToggleVehicle
  RegisterConsoleCommandHandler("MoreRVers.ToggleVehicle", function(FullCommand, Parameters)
    mod.Config.VehicleSpeedEnabled = not mod.Config.VehicleSpeedEnabled
    if mod.update_vehicle_speed then
      mod.update_vehicle_speed(mod.Config.VehicleSpeedEnabled)
    end
    mod.Log("Vehicle Speed: " .. (mod.Config.VehicleSpeedEnabled and "ENABLED" or "DISABLED"))
  end)

  -- ============================================
  -- Fall Damage Commands
  -- ============================================
  
  -- MoreRVers.SetFallDamage <0|1>
  RegisterConsoleCommandHandler("MoreRVers.SetFallDamage", function(FullCommand, Parameters)
    local boolVal = parse_boolean(Parameters[1])
    if boolVal == nil then
      mod.Warn("Usage: MoreRVers.SetFallDamage <0|1> (0=disabled/enabled, 1=enabled, also accepts: true/false, on/off, yes/no)")
      return
    end

    mod.Config.FallDamageEnabled = boolVal
    if mod.update_fall_damage then
      mod.update_fall_damage(boolVal)  -- update_fall_damage expects isActive (true = fall damage prevention enabled)
    end

    mod.Log("Fall Damage Removal: " .. (boolVal and "ENABLED" or "DISABLED"))
  end)

  -- MoreRVers.GetFallDamage
  RegisterConsoleCommandHandler("MoreRVers.GetFallDamage", function(FullCommand, Parameters)
    local enabled = mod.Config.FallDamageEnabled and "ENABLED" or "DISABLED"
    mod.Log(string.format("Fall Damage Removal: %s", enabled))
  end)

  -- MoreRVers.ToggleFallDamage
  RegisterConsoleCommandHandler("MoreRVers.ToggleFallDamage", function(FullCommand, Parameters)
    mod.Config.FallDamageEnabled = not mod.Config.FallDamageEnabled
    if mod.update_fall_damage then
      mod.update_fall_damage(mod.Config.FallDamageEnabled)  -- update_fall_damage expects isActive (true = fall damage prevention enabled)
    end
    mod.Log("Fall Damage Removal: " .. (mod.Config.FallDamageEnabled and "ENABLED" or "DISABLED"))
  end)

  -- ============================================
  -- Revive Commands
  -- ============================================
  
  -- MoreRVers.SetRevive <0|1>
  RegisterConsoleCommandHandler("MoreRVers.SetRevive", function(FullCommand, Parameters)
    local boolVal = parse_boolean(Parameters[1])
    if boolVal == nil then
      mod.Warn("Usage: MoreRVers.SetRevive <0|1> (0=disabled, 1=enabled, also accepts: true/false, on/off, yes/no)")
      return
    end

    mod.Config.ReviveEnabled = boolVal
    mod.Log("Revive: " .. (boolVal and "ENABLED" or "DISABLED"))
  end)

  -- MoreRVers.GetRevive
  RegisterConsoleCommandHandler("MoreRVers.GetRevive", function(FullCommand, Parameters)
    local enabled = mod.Config.ReviveEnabled and "ENABLED" or "DISABLED"
    local keybind = mod.Config.ReviveKeybind or "F6"
    mod.Log(string.format("Revive: %s (Keybind: %s)", enabled, keybind))
  end)

  -- MoreRVers.ToggleRevive
  RegisterConsoleCommandHandler("MoreRVers.ToggleRevive", function(FullCommand, Parameters)
    mod.Config.ReviveEnabled = not mod.Config.ReviveEnabled
    mod.Log("Revive: " .. (mod.Config.ReviveEnabled and "ENABLED" or "DISABLED"))
  end)

  -- ============================================
  -- Throw Distance Commands
  -- ============================================
  
  -- MoreRVers.SetThrow <value>
  RegisterConsoleCommandHandler("MoreRVers.SetThrow", function(FullCommand, Parameters)
    local value = tonumber(Parameters[1])
    if not value then
      mod.Warn("Usage: MoreRVers.SetThrow <value> (range: 0.1-10.0, e.g., MoreRVers.SetThrow 2.5)")
      return
    end

    -- Clamp to reasonable range
    value = math.max(0.1, math.min(value, 10.0))
    mod.Config.ThrowDistanceMultiplier = value

    mod.Log(string.format("Throw Distance Multiplier set to: %.1fx", value))
  end)

  -- MoreRVers.GetThrow
  RegisterConsoleCommandHandler("MoreRVers.GetThrow", function(FullCommand, Parameters)
    local multiplier = mod.Config.ThrowDistanceMultiplier or 2.0
    local enabled = multiplier > 1.0 and "ENABLED" or "DISABLED"
    mod.Log(string.format("Throw Distance: %s (Multiplier: %.1fx)", enabled, multiplier))
  end)

  -- MoreRVers.ToggleThrow
  RegisterConsoleCommandHandler("MoreRVers.ToggleThrow", function(FullCommand, Parameters)
    if mod.Config.ThrowDistanceMultiplier and mod.Config.ThrowDistanceMultiplier > 1.0 then
      mod.Config.ThrowDistanceMultiplier = 1.0
      mod.Log("Throw Distance: DISABLED (set to 1.0x)")
    else
      mod.Config.ThrowDistanceMultiplier = 2.0
      mod.Log("Throw Distance: ENABLED (set to 2.0x)")
    end
  end)

  -- ============================================
  -- Instant Heal Commands
  -- ============================================
  
  -- MoreRVers.SetHeal <0|1>
  RegisterConsoleCommandHandler("MoreRVers.SetHeal", function(FullCommand, Parameters)
    local boolVal = parse_boolean(Parameters[1])
    if boolVal == nil then
      mod.Warn("Usage: MoreRVers.SetHeal <0|1> (0=disabled, 1=enabled, also accepts: true/false, on/off, yes/no)")
      return
    end

    mod.Config.InstantHealEnabled = boolVal
    if mod.update_instant_heal then
      mod.update_instant_heal(boolVal)
    end
    mod.Log("Instant Heal: " .. (boolVal and "ENABLED" or "DISABLED"))
  end)

  -- MoreRVers.SetHealThreshold <value>
  RegisterConsoleCommandHandler("MoreRVers.SetHealThreshold", function(FullCommand, Parameters)
    local value = tonumber(Parameters[1])
    if not value then
      mod.Warn("Usage: MoreRVers.SetHealThreshold <value> (range: 0.01-0.99, e.g., MoreRVers.SetHealThreshold 0.15 for 15%%)")
      return
    end

    -- Clamp to reasonable range
    value = math.max(0.01, math.min(value, 0.99))
    mod.Config.InstantHealThreshold = value

    mod.Log(string.format("Instant Heal Threshold set to: %.1f%% (%.2f)", value * 100, value))
  end)

  -- MoreRVers.GetHeal
  RegisterConsoleCommandHandler("MoreRVers.GetHeal", function(FullCommand, Parameters)
    local enabled = mod.Config.InstantHealEnabled and "ENABLED" or "DISABLED"
    local threshold = (mod.Config.InstantHealThreshold or 0.10) * 100
    mod.Log(string.format("Instant Heal: %s (Threshold: %.1f%%)", enabled, threshold))
  end)

  -- MoreRVers.GetHealThreshold
  RegisterConsoleCommandHandler("MoreRVers.GetHealThreshold", function(FullCommand, Parameters)
    local threshold = mod.Config.InstantHealThreshold or 0.10
    mod.Log(string.format("Instant Heal Threshold: %.1f%% (%.2f)", threshold * 100, threshold))
  end)

  -- MoreRVers.ToggleHeal
  RegisterConsoleCommandHandler("MoreRVers.ToggleHeal", function(FullCommand, Parameters)
    mod.Config.InstantHealEnabled = not mod.Config.InstantHealEnabled
    if mod.update_instant_heal then
      mod.update_instant_heal(mod.Config.InstantHealEnabled)
    end
    mod.Log("Instant Heal: " .. (mod.Config.InstantHealEnabled and "ENABLED" or "DISABLED"))
  end)

  -- ============================================
  -- Utility Commands
  -- ============================================
  
  -- MoreRVers.ToggleMode
  RegisterConsoleCommandHandler("MoreRVers.ToggleMode", function(FullCommand, Parameters)
    local currentMode = mod.Config.ControlMode or mod.Config.ServerMode or "Global"
    if currentMode == "Global" then
      mod.Config.ControlMode = "Individual"
      mod.Config.ServerMode = "Individual"
      mod.Log("ControlMode: INDIVIDUAL (each player controls themselves)")
    else
      mod.Config.ControlMode = "Global"
      mod.Config.ServerMode = "Global"
      mod.Log("ControlMode: GLOBAL (host controls all players)")
    end
  end)

  -- MoreRVers.Enable <feature>
  RegisterConsoleCommandHandler("MoreRVers.Enable", function(FullCommand, Parameters)
    local feature = Parameters[1]
    if not feature then
      mod.Warn("Usage: MoreRVers.Enable <feature>")
      mod.Warn("Valid features: speed, vehicle, heal, throw, falldamage, revive")
      return
    end

    feature = feature:lower()
    if feature == "speed" then
      mod.Config.SpeedBoostEnabled = true
      if mod.update_speed_boost then mod.update_speed_boost(true) end
      mod.Log("Speed Boost ENABLED")
    elseif feature == "vehicle" then
      mod.Config.VehicleSpeedEnabled = true
      if mod.update_vehicle_speed then mod.update_vehicle_speed(true) end
      mod.Log("Vehicle Speed ENABLED")
    elseif feature == "heal" or feature == "instantheal" then
      mod.Config.InstantHealEnabled = true
      if mod.update_instant_heal then mod.update_instant_heal(true) end
      mod.Log("Instant Heal ENABLED")
    elseif feature == "throw" or feature == "throwdistance" then
      mod.Config.ThrowDistanceMultiplier = 2.0
      mod.Log("Throw Distance ENABLED (set to 2.0x)")
    elseif feature == "falldamage" or feature == "fall" then
      mod.Config.FallDamageEnabled = true
      if mod.update_fall_damage then mod.update_fall_damage(true) end  -- true = fall damage prevention enabled
      mod.Log("Fall Damage Removal ENABLED")
    elseif feature == "revive" then
      mod.Config.ReviveEnabled = true
      mod.Log("Revive ENABLED")
    else
      mod.Warn("Unknown feature: " .. feature)
      mod.Warn("Valid features: speed, vehicle, heal, throw, falldamage, revive")
    end
  end)

  -- MoreRVers.Disable <feature>
  RegisterConsoleCommandHandler("MoreRVers.Disable", function(FullCommand, Parameters)
    local feature = Parameters[1]
    if not feature then
      mod.Warn("Usage: MoreRVers.Disable <feature>")
      mod.Warn("Valid features: speed, vehicle, heal, throw, falldamage, revive")
      return
    end

    feature = feature:lower()
    if feature == "speed" then
      mod.Config.SpeedBoostEnabled = false
      if mod.update_speed_boost then mod.update_speed_boost(false) end
      mod.Log("Speed Boost DISABLED")
    elseif feature == "vehicle" then
      mod.Config.VehicleSpeedEnabled = false
      if mod.update_vehicle_speed then mod.update_vehicle_speed(false) end
      mod.Log("Vehicle Speed DISABLED")
    elseif feature == "heal" or feature == "instantheal" then
      mod.Config.InstantHealEnabled = false
      if mod.update_instant_heal then mod.update_instant_heal(false) end
      mod.Log("Instant Heal DISABLED")
    elseif feature == "throw" or feature == "throwdistance" then
      mod.Config.ThrowDistanceMultiplier = 1.0
      mod.Log("Throw Distance DISABLED (set to 1.0x)")
    elseif feature == "falldamage" or feature == "fall" then
      mod.Config.FallDamageEnabled = false
      if mod.update_fall_damage then mod.update_fall_damage(false) end  -- false = fall damage prevention disabled
      mod.Log("Fall Damage Removal DISABLED")
    elseif feature == "revive" then
      mod.Config.ReviveEnabled = false
      mod.Log("Revive DISABLED")
    else
      mod.Warn("Unknown feature: " .. feature)
      mod.Warn("Valid features: speed, vehicle, heal, throw, falldamage, revive")
    end
  end)

  -- MoreRVers.Status
  RegisterConsoleCommandHandler("MoreRVers.Status", function(FullCommand, Parameters)
    print("")
    print("========================================")
    print("  MoreRVers Status")
    print("========================================")
    
    local mode = mod.Config.ControlMode or mod.Config.ServerMode or "Global"
    print(string.format("Control Mode: %s", mode))
    print("")
    
    local speedEnabled = mod.Config.SpeedBoostEnabled and "ENABLED" or "DISABLED"
    local speedMult = mod.Config.SpeedMultiplier or 2.0
    print(string.format("Speed Boost:      %s (%.1fx)", speedEnabled, speedMult))
    
    local vehicleEnabled = mod.Config.VehicleSpeedEnabled and "ENABLED" or "DISABLED"
    local vehicleMult = mod.Config.VehicleSpeedMultiplier or 2.0
    print(string.format("Vehicle Speed:    %s (%.1fx)", vehicleEnabled, vehicleMult))
    
    local healEnabled = mod.Config.InstantHealEnabled and "ENABLED" or "DISABLED"
    local healThreshold = (mod.Config.InstantHealThreshold or 0.10) * 100
    print(string.format("Instant Heal:     %s (threshold: %.1f%%)", healEnabled, healThreshold))
    
    local throwMult = mod.Config.ThrowDistanceMultiplier or 2.0
    local throwEnabled = throwMult > 1.0 and "ENABLED" or "DISABLED"
    print(string.format("Throw Distance:   %s (%.1fx)", throwEnabled, throwMult))
    
    local fallDamageEnabled = mod.Config.FallDamageEnabled and "ENABLED" or "DISABLED"
    print(string.format("Fall Damage:      %s (removal)", fallDamageEnabled))
    
    local reviveEnabled = mod.Config.ReviveEnabled and "ENABLED" or "DISABLED"
    local reviveKeybind = mod.Config.ReviveKeybind or "F6"
    print(string.format("Revive:           %s (keybind: %s)", reviveEnabled, reviveKeybind))
    
    print("========================================")
    print("")
  end)

  -- MoreRVers.Help
  RegisterConsoleCommandHandler("MoreRVers.Help", function(FullCommand, Parameters)
    print("")
    print("========================================")
    print("  MoreRVers Console Commands")
    print("========================================")
    print("")
    print("Speed Boost:")
    print("  MoreRVers.SetSpeed <value>     - Set speed multiplier (0.5-100)")
    print("  MoreRVers.GetSpeed             - Get current speed settings")
    print("  MoreRVers.ToggleSpeed          - Toggle speed boost on/off")
    print("")
    print("Vehicle Speed:")
    print("  MoreRVers.SetVehicle <value>   - Set vehicle multiplier (0.5-100)")
    print("  MoreRVers.GetVehicle           - Get current vehicle settings")
    print("  MoreRVers.ToggleVehicle        - Toggle vehicle speed on/off")
    print("")
    print("Fall Damage:")
    print("  MoreRVers.SetFallDamage <0|1>  - Set fall damage removal (0=off, 1=on)")
    print("  MoreRVers.GetFallDamage        - Get fall damage status")
    print("  MoreRVers.ToggleFallDamage     - Toggle fall damage removal")
    print("")
    print("Revive:")
    print("  MoreRVers.SetRevive <0|1>      - Set revive feature (0=off, 1=on)")
    print("  MoreRVers.GetRevive            - Get revive status")
    print("  MoreRVers.ToggleRevive         - Toggle revive feature")
    print("")
    print("Throw Distance:")
    print("  MoreRVers.SetThrow <value>     - Set throw multiplier (0.1-10.0)")
    print("  MoreRVers.GetThrow             - Get throw distance settings")
    print("  MoreRVers.ToggleThrow          - Toggle throw distance (1.0x <-> 2.0x)")
    print("")
    print("Instant Heal:")
    print("  MoreRVers.SetHeal <0|1>        - Set instant heal (0=off, 1=on)")
    print("  MoreRVers.SetHealThreshold <val> - Set heal threshold (0.01-0.99)")
    print("  MoreRVers.GetHeal              - Get instant heal settings")
    print("  MoreRVers.GetHealThreshold     - Get heal threshold")
    print("  MoreRVers.ToggleHeal           - Toggle instant heal")
    print("")
    print("Utility:")
    print("  MoreRVers.ToggleMode           - Toggle Global/Individual mode")
    print("  MoreRVers.Enable <feature>     - Enable feature (speed, vehicle, heal, throw, falldamage, revive)")
    print("  MoreRVers.Disable <feature>    - Disable feature")
    print("  MoreRVers.Status               - Show all current settings")
    print("  MoreRVers.Help                 - Show this help message")
    print("")
    print("Examples:")
    print("  MoreRVers.SetSpeed 50")
    print("  MoreRVers.SetVehicle 10")
    print("  MoreRVers.SetFallDamage 1")
    print("  MoreRVers.SetThrow 2.5")
    print("  MoreRVers.SetHealThreshold 0.15")
    print("  MoreRVers.ToggleSpeed")
    print("  MoreRVers.Status")
    print("========================================")
    print("")
  end)

  mod.Log("Console commands registered. Type 'MoreRVers.Help' in console for command list.")
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

  -- Register console commands
  local okConsole, errConsole = pcall(function()
    register_console_commands(mod)
  end)

  if not okConsole then
    mod.Debug("Failed to register console commands (non-fatal): " .. tostring(errConsole))
  end

  mod.Log("Menu system ready. Press F7 to open menu.")

  return true
end

return M

