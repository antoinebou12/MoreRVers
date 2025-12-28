-- MoreRVers - hooks/vehicle_speed.lua
-- Responsibilities:
--  - Hook vehicle entry/possession to increase vehicle speed
--  - Apply configurable speed multiplier to vehicles
--  - Support toggle keybind (hold key) or persistent boost
--  - Each player controls their own vehicles (server-safe)

local M = {}

local UEHelpers = require("UEHelpers")

-- Store original speeds for restoration
local originalSpeeds = {}
local vehicleSpeedActive = false
local toggleKeyPressed = false

-- Get vehicle movement component from vehicle actor
local function get_vehicle_movement(vehicle, mod)
  if not vehicle or not vehicle:IsValid() then
    if mod then mod.Debug("get_vehicle_movement: vehicle invalid") end
    return nil
  end
  
  if mod then mod.Debug("Attempting to get vehicle movement component from: " .. tostring(vehicle)) end
  
  -- Try multiple approaches to find vehicle movement component
  local ok, movementComp = pcall(function()
    -- Approach 1: Direct property access (most common)
    if vehicle.VehicleMovement and vehicle.VehicleMovement:IsValid() then
      if mod then mod.Debug("Found VehicleMovement via direct property") end
      return vehicle.VehicleMovement
    end
    
    -- Approach 2: WheeledVehicleMovementComponent
    if vehicle.WheeledVehicleMovementComponent and vehicle.WheeledVehicleMovementComponent:IsValid() then
      if mod then mod.Debug("Found WheeledVehicleMovementComponent via direct property") end
      return vehicle.WheeledVehicleMovementComponent
    end
    
    -- Approach 3: GetComponentByClass for wheeled vehicles
    if vehicle.GetComponentByClass then
      local comp = vehicle:GetComponentByClass("/Script/PhysXVehicles.WheeledVehicleMovementComponent")
      if comp and comp:IsValid() then
        if mod then mod.Debug("Found WheeledVehicleMovementComponent via GetComponentByClass") end
        return comp
      end
      
      -- Try generic vehicle movement
      comp = vehicle:GetComponentByClass("/Script/Engine.VehicleMovementComponent")
      if comp and comp:IsValid() then
        if mod then mod.Debug("Found VehicleMovementComponent via GetComponentByClass") end
        return comp
      end
    end
    
    -- Approach 4: GetComponentsByClass
    if vehicle.GetComponentsByClass then
      local comps = vehicle:GetComponentsByClass("/Script/PhysXVehicles.WheeledVehicleMovementComponent")
      if comps and #comps > 0 and comps[1]:IsValid() then
        if mod then mod.Debug("Found WheeledVehicleMovementComponent via GetComponentsByClass") end
        return comps[1]
      end
    end
    
    return nil
  end)
  
  if ok and movementComp then
    if mod then mod.Debug("Successfully found vehicle movement component: " .. tostring(movementComp)) end
    return movementComp
  end
  
  if mod then mod.Debug("Failed to find vehicle movement component") end
  return nil
end

-- Get speed property from vehicle movement component
local function get_vehicle_speed_property(movementComp, mod)
  if not movementComp or not movementComp:IsValid() then
    return nil, nil
  end
  
  local ok, speedProp, maxSpeedProp = pcall(function()
    -- Try common speed property names
    if movementComp.MaxSpeed then
      return "MaxSpeed", movementComp.MaxSpeed
    end
    if movementComp.MaxEngineRPM then
      return "MaxEngineRPM", movementComp.MaxEngineRPM
    end
    if movementComp.TopSpeed then
      return "TopSpeed", movementComp.TopSpeed
    end
    if movementComp.MaxRPM then
      return "MaxRPM", movementComp.MaxRPM
    end
    if movementComp.EngineMaxRPM then
      return "EngineMaxRPM", movementComp.EngineMaxRPM
    end
    
    return nil, nil
  end)
  
  if ok and speedProp then
    if mod then mod.Debug(string.format("Found speed property: %s = %.2f", speedProp, maxSpeedProp)) end
    return speedProp, maxSpeedProp
  end
  
  if mod then mod.Debug("Could not find speed property on vehicle movement component") end
  return nil, nil
