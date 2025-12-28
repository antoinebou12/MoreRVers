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
- **Host-Only Requirement** - Clients do not require mod installation
- **Non-Destructive** - No permanent game file modifications
- **Flexible Limits** - Configurable player count from 1-24
- **Runtime Patching** - Applied immediately upon session creation
- **Revive System** - Configurable keybind to revive/respawn players
- **Instant Heal** - Automatically restore health to full when it drops below a threshold
- **Enhanced Throw Distance** - Configurable multiplier for player throw distance on damage/death
- **Speed Boost** - Configurable movement speed multiplier with optional toggle keybind

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

### MaxPlayers
- Default: 8 (vanilla game limit is 4)
- Range: 1-24
- Recommended: 8 for optimal stability

### Revive Settings
- **ReviveEnabled**: Enable/disable revive feature (1 = enabled, 0 = disabled)
- **ReviveKeybind**: Keybind for revive (F6, R, F5, etc. - any valid UE4SS key)

### Throw Distance Settings
- **ThrowDistanceMultiplier**: Multiplier for throw distance when players take damage/die
  - 1.0 = normal distance
  - 2.0 = double distance (default)
  - Range: 0.1 - 10.0

### Speed Boost Settings
- **SpeedBoostEnabled**: Enable/disable speed boost feature (1 = enabled, 0 = disabled)
- **SpeedMultiplier**: Multiplier for player movement speed
  - 1.0 = normal speed
  - 2.0 = double speed (default)
  - 1.5 = 50% faster (recommended for subtle boost)
  - Range: 0.5 - 5.0
- **SpeedKeybind**: Keybind for speed boost toggle (hold to activate)
  - Leave empty for persistent boost (always active)
  - Valid keys: F1-F12, etc.
  - Example: `SpeedKeybind = F5` (hold F5 to run faster)

### Instant Heal Settings
- **InstantHealEnabled**: Enable/disable instant heal feature (1 = enabled, 0 = disabled)
- **InstantHealThreshold**: Health threshold percentage below which player is automatically healed to full
  - 0.10 = 10% (default) - heal when health drops below 10%
  - 0.25 = 25% - heal when health drops below 25%
  - 0.05 = 5% - heal when health drops below 5% (more aggressive)
  - Range: 0.01 - 0.99
  - **Note**: This prevents death by healing before health reaches 0%
  - When health drops below this percentage, player is instantly restored to full health
  - Only affects local player (server-safe)

The game must be restarted for configuration changes to take effect.

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
