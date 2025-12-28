-- MoreRVers - main.lua
-- Host-side UE4SS Lua mod to raise multiplayer cap beyond 4 for RV There Yet?

-- Set up package path for this mod's directory structure
local ModPath = debug.getinfo(1, "S").source:match("@?(.*/)")
if not ModPath then
  -- Try Windows path separator
  ModPath = debug.getinfo(1, "S").source:match("@?(.*)[\\/]")
  if ModPath then ModPath = ModPath .. "\\" end
end

local MoreRVers = {
  Name = "MoreRVers",
  Version = "1.0.0",
  Metrics = {
    forcedAllows = 0,
  }
}

-- ModPath detection (silent unless there's an issue)
if not ModPath then
  print("[MoreRVers] WARNING: ModPath not detected - hooks may fail to load!")
end

-- Enhanced INI file parser (reads multiple config values sequentially)
local function parse_ini(filepath)
  local file = io.open(filepath, "r")
  if not file then return nil end
  
  local config = {}
  local currentSection = nil
  
  for line in file:lines() do
    -- Trim whitespace
    line = line:match("^%s*(.-)%s*$")
    
    -- Skip empty lines and comments
    if line == "" or line:match("^;") then
      goto continue
    end
    
    -- Check for section headers [SectionName]
    local section = line:match("^%[([^%]]+)%]$")
    if section then
      currentSection = section:match("^%s*(.-)%s*$")
      goto continue
    end
    
    -- Parse key = value pairs
    local key, value = line:match("^([^=]+)%s*=%s*(.+)$")
    if key and value then
      key = key:match("^%s*(.-)%s*$")
      value = value:match("^%s*(.-)%s*$")
      
      -- Parse MaxPlayers
      if key == "MaxPlayers" then
        local num = tonumber(value)
        if num then
          config.TargetMaxPlayers = num
        end
      end
      
      -- Parse ReviveEnabled (boolean: 1/0, true/false)
      if key == "ReviveEnabled" then
        local boolVal = nil
        if value == "1" or value:lower() == "true" then
          boolVal = true
        elseif value == "0" or value:lower() == "false" then
          boolVal = false
        end
        if boolVal ~= nil then
          config.ReviveEnabled = boolVal
        end
      end
      
      -- Parse ReviveKeybind (string)
      if key == "ReviveKeybind" then
        config.ReviveKeybind = value
      end
      
      -- Parse ThrowDistanceMultiplier (number)
      if key == "ThrowDistanceMultiplier" then
        local num = tonumber(value)
        if num then
          config.ThrowDistanceMultiplier = num
        end
      end
      
      -- Parse SpeedBoostEnabled (boolean: 1/0, true/false)
      if key == "SpeedBoostEnabled" then
        local boolVal = nil
        if value == "1" or value:lower() == "true" then
          boolVal = true
        elseif value == "0" or value:lower() == "false" then
          boolVal = false
        end
        if boolVal ~= nil then
          config.SpeedBoostEnabled = boolVal
        end
      end
      
      -- Parse SpeedMultiplier (number)
      if key == "SpeedMultiplier" then
        local num = tonumber(value)
        if num then
          config.SpeedMultiplier = num
        end
      end
      
      -- Parse SpeedKeybind (string)
      if key == "SpeedKeybind" then
        config.SpeedKeybind = value
      end
      
      -- Parse InstantHealEnabled (boolean: 1/0, true/false)
      if key == "InstantHealEnabled" then
        local boolVal = nil
        if value == "1" or value:lower() == "true" then
          boolVal = true
        elseif value == "0" or value:lower() == "false" then
          boolVal = false
        end
        if boolVal ~= nil then
          config.InstantHealEnabled = boolVal
        end
      end
      
      -- Parse InstantHealThreshold (number: 0.01-0.99)
      if key == "InstantHealThreshold" then
        local num = tonumber(value)
        if num then
          config.InstantHealThreshold = num
        end
      end
    end
    
    ::continue::
  end
  
  file:close()
  return config
end

-- Load config from INI file
local configLoaded = nil
if ModPath then
  local iniPath = ModPath .. "../config.ini"
  local ok, parsedConfig = pcall(function() return parse_ini(iniPath) end)
  if ok and parsedConfig then
    configLoaded = {
      TargetMaxPlayers = parsedConfig.TargetMaxPlayers or 8,
      HardUpperLimit = 24,
      EnableClientUiTweaks = false,
      LogLevel = "INFO",
      TimestampFormat = "%H:%M:%S",
      ReviveEnabled = parsedConfig.ReviveEnabled ~= nil and parsedConfig.ReviveEnabled or true,
      ReviveKeybind = parsedConfig.ReviveKeybind or "F5",
      ThrowDistanceMultiplier = parsedConfig.ThrowDistanceMultiplier or 2.0,
      SpeedBoostEnabled = parsedConfig.SpeedBoostEnabled ~= nil and parsedConfig.SpeedBoostEnabled or true,
      SpeedMultiplier = parsedConfig.SpeedMultiplier or 2.0,
      SpeedKeybind = parsedConfig.SpeedKeybind or "F5",
      InstantHealEnabled = parsedConfig.InstantHealEnabled ~= nil and parsedConfig.InstantHealEnabled or true,
      InstantHealThreshold = parsedConfig.InstantHealThreshold or 0.10
    }
  end
end

MoreRVers.Config = configLoaded or {
  TargetMaxPlayers = 8,
  HardUpperLimit = 24,
  EnableClientUiTweaks = false,
  LogLevel = "INFO",
  TimestampFormat = "%H:%M:%S",
  ReviveEnabled = true,
  ReviveKeybind = "F6",
  ThrowDistanceMultiplier = 2.0,
  SpeedBoostEnabled = true,
  SpeedMultiplier = 2.0,
  SpeedKeybind = "F5",
  InstantHealEnabled = true,
  InstantHealThreshold = 0.10
}

-- Logging utilities with levels and timestamps
local LEVELS = { DEBUG = 10, INFO = 20, WARN = 30, ERROR = 40 }
local CURRENT_LEVEL = LEVELS[MoreRVers.Config.LogLevel or "INFO"] or LEVELS.INFO

local function ts()
  local fmt = MoreRVers.Config.TimestampFormat or "%H:%M:%S"
  local ok, s = pcall(function() return os.date(fmt) end)
  return ok and s or "--:--:--"
end

local function println(level, msg)
  local lvl = level or "INFO"
  print(string.format("[%s] [%s] [%s] %s", ts(), MoreRVers.Name, lvl, tostring(msg)))
end

function MoreRVers.Debug(msg)
  if LEVELS.DEBUG >= CURRENT_LEVEL then println("DEBUG", msg) end
end

function MoreRVers.Log(msg)
  if LEVELS.INFO >= CURRENT_LEVEL then println("INFO", msg) end
end

function MoreRVers.Warn(msg)
  if LEVELS.WARN >= CURRENT_LEVEL then println("WARN", msg) end
end

function MoreRVers.Error(msg)
  if LEVELS.ERROR >= CURRENT_LEVEL then println("ERROR", msg) end
end

-- Clamp and sanitize target cap
local function sanitize_target_cap(v)
  local num = tonumber(v) or 8
  if num < 1 then num = 1 end  -- Allow as low as 1 for testing
  local hard = tonumber(MoreRVers.Config.HardUpperLimit or 24) or 24
  if num > hard then num = hard end
  return num
end

MoreRVers.TargetMaxPlayers = sanitize_target_cap(MoreRVers.Config.TargetMaxPlayers)

-- Key mapping system (GearHotkeys-style)
-- Returns: keyConst, keyName (e.g., Key.F5, "F5")
local function string_to_key(keyString)
  if not keyString or type(keyString) ~= "string" then
    MoreRVers.Warn("Invalid key string provided; falling back to F5")
    return Key.F5, "F5"
  end
  
  -- Key name mapping table: maps common key names to their Key enum equivalents
  -- This handles cases where config uses friendly names but the Key enum uses different names
  -- Based on Keybinds mod, keys use UPPER_CASE_WITH_UNDERSCORES format
  local keyNameMap = {
    -- Shift keys - test LEFT_SHIFT format first (UPPER_CASE_WITH_UNDERSCORES)
    ["LeftShift"] = {"LEFT_SHIFT", "LShift", "LeftShift", "Left_Shift", "Shift_Left", "LEFTSHIFT"},
    ["RightShift"] = {"RIGHT_SHIFT", "RShift", "RightShift", "Right_Shift", "Shift_Right", "RIGHTSHIFT"},
    ["LShift"] = {"LEFT_SHIFT", "LShift", "LeftShift", "Left_Shift"},
    ["RShift"] = {"RIGHT_SHIFT", "RShift", "RightShift", "Right_Shift"},
    ["LEFT_SHIFT"] = {"LEFT_SHIFT", "LShift", "LeftShift", "Left_Shift"},
    ["RIGHT_SHIFT"] = {"RIGHT_SHIFT", "RShift", "RightShift", "Right_Shift"},
    -- Alt keys
    ["LeftAlt"] = {"LEFT_ALT", "LAlt", "LeftAlt", "Left_Alt", "Alt_Left", "LEFTALT"},
    ["RightAlt"] = {"RIGHT_ALT", "RAlt", "RightAlt", "Right_Alt", "Alt_Right", "RIGHTALT"},
    ["Alt"] = {"LEFT_ALT", "LAlt", "LeftAlt", "Left_Alt"},
    ["LAlt"] = {"LEFT_ALT", "LAlt", "LeftAlt", "Left_Alt"},
    ["RAlt"] = {"RIGHT_ALT", "RAlt", "RightAlt", "Right_Alt"},
    ["LEFT_ALT"] = {"LEFT_ALT", "LAlt", "LeftAlt", "Left_Alt"},
    ["RIGHT_ALT"] = {"RIGHT_ALT", "RAlt", "RightAlt", "Right_Alt"},
  }
  
  local keyMap = setmetatable({}, {
    __index = function(t, k)
      local ok, v = pcall(function() return Key[k] end)
      if ok and v ~= nil then
        MoreRVers.Debug("Key lookup success: '" .. k .. "' found")
        return v
      end
      return nil
    end
  })
  
  -- Normalize the key string (trim whitespace)
  local normalizedKey = keyString:match("^%s*(.-)%s*$")
  local attempted = {}
  
  -- Check if we have a mapping for this key name
  if keyNameMap[normalizedKey] then
    -- Try each variation in the mapping
    for _, mappedName in ipairs(keyNameMap[normalizedKey]) do
      table.insert(attempted, mappedName)
      local keyConst = keyMap[mappedName]
      if keyConst then
        return keyConst, mappedName
      end
    end
  end

  -- Try original string first (case-sensitive) for mixed-case keys
  local keyConst = keyMap[normalizedKey]
  if not attempted[1] or attempted[1] ~= normalizedKey then
    table.insert(attempted, normalizedKey)
  end
  if keyConst then
    return keyConst, normalizedKey
  end

  -- If that fails, try uppercase version (for keys like F5, R, etc.)
  local upperKey = normalizedKey:upper()
  if upperKey ~= normalizedKey then
    table.insert(attempted, upperKey)
    keyConst = keyMap[upperKey]
    if keyConst then
      return keyConst, upperKey
    end
  end
  
  -- All attempts failed - log debug info and return fallback
  local attemptedStr = table.concat(attempted, ", ")
  MoreRVers.Debug("Key lookup failed for '" .. keyString .. "' (tried: " .. attemptedStr .. ")")

  -- Try one more time with direct Key table access to test common variations
  -- This helps discover the actual Key enum name if it exists but wasn't in our mapping
  local directOk, directVal = pcall(function()
    -- Test uppercase underscore format first (most likely based on Keybinds mod)
    -- Test Shift keys first (LEFT_SHIFT format)
    MoreRVers.Debug("Testing Key.LEFT_SHIFT...")
    if Key.LEFT_SHIFT then 
      MoreRVers.Debug("Key.LEFT_SHIFT exists!")
      return "LEFT_SHIFT" 
    end
    MoreRVers.Debug("Testing Key.RIGHT_SHIFT...")
    if Key.RIGHT_SHIFT then 
      MoreRVers.Debug("Key.RIGHT_SHIFT exists!")
      return "RIGHT_SHIFT" 
    end
    -- Test Alt keys
    MoreRVers.Debug("Testing Key.LEFT_ALT...")
    if Key.LEFT_ALT then 
      MoreRVers.Debug("Key.LEFT_ALT exists!")
      return "LEFT_ALT" 
    end
    MoreRVers.Debug("Testing Key.RIGHT_ALT...")
    if Key.RIGHT_ALT then 
      MoreRVers.Debug("Key.RIGHT_ALT exists!")
      return "RIGHT_ALT" 
    end
    -- Test mixed case variations for Shift
    MoreRVers.Debug("Testing Key.LeftShift...")
    if Key.LeftShift then 
      MoreRVers.Debug("Key.LeftShift exists!")
      return "LeftShift" 
    end
    MoreRVers.Debug("Testing Key.LShift...")
    if Key.LShift then 
      MoreRVers.Debug("Key.LShift exists!")
      return "LShift" 
    end
    MoreRVers.Debug("Testing Key.Left_Shift...")
    if Key.Left_Shift then 
      MoreRVers.Debug("Key.Left_Shift exists!")
      return "Left_Shift" 
    end
    -- Test mixed case variations for Alt
    MoreRVers.Debug("Testing Key.LeftAlt...")
    if Key.LeftAlt then 
      MoreRVers.Debug("Key.LeftAlt exists!")
      return "LeftAlt" 
    end
    MoreRVers.Debug("Testing Key.LAlt...")
    if Key.LAlt then 
      MoreRVers.Debug("Key.LAlt exists!")
      return "LAlt" 
    end
    MoreRVers.Debug("Testing Key.Left_Alt...")
    if Key.Left_Alt then 
      MoreRVers.Debug("Key.Left_Alt exists!")
      return "Left_Alt" 
    end
    MoreRVers.Debug("No matching Key enum found in direct test")
    return nil
  end)

  if directOk and directVal then
    MoreRVers.Debug("Discovered Key enum value: Key." .. directVal .. " exists for input '" .. keyString .. "'")
    local finalKey = keyMap[directVal]
    if finalKey then
      MoreRVers.Debug("Successfully mapped '" .. keyString .. "' to Key." .. directVal)
      return finalKey, directVal
    else
      MoreRVers.Warn("Key." .. directVal .. " exists but keyMap lookup failed")
    end
  elseif not directOk then
    MoreRVers.Debug("Direct Key enum test failed with error: " .. tostring(directVal))
  end

  MoreRVers.Warn("Invalid key '" .. keyString .. "'; falling back to F5")
  return Key.F5, "F5"
end

-- Export key mapper for hooks
MoreRVers.string_to_key = string_to_key

-- Engine/game info (best-effort)
local function get_engine_info()
  local info = "UE5 (detected)"
  local ok, ver = pcall(function()
    if UE ~= nil and UE.UObject and UE.UObject.GetEngineVersion then
      return UE.UObject.GetEngineVersion()
    end
    return nil
  end)
  if ok and ver then
    info = tostring(ver)
  end
  return info
end

-- Require hook modules with fallbacks that work across common UE4SS layouts
local function require_hook(name)
  -- Try loading relative to current script location using dofile
  if ModPath then
    local hookPath = ModPath .. "hooks\\" .. name .. ".lua"
    local ok, result = pcall(function() return dofile(hookPath) end)
    if ok and result then
      return result
    end
  end
  
  -- Fallback to require with various paths
  local paths = {
    "hooks." .. name,
    "scripts.hooks." .. name,
    "Mods.MoreRVers.scripts.hooks." .. name,
  }
  
  for _, path in ipairs(paths) do
    local ok, result = pcall(function() return require(path) end)
    if ok and result then
      return result
    end
  end
  
  return nil
end

-- Initialization log header
MoreRVers.Log(("MoreRVers v%s loading. Target cap=%d (hard max %d)")
  :format(MoreRVers.Version, MoreRVers.TargetMaxPlayers, MoreRVers.Config.HardUpperLimit))
MoreRVers.Log("Engine: " .. get_engine_info())

-- Load hooks
local game_session = require_hook("game_session")
local join_gate = require_hook("join_gate")
local revive = require_hook("revive")
local throw_distance = require_hook("throw_distance")
local speed_boost = require_hook("speed_boost")
local instant_heal = nil
if MoreRVers.Config.InstantHealEnabled then
  instant_heal = require_hook("instant_heal")
end
local ui_helpers = nil
if MoreRVers.Config.EnableClientUiTweaks then
  ui_helpers = require_hook("ui_helpers")
end

-- Defensive guards
if not game_session then
  MoreRVers.Warn("game_session hook module not found; MaxPlayers may remain vanilla.")
else
  -- Defer hook installation until UE API is ready
  if UE then
    -- Apply MaxPlayers bump as early as possible
    local ok, err = pcall(function()
      game_session.install_hooks(MoreRVers)
      if game_session.get_current_player_count then
        MoreRVers.get_current_player_count = game_session.get_current_player_count
      end
    end)
    if not ok then
      MoreRVers.Error("Failed to install game_session hooks: " .. tostring(err))
    end
  else
    -- UE API not ready - patch GameSession directly when created
    NotifyOnNewObject("/Script/Engine.GameSession", function(obj)
      -- Read original value
      local original = nil
      pcall(function() original = obj.MaxPlayers end)
      
      -- Set new value directly
      local okSet = pcall(function() 
        obj.MaxPlayers = MoreRVers.TargetMaxPlayers 
      end)
      
      if okSet then
        MoreRVers.Log(string.format("Applied MaxPlayers override: %s -> %d",
          tostring(original or "?"), MoreRVers.TargetMaxPlayers))
        
        -- Try to set on CDO too
        pcall(function()
          local cdo = obj:GetClass():GetDefaultObject()
          if cdo then
            cdo.MaxPlayers = MoreRVers.TargetMaxPlayers
          end
        end)
      else
        MoreRVers.Warn("Failed to set MaxPlayers on GameSession")
      end
    end)
  end
end

if join_gate then
  local ok, err = pcall(function()
    join_gate.install_hooks(MoreRVers)
  end)
  if not ok then
    MoreRVers.Error("Failed to install join_gate hooks: " .. tostring(err))
  end
end

if revive then
  local ok, err = pcall(function()
    revive.install_hooks(MoreRVers)
  end)
  if not ok then
    MoreRVers.Warn("Revive hook failed to load (non-fatal): " .. tostring(err))
  end
end

if throw_distance then
  local ok, err = pcall(function()
    throw_distance.install_hooks(MoreRVers)
  end)
  if not ok then
    MoreRVers.Warn("Throw distance hook failed to load (non-fatal): " .. tostring(err))
  end
end

if speed_boost then
  local ok, err = pcall(function()
    speed_boost.install_hooks(MoreRVers)
  end)
  if not ok then
    MoreRVers.Warn("Speed boost hook failed to load (non-fatal): " .. tostring(err))
  end
end

if instant_heal then
  local ok, err = pcall(function()
    instant_heal.install_hooks(MoreRVers)
  end)
  if not ok then
    MoreRVers.Warn("Instant heal hook failed to load (non-fatal): " .. tostring(err))
  end
end

if ui_helpers then
  local ok, err = pcall(function()
    ui_helpers.install_hooks(MoreRVers)
  end)
  if not ok then
    MoreRVers.Warn("UI helpers failed to load (non-fatal): " .. tostring(err))
  end
else
  if MoreRVers.Config.EnableClientUiTweaks then
    MoreRVers.Warn("UI helpers module not found; continuing without client tweaks.")
  end
end

-- Export for other scripts
return MoreRVers
