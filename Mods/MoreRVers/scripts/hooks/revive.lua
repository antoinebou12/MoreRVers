-- MoreRVers - hooks/revive.lua
-- Responsibilities:
--  - Register keybind for reviving/respawning players
--  - Handle player respawn logic

local M = {}

local UEHelpers = require("UEHelpers")

-- Shared health functions (can be used by both revive and instant heal)
-- Get health component from pawn/character
local function get_health_component(pawn, mod)
  if not pawn or not pawn:IsValid() then
    return nil
  end

  local ok, healthComp = pcall(function()
    -- Try direct property access
    if pawn.HealthComponent then
      local isValid = true
      local okCheck = pcall(function() isValid = pawn.HealthComponent:IsValid() end)
      if okCheck and isValid then
        return pawn.HealthComponent
      end
    end
    
    -- Try Health as direct property
    local healthOk, healthVal = pcall(function() return pawn.Health end)
    if healthOk and healthVal and type(healthVal) == "number" then
      return pawn  -- Return pawn itself if Health is a direct property
    end
    
    -- Try GetComponentByClass
    if pawn.GetComponentByClass then
      local healthClasses = {
        "/Script/Engine.HealthComponent",
        "/Script/GameplayAbilities.AbilitySystemComponent",
      }
      
      for _, className in ipairs(healthClasses) do
        local compOk, comp = pcall(function() return pawn:GetComponentByClass(className) end)
        if compOk and comp then
          local compValidOk, compValid = pcall(function() return comp:IsValid() end)
          if compValidOk and compValid then
            return comp
          end
        end
      end
    end
    
    return nil
  end)
  
  return ok and healthComp or nil
end

-- Get current and max health
local function get_health_values(pawn, healthComp, mod)
  if not pawn or not pawn:IsValid() then
    return nil, nil
  end

  local ok, currentHealth, maxHealth = pcall(function()
    if healthComp == pawn then
      local current = pawn.Health or 0
      local max = pawn.MaxHealth or pawn.HealthMax or 100
      return current, max
    end
    
    if healthComp then
      local current = healthComp.CurrentHealth or healthComp.Health or (healthComp.GetHealth and healthComp:GetHealth()) or 0
      local max = healthComp.MaxHealth or healthComp.HealthMax or (healthComp.GetMaxHealth and healthComp:GetMaxHealth()) or 100
      return current, max
    end
    
    local current = pawn.Health or 0
    local max = pawn.MaxHealth or pawn.HealthMax or 100
    return current, max
  end)

  return ok and currentHealth and maxHealth and currentHealth, maxHealth or nil, nil
end

-- Heal pawn to full health
local function heal_pawn_to_full(pawn, mod)
  if not pawn or not pawn:IsValid() then
    return false
  end

  local healthComp = get_health_component(pawn, mod)
  local currentHealth, maxHealth = get_health_values(pawn, healthComp, mod)
  
  if not currentHealth or not maxHealth or maxHealth <= 0 then
    mod.Debug("Could not get health values for healing")
    return false
  end

  if currentHealth >= maxHealth then
    mod.Debug("Health already at maximum")
    return true
  end

  local ok, result = pcall(function()
    -- Try multiple healing methods
    if healthComp == pawn then
      if pawn.SetHealth then
        pawn:SetHealth(maxHealth)
        return true
      end
      if pawn.Health ~= nil then
        pawn.Health = maxHealth
        return true
      end
    end
    
    if healthComp and healthComp ~= pawn then
      if healthComp.SetHealth then
        healthComp:SetHealth(maxHealth)
        return true
      end
      if healthComp.SetCurrentHealth then
        healthComp:SetCurrentHealth(maxHealth)
        return true
      end
      if healthComp.Health ~= nil then
        healthComp.Health = maxHealth
        return true
      end
      if healthComp.CurrentHealth ~= nil then
        healthComp.CurrentHealth = maxHealth
        return true
      end
      if healthComp.Heal then
        local healAmount = maxHealth - currentHealth
        if healAmount > 0 then
          healthComp:Heal(healAmount)
          return true
        end
      end
    end
    
    if pawn.Heal then
      local healAmount = maxHealth - currentHealth
      if healAmount > 0 then
        pawn:Heal(healAmount)
        return true
      end
    end
    
    return false
  end)
  
  if ok and result then
    mod.Log(string.format("Healed player: %.1f%% -> 100%%", (currentHealth / maxHealth) * 100))
    return true
  end
  
  return false
end

