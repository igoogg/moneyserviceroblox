-- MoneyServiceCommandsNloop.lua
-- Place in: ServerScriptService
-- Shows how to use MoneyService from any server Script.

local MoneyService = require(game.ServerStorage.MoneyService)

-- ─────────────────────────────────────────────
--  Listen to money changes (any script can do this)
-- ─────────────────────────────────────────────
MoneyService.MoneyChanged:Connect(function(player, newBalance, delta)
	local sign = delta >= 0 and "+" or ""
	print(("[MoneyService] %s: %s%d → %d Coins"):format(
		player.Name, sign, delta, newBalance))
end)

-- ─────────────────────────────────────────────
--  Example: Give join bonus
-- ─────────────────────────────────────────────
game.Players.PlayerAdded:Connect(function(player)
	-- Small delay to let MoneyService load the player first
	task.wait(1)

	local joinBonus = 50
	local newBalance = MoneyService:AddMoney(player, joinBonus)
	print(("[Bonus] Gave %d join bonus to %s. New balance: %d"):format(
		joinBonus, player.Name, newBalance))
end)

-- ─────────────────────────────────────────────
--  Example: RemoteEvent shop purchase
-- ─────────────────────────────────────────────
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create a RemoteEvent for purchases (place this in ReplicatedStorage manually or via script)
local buyEvent = Instance.new("RemoteEvent")
buyEvent.Name = "BuyItem"
buyEvent.Parent = ReplicatedStorage

local SHOP_ITEMS = {
	Sword  = 200,
	Shield = 150,
	Potion = 50,
}

buyEvent.OnServerEvent:Connect(function(player, itemName)
	local cost = SHOP_ITEMS[itemName]
	if not cost then
		warn("[Shop] Unknown item: " .. tostring(itemName))
		return
	end

	local result = MoneyService:RemoveMoney(player, cost)
	if result == false then
		-- Insufficient funds — fire back to client
		buyEvent:FireClient(player, "FAIL", itemName,
			MoneyService:GetMoney(player), cost)
		print(("[Shop] %s can't afford %s (%d Coins needed)"):format(
			player.Name, itemName, cost))
	else
		-- Success — give item here, then notify client
		buyEvent:FireClient(player, "OK", itemName, result)
		print(("[Shop] %s bought %s for %d Coins. Balance: %d"):format(
			player.Name, itemName, cost, result))
	end
end)

-- ─────────────────────────────────────────────
--  Periodic income: $15 every 60 seconds
-- ─────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(game.Players:GetPlayers()) do
			MoneyService:AddMoney(player, 15)
		end
	end
end)

-- ─────────────────────────────────────────────
--  Example: Admin commands via chat
--  /give PlayerName 500
--  /take PlayerName 100
--  /set  PlayerName 1000
--  /bal  PlayerName
-- ─────────────────────────────────────────────
local ADMIN_IDS = {
	-- Add your Roblox UserId(s) here:
	-- 123456789,
}

local function isAdmin(player)
	for _, id in ipairs(ADMIN_IDS) do
		if player.UserId == id then return true end
	end
	return false
end

game.Players.PlayerAdded:Connect(function(admin)
	admin.Chatted:Connect(function(msg)
		if not isAdmin(admin) then return end

		local parts = msg:split(" ")
		local cmd   = parts[1] and parts[1]:lower()
		local target = parts[2] and game.Players:FindFirstChild(parts[2])
		local amount = parts[3] and tonumber(parts[3])

		if cmd == "/give" and target and amount then
			MoneyService:AddMoney(target, amount)
			print(("[Admin] Gave %d to %s"):format(amount, target.Name))

		elseif cmd == "/take" and target and amount then
			local result = MoneyService:RemoveMoney(target, amount)
			if result == false then
				print(("[Admin] %s has insufficient funds"):format(target.Name))
			end

		elseif cmd == "/set" and target and amount then
			MoneyService:SetMoney(target, amount)
			print(("[Admin] Set %s balance to %d"):format(target.Name, amount))

		elseif cmd == "/bal" and target then
			print(("[Admin] %s balance: %d"):format(
				target.Name, MoneyService:GetMoney(target)))
		end
	end)
end)
