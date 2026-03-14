-- MoneyService.lua
-- Place in: ServerStorage/MoneyService
-- This is a ModuleScript. Require it from any Script or LocalScript (server-side only for mutations).
--
-- USAGE:
--   local MoneyService = require(game.ServerStorage.MoneyService)
--
--   MoneyService:GetMoney(player)          --> number
--   MoneyService:AddMoney(player, amount)  --> number (new balance)
--   MoneyService:RemoveMoney(player, amount) --> number | false  (false = insufficient funds)
--   MoneyService:SetMoney(player, amount)  --> number (new balance)
--   MoneyService:HasMoney(player, amount)  --> boolean
--   MoneyService:ResetMoney(player)        --> number (0)
--   MoneyService:GetLeaderboard(topN)      --> table of {player, balance} sorted desc
--
-- EVENTS (fire from server):
--   MoneyService.MoneyChanged:Connect(function(player, newBalance, delta) end)

local MoneyService = {}
MoneyService.__index = MoneyService

-- ─────────────────────────────────────────────
--  Configuration
-- ─────────────────────────────────────────────
local CONFIG = {
	START_BALANCE     = 100,       -- money each new player starts with
	MAX_BALANCE       = 1_000_000, -- hard cap (set nil to disable)
	MIN_BALANCE       = 0,         -- floor (players can't go below this)
	CURRENCY_NAME     = "$",   -- display name
	DATA_STORE_NAME   = "MoneyService_v1", -- DataStore key prefix
	AUTO_SAVE_INTERVAL = 60,       -- seconds between auto-saves
	USE_DATA_STORE    = true,      -- set false for testing (data won't persist)
}

-- ─────────────────────────────────────────────
--  Internal state
-- ─────────────────────────────────────────────
local Players        = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService     = game:GetService("RunService")

local dataStore = CONFIG.USE_DATA_STORE
	and DataStoreService:GetDataStore(CONFIG.DATA_STORE_NAME)
	or nil

local balances   = {}  -- [userId] = number
local saveTimers = {}  -- [userId] = tick() of last save

-- BindableEvent so other scripts can listen to money changes
local moneyChangedEvent = Instance.new("BindableEvent")
MoneyService.MoneyChanged = moneyChangedEvent.Event

-- ─────────────────────────────────────────────
--  Helpers
-- ─────────────────────────────────────────────
local function clamp(value)
	if CONFIG.MIN_BALANCE then value = math.max(CONFIG.MIN_BALANCE, value) end
	if CONFIG.MAX_BALANCE  then value = math.min(CONFIG.MAX_BALANCE,  value) end
	return value
end

local function getUserId(player)
	return tostring(player.UserId)
end

local function loadFromStore(player)
	if not dataStore then return CONFIG.START_BALANCE end
	local success, result = pcall(function()
		return dataStore:GetAsync(getUserId(player))
	end)
	if success and result ~= nil then
		return clamp(result)
	end
	return CONFIG.START_BALANCE
end

local function saveToStore(player)
	if not dataStore then return end
	local uid = getUserId(player)
	if not balances[uid] then return end
	local success, err = pcall(function()
		dataStore:SetAsync(uid, balances[uid])
	end)
	if not success then
		warn("[MoneyService] Save failed for " .. player.Name .. ": " .. tostring(err))
	else
		saveTimers[uid] = tick()
	end
end

local function updateLeaderstats(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local stat = ls:FindFirstChild(CONFIG.CURRENCY_NAME)
		if stat then stat.Value = amount end
	end
end

-- ─────────────────────────────────────────────
--  Leaderstats setup (auto-creates for each player)
-- ─────────────────────────────────────────────
local function setupLeaderstats(player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end
	if not ls:FindFirstChild(CONFIG.CURRENCY_NAME) then
		local stat = Instance.new("IntValue")
		stat.Name = CONFIG.CURRENCY_NAME
		stat.Value = 0
		stat.Parent = ls
	end
end

-- ─────────────────────────────────────────────
--  Player join / leave
-- ─────────────────────────────────────────────
local function onPlayerAdded(player)
	local uid = getUserId(player)
	local balance = loadFromStore(player)
	balances[uid] = balance
	saveTimers[uid] = tick()

	setupLeaderstats(player)
	updateLeaderstats(player, balance)

	print(("[MoneyService] %s joined with %d %s"):format(
		player.Name, balance, CONFIG.CURRENCY_NAME))
end

local function onPlayerRemoving(player)
	saveToStore(player)
	local uid = getUserId(player)
	balances[uid]   = nil
	saveTimers[uid] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game (Studio testing)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Auto-save loop
task.spawn(function()
	while true do
		task.wait(CONFIG.AUTO_SAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			saveToStore(player)
		end
	end
end)

-- Save all on server close
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveToStore(player)
	end
end)

-- ─────────────────────────────────────────────
--  Public API
-- ─────────────────────────────────────────────

--- Returns the player's current balance. Returns 0 if not loaded yet.
function MoneyService:GetMoney(player)
	return balances[getUserId(player)] or 0
end

--- Returns true if the player has at least `amount` money.
function MoneyService:HasMoney(player, amount)
	return self:GetMoney(player) >= amount
end

--- Adds `amount` to the player's balance. Returns new balance.
--- Negative amounts are silently ignored (use RemoveMoney instead).
function MoneyService:AddMoney(player, amount)
	assert(type(amount) == "number" and amount >= 0,
		"[MoneyService] AddMoney: amount must be a non-negative number")
	local uid = getUserId(player)
	local old = balances[uid] or 0
	local new = clamp(old + amount)
	balances[uid] = new
	updateLeaderstats(player, new)
	moneyChangedEvent:Fire(player, new, new - old)
	return new
end

--- Removes `amount` from the player's balance.
--- Returns new balance on success, or false if the player can't afford it.
function MoneyService:RemoveMoney(player, amount)
	assert(type(amount) == "number" and amount >= 0,
		"[MoneyService] RemoveMoney: amount must be a non-negative number")
	local uid = getUserId(player)
	local old = balances[uid] or 0
	if old < amount then
		return false  -- insufficient funds
	end
	local new = clamp(old - amount)
	balances[uid] = new
	updateLeaderstats(player, new)
	moneyChangedEvent:Fire(player, new, new - old)
	return new
end

--- Forcefully sets the player's balance to `amount`. Returns new balance.
function MoneyService:SetMoney(player, amount)
	assert(type(amount) == "number",
		"[MoneyService] SetMoney: amount must be a number")
	local uid = getUserId(player)
	local old = balances[uid] or 0
	local new = clamp(amount)
	balances[uid] = new
	updateLeaderstats(player, new)
	moneyChangedEvent:Fire(player, new, new - old)
	return new
end

--- Resets the player's balance to 0 (or MIN_BALANCE). Returns new balance.
function MoneyService:ResetMoney(player)
	return self:SetMoney(player, 0)
end

--- Returns a sorted leaderboard table.
--- Each entry: { player = Player, balance = number }
--- topN: how many entries to return (default: all)
function MoneyService:GetLeaderboard(topN)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(list, {
			player  = player,
			balance = self:GetMoney(player),
		})
	end
	table.sort(list, function(a, b) return a.balance > b.balance end)
	if topN then
		local trimmed = {}
		for i = 1, math.min(topN, #list) do
			trimmed[i] = list[i]
		end
		return trimmed
	end
	return list
end

--- Returns CONFIG so other scripts can read currency name, caps, etc.
function MoneyService:GetConfig()
	return CONFIG
end

return MoneyService
