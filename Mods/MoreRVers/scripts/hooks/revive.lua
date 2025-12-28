-- MoreRVers - hooks/revive.lua
-- Responsibilities:
--  - Register keybind for reviving/respawning players
--  - Handle player respawn logic

local M = {}

local UEHelpers = require("UEHelpers")

-- Attempt to revive/respawn the local player only (server-safe)
local function revive_player(mod)
  mod.Debug("Revive attempt initiated")
  
  local ok, err = pcall(function()
    -- Get the local player's controller only
    local PlayerController = UEHelpers.GetPlayerController()
    if not PlayerController or not PlayerController:IsValid() then
      mod.Warn("No valid PlayerController found for revive")
      return false
    end
    mod.Debug("PlayerController found and valid")

    -- Verify this is the local player's controller (server-safe check)
    if PlayerController.IsLocalPlayerController then
      local isLocal = PlayerController:IsLocalPlayerController()
      if not isLocal then
        mod.Warn("PlayerController is not local - cannot revive other players (server-safe check)")
        return false
      end
      mod.Debug("PlayerController verified as local player")
    else
      mod.Debug("IsLocalPlayerController method not available, proceeding with caution")
    end

    -- Additional safety: verify this controller belongs to the local player
    -- On clients, we should only be able to revive ourselves
    local GameMode = UEHelpers.GetGameModeBase()
    if not GameMode or not GameMode:IsValid() then
      mod.Warn("No valid GameMode found for revive")
      return false
    end
    mod.Debug("GameMode found and valid")
    
    -- Check pawn state before attempting revive
    local hasPawn = false
    local pawnState = "none"
    local okPawn, pawnCheck = pcall(function()
      if PlayerController.Pawn then
        if PlayerController.Pawn:IsValid() then
          hasPawn = true
          pawnState = "valid"
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
      else
        mod.Debug("Method 3 failed: " .. tostring(result3 or "Spawn method not available"))
      end
    end

    if not revived then
      mod.Warn("Could not revive player - all revive methods failed. Check console for debug details.")
      return false
    end

    mod.Debug("Revive completed successfully using method: " .. methodUsed)
    return true
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

  if not ok then
    mod.Warn("Failed to register revive keybind: " .. tostring(err))
    return false
  end

  return true
end

return M
