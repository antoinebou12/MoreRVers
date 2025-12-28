-- MoreRVers - hooks/speed_boost.lua
-- Responsibilities:
--  - Hook player movement to increase speed
--  - Apply configurable speed multiplier
--  - Support toggle keybind (hold key) or persistent boost

local M = {}

local UEHelpers = require("UEHelpers")

-- Store original speeds for restoration
local originalSpeeds = {}
local speedBoostActive = false
local toggleKeyPressed = false

-- Get character movement component from pawn
local function get_character_movement(pawn, mod)
  if not pawn or not pawn:IsValid() then
    if mod then mod.Debug("get_character_movement: pawn invalid") end
    return nil
  end

  if mod then mod.Debug("Attempting to get CharacterMovementComponent from pawn: " .. tostring(pawn)) end

  -- Try to get CharacterMovementComponent
  local ok, movementComp = pcall(function()
    -- Standard UE4/UE5 Character has CharacterMovement property
    if pawn.CharacterMovement and pawn.CharacterMovement:IsValid() then
      if mod then mod.Debug("Found CharacterMovement via direct property access") end
      return pawn.CharacterMovement
    end
    
    -- Alternative: Try to find component by class
    if pawn.GetComponentsByClass then
      if mod then mod.Debug("Trying GetComponentsByClass for CharacterMovementComponent") end
      local comps = pawn:GetComponentsByClass("/Script/Engine.CharacterMovementComponent")
      if comps and #comps > 0 then
        if mod then mod.Debug("Found CharacterMovementComponent via GetComponentsByClass") end
        return comps[1]
      end
    end

    -- Try GetComponentByClass
    if pawn.GetComponentByClass then
      if mod then mod.Debug("Trying GetComponentByClass for CharacterMovementComponent") end
      local comp = pawn:GetComponentByClass("/Script/Engine.CharacterMovementComponent")
      if comp and comp:IsValid() then
        if mod then mod.Debug("Found CharacterMovementComponent via GetComponentByClass") end
        return comp
      end
    end

    return nil
  end)

  if ok and movementComp then
    if mod then mod.Debug("CharacterMovementComponent found successfully: " .. tostring(movementComp)) end
    return movementComp
  end

  if mod then mod.Debug("Failed to find CharacterMovementComponent") end
  return nil
end

-- Apply speed multiplier to movement component
local function apply_speed_boost(mod, movementComp, multiplier, isActive)
  if not movementComp or not movementComp:IsValid() then
    if mod then mod.Debug("apply_speed_boost: movement component invalid") end
    return false
  end

  mod.Debug(string.format("Applying speed boost: multiplier=%.1fx, active=%s", multiplier, tostring(isActive)))

  local ok, err = pcall(function()
    -- Get component ID for tracking original speed
    local compId = tostring(movementComp)

    -- Store original speed if not already stored
    if not originalSpeeds[compId] then
      if movementComp.MaxWalkSpeed then
        originalSpeeds[compId] = movementComp.MaxWalkSpeed
        mod.Debug(string.format("Stored original MaxWalkSpeed: %.1f", originalSpeeds[compId]))
      else
        -- Try alternative speed properties
        if movementComp.MaxSpeed then
          originalSpeeds[compId] = movementComp.MaxSpeed
          mod.Debug(string.format("Stored original MaxSpeed: %.1f", originalSpeeds[compId]))
        else
          -- Default fallback
          originalSpeeds[compId] = 600.0
          mod.Debug("Using default original speed: 600.0")
        end
      end
    end

    local originalSpeed = originalSpeeds[compId]
    local newSpeed = originalSpeed

    -- Apply multiplier if active
    if isActive then
      newSpeed = originalSpeed * multiplier
      mod.Debug(string.format("Speed boost ACTIVE: %.1f -> %.1f (%.1fx)", originalSpeed, newSpeed, multiplier))
    else
      mod.Debug(string.format("Speed boost INACTIVE: restoring to %.1f", originalSpeed))
    end

    -- Apply the speed change
    if movementComp.MaxWalkSpeed ~= nil then
      local currentSpeed = movementComp.MaxWalkSpeed
      movementComp.MaxWalkSpeed = newSpeed
      if isActive then
        mod.Log(string.format("Speed modified: MaxWalkSpeed %.1f -> %.1f (%.1fx)",
          originalSpeed, newSpeed, multiplier))
      else
        mod.Debug(string.format("Speed restored: MaxWalkSpeed %.1f -> %.1f", currentSpeed, newSpeed))
      end
    elseif movementComp.MaxSpeed ~= nil then
      local currentSpeed = movementComp.MaxSpeed
      movementComp.MaxSpeed = newSpeed
      if isActive then
        mod.Log(string.format("Speed modified: MaxSpeed %.1f -> %.1f (%.1fx)",
          originalSpeed, newSpeed, multiplier))
      else
        mod.Debug(string.format("Speed restored: MaxSpeed %.1f -> %.1f", currentSpeed, newSpeed))
      end
    end

    return true
  end)
  
  if not ok then
    mod.Debug("Failed to apply speed boost: " .. tostring(err))
    return false
  end
  
  return true
