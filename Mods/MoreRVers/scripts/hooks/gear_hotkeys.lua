-- MoreRVers - hooks/gear_hotkeys.lua
-- Responsibilities:
--  - Register gear hotkeys for vehicle control (arcade mode)
--  - Support sequential linking (shift up/down) and direct gear selection
--  - Works independently - does not require Speed mode

local M = {}

local UEHelpers = require("UEHelpers")

-- Constants
local SHIFT_PARK = 0
local SHIFT_REVERSE = 1
local SHIFT_NEUTRAL = 2
local SHIFT_DRIVE = 3

-- Cached context (auto-refresh on invalid)
local Ctx = {
    Player = nil,
    Vehicle = nil,
    GearBox = nil,
}

local function RefreshContext()
    local PC = FindFirstOf("PlayerController")
    if PC and PC:IsValid() then Ctx.Player = PC end

    local Veh = nil
    if Ctx.Player and Ctx.Player:IsValid() then
        local ok, pawn = pcall(function() return Ctx.Player.AcknowledgedPawn end)
        if ok and pawn and pawn:IsValid() then Veh = pawn end
        if not Veh then
            ok, pawn = pcall(function() return Ctx.Player.Pawn end)
            if ok and pawn and pawn:IsValid() then Veh = pawn end
        end
        if Veh and Veh:IsValid() then
            if Veh:IsA("AVS_Vehicle_C") or Veh:IsA("AVehicleSystemBase") then
                Ctx.Vehicle = Veh
            end
        end
    end
    if not (Ctx.Vehicle and Ctx.Vehicle:IsValid()) then
        Veh = FindFirstOf("AVS_Vehicle_C")
        if Veh and Veh:IsValid() then Ctx.Vehicle = Veh end
    end

    -- Gearbox
    local GB = FindFirstOf("RGGearBox")
    if GB and GB:IsValid() then Ctx.GearBox = GB end
end

local function GetPlayerVehicle()
    if not (Ctx.Vehicle and Ctx.Vehicle:IsValid()) then RefreshContext() end
    return (Ctx.Vehicle and Ctx.Vehicle:IsValid()) and Ctx.Vehicle or nil
end

local function GetGearBoxFromVehicle(Veh)
    if not (Ctx.GearBox and Ctx.GearBox:IsValid()) then RefreshContext() end
    return (Ctx.GearBox and Ctx.GearBox:IsValid()) and Ctx.GearBox or nil
end

-- Check if clutch is down
local function IsClutchDownGame()
    local Veh = GetPlayerVehicle()
    if not (Veh and Veh:IsValid()) then return nil end
    local GB = GetGearBoxFromVehicle(Veh)
    if not GB then return nil end
    local ok, result = pcall(function() return GB:IsClutchDown() end)
    if ok then
        return not not result
    else
        local ok2, res2 = pcall(function()
            return GB:Call("/Script/Ride.RGGearBox:IsClutchDown")
        end)
        if ok2 then return not not res2 end
    end
    return nil
end

-- Update the HUD to display the current gear
local function UpdateShifterHUD(gearNum)
    local Veh = GetPlayerVehicle()
    if not (Veh and Veh:IsValid()) then return end
    local GB = GetGearBoxFromVehicle(Veh)
    if not GB then return end

    local okUpdate, errUpdate = pcall(function()
        GB:Server_SetCurrentGear(gearNum)
    end)
    if okUpdate then
        -- Success
    end
end

-- Set manual gear safely
local function SetManualGearSafe(gearNum, mod)
    local Veh = GetPlayerVehicle()
    if not (Veh and Veh:IsValid()) then
        if mod then mod.Debug("No player vehicle found; cannot set gear") end
        return
    end
    
    -- Ensure shifter is in Drive/CurrentGear mode (value 3) before setting a manual gear
    local okShift, errShift = pcall(function() Veh:RPC_Server_Shifter(SHIFT_DRIVE) end)
    if not okShift then
        local okSet, errSet = pcall(function() Veh:SetShifterPosition(SHIFT_DRIVE) end)
    end
    
    local ok, err = pcall(function()
        Veh:SetManualGear(gearNum)
    end)
    if not ok then
        if mod then mod.Warn("SetManualGear failed: " .. tostring(err)) end
    else
        UpdateShifterHUD(gearNum)
    end
end

-- Set reverse safely
local function SetReverseSafe(mod)
    local Veh = GetPlayerVehicle()
    if not (Veh and Veh:IsValid()) then
        if mod then mod.Debug("No player vehicle found; cannot set reverse") end
        return
    end

    -- Step 1: Ensure we're in Drive/CurrentGear (3) so SetManualGear applies
    local okShiftDrive, errShiftDrive = pcall(function() Veh:RPC_Server_Shifter(3) end)
    if not okShiftDrive then
        local okSetDrive, errSetDrive = pcall(function() Veh:SetShifterPosition(3) end)
    end

    -- Step 2: Pre-select first gear to maximize reverse torque
    local okPreGear, errPreGear = pcall(function() Veh:SetManualGear(1) end)

    -- Step 3: Shift to Reverse
    local reverseValue = SHIFT_REVERSE
    local okRev, errRev = pcall(function() Veh:RPC_Server_Shifter(reverseValue) end)
    if not okRev then
        local okSetRev, errSetRev = pcall(function() Veh:SetShifterPosition(reverseValue) end)
        if okSetRev then
            UpdateShifterHUD(-1)
        end
    else
        UpdateShifterHUD(-1)
    end
