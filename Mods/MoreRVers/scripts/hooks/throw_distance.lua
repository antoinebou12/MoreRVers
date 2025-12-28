-- MoreRVers - hooks/throw_distance.lua
-- Responsibilities:
--  - Hook damage/death events to increase throw distance
--  - Apply configurable multiplier to throw force

local M = {}

local UEHelpers = require("UEHelpers")

-- Get physics component from actor/pawn
local function get_physics_component(actor)
  if not actor or not actor:IsValid() then
    return nil
  end
  
  -- Try RootComponent first (most common)
  local ok1, rootComp = pcall(function()
    if actor.RootComponent and actor.RootComponent:IsValid() then
      return actor.RootComponent
    end
    return nil
  end)
  
  if ok1 and rootComp then
    -- Check if it's a physics component
    local ok2, isPrimitive = pcall(function()
      if rootComp.IsSimulatingPhysics and rootComp:IsSimulatingPhysics() then
        return true
      end
      -- Even if not simulating, we can try to add impulse
      return true
    end)
    if ok2 then
      return rootComp
    end
  end
  
  -- Try MeshComponent as fallback
  local ok3, meshComp = pcall(function()
    if actor.MeshComponent and actor.MeshComponent:IsValid() then
      return actor.MeshComponent
    end
    return nil
  end)
  
  if ok3 and meshComp then
    return meshComp
  end
  
  return nil
end

-- Apply throw impulse to component
local function apply_throw_impulse(mod, component, direction, baseForce, multiplier)
  if not component or not component:IsValid() then
    return false
  end
  
  local finalForce = baseForce * multiplier
  
  -- Normalize direction if needed
  local dirX = direction.X or 0
  local dirY = direction.Y or 0
  local dirZ = direction.Z or 0
  
  -- Calculate magnitude
  local mag = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
  if mag > 0.001 then
    dirX = dirX / mag
    dirY = dirY / mag
    dirZ = dirZ / mag
  else
    -- Default upward direction if no direction
    dirX = 0
    dirY = 0
    dirZ = 1
  end
  
  -- Apply impulse
  local ok, err = pcall(function()
    if component.AddImpulse then
      component:AddImpulse({X = dirX * finalForce, Y = dirY * finalForce, Z = dirZ * finalForce})
      return true
    elseif component.AddImpulseAtLocation then
      local loc = {X = 0, Y = 0, Z = 0}
      local okLoc, location = pcall(function()
        if component.K2_GetComponentLocation then
          return component:K2_GetComponentLocation()
        end
        return loc
      end)
      if okLoc and location then loc = location end
      
      component:AddImpulseAtLocation(
        {X = dirX * finalForce, Y = dirY * finalForce, Z = dirZ * finalForce},
        loc
      )
      return true
    end
    return false
  end)
  
  if ok and err then
    mod.Debug(string.format("Applied throw impulse: force=%.2f, dir=(%.2f,%.2f,%.2f)", 
      finalForce, dirX, dirY, dirZ))
    return true
  else
    mod.Debug("Failed to apply throw impulse: " .. tostring(err))
    return false
  end
end

-- Hook damage events to increase throw distance
local function hook_damage_event(mod)
  local multiplier = mod.Config.ThrowDistanceMultiplier or 2.0
  
  -- Skip if multiplier is 1.0 or less (no effect)
  if multiplier <= 1.0 then
    mod.Debug("Throw distance multiplier is 1.0 or less; skipping hook")
    return false
  end
  
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
        
        -- Get damage direction from DamageEvent
        local damageDir = {X = 0, Y = 0, Z = 1}  -- Default upward
        local baseForce = 1000.0  -- Base impulse force
        
        local okDir, dir = pcall(function()
          if DamageEvent and DamageEvent.HitInfo then
            local hitInfo = DamageEvent.HitInfo
            if hitInfo.ImpactNormal then
              local normal = hitInfo.ImpactNormal
              -- Reverse normal for throw direction
              return {X = -normal.X, Y = -normal.Y, Z = -normal.Z}
            end
          end
          -- Try to get from damage instigator
          if DamageEvent and DamageEvent.Instigator then
            local instigator = DamageEvent.Instigator
            if instigator:IsValid() and instigator.K2_GetActorLocation then
              local instLoc = instigator:K2_GetActorLocation()
              local selfLoc = {X = 0, Y = 0, Z = 0}
              local okSelf, selfLocResult = pcall(function()
                if self.K2_GetActorLocation then
                  return self:K2_GetActorLocation()
                end
                return selfLoc
              end)
              if okSelf and selfLocResult then
                selfLoc = selfLocResult
              end
              
              -- Calculate direction from instigator to self
              local dx = selfLoc.X - instLoc.X
              local dy = selfLoc.Y - instLoc.Y
              local dz = selfLoc.Z - instLoc.Z
              local mag = math.sqrt(dx*dx + dy*dy + dz*dz)
              if mag > 0.001 then
                return {X = dx/mag, Y = dy/mag, Z = dz/mag}
              end
            end
          end
          return damageDir
        end)
        
        if okDir and dir then
          damageDir = dir
        end
        
        -- Scale base force by damage amount
        baseForce = baseForce * (1.0 + DamageAmount / 100.0)
        
        -- Get physics component and apply impulse
        local component = get_physics_component(self)
        if component then
          apply_throw_impulse(mod, component, damageDir, baseForce, multiplier)
        end
      end)
      
      if ok then
        mod.Log("Hooked damage event: " .. sig)
        hooked = true
        break
      else
        mod.Debug("Failed to hook " .. sig .. ": " .. tostring(err))
      end
    end)
    
    if hooked then break end
  end
  
  if not hooked then
    mod.Warn("Could not hook any damage events for throw distance")
    return false
  end
  
  return true
end

function M.install_hooks(mod)
  local multiplier = mod.Config.ThrowDistanceMultiplier or 2.0
  
  -- Clamp multiplier to reasonable range
  if multiplier < 0.1 then multiplier = 0.1 end
  if multiplier > 10.0 then multiplier = 10.0 end
  
  mod.Log(string.format("Throw distance multiplier: %.2f", multiplier))
  
  if multiplier <= 1.0 then
    mod.Log("Throw distance feature disabled (multiplier <= 1.0)")
    return false
  end
  
  local ok, err = pcall(function()
    return hook_damage_event(mod)
  end)
  
  if not ok then
    mod.Warn("Failed to install throw distance hooks: " .. tostring(err))
    return false
  end
  
  return true
end

return M

