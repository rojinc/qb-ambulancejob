# FiveM Development Plugin

A comprehensive plugin for FiveM resource development. Provides framework support and best practices for QBox, QBCore, and ESX frameworks.

**Supports:** Claude Code, Cursor, Windsurf, and other AI coding assistants.

## Features

- **Dynamic Documentation Fetching** - Fetches up-to-date natives and framework docs via WebFetch
- **Multi-Framework Support** - QBox, QBCore, ESX with auto-detection
- **Language Support** - Lua scripting + NUI (JavaScript/TypeScript)
- **Asset Discovery** - PlebMasters Forge integration for props, vehicles, peds
- **Best Practices** - Performance, security, and code organization patterns

## Installation

### Claude Code (NPM)

```bash
npm install -g claude-fivem-dev
```

### Claude Code (Git)

```bash
git clone https://github.com/melihbozkurt10/fivem-dev-plugin.git ~/.claude/skills/fivem-dev
```

### Cursor / Windsurf

1. Download `.cursorrules` or `FIVEM_CURSOR_RULES.md` from this repo
2. Copy to your FiveM project root as `.cursorrules`

```bash
# Or use curl
curl -o .cursorrules https://raw.githubusercontent.com/melihbozkurt10/fivem-dev-plugin/main/.cursorrules
```

### Manual

1. Download/clone this repository
2. Copy to `~/.claude/skills/fivem-dev/`
3. Restart your AI assistant

## Usage

### Automatic (Skill)

The skill activates automatically when you ask FiveM-related questions:

- "How do I use GetPlayerPed?"
- "QBCore'da player money nasıl alınır?"
- "Create a vehicle spawn script"
- "What's the prop name for laptop?"

### Command

Use the `/fivem-dev` command for direct queries:

```
/fivem-dev How to create a callback in QBCore?
/fivem-dev ox_lib progress bar example
/fivem-dev ESX xPlayer methods
```

## Documentation Sources

| Source | URL | Usage |
|--------|-----|-------|
| FiveM Natives | https://docs.fivem.net/natives/ | Native functions |
| QBox | https://docs.qbox.re/ | QBox framework |
| QBCore | https://docs.qbcore.org/ | QBCore framework |
| ESX | https://docs.esx-framework.org/ | ESX framework |
| ox_lib | https://overextended.dev/ox_lib | Utility library |
| PlebMasters | https://forge.plebmasters.de/ | GTA V assets |

## Skill Files

| File | Description |
|------|-------------|
| `SKILL.md` | Main orchestrator with decision tree |
| `frameworks/` | QBox, QBCore, ESX references |
| `scripting/` | Lua patterns, NUI guide, client-server architecture |
| `resources/` | fxmanifest.lua, ox_lib guide |
| `assets/` | Asset discovery guide |

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License - Feel free to use and modify.

## Credits

- FiveM Documentation: https://docs.fivem.net/
- QBox Project: https://github.com/qbox-project
- QBCore Framework: https://github.com/qbcore-framework
- ESX Framework: https://github.com/esx-framework
- Overextended (ox_lib): https://github.com/overextended
- PlebMasters: https://forge.plebmasters.de/
