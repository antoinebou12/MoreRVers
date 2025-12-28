-- MoreRVers - hooks/instant_heal.lua
-- Responsibilities:
--  - Hook damage events to monitor player health
--  - Automatically restore health to full when it drops below threshold
--  - Each player controls their own instant heal

local M = {}

local UEHelpers = require("UEHelpers")

-- Get health component from pawn/character
local function get_health_component(pawn, mod)
  if not pawn or not pawn:IsValid() then
    if mod then mod.Debug("get_health_component: pawn invalid") end
    return nil
  end

  if mod then mod.Debug("Attempting to get health component from pawn: " .. tostring(pawn)) end

  -- Try multiple approaches to find health component
  local ok, healthComp = pcall(function()
    -- Approach 1: Direct property access
    if pawn.HealthComponent then
      local isValid = true
      local okCheck = pcall(function() isValid = pawn.HealthComponent:IsValid() end)
      if okCheck and isValid then
        if mod then mod.Debug("Found HealthComponent via direct property access") end
        return pawn.HealthComponent
      end
    end
    
    -- Approach 2: Health property (some games use this)
    local healthOk, healthVal = pcall(function() return pawn.Health end)
    if healthOk and healthVal and type(healthVal) == "number" then
      if mod then mod.Debug("Found Health as direct property on pawn: " .. tostring(healthVal)) end
      return pawn  -- Return pawn itself if Health is a direct property
    end
    
    -- Approach 3: GetComponentByClass for health-related components
    if pawn.GetComponentByClass then
      -- Try common health component class names
      local healthClasses = {
        "/Script/Engine.HealthComponent",
        "/Script/GameplayAbilities.AbilitySystemComponent",
        "/Script/Engine.ActorComponent"
      }
      
      for _, className in ipairs(healthClasses) do
        local compOk, comp = pcall(function() return pawn:GetComponentByClass(className) end)
        if compOk and comp then
          local compValidOk, compValid = pcall(function() return comp:IsValid() end)
          if compValidOk and compValid then
            -- Check if it has health-related properties
            local hasHealth = false
            local checkOk = pcall(function()
              hasHealth = (comp.Health ~= nil) or (comp.CurrentHealth ~= nil) or (comp.GetHealth ~= nil)
            end)
            if checkOk and hasHealth then
              if mod then mod.Debug("Found health component via GetComponentByClass: " .. className) end
              return comp
            end
          end
        end
      end
    end
    
    -- Approach 4: Try GetComponentsByClass
    if pawn.GetComponentsByClass then
      local compsOk, comps = pcall(function() return pawn:GetComponentsByClass("/Script/Engine.ActorComponent") end)
      if compsOk and comps then
        for _, comp in ipairs(comps) do
          local compValidOk, compValid = pcall(function() return comp:IsValid() end)
          if compValidOk and compValid then
            local hasHealth = false
            local checkOk = pcall(function()
              hasHealth = (comp.Health ~= nil) or (comp.CurrentHealth ~= nil) or (comp.GetHealth ~= nil)
            end)
            if checkOk and hasHealth then
              if mod then mod.Debug("Found health component via GetComponentsByClass") end
              return comp
            end
          end
        end
      end
    end
    
    return nil
  end)
  
  if ok and healthComp then
    if mod then mod.Debug("Health component found successfully: " .. tostring(healthComp)) end
    return healthComp
  end

  if mod then mod.Debug("Failed to find health component - tried all approaches") end
  return nil
end

-- Get current and max health from pawn/component
local function get_health_values(pawn, healthComp, mod)
  if not pawn or not pawn:IsValid() then
    return nil, nil
  end

  if mod then mod.Debug("Getting health values from pawn") end

  local ok, currentHealth, maxHealth = pcall(function()
    -- If healthComp is the pawn itself (Health is direct property)
    if healthComp == pawn then
      local current = pawn.Health or 0
      local max = pawn.MaxHealth or pawn.HealthMax or 100
      return current, max
    end
    
    -- Try health component properties
    if healthComp then
      -- Try various property names
      local current = healthComp.CurrentHealth or healthComp.Health or healthComp.GetHealth and healthComp:GetHealth() or 0
      local max = healthComp.MaxHealth or healthComp.HealthMax or healthComp.GetMaxHealth and healthComp:GetMaxHealth() or 100
      
      -- If GetHealth function exists, use it
      if healthComp.GetHealth and not current then
        current = healthComp:GetHealth()
      end
      if healthComp.GetMaxHealth and not max then
        max = healthComp:GetMaxHealth()
      end
      
      return current, max
    end
    
    -- Fallback: try direct pawn properties
    local current = pawn.Health or 0
    local max = pawn.MaxHealth or pawn.HealthMax or 100
    
    return current, max
  end)

  if ok and currentHealth and maxHealth then
    if mod then
      mod.Debug(string.format("Health values: current=%.1f, max=%.1f (%.1f%%)",
        currentHealth, maxHealth, (currentHealth / maxHealth) * 100))
    end
    return currentHealth, maxHealth
  end

  if mod then mod.Debug("Failed to get health values") end
  return nil, nil
