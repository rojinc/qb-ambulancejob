# qb-ambulancejob
EMS Job and Death/Wound Logic for QB-Core Framework with Kockdown Feature :ambulance:

## Features

### Knockdown State
The ambulance job now includes a knockdown system that provides an intermediate state between full health and critical bleeding:

- **Knockdown Mechanics**: When players take damage, they enter a knockdown state instead of immediately going to laststand/bleeding
- **Duration**: Players remain knocked down for a configurable duration (default: 40 seconds) before transitioning to bleeding state
- **Animations**: Supports different animations based on player location (ground or vehicle)
- **Revival**: EMS can revive knocked down players using a skillbar minigame without requiring a full revive
- **Damage During Knockdown**: Taking any damage while knocked down immediately transitions the player to bleeding state
- **State Management**: Players are disarmed during knockdown and stay immobilized with appropriate animations

### Demo Video

[![Knockdown Feature Demo](https://img.shields.io/badge/▶️%20PLAY-Demo%20Video-blue?style=for-the-badge&logoColor=white)](https://r2.fivemanage.com/mCsNNhSbyC8uNtlPhbsr0/2025-10-3118-26-58.mp4)

### Configuration
The knockdown feature can be configured in `config.lua`:
- `Config.KnockdownTime` - Duration of knockdown state in seconds (default: 40)
- `Config.ReviveInterval` - Timer for reviving players in laststand (default: 360 seconds)
- `Config.MinimumRevive` - Minimum time for laststand revive (default: 300 seconds)

## Dependencies
- [qb-core](https://github.com/qbcore-framework/qb-core) (Required)
- [qb-phone](https://github.com/qbcore-framework/qb-phone) (Required)
- [qb-target](https://github.com/BerkieBb/qb-target) (Optional)
- [PolyZone](https://github.com/mkafrin/PolyZone) (Required)
- [qb-minigames](https://github.com/qbcore-framework/qb-minigames) (Required for knockdown revive skillbar)

# Server.cfg Convar Update
- Global DrawTextUi Option
```
setr UseTarget false
``` 

- Global Target Option
```
setr UseTarget true
```


# License

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
