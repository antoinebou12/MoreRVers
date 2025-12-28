-- MoreRVers - hooks/revive.lua
-- Responsibilities:
--  - Register keybind for reviving/respawning players
--  - Handle player respawn logic

local M = {}

local UEHelpers = require("UEHelpers")

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

-- Attempt to revive player(s) based on ServerMode
local function revive_player(mod)
  mod.Log("=== REVIVE ATTEMPT INITIATED ===")
  mod.Debug("Revive attempt initiated")

  local serverMode = mod.Config.ServerMode or "Global"

  local ok, err = pcall(function()
    if serverMode == "Global" then
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

  if not ok then
    mod.Warn("Failed to register revive keybind: " .. tostring(err))
    return false
  end

  return true
end

return M