end

-- Set health to max value
local function set_health_to_max(pawn, healthComp, maxHealth, mod)
  if not pawn or not pawn:IsValid() or not maxHealth then
    if mod then mod.Debug("set_health_to_max: invalid inputs") end
    return false
  end

  if mod then mod.Debug("Attempting to set health to max: " .. tostring(maxHealth)) end

  local ok, result = pcall(function()
    -- Method 1: If healthComp is the pawn itself (Health is direct property)
    if healthComp == pawn then
      if mod then mod.Debug("Trying to set health on pawn directly") end
      
      -- Try SetHealth method first
      if pawn.SetHealth then
        pawn:SetHealth(maxHealth)
        if mod then mod.Debug("Set health via pawn:SetHealth(" .. tostring(maxHealth) .. ")") end
        return true
      end
      
      -- Try direct property assignment
      if pawn.Health ~= nil then
        pawn.Health = maxHealth
        if mod then mod.Debug("Set health via pawn.Health = " .. tostring(maxHealth)) end
        return true
      end
      
      -- Try SetCurrentHealth
      if pawn.SetCurrentHealth then
        pawn:SetCurrentHealth(maxHealth)
        if mod then mod.Debug("Set health via pawn:SetCurrentHealth(" .. tostring(maxHealth) .. ")") end
        return true
      end
    end
    
    -- Method 2: Try health component methods/properties
    if healthComp and healthComp ~= pawn then
      if mod then mod.Debug("Trying to set health on health component") end
      
      -- Try SetHealth method
      if healthComp.SetHealth then
        healthComp:SetHealth(maxHealth)
        if mod then mod.Debug("Set health via healthComp:SetHealth(" .. tostring(maxHealth) .. ")") end
        return true
      end
      
      -- Try SetCurrentHealth method
      if healthComp.SetCurrentHealth then
        healthComp:SetCurrentHealth(maxHealth)
        if mod then mod.Debug("Set health via healthComp:SetCurrentHealth(" .. tostring(maxHealth) .. ")") end
        return true
      end
      
      -- Try direct property assignment
      if healthComp.Health ~= nil then
        healthComp.Health = maxHealth
        if mod then mod.Debug("Set health via healthComp.Health = " .. tostring(maxHealth)) end
        return true
      end
      if healthComp.CurrentHealth ~= nil then
        healthComp.CurrentHealth = maxHealth
        if mod then mod.Debug("Set health via healthComp.CurrentHealth = " .. tostring(maxHealth)) end
        return true
      end
      
      -- Try Heal method (heal the difference)
      if healthComp.Heal then
        local current, max = get_health_values(pawn, healthComp, mod)
        if current and max then
          local healAmount = max - current
          if healAmount > 0 then
            healthComp:Heal(healAmount)
            if mod then mod.Debug("Healed via healthComp:Heal(" .. tostring(healAmount) .. ")") end
            return true
          end
        end
      end
      
      -- Try AddHealth method
      if healthComp.AddHealth then
        local current, max = get_health_values(pawn, healthComp, mod)
        if current and max then
          local healAmount = max - current
          if healAmount > 0 then
            healthComp:AddHealth(healAmount)
            if mod then mod.Debug("Healed via healthComp:AddHealth(" .. tostring(healAmount) .. ")") end
            return true
          end
        end
      end
    end
    
    -- Method 3: Fallback - try pawn methods directly
    if mod then mod.Debug("Trying fallback methods on pawn") end
    
    if pawn.SetHealth then
      pawn:SetHealth(maxHealth)
      if mod then mod.Debug("Set health via pawn:SetHealth (fallback)") end
      return true
    end
    
    if pawn.Heal then
      local current, max = get_health_values(pawn, healthComp, mod)
      if current and max then
        local healAmount = max - current
        if healAmount > 0 then
          pawn:Heal(healAmount)
          if mod then mod.Debug("Healed via pawn:Heal(" .. tostring(healAmount) .. ") (fallback)") end
          return true
        end
      end
    end
    
    if pawn.AddHealth then
      local current, max = get_health_values(pawn, healthComp, mod)
      if current and max then
        local healAmount = max - current
        if healAmount > 0 then
          pawn:AddHealth(healAmount)
          if mod then mod.Debug("Healed via pawn:AddHealth(" .. tostring(healAmount) .. ") (fallback)") end
          return true
        end
      end
    end
    
    if mod then mod.Warn("All health restoration methods failed") end
    
    -- DIAGNOSTIC: Log all available methods on healthComp for troubleshooting
    if healthComp then
      local availableMethods = {}
      pcall(function()
        for key, value in pairs(healthComp) do
          if type(value) == "function" or (type(value) == "table" and value.IsValid) then
            table.insert(availableMethods, tostring(key))
          end
        end
      end)
      if #availableMethods > 0 then
        mod.Warn("Available methods on health component: " .. table.concat(availableMethods, ", "))
      end
    end
    
    return false
  end)
  
  if ok and result == true then
    if mod then
      -- Verify health was actually set
      local verifyCurrent, verifyMax = get_health_values(pawn, healthComp, mod)
      if verifyCurrent and verifyMax then
        mod.Debug(string.format("Health verification: current=%.1f, max=%.1f (%.1f%%)",
          verifyCurrent, verifyMax, (verifyCurrent / verifyMax) * 100))
      end
    end
    return true
  else
    if mod then mod.Warn("Failed to set health: " .. tostring(result)) end
  end
  
  return false