-- Check if we're in single-player mode (standalone or only 1 player)
local function is_single_player()
  local ok, result = pcall(function()
    local World = UEHelpers.GetWorld()
    if not World or not World:IsValid() then
      return false
    end
    
    -- Check NetMode - NM_Standalone = 0 means single-player
    if World.GetNetMode then
      local netMode = World:GetNetMode()
      if netMode == 0 then  -- NM_Standalone
        return true
      end
    end
    
    -- Also check if there's only 1 player
    local GameMode = UEHelpers.GetGameModeBase()
    if GameMode and GameMode:IsValid() then
      if GameMode.GetNumPlayers then
        local numPlayers = GameMode:GetNumPlayers()
        if numPlayers == 1 then
          return true
        end
      end
    end
    
    return false
  end)
  
  return ok and result == true
end

-- Heal a single player (if they have a valid pawn)
local function heal_single_player(mod, PlayerController)
  if not PlayerController or not PlayerController:IsValid() then
    return false
  end

  local ok, result = pcall(function()
    local pawn = PlayerController.Pawn
    if pawn and pawn:IsValid() then
      return heal_pawn_to_full(pawn, mod)
    end
    return false
  end)

  return ok and result == true
end

-- Attempt to revive/respawn a single player controller
local function revive_single_player(mod, PlayerController)
  if not PlayerController or not PlayerController:IsValid() then
    mod.Warn("Invalid PlayerController provided to revive_single_player")
    return false
  end

  mod.Debug("Reviving PlayerController: " .. tostring(PlayerController))

  local ok, err = pcall(function()
    local GameMode = UEHelpers.GetGameModeBase()
    if not GameMode or not GameMode:IsValid() then
      mod.Warn("No valid GameMode found for revive")
      return false
    end

    -- Check pawn state before attempting revive
    local hasPawn = false
    local pawnState = "none"
    local pawn = nil
    local okPawn, pawnCheck = pcall(function()
      if PlayerController.Pawn then
        if PlayerController.Pawn:IsValid() then
          hasPawn = true
          pawnState = "valid"
          pawn = PlayerController.Pawn
          return true
        else
          pawnState = "invalid"
          return false
        end
      else
        pawnState = "none"
        return false
      end
    end)
    mod.Debug(string.format("Pawn state check: hasPawn=%s, state=%s", tostring(hasPawn), pawnState))
    
    -- If player has a valid pawn, try to heal them first instead of reviving
    if hasPawn and pawn then
      local currentHealth, maxHealth = get_health_values(pawn, get_health_component(pawn, mod), mod)
      if currentHealth and maxHealth and maxHealth > 0 then
        local healthPercent = currentHealth / maxHealth
        if healthPercent < 1.0 then
          mod.Debug(string.format("Player has valid pawn with %.1f%% health - healing instead of reviving", healthPercent * 100))
          if heal_pawn_to_full(pawn, mod) then
            mod.Log("Player healed to full health")
            return true
          end
        end
      end
    end

    -- Try multiple revive methods
    local revived = false
    local methodUsed = "none"

    -- Method 1: Use GameMode::RestartPlayer
    mod.Debug("Attempting revive method 1: GameMode::RestartPlayer")
    local ok1, result1 = pcall(function()
      if GameMode.RestartPlayer then
        GameMode:RestartPlayer(PlayerController)
        return true
      end
      return false
    end)

    if ok1 and result1 then
      methodUsed = "GameMode::RestartPlayer"
      mod.Log("Successfully revived player using " .. methodUsed)
      revived = true
      
      -- Heal player after revive (wait a frame for pawn to be ready)
      ExecuteInGameThread(function()
        local pawn = PlayerController.Pawn
        if pawn and pawn:IsValid() then
          heal_pawn_to_full(pawn, mod)
        end
      end)
      
      return true
    else
      mod.Debug("Method 1 failed: " .. tostring(result1 or "RestartPlayer not available"))
    end

    -- Method 2: Use GameplayStatics::RestartPlayer
    if not revived then
      mod.Debug("Attempting revive method 2: GameplayStatics::RestartPlayer")
      local ok2, result2 = pcall(function()
        local GameplayStatics = UEHelpers.GetGameplayStatics()
        if GameplayStatics:IsValid() and GameplayStatics.RestartPlayer then
          GameplayStatics:RestartPlayer(PlayerController)
          return true
        end
        return false
      end)

      if ok2 and result2 then
        methodUsed = "GameplayStatics::RestartPlayer"
        mod.Log("Successfully revived player using " .. methodUsed)
        revived = true
        
        -- Heal player after revive (wait a frame for pawn to be ready)
        ExecuteInGameThread(function()
          local pawn = PlayerController.Pawn
          if pawn and pawn:IsValid() then
            heal_pawn_to_full(pawn, mod)
          end
        end)
        
        return true
      else
        mod.Debug("Method 2 failed: " .. tostring(result2 or "GameplayStatics::RestartPlayer not available"))
      end
    end

    -- Method 3: Try to spawn a new pawn if player has none
    if not revived then
      mod.Debug("Attempting revive method 3: Spawn new pawn")
      local ok3, result3 = pcall(function()
        if not PlayerController.Pawn or not PlayerController.Pawn:IsValid() then
          -- Try to get the default pawn class from GameMode
          local DefaultPawnClass = nil
          if GameMode.DefaultPawnClass and GameMode.DefaultPawnClass:IsValid() then
            DefaultPawnClass = GameMode.DefaultPawnClass
            mod.Debug("Found DefaultPawnClass from GameMode")
          else
            mod.Debug("DefaultPawnClass not found in GameMode")
          end

          if DefaultPawnClass then
            local World = UEHelpers.GetWorld()
            if World and World:IsValid() then
              -- Try to spawn at a safe location (origin or player start)
              local SpawnLocation = {X = 0, Y = 0, Z = 100}
              local SpawnRotation = {Pitch = 0, Yaw = 0, Roll = 0}

              -- Try to find a PlayerStart
              local PlayerStarts = FindAllOf("PlayerStart")
              if PlayerStarts and #PlayerStarts > 0 then
                local Start = PlayerStarts[1]
                if Start:IsValid() and Start.K2_GetActorLocation then
                  SpawnLocation = Start:K2_GetActorLocation()
                  if Start.K2_GetActorRotation then
                    SpawnRotation = Start:K2_GetActorRotation()
                  end
                  mod.Debug("Found PlayerStart for spawn location")
                end
              else
                mod.Debug("No PlayerStart found, using default location")
              end

              local NewPawn = World:SpawnActor(DefaultPawnClass, SpawnLocation, SpawnRotation, {})
              if NewPawn and NewPawn:IsValid() then
                PlayerController:Possess(NewPawn)
                methodUsed = "Spawn new pawn"
                mod.Log("Successfully revived player using " .. methodUsed)
                
                -- Heal player after spawn
                ExecuteInGameThread(function()
                  if NewPawn and NewPawn:IsValid() then
                    heal_pawn_to_full(NewPawn, mod)
                  end
                end)
                
                return true
              else
                mod.Debug("Failed to spawn new pawn or pawn is invalid")
              end
            else
              mod.Debug("World not found or invalid")
            end
          end
        else
          mod.Debug("Player already has a valid pawn, skipping spawn method")
        end
        return false
      end)

      if ok3 and result3 then
        revived = true
        return true
      else
        mod.Debug("Method 3 failed: " .. tostring(result3 or "Spawn method not available"))
      end
    end

    if not revived then
      mod.Warn("Could not revive player - all revive methods failed. Check console for debug details.")
      mod.Log("REVIVE FAILED: All methods failed")
      return false
    end

    return true
  end)

  if not ok then
    mod.Error("Error during revive: " .. tostring(err))
    return false
  end

  return err or false
