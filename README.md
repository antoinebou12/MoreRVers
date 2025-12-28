# MoreRVers - Multiplayer Expansion Mod for RV There Yet?

![Version](https://img.shields.io/badge/version-1.0.1-blue)
![Game](https://img.shields.io/badge/game-RV%20There%20Yet%3F-orange)
![Modloader](https://img.shields.io/badge/modloader-UE4SS-purple)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)

A runtime mod that increases the multiplayer player cap beyond the default 4-player limit for RV There Yet, with additional features including configurable revive, enhanced throw distance, and speed boost.

**Only the host needs to install the mod.**

## Overview

This mod patches the game's multiplayer cap at runtime, allowing you to host sessions with more than the default 4 players. The modification uses UE4SS for runtime patching without requiring binary editing or permanent game file changes.

## Features

- **Simple Configuration** - INI file configuration for all features
- **Console Commands** - Comprehensive runtime control via UE4SS console (no restart required)
- **Host-Only Requirement** - Clients do not require mod installation
- **Non-Destructive** - No permanent game file modifications
- **Flexible Limits** - Configurable player count from 1-24
- **Runtime Patching** - Applied immediately upon session creation
- **Global/Individual Modes** - Choose between host-controlled (Global) or per-player (Individual) feature control
- **Revive System** - Configurable keybind to revive/respawn players (enabled by default)
- **Instant Heal** - Automatically restore health to full when it drops below a threshold (enabled by default)
- **Enhanced Throw Distance** - Configurable multiplier for player throw distance on damage/death
- **Speed Boost** - Configurable movement speed multiplier with optional toggle keybind (enabled by default)
- **Vehicle Speed Boost** - Configurable vehicle speed multiplier with optional toggle keybind
- **Fall Damage Removal** - Option to disable fall damage for all players
- **Gear Hotkeys** - Arcade-style gear shifting with hotkeys for direct gear selection or sequential shifting
- **Control Menu** - In-game menu (F7) for runtime control of all features without console access

## Installation

Two installation packages are available with each release. **The With-UE4SS package is recommended for most users.**

### Option 1: With-UE4SS (Recommended - Easy Install)

**File:** `MoreRVers-vX.Y.Z-WithUE4SS.zip`

This package includes UE4SS experimental and MoreRVers pre-configured. Just extract and play!

1. Download `MoreRVers-vX.Y.Z-WithUE4SS.zip` from the latest release
2. Navigate to your game directory:
   ```
   <Steam>\steamapps\common\Ride\Ride\Binaries\Win64\
   ```
3. Extract **all files** from the zip directly into the `Win64` folder
4. (Optional) Configure settings by editing `ue4ss\Mods\MoreRVers\config.ini`:
   ```ini
   MaxPlayers = 8
   
   [Revive]
   ReviveEnabled = 1
   ReviveKeybind = F6
   
   [Throw]
   ThrowDistanceMultiplier = 2.0
   
   [Speed]
   SpeedBoostEnabled = 1
   SpeedMultiplier = 2.0
   SpeedKeybind = F5
   
   [InstantHeal]
   InstantHealEnabled = 1
   InstantHealThreshold = 0.10
   ```
5. Launch the game and host a session

**That's it!** The mod is pre-enabled!

### Option 2: Mod-Only (Advanced Users)

**File:** `MoreRVers-vX.Y.Z-ModOnly.zip`

Use this if you already have UE4SS experimental installed and configured.

**Requirements:**
- [UE4SS experimental branch](https://github.com/UE4SS-RE/RE-UE4SS/releases) (3.0.1+)
- RV There Yet? (Steam version)

**Installation:**

1. Download `MoreRVers-vX.Y.Z-ModOnly.zip` from the latest release
2. Extract the `MoreRVers` folder to:
   ```
   <Steam>\steamapps\common\Ride\Ride\Binaries\Win64\ue4ss\Mods\
   ```
3. Enable the mod by editing `ue4ss\Mods\mods.txt`:
   ```
   MoreRVers : 1
   ```
   Note: Add this line before `Keybinds : 1`
4. Configure settings in `ue4ss\Mods\MoreRVers\config.ini`:
   ```ini
   MaxPlayers = 8
   ReviveEnabled = 1
   ReviveKeybind = F5
   ThrowDistanceMultiplier = 2.0
   SpeedBoostEnabled = 1
   SpeedMultiplier = 2.0
   SpeedKeybind = LeftShift
   ```
5. Launch the game and host a session

## File Tree
When properly installed, your game directory should look similar to this:
```
{Steam}\steamapps\common\Ride\
├── Ride\
│   └── Binaries\
│       └── Win64\
│           ├── Ride-Win64-Shipping.exe         
│           ├── dwmapi.dll                       
│           │
│           └── ue4ss\                          
│               ├── UE4SS.dll                  
│               ├── UE4SS-settings.ini         
│               │
│               └── Mods\
│                   ├── mods.txt                 
│                   │
│                   └── MoreRVers\               
│                       ├── mod.json             
│                       ├── config.ini           
│                       │
│                       └── scripts\
```

## Configuration

Edit `UE4SS/Mods/MoreRVers/config.ini`:

```ini
MaxPlayers = 8

[Mode]
ControlMode = Global

[Revive]
ReviveEnabled = 1
ReviveKeybind = F6

[Throw]
ThrowDistanceMultiplier = 2.0

[Speed]
SpeedBoostEnabled = 1
SpeedMultiplier = 2.0
SpeedKeybind = F5

[InstantHeal]
InstantHealEnabled = 1
InstantHealThreshold = 0.10
```

**Configuration Parameters:**

### Mode Settings
- **ControlMode**: Control how features are applied in multiplayer
  - `Global` (default): Host controls ALL players' features
    - When host presses F5, ALL players get speed boost
    - When host presses F6, ALL players get revived
    - Instant heal applies to ALL players globally
    - Only the host's keybinds affect all players
  - `Individual`: Each player controls their own features independently
    - Each player can toggle their own speed, revive themselves
    - Instant heal only affects the player who enabled it
    - Works in single player or when each player controls themselves

### MaxPlayers
- Default: 8 (vanilla game limit is 4)
- Range: 1-24
- Recommended: 8 for optimal stability

### Revive Settings
- **ReviveEnabled**: Enable/disable revive feature (1 = enabled by default, 0 = disabled)
- **ReviveKeybind**: Keybind for revive (F6, R, F5, etc. - any valid UE4SS key)
  - **Global mode**: Host's keybind revives ALL players
  - **Individual mode**: Each player revives themselves

### Throw Distance Settings
- **ThrowDistanceMultiplier**: Multiplier for throw distance when players take damage/die
  - 1.0 = normal distance
  - 2.0 = double distance (default)
  - Range: 0.1 - 10.0

### Speed Boost Settings
- **SpeedBoostEnabled**: Enable/disable speed boost feature (1 = enabled by default, 0 = disabled)
- **SpeedMultiplier**: Multiplier for player movement speed
  - 1.0 = normal speed
  - 2.0 = double speed (default)
  - 1.5 = 50% faster (recommended for subtle boost)
  - Range: 0.5 - 5.0
- **SpeedKeybind**: Keybind for speed boost toggle (hold to activate)
  - Leave empty for persistent boost (always active)
  - Valid keys: F1-F12, etc.
  - Example: `SpeedKeybind = F5` (hold F5 to run faster)
  - **Global mode**: Host's keybind controls ALL players' speed
  - **Individual mode**: Each player controls their own speed

### Instant Heal Settings
- **InstantHealEnabled**: Enable/disable instant heal feature (1 = enabled by default, 0 = disabled)
- **InstantHealThreshold**: Health threshold percentage below which player is automatically healed to full
  - 0.10 = 10% (default) - heal when health drops below 10%
  - 0.25 = 25% - heal when health drops below 25%
  - 0.05 = 5% - heal when health drops below 5% (more aggressive)
  - Range: 0.01 - 0.99
  - **Note**: This prevents death by healing before health reaches 0%
  - When health drops below this percentage, player is instantly restored to full health
  - **Global mode**: Host's settings apply to ALL players
  - **Individual mode**: Each player's heal works independently

### Vehicle Speed Settings
- **VehicleSpeedEnabled**: Enable/disable vehicle speed boost (1 = enabled by default, 0 = disabled)
- **VehicleSpeedMultiplier**: Multiplier for vehicle speed
  - 1.0 = normal speed
  - 2.0 = double speed (default)
  - Range: 0.5 - 100.0
- **VehicleKeybind**: Keybind for vehicle speed toggle (hold to activate)
  - Leave empty for persistent boost (always active)
  - Valid keys: F1-F12, etc.
  - Example: `VehicleKeybind = F8` (hold F8 for faster vehicles)
  - **Global mode**: Host's keybind controls ALL vehicles
  - **Individual mode**: Each player controls their own vehicle speed

### Fall Damage Settings
- **FallDamageEnabled**: Enable/disable fall damage removal (1 = enabled by default, 0 = disabled)
  - When enabled, players will not take damage from falling/landing
  - Works in both Global and Individual modes

### Gear Hotkeys Settings
- **GearHotkeysEnabled**: Enable/disable gear hotkeys feature (1 = enabled by default, 0 = disabled)
- **SequentialLinking**: Arcade mode for sequential gear shifting (1 = enabled by default, 0 = disabled)
  - When enabled: Use arrow keys (up/down) to shift through gears sequentially
  - When disabled: Use numpad keys for direct gear selection
- **Gear Keys**: Direct gear selection keybinds (when SequentialLinking = 0)
  - **Gear1Key** through **Gear5Key**: Numpad keys (NUM_ONE, NUM_TWO, etc.)
  - **ReverseKey**: Reverse gear keybind (default: NUM_ZERO)
  - **NeutralKey**: Neutral gear keybind (default: NUM_SIX)
- **Sequential Shift Keys**: Used when SequentialLinking = 1
  - **ShiftUpKey**: Shift to higher gear (default: UP_ARROW)
  - **ShiftDownKey**: Shift to lower gear (default: DOWN_ARROW)
- **Note**: Gear hotkeys work independently of vehicle speed settings

### Menu Settings
- **MenuKeybind**: Keybind to open the in-game control menu (default: F7)
  - Press this key to open the console-based menu for runtime feature control
  - When menu is open, press F10 to toggle ControlMode (Global/Individual)

The game must be restarted for configuration changes to take effect.

## Console Commands

MoreRVers provides comprehensive console commands for runtime control of all features. These commands take effect immediately without requiring a game restart.

**Alternative to Console Commands**: You can also use the in-game control menu (press F7) to toggle features and adjust multipliers without typing commands. See the [Menu Settings](#menu-settings) section for more information.

### Opening the Console

Open the UE4SS console (usually with `~` or `` ` `` key, or check your UE4SS settings).

### Command Categories

#### Speed Boost Commands
- `MoreRVers.SetSpeed <value>` - Set speed multiplier (range: 0.5-100)
  - Example: `MoreRVers.SetSpeed 50`
- `MoreRVers.GetSpeed` - Display current speed boost settings
- `MoreRVers.ToggleSpeed` - Toggle speed boost on/off

#### Vehicle Speed Commands
- `MoreRVers.SetVehicle <value>` - Set vehicle speed multiplier (range: 0.5-100)
  - Example: `MoreRVers.SetVehicle 20`
- `MoreRVers.GetVehicle` - Display current vehicle speed settings
- `MoreRVers.ToggleVehicle` - Toggle vehicle speed boost on/off

#### Fall Damage Commands
- `MoreRVers.SetFallDamage <0|1>` - Enable/disable fall damage removal
  - `0` = disabled (normal fall damage), `1` = enabled (no fall damage)
  - Also accepts: `true`/`false`, `on`/`off`, `yes`/`no`, `enabled`/`disabled`
  - Example: `MoreRVers.SetFallDamage 1`
- `MoreRVers.GetFallDamage` - Display fall damage removal status
- `MoreRVers.ToggleFallDamage` - Toggle fall damage removal

#### Revive Commands
- `MoreRVers.SetRevive <0|1>` - Enable/disable revive feature
  - `0` = disabled, `1` = enabled
  - Also accepts: `true`/`false`, `on`/`off`, `yes`/`no`, `enabled`/`disabled`
  - Example: `MoreRVers.SetRevive 1`
- `MoreRVers.GetRevive` - Display revive feature status (includes keybind)
- `MoreRVers.ToggleRevive` - Toggle revive feature

#### Throw Distance Commands
- `MoreRVers.SetThrow <value>` - Set throw distance multiplier (range: 0.1-10.0)
  - Example: `MoreRVers.SetThrow 2.5`
- `MoreRVers.GetThrow` - Display current throw distance settings
- `MoreRVers.ToggleThrow` - Toggle between 1.0x (normal) and 2.0x (double)

#### Instant Heal Commands
- `MoreRVers.SetHeal <0|1>` - Enable/disable instant heal
  - `0` = disabled, `1` = enabled
  - Also accepts: `true`/`false`, `on`/`off`, `yes`/`no`, `enabled`/`disabled`
  - Example: `MoreRVers.SetHeal 1`
- `MoreRVers.SetHealThreshold <value>` - Set health threshold for auto-heal (range: 0.01-0.99)
  - `0.10` = 10% health, `0.25` = 25% health, etc.
  - Example: `MoreRVers.SetHealThreshold 0.15` (heal at 15% health)
- `MoreRVers.GetHeal` - Display instant heal settings (enabled status and threshold)
- `MoreRVers.GetHealThreshold` - Display current heal threshold
- `MoreRVers.ToggleHeal` - Toggle instant heal on/off

#### Utility Commands
- `MoreRVers.ToggleMode` - Toggle between Global and Individual control modes
- `MoreRVers.Enable <feature>` - Enable a feature by name
  - Valid features: `speed`, `vehicle`, `heal`, `throw`, `falldamage`, `revive`
  - Example: `MoreRVers.Enable speed`
- `MoreRVers.Disable <feature>` - Disable a feature by name
  - Valid features: `speed`, `vehicle`, `heal`, `throw`, `falldamage`, `revive`
  - Example: `MoreRVers.Disable falldamage`
- `MoreRVers.Status` - Display all current settings at once
- `MoreRVers.Help` - Show complete command list with usage examples

### Usage Examples

```
MoreRVers.SetSpeed 50              # Set speed multiplier to 50x
MoreRVers.SetVehicle 10            # Set vehicle multiplier to 10x
MoreRVers.SetFallDamage 1          # Enable fall damage removal
MoreRVers.SetRevive true           # Enable revive feature
MoreRVers.SetThrow 2.5             # Set throw distance to 2.5x
MoreRVers.SetHealThreshold 0.15    # Heal when health drops below 15%
MoreRVers.ToggleSpeed              # Toggle speed boost
MoreRVers.Status                   # Show all current settings
MoreRVers.Help                     # Show command list
```

### Boolean Value Formats

Commands that accept boolean values (enable/disable) accept multiple formats:
- Numeric: `0` (disabled) or `1` (enabled)
- Text: `true`/`false`, `on`/`off`, `yes`/`no`, `enabled`/`disabled`
- Case-insensitive

### Command Behavior

- All commands take effect **immediately** without restarting the game
- Commands validate input ranges and provide helpful error messages
- Settings changed via console commands persist for the current game session
- Console command changes do not modify the `config.ini` file (config file changes require game restart)

## Verification

Successful installation can be verified by checking the UE4SS console for the following messages:

```
[MoreRVers] [INFO] MoreRVers v1.0.0 loading. Target cap=8 (hard max 24)
[MoreRVers] [INFO] Applied MaxPlayers override: 4 → 8
[MoreRVers] [INFO] Revive keybind registered: F6
[MoreRVers] [INFO] Throw distance multiplier: 2.00
[MoreRVers] [INFO] Speed boost multiplier: 2.00
[MoreRVers] [INFO] Speed boost toggle keybind registered: F5 (hold to activate)
[MoreRVers] [INFO] Instant heal enabled: threshold = 10.0%
```

## Troubleshooting

### Mod fails to load

- Check UE4SS console for error messages
- Verify UE4SS 3.0.1 or higher is installed
- Confirm file structure matches the documented structure
- Ensure mod is enabled in `mods.txt`

### Player limit remains at 4

- Check console for "Applied MaxPlayers override" confirmation message
- Test with `MaxPlayers = 1` to verify mod functionality
- Review `UE4SS-settings.ini` to ensure Lua scripting is enabled

### Game crashes or instability

- Reduce the configured player count
- Reduce ThrowDistanceMultiplier if experiencing physics issues
- Verify UE4SS version compatibility
- Report issues with complete console logs

### Revive not working

- Check that `ReviveEnabled = 1` in config.ini
- Verify the keybind is not conflicting with game controls
- Check console for "Revive keybind registered" message
- Ensure you're in a game session (not main menu)

### Throw distance not working

- Verify `ThrowDistanceMultiplier > 1.0` in config.ini
- Check console for "Throw distance multiplier" message
- Ensure the multiplier is within valid range (0.1 - 10.0)

### Speed boost not working

- Check that `SpeedBoostEnabled = 1` in config.ini
- Verify `SpeedMultiplier` is within valid range (0.5 - 5.0)
- If using toggle mode, check that `SpeedKeybind` is set correctly
- Check console for "Speed boost multiplier" message
- Ensure you're in a game session with a valid pawn
- Try setting `SpeedKeybind = ` (empty) for persistent boost mode
- High multipliers (3.0+) may cause physics issues or break level logic

### Instant heal not working

- Check that `InstantHealEnabled = 1` in config.ini
- Verify `InstantHealThreshold` is within valid range (0.01 - 0.99)
- Check console for "Instant heal enabled" message
- Ensure you're in a game session (not main menu)
- The feature only affects the local player (server-safe)
- Health component may not be accessible in all game states - check console for debug messages

## Contributing

Bug reports and feature suggestions can be submitted via GitHub Issues. Pull requests are welcome.

## License

MIT License. See LICENSE file for details.

## Credits

- **UE4SS Team** - Unreal Engine modding framework
- **RV There Yet? Community** - Testing and feedback
