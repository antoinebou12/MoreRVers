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
local function get_character_movement(pawn)
  if not pawn or not pawn:IsValid() then
    return nil
  end
  
  -- Try to get CharacterMovementComponent
  local ok, movementComp = pcall(function()
    -- Standard UE4/UE5 Character has CharacterMovement property
    if pawn.CharacterMovement and pawn.CharacterMovement:IsValid() then
      return pawn.CharacterMovement
    end
    
    -- Alternative: Try to find component by class
    if pawn.GetComponentsByClass then
      local comps = pawn:GetComponentsByClass("/Script/Engine.CharacterMovementComponent")
      if comps and #comps > 0 then
        return comps[1]
      end
    end
    
    -- Try GetComponentByClass
    if pawn.GetComponentByClass then
      local comp = pawn:GetComponentByClass("/Script/Engine.CharacterMovementComponent")
      if comp and comp:IsValid() then
        return comp
      end
    end
    
    return nil
  end)
  
  if ok and movementComp then
    return movementComp
  end
  
  return nil
end

-- Apply speed multiplier to movement component
local function apply_speed_boost(mod, movementComp, multiplier, isActive)
  if not movementComp or not movementComp:IsValid() then
    return false
  end
  
  local ok, err = pcall(function()
    -- Get component ID for tracking original speed
    local compId = tostring(movementComp)
    
    -- Store original speed if not already stored
    if not originalSpeeds[compId] then
      if movementComp.MaxWalkSpeed then
        originalSpeeds[compId] = movementComp.MaxWalkSpeed
      else
        -- Try alternative speed properties
        if movementComp.MaxSpeed then
          originalSpeeds[compId] = movementComp.MaxSpeed
        else
          -- Default fallback
          originalSpeeds[compId] = 600.0
        end
      end
    end
    
    local originalSpeed = originalSpeeds[compId]
    local newSpeed = originalSpeed
    
    -- Apply multiplier if active
    if isActive then
      newSpeed = originalSpeed * multiplier
    end
    
    -- Apply the speed change
    if movementComp.MaxWalkSpeed ~= nil then
      movementComp.MaxWalkSpeed = newSpeed
    elseif movementComp.MaxSpeed ~= nil then
      movementComp.MaxSpeed = newSpeed
    end
    
    return true
  end)
  
  if not ok then
    mod.Debug("Failed to apply speed boost: " .. tostring(err))
    return false
  end
  
  return true
end

-- Update speed for local player only (server-safe)
local function update_player_speeds(mod, multiplier, isActive)
  local ok, err = pcall(function()
    -- Get the local player's controller only
    local PlayerController = UEHelpers.GetPlayerController()
    if not PlayerController or not PlayerController:IsValid() then
      return false
    end
    
    -- Verify this is the local player's controller (server-safe check)
    if PlayerController.IsLocalPlayerController and not PlayerController:IsLocalPlayerController() then
      mod.Debug("PlayerController is not local - cannot modify speed for other players")
      return false
    end
    
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
      return false
    end
    
    -- Get movement component and apply speed (only to local player)
    local movementComp = get_character_movement(pawn)
    if movementComp then
      apply_speed_boost(mod, movementComp, multiplier, isActive)
      return true
    end
    
    return false
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
        
        -- Only apply speed to local player's pawn (server-safe)
        if self.IsLocalPlayerController and not self:IsLocalPlayerController() then
          return -- Skip non-local players
        end
        
        -- Wait a frame for component initialization
        ExecuteInGameThread(function()
          local movementComp = get_character_movement(InPawn)
          if movementComp then
            local isActive = true
            if mod.Config.SpeedKeybind and mod.Config.SpeedKeybind ~= "" then
              isActive = toggleKeyPressed
            end
            apply_speed_boost(mod, movementComp, multiplier, isActive)
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
  local toggleResetTimer = 0
  local toggleResetInterval = 0.15 -- Reset after 150ms of no key press
  
  -- Use a tick function to check key state and update speed
  local lastUpdate = 0
  local updateInterval = 0.05 -- Update every 50ms for responsive feel
  
  local function speed_tick()
    local currentTime = os.clock()
    
    -- Check if toggle should reset (key not held)
    if toggleKeyPressed and (currentTime - toggleResetTimer) > toggleResetInterval then
      toggleKeyPressed = false
    end
    
    if currentTime - lastUpdate < updateInterval then
      return
    end
    lastUpdate = currentTime
    
    ExecuteInGameThread(function()
      -- Update speeds based on toggle state
      update_player_speeds(mod, multiplier, toggleKeyPressed)
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
  
  mod.Log(string.format("Speed boost multiplier: %.2f", multiplier))
  
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
    local ok, err = pcall(function()
      -- Register key press - refreshes timer to keep speed active
      RegisterKeyBind(keybind, function()
        toggleKeyPressed = true
        if timerUpdateFunc then
          timerUpdateFunc() -- Refresh the timer
        end
        ExecuteInGameThread(function()
          update_player_speeds(mod, multiplier, true)
        end)
      end)

      if actualKeyName ~= keybindString then
        mod.Log("Speed boost toggle keybind registered: " .. actualKeyName .. " (from config: " .. keybindString .. ", hold to activate)")
      else
        mod.Log("Speed boost toggle keybind registered: " .. actualKeyName .. " (hold to activate)")
      end
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

return M

