-- MoreRVers - hooks/instant_heal.lua
-- Responsibilities:
--  - Hook damage events to monitor player health
--  - Automatically restore health to full when it drops below threshold
--  - Only affect local player (server-safe)

local M = {}

local UEHelpers = require("UEHelpers")

-- Get health component from pawn/character
local function get_health_component(pawn)
  if not pawn or not pawn:IsValid() then
    return nil
  end
  
  -- Try multiple approaches to find health component
  local ok, healthComp = pcall(function()
    -- Approach 1: Direct property access
    if pawn.HealthComponent and pawn.HealthComponent:IsValid() then
      return pawn.HealthComponent
    end
    
    -- Approach 2: Health property (some games use this)
    if pawn.Health and type(pawn.Health) == "number" then
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
        local comp = pawn:GetComponentByClass(className)
        if comp and comp:IsValid() then
          -- Check if it has health-related properties
          if comp.Health or comp.CurrentHealth or comp.GetHealth then
            return comp
          end
        end
      end
    end
    
    -- Approach 4: Try GetComponentsByClass
    if pawn.GetComponentsByClass then
      local comps = pawn:GetComponentsByClass("/Script/Engine.ActorComponent")
      if comps then
        for _, comp in ipairs(comps) do
          if comp:IsValid() and (comp.Health or comp.CurrentHealth or comp.GetHealth) then
            return comp
          end
        end
      end
    end
    
    return nil
  end)
  
  if ok and healthComp then
    return healthComp
  end
  
  return nil
end

-- Get current and max health from pawn/component
local function get_health_values(pawn, healthComp)
  if not pawn or not pawn:IsValid() then
    return nil, nil
  end
  
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
    return currentHealth, maxHealth
  end
  
  return nil, nil
end

-- Set health to max value
local function set_health_to_max(pawn, healthComp, maxHealth)
  if not pawn or not pawn:IsValid() or not maxHealth then
    return false
  end
  
  local ok, result = pcall(function()
    -- If healthComp is the pawn itself
    if healthComp == pawn then
      if pawn.SetHealth then
        pawn:SetHealth(maxHealth)
        return true
      elseif pawn.Health then
        pawn.Health = maxHealth
        return true
      end
      return false
    end
    
    -- Try health component methods/properties
    if healthComp then
      -- Try SetHealth method
      if healthComp.SetHealth then
        healthComp:SetHealth(maxHealth)
        return true
      end
      
      -- Try SetCurrentHealth method
      if healthComp.SetCurrentHealth then
        healthComp:SetCurrentHealth(maxHealth)
        return true
      end
      
      -- Try direct property assignment
      if healthComp.Health then
        healthComp.Health = maxHealth
        return true
      end
      if healthComp.CurrentHealth then
        healthComp.CurrentHealth = maxHealth
        return true
      end
      
      -- Try Heal method
      if healthComp.Heal then
        local current, max = get_health_values(pawn, healthComp)
        if current and max then
          local healAmount = max - current
          if healAmount > 0 then
            healthComp:Heal(healAmount)
            return true
          end
        end
      end
    end
    
    -- Fallback: try pawn methods
    if pawn.SetHealth then
      pawn:SetHealth(maxHealth)
      return true
    end
    if pawn.Heal then
      local current, max = get_health_values(pawn, healthComp)
      if current and max then
        local healAmount = max - current
        if healAmount > 0 then
          pawn:Heal(healAmount)
          return true
        end
      end
    end
    
    return false
  end)
  
  return ok and result == true
end

-- Check if pawn belongs to local player
local function is_local_player_pawn(pawn)
  if not pawn or not pawn:IsValid() then
    return false
  end
  
  local ok, result = pcall(function()
    local PlayerController = UEHelpers.GetPlayerController()
    if not PlayerController or not PlayerController:IsValid() then
      return false
    end
    
    -- Check if this is the local player's controller
    if PlayerController.IsLocalPlayerController and not PlayerController:IsLocalPlayerController() then
      return false
    end
    
    -- Check if this pawn is controlled by the local player
    if PlayerController.Pawn == pawn then
      return true
    end
    
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
        
        -- Only heal local player (server-safe)
        if not is_local_player_pawn(self) then
          return
        end
        
        -- Use ExecuteInGameThread to ensure we're in the game thread
        -- This allows damage to be applied first, then we check health
        ExecuteInGameThread(function()
          -- Small delay to let damage be applied
          local okDelay, _ = pcall(function()
            -- Get health component
            local healthComp = get_health_component(self)
            if not healthComp then
              mod.Debug("Could not find health component for instant heal")
              return
            end
            
            -- Get current and max health
            local currentHealth, maxHealth = get_health_values(self, healthComp)
            if not currentHealth or not maxHealth or maxHealth <= 0 then
              mod.Debug("Could not get health values for instant heal")
              return
            end
            
            -- Calculate health percentage
            local healthPercent = currentHealth / maxHealth
            
            -- Check if health is below threshold
            if healthPercent < threshold then
              mod.Log(string.format("Health below threshold (%.1f%% < %.1f%%), healing to full", 
                healthPercent * 100, threshold * 100))
              
              -- Heal to full
              local healed = set_health_to_max(self, healthComp, maxHealth)
              if healed then
                mod.Debug(string.format("Instant heal successful: %.1f%% -> 100%%", healthPercent * 100))
              else
                mod.Warn("Instant heal failed: could not set health to max")
              end
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

function M.install_hooks(mod)
  local enabled = mod.Config.InstantHealEnabled
  local threshold = mod.Config.InstantHealThreshold or 0.10
  
  -- Check if feature is enabled
  if not enabled or enabled == false or enabled == 0 then
    mod.Debug("Instant heal feature disabled")
    return false
  end
  
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