end

-- Attempt to revive player(s) based on ControlMode
local function revive_player(mod)
  mod.Log("=== REVIVE ATTEMPT INITIATED ===")
  mod.Debug("Revive attempt initiated")
  
  local serverMode = mod.Config.ControlMode or mod.Config.ServerMode or "Global"

  local ok, err = pcall(function()
    -- Check if we're in single-player mode first
    if is_single_player() then
      -- SINGLE-PLAYER MODE: Always allow revive (treat as Individual mode)
      mod.Debug("Single-player mode detected: Reviving this player")
      mod.Log("Single-player mode: Reviving player")

      -- Get this player's controller
      local PlayerController = UEHelpers.GetPlayerController()
      if not PlayerController or not PlayerController:IsValid() then
        mod.Warn("No valid PlayerController found for revive")
        mod.Log("REVIVE FAILED: No PlayerController")
        return false
      end
      mod.Debug("PlayerController found and valid: " .. tostring(PlayerController))
      mod.Log("PlayerController found: " .. tostring(PlayerController))

      -- Use the shared revive function
      return revive_single_player(mod, PlayerController)
    elseif serverMode == "Global" then
      -- GLOBAL MODE: Host revives ALL players
      if mod.is_host_or_server and mod.is_host_or_server() then
        mod.Log("Global mode: Host reviving ALL players")
        mod.Debug("Global mode: Host detected - reviving all players")

        local playersRevived = 0
        local okFind, allControllers = pcall(function()
          return FindAllOf("PlayerController")
        end)

        if okFind and allControllers then
          mod.Debug(string.format("Found %d player controllers to revive", #allControllers))

          for _, controller in ipairs(allControllers) do
            if controller and controller:IsValid() then
              if revive_single_player(mod, controller) then
                playersRevived = playersRevived + 1
              end
            end
          end

          mod.Log(string.format("Global mode: Host revived %d player(s)", playersRevived))
          return playersRevived > 0
        else
          mod.Debug("Failed to find player controllers for global mode: " .. tostring(allControllers))
          return false
        end
      else
        mod.Debug("Global mode: Not host - only host can revive")
        mod.Log("REVIVE FAILED: Not host (Global mode)")
        return false  -- Only host can revive in Global mode
      end

    else
      -- INDIVIDUAL MODE: Revive only this player
      mod.Debug("Individual mode: Reviving this player only")

      -- Get this player's controller
      local PlayerController = UEHelpers.GetPlayerController()
      if not PlayerController or not PlayerController:IsValid() then
        mod.Warn("No valid PlayerController found for revive")
        mod.Log("REVIVE FAILED: No PlayerController")
        return false
      end
      mod.Debug("PlayerController found and valid: " .. tostring(PlayerController))
      mod.Log("PlayerController found: " .. tostring(PlayerController))

      -- Use the shared revive function
      return revive_single_player(mod, PlayerController)
    end
  end)

  if not ok then
    mod.Error("Error during revive: " .. tostring(err))
    return false
  end

  return err or false
end

function M.install_hooks(mod)
  -- Check if revive is enabled in config
  if not mod.Config.ReviveEnabled then
    mod.Log("Revive feature disabled in config")
    return false
  end
  
  -- Get keybind from config with fallback (F6 for revive)
  local keybindString = mod.Config.ReviveKeybind or "F6"
  local keybind = nil
  local actualKeyName = keybindString

  if mod.string_to_key then
    keybind, actualKeyName = mod.string_to_key(keybindString)
    if not actualKeyName then
      actualKeyName = "F6"
    end
  else
    mod.Warn("string_to_key helper not available; using F6")
    keybind = Key.F6
    actualKeyName = "F6"
  end

  -- Register keybind for revive
  mod.Debug("Registering revive keybind: " .. keybindString)
  local ok, err = pcall(function()
    RegisterKeyBind(keybind, function()
      mod.Debug("Revive keybind pressed")
      ExecuteInGameThread(function()
        local success = revive_player(mod)
        if success then
          mod.Debug("Revive keybind handler completed successfully")
        else
          mod.Debug("Revive keybind handler completed with failure")
        end
      end)
    end)
    if actualKeyName ~= keybindString then
      mod.Log("Revive keybind registered: " .. actualKeyName .. " (from config: " .. keybindString .. ")")
    else
      mod.Log("Revive keybind registered: " .. actualKeyName)
    end
  end)
  
  -- Register F9 keybind for manual heal
  local okHeal, errHeal = pcall(function()
    RegisterKeyBind(Key.F9, function()
      mod.Debug("Manual heal keybind pressed (F9)")
      ExecuteInGameThread(function()
        local serverMode = mod.Config.ControlMode or mod.Config.ServerMode or "Global"
        
        if serverMode == "Global" then
          -- Global mode: Host heals ALL players
          if mod.is_host_or_server and mod.is_host_or_server() then
            mod.Log("Global mode: Host healing ALL players")
            local playersHealed = 0
            local okFind, allControllers = pcall(function()
              return FindAllOf("PlayerController")
            end)
            
            if okFind and allControllers then
              for _, controller in ipairs(allControllers) do
                if controller and controller:IsValid() then
                  if heal_single_player(mod, controller) then
                    playersHealed = playersHealed + 1
                  end
                end
              end
              mod.Log(string.format("Global mode: Host healed %d player(s)", playersHealed))
            end
          else
            mod.Log("HEAL FAILED: Not host (Global mode)")
          end
        else
          -- Individual mode: Heal only this player
          local PlayerController = UEHelpers.GetPlayerController()
          if PlayerController and PlayerController:IsValid() then
            if heal_single_player(mod, PlayerController) then
              mod.Log("Player healed to full health")
            else
              mod.Warn("Heal failed: Could not heal player")
            end
          else
            mod.Warn("Heal failed: No PlayerController found")
          end
        end
      end)
    end)
    mod.Log("Manual heal keybind registered: F9")
  end)
  
  if not okHeal then
    mod.Debug("Failed to register manual heal keybind: " .. tostring(errHeal))
  end

  if not ok then
    mod.Warn("Failed to register revive keybind: " .. tostring(err))
    return false
  end

  return true
end

return M
