-- MoreRVers - hooks/fall_damage.lua
-- Responsibilities:
--  - Hook damage events to detect fall damage
--  - Prevent fall damage when enabled
--  - Support Global/Individual mode and single-player

local M = {}

local UEHelpers = require("UEHelpers")

-- Check if pawn belongs to this player
local function is_player_pawn(pawn, mod)
  if not pawn or not pawn:IsValid() then
    return false
  end

  local ok, result = pcall(function()
    local PlayerController = UEHelpers.GetPlayerController()
    if not PlayerController or not PlayerController:IsValid() then
      return false
    end

    -- Check if this pawn is controlled by this player
    if PlayerController.Pawn == pawn then
      return true
    end

    return false
  end)

  return ok and result == true
end

-- Check if damage is from falling
local function is_fall_damage(self, DamageEvent, mod)
  if not self or not self:IsValid() then
    return false
  end

  local ok, result = pcall(function()
    -- Method 1: Check damage type/cause
    if DamageEvent then
      -- Check if damage type indicates fall damage
      if DamageEvent.DamageType then
        local damageType = DamageEvent.DamageType
        local typeName = tostring(damageType)
        if typeName and (typeName:find("Fall", 1, true) or typeName:find("Landing", 1, true)) then
          if mod then mod.Debug("Fall damage detected via DamageType: " .. typeName) end
          return true
        end
      end
      
      -- Check if damage cause is fall-related
      if DamageEvent.DamageCauser then
        local causer = DamageEvent.DamageCauser
        local causerName = tostring(causer)
        if causerName and (causerName:find("CharacterMovement", 1, true) or causerName:find("Fall", 1, true)) then
          if mod then mod.Debug("Fall damage detected via DamageCauser: " .. causerName) end
          return true
        end
      end
    end
    
    -- Method 2: Check if character is falling/landing
    if self:IsA("Character") or self:IsA("Pawn") then
      -- Check movement component state
      if self.CharacterMovement then
        local movement = self.CharacterMovement
        if movement and movement:IsValid() then
          -- Check if character is falling or just landed
          local isFalling = false
          local isFlying = false
          local okMove, moveResult = pcall(function()
            if movement.IsFalling then
              isFalling = movement:IsFalling()
            end
            if movement.IsFlying then
              isFlying = movement:IsFlying()
            end
            return isFalling or isFlying
          end)
          
          if okMove and (isFalling or isFlying) then
            -- Check if we just landed (velocity changed from falling to not falling)
            local velocity = {X = 0, Y = 0, Z = 0}
            local okVel, velResult = pcall(function()
              if movement.Velocity then
                velocity = movement.Velocity
              elseif movement.K2_GetVelocity then
                velocity = movement:K2_GetVelocity()
              end
              return velocity
            end)
            
            if okVel and velocity then
              local zVel = velocity.Z or 0
              -- If Z velocity is negative (falling down) or just became positive (landing), likely fall damage
              if zVel < -100 or (zVel > -50 and zVel < 50) then
                if mod then mod.Debug("Fall damage detected via movement state (falling/landing)") end
                return true
              end
            end
          end
        end
      end
    end
    
    -- Method 3: Check if damage source is self (fall damage often has no external causer)
    if DamageEvent then
      if not DamageEvent.Instigator or DamageEvent.Instigator == self then
        -- Damage with no instigator or self as instigator might be fall damage
        -- This is a heuristic - we'll be more conservative
        if mod then mod.Debug("Potential fall damage (no external instigator)") end
        -- Don't return true here - too broad, but log for debugging
      end
    end
    
    return false
  end)
  
  return ok and result == true
end