end

-- Apply speed multiplier to vehicle
local function apply_vehicle_speed(mod, vehicle, multiplier, isActive)
  if not vehicle or not vehicle:IsValid() then
    mod.Debug("apply_vehicle_speed: vehicle invalid")
    return false
  end
  
  mod.Debug(string.format("Applying vehicle speed: multiplier=%.2f, isActive=%s", multiplier, tostring(isActive)))
  
  local movementComp = get_vehicle_movement(vehicle, mod)
  if not movementComp then
    mod.Debug("Could not get vehicle movement component for speed modification")
    return false
  end
  
  local ok, err = pcall(function()
    local compId = tostring(movementComp)
    
    -- Get speed property
    local speedProp, originalSpeed = get_vehicle_speed_property(movementComp, mod)
    if not speedProp or not originalSpeed then
      mod.Debug("Could not find speed property on vehicle movement component")
      return false
    end
    
    -- Store original speed if not already stored
    if not originalSpeeds[compId] then
      originalSpeeds[compId] = originalSpeed
      mod.Debug(string.format("Stored original vehicle speed: %.2f", originalSpeed))
    end
    
    local storedOriginal = originalSpeeds[compId]
    local newSpeed = storedOriginal
    
    -- Apply multiplier if active
    if isActive then
      newSpeed = storedOriginal * multiplier
      mod.Debug(string.format("Speed calculation: %.2f * %.2f = %.2f", storedOriginal, multiplier, newSpeed))
    else
      mod.Debug("Vehicle speed inactive - restoring original speed")
    end
    
    -- Apply the speed change
    if speedProp == "MaxSpeed" then
      movementComp.MaxSpeed = newSpeed
    elseif speedProp == "MaxEngineRPM" then
      movementComp.MaxEngineRPM = newSpeed
    elseif speedProp == "TopSpeed" then
      movementComp.TopSpeed = newSpeed
    elseif speedProp == "MaxRPM" then
      movementComp.MaxRPM = newSpeed
    elseif speedProp == "EngineMaxRPM" then
      movementComp.EngineMaxRPM = newSpeed
    end
    
    mod.Log(string.format("Vehicle speed modified: %.2f -> %.2f (%.2fx)", 
      storedOriginal, newSpeed, multiplier))
    
    return true
  end)
  
  if not ok then
    mod.Debug("Failed to apply vehicle speed: " .. tostring(err))
    return false
  end
  
  return err or false
end

-- Check if vehicle is controlled by this player (each player controls their own)
local function is_player_vehicle(vehicle, mod)
  if not vehicle or not vehicle:IsValid() then
    return false
  end

  local ok, result = pcall(function()
    local PlayerController = UEHelpers.GetPlayerController()
    if not PlayerController or not PlayerController:IsValid() then
      if mod then mod.Debug("PlayerController is nil or invalid") end
      return false
    end

    -- Check if this vehicle is this player's pawn
    if PlayerController.Pawn == vehicle then
      if mod then mod.Debug("Vehicle is this player's pawn") end
      return true
    end

    -- Alternative: Get vehicle's controller
    local controller = nil
    if vehicle.GetController then
      controller = vehicle:GetController()
    elseif vehicle.Controller then
      controller = vehicle.Controller
    end

    if controller and controller:IsValid() then
      if controller == PlayerController then
        if mod then mod.Debug("Vehicle is controlled by this player") end
        return true
      end
    end

    if mod then mod.Debug("Vehicle is not controlled by this player") end
    return false
  end)

  return ok and result == true
end

