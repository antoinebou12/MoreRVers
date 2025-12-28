-- MoreRVers - hooks/revive.lua
-- Responsibilities:
--  - Register keybind for reviving/respawning players
--  - Handle player respawn logic

local M = {}

local UEHelpers = require("UEHelpers")

-- Attempt to revive/respawn the player
local function revive_player(mod)
  local ok, err = pcall(function()
    local PlayerController = UEHelpers.GetPlayerController()
    if not PlayerController:IsValid() then
      mod.Warn("No valid PlayerController found for revive")
      return false
    end

    local GameMode = UEHelpers.GetGameModeBase()
    if not GameMode:IsValid() then
      mod.Warn("No valid GameMode found for revive")
      return false
    end

    -- Try multiple revive methods
    local revived = false
    
    -- Method 1: Use GameMode::RestartPlayer
    local ok1, result1 = pcall(function()
      if GameMode.RestartPlayer then
        GameMode:RestartPlayer(PlayerController)
        return true
      end
      return false
    end)
    
    if ok1 and result1 then
      mod.Log("Revived player using GameMode::RestartPlayer")
      revived = true
    end

    -- Method 2: Use GameplayStatics::RestartPlayer
    if not revived then
      local ok2, result2 = pcall(function()
        local GameplayStatics = UEHelpers.GetGameplayStatics()
        if GameplayStatics:IsValid() and GameplayStatics.RestartPlayer then
          GameplayStatics:RestartPlayer(PlayerController)
          return true
        end
        return false
      end)
      
      if ok2 and result2 then
        mod.Log("Revived player using GameplayStatics::RestartPlayer")
        revived = true
      end
    end

    -- Method 3: Try to spawn a new pawn if player has none
    if not revived then
      local ok3, result3 = pcall(function()
        if not PlayerController.Pawn or not PlayerController.Pawn:IsValid() then
          -- Try to get the default pawn class from GameMode
          local DefaultPawnClass = nil
          if GameMode.DefaultPawnClass and GameMode.DefaultPawnClass:IsValid() then
            DefaultPawnClass = GameMode.DefaultPawnClass
          end
          
          if DefaultPawnClass then
            local World = UEHelpers.GetWorld()
            if World:IsValid() then
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
                end
              end
              
              local NewPawn = World:SpawnActor(DefaultPawnClass, SpawnLocation, SpawnRotation, {})
              if NewPawn:IsValid() then
                PlayerController:Possess(NewPawn)
                mod.Log("Revived player by spawning new pawn")
                return true
              end
            end
          end
        end
        return false
      end)
      
      if ok3 and result3 then
        revived = true
      end
    end

    if not revived then
      mod.Warn("Could not revive player - no valid revive method found")
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

function M.install_hooks(mod)
  -- Check if revive is enabled in config
  if not mod.Config.ReviveEnabled then
    mod.Log("Revive feature disabled in config")
    return false
  end
  
  -- Get keybind from config with fallback
  local keybindString = mod.Config.ReviveKeybind or "F5"
  local keybind = nil
  
  if mod.string_to_key then
    keybind = mod.string_to_key(keybindString)
  else
    mod.Warn("string_to_key helper not available; using F5")
    keybind = Key.F5
  end
  
  -- Register keybind for revive
  local ok, err = pcall(function()
    RegisterKeyBind(keybind, function()
      ExecuteInGameThread(function()
        revive_player(mod)
      end)
    end)
    mod.Log("Revive keybind registered: " .. keybindString)
  end)

  if not ok then
    mod.Warn("Failed to register revive keybind: " .. tostring(err))
    return false
  end

  return true
end

return M