end

-- Check if pawn belongs to this player (each player controls their own)
local function is_player_pawn(pawn, mod)
  if not pawn or not pawn:IsValid() then
    return false
  end

  local ok, result = pcall(function()
    local PlayerController = UEHelpers.GetPlayerController()
    if not PlayerController or not PlayerController:IsValid() then
      if mod then mod.Debug("PlayerController is nil or invalid") end
      return false
    end

    -- Check if this pawn is controlled by this player
    if PlayerController.Pawn == pawn then
      if mod then mod.Debug("Pawn belongs to this player") end
      return true
    end

    if mod then mod.Debug("Pawn does not belong to this player") end
    return false
  end)

  return ok and result == true
end

-- Hook damage events to check and heal health
local function hook_damage_event(mod)
  local threshold = mod.Config.InstantHealThreshold or 0.10
  
  -- Clamp threshold to valid range
  if threshold < 0.01 then threshold = 0.01 end
  if threshold > 0.99 then threshold = 0.99 end
  
  -- Try multiple damage event signatures
  local signatures = {
    "/Script/Engine.Actor:TakeAnyDamage",
    "/Script/Engine.Pawn:ReceiveAnyDamage",
    "/Script/Engine.Actor:TakeDamage",
  }
  
  local hooked = false
  for _, sig in ipairs(signatures) do
    local ok, err = pcall(function()
      RegisterHook(sig, function(self, DamageAmount, DamageEvent, ...)
        -- Validate inputs
        if not self or not self:IsValid() then return end
        if not DamageAmount or DamageAmount <= 0 then return end
        
        -- Only apply to pawns/characters
        local isPawn = false
        local okCheck, result = pcall(function()
          if self:IsA("Pawn") or self:IsA("Character") then
            return true
          end
          return false
        end)
        if okCheck and result then
          isPawn = true
        end
        
        if not isPawn then return end

        -- Check ControlMode to determine who gets healed
        local serverMode = mod.Config.ControlMode or mod.Config.ServerMode or "Global"
        if serverMode == "Individual" then
          -- Individual mode: Only heal this player's pawn
          if not is_player_pawn(self, mod) then
            return
          end
        else
          -- Global mode: Only host can control healing
          if mod.is_host_or_server and not mod.is_host_or_server() then
            mod.Debug("Global mode: Not host - instant heal controlled by host only")
            return  -- Only host controls healing in Global mode
          end
          -- Global mode: Host controls - heal ALL pawns
        end

        -- Use ExecuteInGameThread to ensure we're in the game thread
        -- This allows damage to be applied first, then we check health
        ExecuteInGameThread(function()
          -- Small delay to let damage be applied
          local okDelay, _ = pcall(function()
            -- Get health component
            local healthComp = get_health_component(self, mod)
            if not healthComp then
              mod.Debug("Could not find health component for instant heal")
              return
            end

            -- Get current and max health
            local currentHealth, maxHealth = get_health_values(self, healthComp, mod)
            if not currentHealth or not maxHealth or maxHealth <= 0 then
              mod.Debug("Could not get health values for instant heal")
              return
            end

            -- Calculate health percentage
            local healthPercent = currentHealth / maxHealth

            mod.Debug(string.format("Current health: %.1f%% (threshold: %.1f%%)",
              healthPercent * 100, threshold * 100))

            -- Check if instant heal is enabled (menu toggle support)
            if not instantHealEnabled then
              mod.Debug("Instant heal disabled via menu - skipping")
              return
            end
            
            -- Check if health is below threshold and not dead
            if healthPercent < threshold and healthPercent > 0 then
              mod.Log(string.format("Instant heal triggered: health %.1f%% < threshold %.1f%%",
                healthPercent * 100, threshold * 100))

              -- Try multiple times with slight delay to ensure damage is applied first
              local healAttempts = 0
              local maxAttempts = 3
              local healed = false
              
              while healAttempts < maxAttempts and not healed do
                healAttempts = healAttempts + 1
                mod.Debug(string.format("Heal attempt %d/%d", healAttempts, maxAttempts))
                
                -- Re-check health values before healing
                local checkCurrent, checkMax = get_health_values(self, healthComp, mod)
                if checkCurrent and checkMax and checkMax > 0 then
                  local checkPercent = checkCurrent / checkMax
                  if checkPercent < threshold then
                    healed = set_health_to_max(self, healthComp, checkMax, mod)
                    if healed then
                      mod.Log(string.format("Instant heal successful: %.1f%% -> 100%%", checkPercent * 100))
                      break
                    else
                      mod.Debug(string.format("Heal attempt %d failed, retrying...", healAttempts))
                      -- Small delay before retry
                      if healAttempts < maxAttempts then
                        local delayOk = pcall(function()
                          -- Wait a tiny bit
                          for i = 1, 10000 do end -- Longer delay for game engine
                        end)
                      end
                    end
                  else
                    mod.Debug("Health already above threshold, no heal needed")
                    healed = true -- Health is fine, no need to heal
                    break
                  end
                end
              end
              
              if not healed then
                mod.Warn(string.format("Instant heal failed after %d attempts", maxAttempts))
              end
            elseif healthPercent <= 0 then
              mod.Debug("Player is dead (0% health) - instant heal skipped (use F6 revive instead)")
            end
          end)
          
          if not okDelay then
            mod.Debug("Error in instant heal delay: " .. tostring(_))
          end
        end)
      end)
      
      if ok then
        mod.Log("Hooked damage event for instant heal: " .. sig)
        hooked = true
        break
      else
        mod.Debug("Failed to hook " .. sig .. " for instant heal: " .. tostring(err))
      end
    end)
    
    if hooked then break end
  end
  
  if not hooked then
    mod.Warn("Could not hook any damage events for instant heal")
    return false
  end
  
  return true