-- Hook damage events to prevent fall damage
local function hook_fall_damage_prevention(mod)
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

        -- Check if this is fall damage
        if not is_fall_damage(self, DamageEvent, mod) then
          return  -- Not fall damage, let it through
        end

        -- Check if we're in single-player mode first
        local isSinglePlayer = false
        local okSP, resultSP = pcall(function()
          local World = UEHelpers.GetWorld()
          if World and World:IsValid() and World.GetNetMode then
            local netMode = World:GetNetMode()
            if netMode == 0 then  -- NM_Standalone
              return true
            end
          end
          return false
        end)
        if okSP and resultSP then
          isSinglePlayer = true
        end
        
        -- Check ControlMode to determine who gets fall damage protection
        local serverMode = mod.Config.ControlMode or mod.Config.ServerMode or "Global"
        if isSinglePlayer then
          -- Single-player: Always allow fall damage prevention
          if not is_player_pawn(self, mod) then
            return
          end
        elseif serverMode == "Individual" then
          -- Individual mode: Only prevent fall damage for this player's pawn
          if not is_player_pawn(self, mod) then
            return
          end
        else
          -- Global mode: Only host can control fall damage prevention
          if mod.is_host_or_server and not mod.is_host_or_server() then
            mod.Debug("Global mode: Not host - fall damage prevention controlled by host only")
            return  -- Only host controls in Global mode
          end
          -- Global mode: Host controls - prevent fall damage for ALL pawns
        end

        -- Check if fall damage prevention is enabled
        if not fallDamageEnabled then
          mod.Debug("Fall damage prevention disabled - allowing damage")
          return
        end

        -- Prevent fall damage by modifying the damage amount
        mod.Debug(string.format("Fall damage prevented: %.2f damage blocked", DamageAmount))
        mod.Log(string.format("Fall damage prevented: %.2f damage blocked", DamageAmount))
        
        -- Try to modify damage amount to 0
        -- Note: Some damage hooks may not allow modification, so we'll try multiple approaches
        local okModify, modifyResult = pcall(function()
          -- Approach 1: Try to modify DamageAmount directly (if possible)
          if DamageAmount then
            -- DamageAmount might be a reference we can modify
            -- This depends on the hook implementation
          end
          
          -- Approach 2: Heal the damage immediately after it's applied
          -- We'll do this in ExecuteInGameThread
          ExecuteInGameThread(function()
            local healthComp = nil
            local okHealth, healthResult = pcall(function()
              -- Try to get health component
              if self.HealthComponent and self.HealthComponent:IsValid() then
                healthComp = self.HealthComponent
              elseif self.Health then
                healthComp = self  -- Health is direct property
              end
              return healthComp
            end)
            
            if okHealth and healthComp then
              -- Get current health
              local currentHealth = 0
              local maxHealth = 100
              local okGet, getResult = pcall(function()
                if healthComp == self then
                  currentHealth = self.Health or 0
                  maxHealth = self.MaxHealth or self.HealthMax or 100
                else
                  currentHealth = healthComp.CurrentHealth or healthComp.Health or 0
                  maxHealth = healthComp.MaxHealth or healthComp.HealthMax or 100
                end
                return currentHealth, maxHealth
              end)
              
              if okGet then
                -- Heal back the damage that was taken
                local healAmount = DamageAmount
                local okHeal, healResult = pcall(function()
                  if healthComp == self then
                    if self.SetHealth then
                      self:SetHealth(currentHealth + healAmount)
                      return true
                    elseif self.Health then
                      self.Health = currentHealth + healAmount
                      return true
                    end
                  else
                    if healthComp.SetHealth then
                      healthComp:SetHealth(currentHealth + healAmount)
                      return true
                    elseif healthComp.Heal then
                      healthComp:Heal(healAmount)
                      return true
                    elseif healthComp.AddHealth then
                      healthComp:AddHealth(healAmount)
                      return true
                    end
                  end
                  return false
                end)
                
                if okHeal and healResult then
                  mod.Debug("Fall damage healed back successfully")
                end
              end
            end
          end)
          
          return true
        end)
        
        -- Return modified damage (0) if possible
        -- Some hook systems allow returning modified values
        return 0  -- Try to return 0 damage
      end)
      
      if ok then
        mod.Log("Hooked damage event for fall damage prevention: " .. sig)
        hooked = true
        break
      else
        mod.Debug("Failed to hook " .. sig .. " for fall damage prevention: " .. tostring(err))
      end
    end)
    
    if hooked then break end
  end
  
  if not hooked then
    mod.Warn("Could not hook any damage events for fall damage prevention")
    return false
  end
  
  return true
end

-- Module-level state for menu control
local fallDamageEnabled = true

-- Export update function for menu system
function M.update_active(mod, isActive)
  fallDamageEnabled = isActive
  mod.Config.FallDamageEnabled = isActive
  mod.Log("Fall Damage Prevention: " .. (isActive and "ENABLED" or "DISABLED"))
end

function M.install_hooks(mod)
  local enabled = mod.Config.FallDamageEnabled

  -- Check if feature is enabled
  if not enabled or enabled == false or enabled == 0 then
    mod.Debug("Fall damage prevention feature disabled")
    fallDamageEnabled = false
    return false
  end

  fallDamageEnabled = true

  mod.Log("Fall damage prevention enabled")

  local ok, err = pcall(function()
    return hook_fall_damage_prevention(mod)
  end)

  if not ok then
    mod.Warn("Failed to install fall damage prevention hooks: " .. tostring(err))
    return false
  end

  return true
end

return M

