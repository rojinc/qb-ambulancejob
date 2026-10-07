# NUI Development Guide

> HTML/CSS/JavaScript UI for FiveM resources

## Setup

### fxmanifest.lua
```lua
fx_version 'cerulean'
game 'gta5'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*.png'
}

client_script 'client/main.lua'
```

### Basic HTML Structure
```html
<!-- html/index.html -->
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div id="app" style="display: none;">
        <!-- Your UI here -->
    </div>
    <script src="script.js"></script>
</body>
</html>
```

---

## Lua → NUI Communication

### SendNUIMessage
```lua
-- Client Lua
SendNUIMessage({
    action = 'openMenu',
    data = {
        title = 'Main Menu',
        items = {
            { id = 1, label = 'Option 1' },
            { id = 2, label = 'Option 2' }
        }
    }
})
```

### Receiving in JavaScript
```javascript
// html/script.js
window.addEventListener('message', function(event) {
    const data = event.data;

    switch(data.action) {
        case 'openMenu':
            document.getElementById('app').style.display = 'block';
            renderMenu(data.data);
            break;
        case 'closeMenu':
            document.getElementById('app').style.display = 'none';
            break;
    }
});

function renderMenu(menuData) {
    const container = document.getElementById('menu-items');
    container.innerHTML = '';

    menuData.items.forEach(item => {
        const el = document.createElement('div');
        el.className = 'menu-item';
        el.textContent = item.label;
        el.onclick = () => selectItem(item.id);
        container.appendChild(el);
    });
}
```

---

## NUI → Lua Communication

### JavaScript Fetch
```javascript
// Send data to Lua
async function selectItem(itemId) {
    const response = await fetch(`https://${GetParentResourceName()}/selectItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ itemId: itemId })
    });

    const result = await response.json();
    console.log('Lua returned:', result);
}

function closeMenu() {
    fetch(`https://${GetParentResourceName()}/closeMenu`, {
        method: 'POST',
        body: JSON.stringify({})
    });
}
```

### Lua Callback
```lua
-- Client Lua
RegisterNUICallback('selectItem', function(data, cb)
    print('Selected item:', data.itemId)

    -- Do something with selection
    TriggerServerEvent('myresource:itemSelected', data.itemId)

    -- Return response to NUI
    cb({ success = true, message = 'Item selected' })
end)

RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)
```

---

## NUI Focus

```lua
-- Enable NUI focus (mouse + keyboard captured)
SetNuiFocus(true, true)

-- Enable mouse only (keyboard still works for game)
SetNuiFocus(true, false)

-- Disable NUI focus
SetNuiFocus(false, false)

-- Check if NUI has focus
if IsNuiFocused() then
    -- NUI is active
end

-- Keep input for game (movement, etc.)
SetNuiFocusKeepInput(true)
```

---

## ESC Key Handling

```javascript
// JavaScript - Handle ESC to close
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeMenu();
    }
});
```

```lua
-- Lua - Alternative with keybind
CreateThread(function()
    while menuOpen do
        if IsControlJustPressed(0, 322) then  -- ESC
            closeMenu()
        end
        Wait(0)
    end
end)
```

---

## CSS Best Practices

```css
/* html/style.css */

/* Reset and base */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
    font-family: 'Segoe UI', Arial, sans-serif;
}

body {
    background: transparent;
    overflow: hidden;
    user-select: none;
}

/* Main container */
#app {
    position: absolute;
    width: 100vw;
    height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
}

/* Menu panel */
.menu-panel {
    background: rgba(0, 0, 0, 0.85);
    border-radius: 8px;
    padding: 20px;
    min-width: 300px;
    backdrop-filter: blur(10px);
    border: 1px solid rgba(255, 255, 255, 0.1);
}

/* Menu items */
.menu-item {
    padding: 12px 16px;
    margin: 4px 0;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s ease;
    color: white;
}

.menu-item:hover {
    background: rgba(255, 255, 255, 0.15);
    transform: translateX(4px);
}

/* Animations */
@keyframes fadeIn {
    from { opacity: 0; transform: scale(0.95); }
    to { opacity: 1; transform: scale(1); }
}

.menu-panel {
    animation: fadeIn 0.2s ease;
}
```

---

## TypeScript Setup

### package.json
```json
{
    "scripts": {
        "build": "tsc && npm run copy",
        "watch": "tsc -w"
    },
    "devDependencies": {
        "typescript": "^5.0.0"
    }
}
```

### tsconfig.json
```json
{
    "compilerOptions": {
        "target": "ES2020",
        "module": "ESNext",
        "outDir": "./html",
        "rootDir": "./src",
        "strict": true,
        "esModuleInterop": true
    },
    "include": ["src/**/*"]
}
```

### TypeScript Example
```typescript
// src/main.ts
interface MenuItem {
    id: number;
    label: string;
    icon?: string;
}

interface MenuMessage {
    action: 'openMenu' | 'closeMenu';
    data?: {
        title: string;
        items: MenuItem[];
    };
}

declare function GetParentResourceName(): string;

window.addEventListener('message', (event: MessageEvent<MenuMessage>) => {
    const { action, data } = event.data;

    if (action === 'openMenu' && data) {
        showMenu(data.items);
    }
});

async function postNUI<T>(endpoint: string, data: object): Promise<T> {
    const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
    return response.json();
}
```

---

## React/Vue Integration

### React Setup (Vite)
```bash
npm create vite@latest html -- --template react-ts
cd html
npm install
```

```tsx
// src/App.tsx
import { useEffect, useState } from 'react';
import { useNuiEvent } from './hooks/useNuiEvent';

function App() {
    const [visible, setVisible] = useState(false);
    const [items, setItems] = useState([]);

    useNuiEvent('openMenu', (data) => {
        setItems(data.items);
        setVisible(true);
    });

    useNuiEvent('closeMenu', () => setVisible(false));

    if (!visible) return null;

    return (
        <div className="menu">
            {items.map(item => (
                <button key={item.id} onClick={() => selectItem(item.id)}>
                    {item.label}
                </button>
            ))}
        </div>
    );
}
```

### Custom Hook
```tsx
// src/hooks/useNuiEvent.ts
import { useEffect, useRef } from 'react';

export function useNuiEvent<T>(action: string, handler: (data: T) => void) {
    const savedHandler = useRef(handler);

    useEffect(() => {
        savedHandler.current = handler;
    }, [handler]);

    useEffect(() => {
        const listener = (event: MessageEvent) => {
            if (event.data.action === action) {
                savedHandler.current(event.data.data);
            }
        };

        window.addEventListener('message', listener);
        return () => window.removeEventListener('message', listener);
    }, [action]);
}
```

---

## Debug Mode

```lua
-- Open NUI in browser for development
RegisterCommand('openui', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openMenu', data = testData })
end)
```

```javascript
// Mock GetParentResourceName for browser testing
if (!window.GetParentResourceName) {
    window.GetParentResourceName = () => 'myresource';
}

// Mock fetch responses
if (window.location.protocol !== 'nui:') {
    window.fetch = async (url, options) => {
        console.log('Mock fetch:', url, JSON.parse(options.body));
        return { json: async () => ({ success: true }) };
    };
}
```