end

-- Module-level state for menu control
local instantHealEnabled = true

-- Export update functions for menu system
function M.update_active(mod, isActive)
  instantHealEnabled = isActive
  mod.Config.InstantHealEnabled = isActive
  mod.Log("Instant Heal: " .. (isActive and "ENABLED" or "DISABLED"))
  -- Note: The hook is already registered, the instantHealEnabled flag controls whether healing occurs
end

function M.update_threshold(mod, threshold)
  mod.Config.InstantHealThreshold = threshold
  mod.Log(string.format("Instant Heal threshold: %.1f%%", threshold * 100))
end

function M.install_hooks(mod)
  local enabled = mod.Config.InstantHealEnabled
  local threshold = mod.Config.InstantHealThreshold or 0.10

  -- Check if feature is enabled
  if not enabled or enabled == false or enabled == 0 then
    mod.Debug("Instant heal feature disabled")
    instantHealEnabled = false
    return false
  end

  instantHealEnabled = true

  -- Clamp threshold to valid range
  if threshold < 0.01 then threshold = 0.01 end
  if threshold > 0.99 then threshold = 0.99 end

  mod.Log(string.format("Instant heal enabled: threshold = %.1f%%", threshold * 100))

  local ok, err = pcall(function()
    return hook_damage_event(mod)
  end)

  if not ok then
    mod.Warn("Failed to install instant heal hooks: " .. tostring(err))
    return false
  end

  return true
end

return M
