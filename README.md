# 💰 Roblox Money System

A plug-and-play coin/currency system for Roblox games. Drop in three scripts and you have full money management with DataStore persistence, a leaderboard stat, HUD, and a clean API you can import from any Script.

---

## Features

- **One-line API** — `AddMoney`, `RemoveMoney`, `GetMoney`, `SetMoney`, `HasMoney` from any server Script
- **DataStore persistence** — balances save automatically between sessions
- **Multi-player safe** — each player has an isolated balance loaded on join, saved on leave
- **Leaderstats** — coin count appears in the default Roblox leaderboard automatically
- **Event system** — `MoneyChanged` fires on every balance change so any script can react
- **HUD** — animated coin display with +/− popups for the player
- **Admin commands** — `/give`, `/take`, `/set`, `/bal` in chat (add your UserId to enable)
- **Configurable** — starting balance, cap, floor, currency name, save interval

---

## File structure

```
MoneyService.lua          → ServerStorage/MoneyService     (ModuleScript)
ExampleServerScript.lua   → ServerScriptService/AnyName    (Script)
MoneyUI.lua               → StarterPlayerScripts/MoneyUI   (LocalScript)
```

---

## Quick start

**1.** In Roblox Studio, create a **ModuleScript** inside `ServerStorage`.  
Rename it `MoneyService` and paste the contents of `MoneyService.lua`.

**2.** Create a **Script** inside `ServerScriptService`.  
Paste the contents of `ExampleServerScript.lua` (or write your own — see API below).

**3.** Create a **LocalScript** inside `StarterPlayerScripts`.  
Paste the contents of `MoneyUI.lua` for the HUD.

That's it. Run the game — each player starts with 100 coins and a leaderboard stat appears automatically.

---

## Configuration

Edit the `CONFIG` table at the top of `MoneyService.lua`:

```lua
local CONFIG = {
    START_BALANCE      = 100,          -- coins each new player starts with
    MAX_BALANCE        = 1_000_000,    -- hard cap  (set nil to disable)
    MIN_BALANCE        = 0,            -- floor (players can't go below this)
    CURRENCY_NAME      = "Coins",      -- leaderboard stat name
    DATA_STORE_NAME    = "MoneyService_v1",
    AUTO_SAVE_INTERVAL = 60,           -- seconds between auto-saves
    USE_DATA_STORE     = true,         -- false = no persistence (testing only)
}
```

> **Tip:** Change `CURRENCY_NAME` before your first publish. Changing it later creates a new DataStore key and existing balances won't carry over.

---

## API

Require the module from any **server-side** Script:

```lua
local MoneyService = require(game.ServerStorage.MoneyService)
```

### `MoneyService:GetMoney(player)` → `number`

Returns the player's current balance. Returns `0` if the player hasn't loaded yet.

```lua
local balance = MoneyService:GetMoney(player)
print(player.Name .. " has " .. balance .. " coins")
```

---

### `MoneyService:HasMoney(player, amount)` → `boolean`

Returns `true` if the player has at least `amount` coins. Use this before purchases.

```lua
if MoneyService:HasMoney(player, 200) then
    -- safe to charge
end
```

---

### `MoneyService:AddMoney(player, amount)` → `number`

Adds `amount` to the player's balance. Respects `MAX_BALANCE`. Amount must be ≥ 0.  
Returns the new balance.

```lua
local newBalance = MoneyService:AddMoney(player, 500)
print("New balance: " .. newBalance)
```

---

### `MoneyService:RemoveMoney(player, amount)` → `number | false`

Deducts `amount` from the player's balance. Returns the new balance on success, or `false` if the player can't afford it. **Always check the return value before giving an item.**

```lua
local result = MoneyService:RemoveMoney(player, 200)
if result == false then
    -- insufficient funds
    notifyPlayer(player, "Not enough coins!")
    return
end
-- result = new balance, safe to give item
```

---

### `MoneyService:SetMoney(player, amount)` → `number`

