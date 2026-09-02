# Sterix Police — Bridge Usage Guide

The bridge is what lets the rest of the script stay framework-agnostic. Instead of calling
`qbx_core` / `qb-core` / `es_extended` / `ox_inventory` / `ox_target` directly anywhere in
`client/` or `server/`, you call `Bridge.*`. Whichever framework is actually running fills in
those functions automatically — the rest of your code never has to check which one it is.

> Callbacks are **not** wrapped by the bridge. Use ox_lib's `lib.callback` /
> `lib.callback.register` directly — see the [Callbacks](#callbacks-ox_lib-direct) section.

## How it loads

```
bridge/
├── client.lua        -- framework-agnostic: notify, progress, input, context menu, target
├── server.lua         -- framework-agnostic: notify
├── qbx/{client,server}.lua   -- qbx_core + ox_inventory
├── qb/{client,server}.lua    -- qb-core + built-in Player.Functions items
└── esx/{client,server}.lua   -- es_extended + ox_inventory
```

Every file in `bridge/qbx`, `bridge/qb`, `bridge/esx` starts with a guard:

```lua
if GetResourceState('qbx_core') ~= 'started' then return end
```

All three load every time (see `fxmanifest.lua`), but only the one matching your actual
framework fills in the global `Bridge` table. You can check which one is active with:

```lua
print(Bridge.Framework) -- 'qbx' | 'qb' | 'esx'
```

---

## Client API (`Bridge.*` in any `client/` file)

### Player / Job

```lua
local playerData = Bridge.GetPlayerData()
local job = Bridge.GetJob() -- { name, label, grade, grade_label, onduty, ... }
local loaded = Bridge.IsPlayerLoaded()
```

### Notify

```lua
Bridge.Notify('You clocked in.', 'success', 5000, 'Sterix PD')
-- Bridge.Notify(text, type, duration, title)
-- type: 'inform' | 'success' | 'error' | 'warning'
```

### Progress bar

```lua
local finished = Bridge.Progress('Checking ID...', 3000, {
    canCancel = true,
    useWhileDead = false,
    disable = { move = true, car = true },
    anim = { dict = 'mp_common', clip = 'givetake1_a' },
})

if finished then
    -- player completed the progress without cancelling
end
```

### Target

```lua
-- Box zone
local zoneId = Bridge.AddBoxZone('sterix_armory', vector3(452.6, -980.0, 30.7), 1.5, 1.5, {
    heading = 0.0,
    height = 2.0,
    options = {
        {
            label = 'Open Armory',
            icon = 'fas fa-gun',
            onSelect = function()
                -- open armory
            end,
        },
    },
})

-- Entity
Bridge.AddTargetEntity(entity, {
    { label = 'Search', icon = 'fas fa-search', onSelect = function() end },
})

-- Model
Bridge.AddTargetModel(`prop_cabinet01a`, {
    { label = 'Open Locker', icon = 'fas fa-box', onSelect = function() end },
})

-- Cleanup
Bridge.RemoveZone(zoneId)
```

### Bridge events

Fired automatically by whichever framework file is active — react to these instead of the
framework's own job/player events. All client-side bridge events are namespaced with
`:client:`:

```lua
RegisterNetEvent('sterix_police:bridge:client:jobUpdate', function(job)
end)

RegisterNetEvent('sterix_police:bridge:client:playerLoaded', function()
end)

RegisterNetEvent('sterix_police:bridge:client:playerUnloaded', function()
end)
```

Also fired on resource start/restart (see [Resource lifecycle](#resource-lifecycle) below):

```lua
RegisterNetEvent('sterix_police:bridge:client:resourceStart', function()
end)
```

### Duty

```lua
Bridge.ToggleDuty()      -- flip current duty state
Bridge.SetDuty(false)    -- set an explicit state (deterministic, idempotent)
```

Both fire a server event that calls the matching `Bridge.*Duty(source)` on whichever
framework file is active. No return value here — react to the change via the `jobUpdate`
bridge event above. `SetDuty` is the safe choice when you know the state you want (e.g.
forcing a player off duty on spawn/relog): it never flips the wrong way and is a no-op
server-side if the state already matches. On ESX `ToggleDuty` is a no-op (prints a warning)
since ESX has no built-in duty state; `SetDuty` just echoes the requested state to the
script's own duty tracking.

### Inventory (client-side check)

```lua
if Bridge.HasItem('handcuffs', 1) then
end
```

---

## Resource lifecycle

Fired via `AddEventHandler('onResourceStart'/'onResourceStop', ...)` when this resource
itself starts or stops — a `restart` fires stop then start. Both handlers are guarded so
they only fire for this resource, not every resource on the server. Client and server each
get their own namespaced events:

```lua
-- client/*.lua
RegisterNetEvent('sterix_police:bridge:client:resourceStart', function()
end)

RegisterNetEvent('sterix_police:bridge:client:resourceStop', function()
    -- cleanup: remove zones, hide UI, stop threads, etc.
end)

-- server/*.lua
RegisterNetEvent('sterix_police:bridge:server:resourceStart', function()
end)

RegisterNetEvent('sterix_police:bridge:server:resourceStop', function()
    -- cleanup: persist state, clear timers, etc.
end)
```

---

## Server API (`Bridge.*` in any `server/` file)

### Player / Job

```lua
local player = Bridge.GetPlayer(source)
local identifier = Bridge.GetPlayerIdentifier(source) -- citizenid / esx identifier
local job = Bridge.GetJob(source)

Bridge.SetJob(source, 'police', 2)

local newOnDuty = Bridge.ToggleDuty(source)      -- boolean, or nil on esx (unsupported)
local onDuty    = Bridge.SetDuty(source, false)  -- boolean; idempotent, only notifies on real change

local allPlayers = Bridge.GetPlayers()
local onDuty = Bridge.GetPlayersOnDuty('police') -- number[] of source ids
```

### Notify

```lua
Bridge.Notify(source, 'You have been dispatched.', 'inform', 5000, 'Dispatch')
```

### Inventory

```lua
Bridge.AddItem(source, 'handcuffs', 1)
Bridge.RemoveItem(source, 'handcuffs', 1)

if Bridge.HasItem(source, 'handcuffs', 1) then
end
```

> Signature differs slightly by framework internally (`qbx`/`esx` take `metadata, slot`,
> `qb` takes `slot, info`) but the call shape `Bridge.AddItem(source, item, amount, ...)`
> is the same everywhere — you don't need to branch on `Bridge.Framework` to use it.

---

## Callbacks (ox_lib, direct)

The bridge does not wrap callbacks — `ox_lib` is already a dependency and works the same
regardless of framework, so use it directly.

**Server:**

```lua
lib.callback.register('sterix_police:server:getNearbyOfficers', function(source)
    return Bridge.GetPlayersOnDuty('police')
end)
```

**Client:**

```lua
-- async
lib.callback('sterix_police:server:getNearbyOfficers', false, function(officers)
end)

-- awaited (inside a thread)
local officers = lib.callback.await('sterix_police:server:getNearbyOfficers', false)
```

---

## Adding to the bridge

If you need something not covered above (e.g. a stash, a shop, a specific item event),
add it to **all three** framework files (`bridge/qbx`, `bridge/qb`, `bridge/esx`) with the
same `Bridge.FunctionName(...)` signature, or to the root `bridge/client.lua` /
`bridge/server.lua` if it's identical across frameworks (like `Notify`). Never call
`qbx_core` / `qb-core` / `es_extended` / `ox_inventory` / `ox_target` directly from
`client/` or `server/` — always go through `Bridge.*`.