end

-- Set neutral safely
local function SetNeutralSafe(mod)
    local Veh = GetPlayerVehicle()
    if not (Veh and Veh:IsValid()) then
        if mod then mod.Warn("No player vehicle found; cannot set neutral") end
        return
    end
    local neutralValue = SHIFT_NEUTRAL
    local ok, err = pcall(function() Veh:RPC_Server_Shifter(neutralValue) end)
    if not ok then
        local ok2, err2 = pcall(function() Veh:SetShifterPosition(neutralValue) end)
        if ok2 then
            UpdateShifterHUD(0)
        end
    else
        UpdateShifterHUD(0)
    end
end

-- Check if clutch is active
local function IsClutchActive()
    local clutch = IsClutchDownGame()
    if clutch == nil then
        return false
    end
    return clutch
end

-- Get current gear
local function GetCurrentGear()
    local Veh = GetPlayerVehicle()
    if not (Veh and Veh:IsValid()) then return nil end
    local GB = GetGearBoxFromVehicle(Veh)
    if not GB then return nil end
    local ok, gear = pcall(function() return GB.CurrentGear end)
    if ok and gear then return gear end
    return nil
end

-- Shift up (sequential)
local function ShiftUp(mod)
    local current = GetCurrentGear()
    if not current then
        if mod then mod.Debug("Cannot shift up: no current gear available") end
        return
    end
    local next = current + 1
    if next > 5 then next = 5 end
    SetManualGearSafe(next, mod)
end

-- Shift down (sequential)
local function ShiftDown(mod)
    local current = GetCurrentGear()
    if not current then
        if mod then mod.Debug("Cannot shift down: no current gear available") end
        return
    end
    local next = current - 1
    if next < 1 then next = 1 end
    SetManualGearSafe(next, mod)
end

-- Register gear hotkeys
local function register_gear_hotkeys(mod)
    if not mod.Config.GearHotkeysEnabled then
        mod.Log("Gear hotkeys feature disabled in config")
        return false
    end

    local keyMap = setmetatable({}, {
        __index = function(t, k)
            local ok, v = pcall(function() return Key[k] end)
            if ok then return v end
            return nil
        end
    })

    local function keyFrom(name, default)
        local chosen = mod.Config[name] or default
        local kc = keyMap[chosen]
        if not kc then
            mod.Warn(string.format("Invalid key '%s' for %s; falling back to %s", tostring(chosen), tostring(name), tostring(default)))
            kc = keyMap[default]
        end
        return kc
    end

    local binds = {}
    
    -- Direct gear selection (always available)
    table.insert(binds, {keyFrom("Gear1Key", "NUM_ONE"), function()
        if IsClutchActive() then
            SetManualGearSafe(1, mod)
        end
    end})
    
    table.insert(binds, {keyFrom("Gear2Key", "NUM_TWO"), function()
        if IsClutchActive() then
            SetManualGearSafe(2, mod)
        end
    end})
    
    table.insert(binds, {keyFrom("Gear3Key", "NUM_THREE"), function()
        if IsClutchActive() then
            SetManualGearSafe(3, mod)
        end
    end})
    
    table.insert(binds, {keyFrom("Gear4Key", "NUM_FOUR"), function()
        if IsClutchActive() then
            SetManualGearSafe(4, mod)
        end
    end})
    
    table.insert(binds, {keyFrom("Gear5Key", "NUM_FIVE"), function()
        if IsClutchActive() then
            SetManualGearSafe(5, mod)
        end
    end})
    
    table.insert(binds, {keyFrom("ReverseKey", "NUM_ZERO"), function()
        if IsClutchActive() then
            SetReverseSafe(mod)
        end
    end})
    
    table.insert(binds, {keyFrom("NeutralKey", "NUM_SIX"), function()
        if IsClutchActive() then
            SetNeutralSafe(mod)
        end
    end})
    
    -- Sequential linking (arcade mode) - only if enabled
    if mod.Config.SequentialLinking then
        table.insert(binds, {keyFrom("ShiftUpKey", "UP_ARROW"), function()
            if IsClutchActive() then
                ShiftUp(mod)
            end
        end})
        
        table.insert(binds, {keyFrom("ShiftDownKey", "DOWN_ARROW"), function()
            if IsClutchActive() then
                ShiftDown(mod)
            end
        end})
    end

    for _, entry in ipairs(binds) do
        local keyConst, func = entry[1], entry[2]
        local ok, err = pcall(function()
            RegisterKeyBind(keyConst, func)
        end)
        if not ok then
            mod.Debug("RegisterKeyBind failed: " .. tostring(err))
        end
    end

    local modeText = mod.Config.SequentialLinking and "Arcade mode (sequential linking enabled)" or "Direct gear selection only"
    mod.Log("Gear hotkeys registered: " .. modeText)

    return true
end

function M.install_hooks(mod)
    mod.Log("Gear hotkeys system initializing...")

    local ok, err = pcall(function()
        return register_gear_hotkeys(mod)
    end)

    if not ok then
        mod.Warn("Failed to install gear hotkeys: " .. tostring(err))
        return false
    end

    return true
end

return M