end

-- Update speed based on ControlMode (Global = all players, Individual = this player only)
local function update_player_speeds(mod, multiplier, isActive)
  local serverMode = mod.Config.ControlMode or mod.Config.ServerMode or "Global"

  local ok, err = pcall(function()
    if serverMode == "Global" then
      -- GLOBAL MODE: Host controls ALL players' speed
      -- Check if we're the host
      if mod.is_host_or_server and mod.is_host_or_server() then
        mod.Debug("Global mode: Host detected - applying speed boost to ALL players")

        local pawnsModified = 0
        local okFind, allCharacters = pcall(function()
          return FindAllOf("Character")
        end)

        if okFind and allCharacters then
          mod.Debug(string.format("Found %d characters to modify", #allCharacters))

          for _, character in ipairs(allCharacters) do
            if character and character:IsValid() then
              local movementComp = get_character_movement(character, mod)
              if movementComp then
                apply_speed_boost(mod, movementComp, multiplier, isActive)
                pawnsModified = pawnsModified + 1
              end
            end
          end

          mod.Log(string.format("Global mode: Host modified speed for %d character(s)", pawnsModified))
          return true
        else
          mod.Debug("Failed to find characters for global mode: " .. tostring(allCharacters))
          return false
        end
      else
        mod.Debug("Global mode: Not host - speed controlled by host only")
        return false  -- Only host can control speed in Global mode
      end

    else
      -- INDIVIDUAL MODE: Apply only to this player's pawn (each player controls their own)
      mod.Debug("Individual mode: Applying speed boost to this player only")

      local PlayerController = UEHelpers.GetPlayerController()
      if not PlayerController or not PlayerController:IsValid() then
        mod.Debug("No valid PlayerController found for speed boost")
        return false
      end

      mod.Debug("PlayerController found - applying speed boost")

      -- Get pawn from controller
      local pawn = nil
      local okPawn, pawnResult = pcall(function()
        if PlayerController.Pawn and PlayerController.Pawn:IsValid() then
          return PlayerController.Pawn
        end
        return nil
      end)

      if okPawn and pawnResult then
        pawn = pawnResult
      end

      if not pawn then
        mod.Debug("No pawn found for player")
        return false
      end

      mod.Debug("Found player pawn: " .. tostring(pawn))

      -- Get movement component and apply speed
      local movementComp = get_character_movement(pawn, mod)
      if movementComp then
        apply_speed_boost(mod, movementComp, multiplier, isActive)
        return true
      else
        mod.Debug("Could not find movement component for player pawn")
      end

      return false
    end
  end)

  if not ok then
    mod.Debug("Error updating player speeds: " .. tostring(err))
    return false
  end

  return err or false
end

-- Hook pawn creation to apply speed boost on spawn
local function hook_pawn_creation(mod, multiplier)
  -- Hook PlayerController::Possess to catch when pawn is possessed
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
        
        mod.Debug("Player possessed pawn: " .. tostring(InPawn))

        -- Wait a frame for component initialization
        ExecuteInGameThread(function()
          local movementComp = get_character_movement(InPawn, mod)
          if movementComp then
            local isActive = true
            if mod.Config.SpeedKeybind and mod.Config.SpeedKeybind ~= "" then
              isActive = toggleKeyPressed
            end
            mod.Debug(string.format("Applying speed on pawn possession: active=%s", tostring(isActive)))
            apply_speed_boost(mod, movementComp, multiplier, isActive)
          else
            mod.Debug("Could not find movement component on possessed pawn")
          end
        end)
      end)
      
      mod.Log("Hooked pawn creation: " .. sig)
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
local function setup_speed_tick(mod, multiplier)
  -- Only needed if using toggle keybind
  if not mod.Config.SpeedKeybind or mod.Config.SpeedKeybind == "" then
    return true
  end
  
  -- Timer to auto-reset toggle state (simulates key release)
  -- This creates a "hold" effect - keybind refreshes the timer
  local toggleResetTimer = nil
  local toggleResetInterval = 0.2 -- Reset after 200ms of no key press (increased for better responsiveness)
  
  -- Use a tick function to check key state and update speed
  local lastUpdate = 0
  local updateInterval = 0.05 -- Update every 50ms for responsive feel
  
  local function speed_tick()
    local currentTime = os.clock()
    
    -- Check if toggle should reset (key not held)
    if toggleKeyPressed and toggleResetTimer and (currentTime - toggleResetTimer) > toggleResetInterval then
      mod.Debug("Speed boost timer expired - deactivating speed")
      toggleKeyPressed = false
      toggleResetTimer = nil
    end
    
    if currentTime - lastUpdate < updateInterval then
      return
    end
    lastUpdate = currentTime
    
    ExecuteInGameThread(function()
      -- Update speeds based on toggle state
      local success = update_player_speeds(mod, multiplier, toggleKeyPressed)
      if not success and toggleKeyPressed then
        mod.Debug("Speed boost update failed in tick")
      elseif success and toggleKeyPressed then
        mod.Debug("Speed boost active in tick")
      elseif not toggleKeyPressed then
        mod.Debug("Speed boost inactive in tick")
      end
    end)
  end
  
  -- Register tick callback
  local ok, err = pcall(function()
    -- Use RegisterHook on Tick if available
    RegisterHook("/Script/Engine.Actor:ReceiveTick", function(self, DeltaSeconds)
      if self and self:IsValid() then
        -- Only tick on player pawn
        local isPlayerPawn = false
        local okCheck, result = pcall(function()
          if self:IsA("Pawn") or self:IsA("Character") then
            local PlayerController = UEHelpers.GetPlayerController()
            if PlayerController and PlayerController:IsValid() and PlayerController.Pawn == self then
              return true
            end
          end
          return false
        end)
        if okCheck and result then
          speed_tick()
        end
      end
    end)
    return true
  end)
  
  if not ok then
    mod.Debug("Could not register tick hook for speed updates")
    return true
  end
  
  -- Return the timer update function for keybind to use
  return function()
    toggleResetTimer = os.clock()
  end
end

function M.install_hooks(mod)
  -- Check if speed boost is enabled in config
  if not mod.Config.SpeedBoostEnabled then
    mod.Log("Speed boost feature disabled in config")
    return false
  end
  
  local multiplier = mod.Config.SpeedMultiplier or 2.0
  
  -- Clamp multiplier to reasonable range
  if multiplier < 0.5 then multiplier = 0.5 end
  if multiplier > 5.0 then multiplier = 5.0 end
  
  mod.Log(string.format("Speed boost enabled: multiplier=%.2fx", multiplier))
  
  -- Setup tick-based updates first (needed for toggle mode)
  local timerUpdateFunc = nil
  if mod.Config.SpeedKeybind and mod.Config.SpeedKeybind ~= "" then
    local okTick, tickResult = pcall(function()
      return setup_speed_tick(mod, multiplier)
    end)
    
    if okTick and type(tickResult) == "function" then
      timerUpdateFunc = tickResult
    end
    
    if not okTick then
      mod.Debug("Failed to setup speed tick: " .. tostring(tickResult))
    end
  end
  
  -- If keybind is set, register toggle keybind
  if mod.Config.SpeedKeybind and mod.Config.SpeedKeybind ~= "" then
    local keybindString = mod.Config.SpeedKeybind
    local keybind = nil
    local actualKeyName = keybindString

    if mod.string_to_key then
      keybind, actualKeyName = mod.string_to_key(keybindString)
      if not actualKeyName then
        actualKeyName = "F5"
      end
    else
      mod.Warn("string_to_key helper not available; using F5")
      keybind = Key.F5
      actualKeyName = "F5"
    end

    -- Register keybind for toggle (hold to activate)
    mod.Debug("Registering speed boost toggle keybind: " .. keybindString)
    local ok, err = pcall(function()
      -- Register key press - refreshes timer to keep speed active
      RegisterKeyBind(keybind, function()
        mod.Debug("Speed boost keybind pressed - activating speed")
        toggleKeyPressed = true
        if timerUpdateFunc then
          timerUpdateFunc() -- Refresh the timer
          mod.Debug("Timer refreshed for speed boost")
        end
        ExecuteInGameThread(function()
          local success = update_player_speeds(mod, multiplier, true)
          if success then
            mod.Debug("Speed boost activated successfully")
          else
            mod.Debug("Speed boost activation failed")
          end
        end)
      end)

      if actualKeyName ~= keybindString then
        mod.Log("Speed boost toggle keybind registered: " .. actualKeyName .. " (from config: " .. keybindString .. ", hold to activate)")
      else
        mod.Log("Speed boost toggle keybind registered: " .. actualKeyName .. " (hold to activate)")
      end
      mod.Debug("Speed boost keybind registration successful")
    end)
    
    if not ok then
      mod.Warn("Failed to register speed boost keybind: " .. tostring(err))
    end
  else
    -- Persistent mode: always apply speed boost
    mod.Log("Speed boost mode: persistent (always active)")
    toggleKeyPressed = true
  end
  
  -- Hook pawn creation to apply speed on spawn
  local ok1, err1 = pcall(function()
    return hook_pawn_creation(mod, multiplier)
  end)
  
  if not ok1 then
    mod.Warn("Failed to hook pawn creation: " .. tostring(err1))
  end
  
  -- For persistent mode, apply speed immediately
  if not mod.Config.SpeedKeybind or mod.Config.SpeedKeybind == "" then
    ExecuteInGameThread(function()
      update_player_speeds(mod, multiplier, true)
    end)
  end
  
  return true
end

-- Export update functions for menu system
function M.update_active(mod, isActive)
  speedBoostActive = isActive
  local multiplier = mod.Config.SpeedMultiplier or 2.0
  ExecuteInGameThread(function()
    update_player_speeds(mod, multiplier, isActive)
  end)
end

function M.update_multiplier(mod, multiplier)
  mod.Config.SpeedMultiplier = multiplier
  if speedBoostActive then
    ExecuteInGameThread(function()
      update_player_speeds(mod, multiplier, true)
    end)
  end
end

return M