-- Update speed for vehicles based on ServerMode (Global = all vehicles, Individual = this player's only)
local function update_vehicle_speeds(mod, multiplier, isActive)
  local serverMode = mod.Config.ServerMode or "Global"

  local ok, err = pcall(function()
    -- Try to find all vehicles
    local vehicles = {}

    -- Try FindAllOf for different vehicle types
    local vehicleTypes = {
      "WheeledVehicle",
      "Vehicle",
      "RV",
      "Car"
    }

    for _, vehicleType in ipairs(vehicleTypes) do
      local found = FindAllOf(vehicleType)
      if found then
        for _, v in ipairs(found) do
          if v:IsValid() then
            table.insert(vehicles, v)
          end
        end
      end
    end

    -- Apply speed based on ServerMode
    local modified = 0
    for _, vehicle in ipairs(vehicles) do
      local shouldModify = false

      if serverMode == "Global" then
        -- Global mode: Apply to ALL vehicles (host controls all)
        shouldModify = true
      else
        -- Individual mode: Only apply to this player's vehicles
        shouldModify = is_player_vehicle(vehicle, mod)
      end

      if shouldModify then
        if apply_vehicle_speed(mod, vehicle, multiplier, isActive) then
          modified = modified + 1
        end
      end
    end

    if modified > 0 then
      mod.Log(string.format("%s mode: Modified speed for %d vehicle(s)", serverMode, modified))
    end

    return true
  end)

  if not ok then
    return false
  end

  return err or false
end

-- Hook vehicle possession to apply speed on entry
local function hook_vehicle_possession(mod, multiplier)
  local signatures = {
    "/Script/Engine.PlayerController:Possess",
    "/Script/Engine.PlayerController:OnPossess",
  }

  local hooked = false
  for _, sig in ipairs(signatures) do
    local ok, err = pcall(function()
      RegisterHook(sig, function(self, InPawn, ...)
        if not self or not self:IsValid() then return end
        if not InPawn or not InPawn:IsValid() then return end

        -- Only apply to this player's controller (each player controls their own)
        local PlayerController = UEHelpers.GetPlayerController()
        if not PlayerController or self ~= PlayerController then
          return
        end

        -- Check if possessed actor is a vehicle
        local isVehicle = false
        local okCheck, result = pcall(function()
          if InPawn:IsA("Vehicle") or InPawn:IsA("WheeledVehicle") then
            return true
          end
          return false
        end)
        if okCheck and result then
          isVehicle = true
        end

        if isVehicle then
          mod.Debug("Player entered vehicle: " .. tostring(InPawn))
          -- Wait a frame for component initialization
          ExecuteInGameThread(function()
            local isActive = true
            if mod.Config.VehicleKeybind and mod.Config.VehicleKeybind ~= "" then
              isActive = toggleKeyPressed
            end
            mod.Debug(string.format("Applying vehicle speed on entry: isActive=%s", tostring(isActive)))
            apply_vehicle_speed(mod, InPawn, multiplier, isActive)
          end)
        end
      end)

      mod.Log("Hooked vehicle possession: " .. sig)
      hooked = true
      return true
    end)

    if ok and hooked then
      break
    end
  end

  return hooked
end

-- Setup tick-based speed updates (for toggle mode)
local function setup_vehicle_speed_tick(mod, multiplier)
  -- Only needed if using toggle keybind
  if not mod.Config.VehicleKeybind or mod.Config.VehicleKeybind == "" then
    return true
  end
  
  -- Timer to auto-reset toggle state
  local toggleResetTimer = nil
  local toggleResetInterval = 0.15 -- Reset after 150ms of no key press
  
  -- Use a tick function to check key state and update speed
  local lastUpdate = 0
  local updateInterval = 0.05 -- Update every 50ms
  
  local function vehicle_speed_tick()
    local currentTime = os.clock()
    
    -- Check if toggle should reset (key not held)
    if toggleKeyPressed and toggleResetTimer and (currentTime - toggleResetTimer) > toggleResetInterval then
      mod.Debug("Vehicle speed timer expired - deactivating speed")
      toggleKeyPressed = false
      toggleResetTimer = nil
    end
    
    if currentTime - lastUpdate < updateInterval then
      return
    end
    lastUpdate = currentTime
    
    ExecuteInGameThread(function()
      -- Update speeds based on toggle state
      update_vehicle_speeds(mod, multiplier, toggleKeyPressed)
    end)
  end
  
  -- Register tick callback
  local ok, err = pcall(function()
    RegisterHook("/Script/Engine.Actor:ReceiveTick", function(self, DeltaSeconds)
      if self and self:IsValid() then
        -- Only tick on player pawn or vehicle
        local isRelevant = false
        local okCheck, result = pcall(function()
          if self:IsA("Pawn") or self:IsA("Character") or self:IsA("Vehicle") then
            local PlayerController = UEHelpers.GetPlayerController()
            if PlayerController and PlayerController:IsValid() and PlayerController.Pawn == self then
              return true
            end
          end
          return false
        end)
        if okCheck and result then
          vehicle_speed_tick()
        end
      end
    end)
    return true
  end)
  
    if not ok then
      return true
    end
  
  -- Return the timer update function for keybind to use
  return function()
    toggleResetTimer = os.clock()
  end
end

-- Export update functions for menu system
function M.update_active(mod, isActive)
  vehicleSpeedActive = isActive
  local multiplier = mod.Config.VehicleSpeedMultiplier or 2.0
  ExecuteInGameThread(function()
    update_vehicle_speeds(mod, multiplier, isActive)
  end)
end

function M.update_multiplier(mod, multiplier)
  mod.Config.VehicleSpeedMultiplier = multiplier
  if vehicleSpeedActive then
    ExecuteInGameThread(function()
      update_vehicle_speeds(mod, multiplier, true)
    end)
  end
end

function M.install_hooks(mod)
  -- Check if vehicle speed is enabled in config
  if not mod.Config.VehicleSpeedEnabled then
    mod.Log("Vehicle speed feature disabled in config")
    return false
  end
  
  local multiplier = mod.Config.VehicleSpeedMultiplier or 2.0
  
  -- Clamp multiplier to reasonable range
  if multiplier < 0.5 then multiplier = 0.5 end
  if multiplier > 10.0 then multiplier = 10.0 end
  
  mod.Log(string.format("Vehicle speed multiplier: %.2f", multiplier))
  
  -- Setup tick-based updates first (needed for toggle mode)
  local timerUpdateFunc = nil
  if mod.Config.VehicleKeybind and mod.Config.VehicleKeybind ~= "" then
    local okTick, tickResult = pcall(function()
      return setup_vehicle_speed_tick(mod, multiplier)
    end)
    
    if okTick and type(tickResult) == "function" then
      timerUpdateFunc = tickResult
    end
    
    if not okTick then
      -- Failed to setup tick, continue anyway
    end
  end
  
  -- If keybind is set, register toggle keybind
  if mod.Config.VehicleKeybind and mod.Config.VehicleKeybind ~= "" then
    local keybindString = mod.Config.VehicleKeybind
    local keybind = nil
    
    if mod.string_to_key then
      keybind = mod.string_to_key(keybindString)
    else
      mod.Warn("string_to_key helper not available; using F8")
      keybind = Key.F8
    end
    
    -- Register keybind for toggle (hold to activate)
    local ok, err = pcall(function()
      RegisterKeyBind(keybind, function()
        toggleKeyPressed = true
        if timerUpdateFunc then
          timerUpdateFunc() -- Refresh the timer
        end
        ExecuteInGameThread(function()
          update_vehicle_speeds(mod, multiplier, true)
        end)
      end)
      
      mod.Log("Vehicle speed toggle keybind registered: " .. keybindString .. " (hold to activate)")
    end)
    
    if not ok then
      mod.Warn("Failed to register vehicle speed keybind: " .. tostring(err))
    end
  else
    -- Persistent mode: always apply speed boost
    mod.Log("Vehicle speed mode: persistent (always active)")
    toggleKeyPressed = true
    vehicleSpeedActive = true
  end
  
  -- Hook vehicle possession to apply speed on entry
  local ok1, err1 = pcall(function()
    return hook_vehicle_possession(mod, multiplier)
  end)
  
  if not ok1 then
    mod.Warn("Failed to hook vehicle possession: " .. tostring(err1))
  end
  
  -- For persistent mode, apply speed immediately
  if not mod.Config.VehicleKeybind or mod.Config.VehicleKeybind == "" then
    ExecuteInGameThread(function()
      update_vehicle_speeds(mod, multiplier, true)
    end)
  end
  
  return true
end

return M