Forcefully sets the balance to `amount`. Clamped between `MIN_BALANCE` and `MAX_BALANCE`.  
Useful for admin tools and testing.

```lua
MoneyService:SetMoney(player, 1000)
```

---

### `MoneyService:ResetMoney(player)` → `number`

Resets balance to `0` (or `MIN_BALANCE` if configured). Returns the new balance.

```lua
MoneyService:ResetMoney(player)
```

---

### `MoneyService:GetLeaderboard(topN?)` → `table`

Returns a table of all online players sorted by balance descending.  
Each entry: `{ player = Player, balance = number }`.  
Pass a number to limit results.

```lua
local top5 = MoneyService:GetLeaderboard(5)
for rank, entry in ipairs(top5) do
    print(rank, entry.player.Name, entry.balance)
end
```

---

### `MoneyService.MoneyChanged`

A `BindableEvent` that fires on every balance change. Connect from any server Script.  
Parameters: `player`, `newBalance`, `delta` (positive = earned, negative = spent).

```lua
MoneyService.MoneyChanged:Connect(function(player, newBalance, delta)
    if delta > 0 then
        print(player.Name .. " earned " .. delta .. " coins")
    elseif delta < 0 then
        print(player.Name .. " spent " .. math.abs(delta) .. " coins")
    end
end)
```

---

## Usage examples

### Shop purchase

```lua
local MoneyService = require(game.ServerStorage.MoneyService)

local ITEMS = {
    Sword  = 200,
    Shield = 150,
    Potion = 50,
}

buyRemote.OnServerEvent:Connect(function(player, itemName)
    local cost = ITEMS[itemName]
    if not cost then return end

    local result = MoneyService:RemoveMoney(player, cost)
    if result == false then
        buyRemote:FireClient(player, "FAIL", cost)
        return
    end

    -- give item
    local clone = game.ServerStorage.Items[itemName]:Clone()
    clone.Parent = player.Backpack
    buyRemote:FireClient(player, "OK", result)
end)
```

### Passive income

```lua
local MoneyService = require(game.ServerStorage.MoneyService)

task.spawn(function()
    while true do
        task.wait(10)
        for _, player in ipairs(game.Players:GetPlayers()) do
            MoneyService:AddMoney(player, 5)
        end
    end
end)
```

### Reward on kill

```lua
local MoneyService = require(game.ServerStorage.MoneyService)

game.Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.Died:Connect(function()
            local tag = humanoid:FindFirstChild("creator")
            if tag and tag.Value then
                MoneyService:AddMoney(tag.Value, 50)
            end
        end)
    end)
end)
```

### Admin chat commands

Add your Roblox `UserId` to the `ADMIN_IDS` table in `ExampleServerScript.lua`:

```lua
local ADMIN_IDS = { 123456789 }
```

Then use in chat:

| Command | Description |
|---|---|
| `/give PlayerName 500` | Add 500 coins to a player |
| `/take PlayerName 100` | Remove 100 coins from a player |
| `/set PlayerName 1000` | Set a player's balance to 1000 |
| `/bal PlayerName` | Print a player's current balance |

---

## How data saving works

- Balances load from DataStore when a player joins.
- They save automatically every `AUTO_SAVE_INTERVAL` seconds (default: 60).
- They save immediately when a player leaves.
- `game:BindToClose` saves all players when the server shuts down.

Set `USE_DATA_STORE = false` during testing to skip DataStore calls entirely (Studio free model testing, no data is written or read).

---

## Notes

- All money mutations (`Add`, `Remove`, `Set`) must be called **server-side** only. Never require or call this from a LocalScript — exploit clients could modify balances.
- The `MoneyUI.lua` LocalScript only reads the `leaderstats` value — it cannot change the balance.
- If you rename `CURRENCY_NAME` mid-development, update it in `MoneyUI.lua` too (the `WaitForChild` calls on the leaderstats folder).

---

## License

MIT — free to use in any Roblox game, commercial or otherwise.
