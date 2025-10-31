<h1 align="center">
  QBCore Ambulance Job
  <br>
</h1>

[![Watch Demo](https://r2.fivemanage.com/mCsNNhSbyC8uNtlPhbsr0/2025-10-3118-26-58.mp4)](https://r2.fivemanage.com/mCsNNhSbyC8uNtlPhbsr0/2025-10-3118-26-58.mp4)

<h4 align="center">EMS Job and Death/Wound Logic for QBCore Framework with Knockdown Feature</h4>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#knockdown-system">Knockdown System</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#dependencies">Dependencies</a> •
  <a href="#setup">Setup</a> •
  <a href="#license">License</a>
</p>

---

## Features

### Knockdown System

The ambulance job now includes a complete knockdown system that provides an intermediate state between full health and critical bleeding:

- **Knockdown Mechanics**: When players take damage, they enter a knockdown state instead of immediately going to laststand/bleeding
- **Duration**: Players remain knocked down for a configurable duration (default: 40 seconds) before transitioning to bleeding state
- **Animations**: Supports different animations based on player location (ground or vehicle)
- **Revival**: EMS can revive knocked down players using a skillbar minigame without requiring a full revive
- **Damage During Knockdown**: Taking any damage while knocked down immediately transitions the player to bleeding state
- **State Management**: Players are disarmed during knockdown and stay immobilized with appropriate animations

### Configuration

The knockdown feature can be configured in `config.lua`:

```lua
Config.KnockdownTime = 40       -- How long the knockdown state lasts before going to bleeding state
Config.ReviveInterval = 360     -- How long the timer is for players to revive a player in laststand
Config.MinimumRevive = 300      -- How long the timer is for players to revive a player in laststand
```

## Dependencies

- [qb-core](https://github.com/qbcore-framework/qb-core) (Required)
- [qb-phone](https://github.com/qbcore-framework/qb-phone) (Required)
- [qb-target](https://github.com/BerkieBb/qb-target) (Optional)
- [PolyZone](https://github.com/mkafrin/PolyZone) (Required)
- [qb-minigames](https://github.com/qbcore-framework/qb-minigames) (Required for knockdown revive skillbar)

## Setup

### Server Configuration

Add the following to your `server.cfg` to configure the target system:

```
# Global DrawTextUi Option (Default)
setr UseTarget false

# Alternative: Global Target Option (qb-target)
setr UseTarget true
```

### Installation

1. Download and extract the resource into your `resources` folder
2. Ensure it's started in your `server.cfg`:
   ```
   ensure qb-ambulancejob
   ```
3. Restart your server

---

## License

    QBCore Framework
    Copyright (C) 2021 Joshua Eger

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>
