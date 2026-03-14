-- MoneyUI.lua
-- Place in: StarterPlayerScripts (or StarterGui as a LocalScript)
-- Shows the player their current coin balance in a HUD.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ─────────────────────────────────────────────
--  Build the HUD
-- ─────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MoneyHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

-- Coin icon + balance label
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 180, 0, 50)
frame.Position = UDim2.new(1, -200, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 210, 50)
stroke.Thickness = 2
stroke.Parent = frame

local icon = Instance.new("TextLabel")
icon.Size = UDim2.new(0, 40, 1, 0)
icon.Position = UDim2.new(0, 5, 0, 0)
icon.BackgroundTransparency = 1
icon.Text = "🪙"
icon.TextScaled = true
icon.Parent = frame

local balLabel = Instance.new("TextLabel")
balLabel.Name = "Balance"
balLabel.Size = UDim2.new(1, -50, 1, 0)
balLabel.Position = UDim2.new(0, 48, 0, 0)
balLabel.BackgroundTransparency = 1
balLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
balLabel.TextScaled = true
balLabel.Font = Enum.Font.GothamBold
balLabel.TextXAlignment = Enum.TextXAlignment.Left
balLabel.Text = "0"
balLabel.Parent = frame

-- +/- popup label for delta feedback
local deltaLabel = Instance.new("TextLabel")
deltaLabel.Size = UDim2.new(0, 120, 0, 30)
deltaLabel.Position = UDim2.new(1, -200, 0, 75)
deltaLabel.BackgroundTransparency = 1
deltaLabel.Font = Enum.Font.GothamBold
deltaLabel.TextScaled = true
deltaLabel.TextTransparency = 1
deltaLabel.Parent = screenGui

-- ─────────────────────────────────────────────
--  Update function
-- ─────────────────────────────────────────────
local lastBalance = 0

local function formatNumber(n)
	-- Adds commas: 1234567 → "1,234,567"
	local s = tostring(math.floor(n))
	return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function updateBalance(newBal)
	local delta = newBal - lastBalance
	balLabel.Text = formatNumber(newBal)

	if delta ~= 0 and lastBalance ~= 0 then
		-- Show +/- popup
		deltaLabel.TextTransparency = 0
		deltaLabel.TextColor3 = delta > 0
			and Color3.fromRGB(80, 255, 120)
			or  Color3.fromRGB(255, 80, 80)
		deltaLabel.Text = (delta > 0 and "+" or "") .. formatNumber(delta)

		local tween = TweenService:Create(deltaLabel,
			TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 1 })
		tween:Play()

		-- Bounce the frame
		local bounce = TweenService:Create(frame,
			TweenInfo.new(0.1, Enum.EasingStyle.Bounce),
			{ Size = UDim2.new(0, 190, 0, 55) })
		bounce:Play()
		bounce.Completed:Connect(function()
			TweenService:Create(frame,
				TweenInfo.new(0.15),
				{ Size = UDim2.new(0, 180, 0, 50) }):Play()
		end)
	end

	lastBalance = newBal
end

-- ─────────────────────────────────────────────
--  Watch leaderstats for changes
-- ─────────────────────────────────────────────
local function watchLeaderstats()
	local ls = player:WaitForChild("leaderstats", 10)
	if not ls then return end

	-- Try common currency names; MoneyService uses CONFIG.CURRENCY_NAME
	local coinsStat = ls:WaitForChild("Coins", 5)
		or ls:WaitForChild("Money", 5)
		or ls:WaitForChild("Cash", 5)

	if coinsStat then
		updateBalance(coinsStat.Value)
		coinsStat.Changed:Connect(function(val)
			updateBalance(val)
		end)
	end
end

task.spawn(watchLeaderstats)

-- ─────────────────────────────────────────────
--  Listen for shop results (from ExampleServerScript)
-- ─────────────────────────────────────────────
local buyEvent = ReplicatedStorage:WaitForChild("BuyItem", 5)
if buyEvent then
	buyEvent.OnClientEvent:Connect(function(status, itemName, balanceOrCost, cost)
		if status == "FAIL" then
			-- Show "can't afford" message
			local msg = Instance.new("TextLabel")
			msg.Size = UDim2.new(0, 260, 0, 40)
			msg.Position = UDim2.new(0.5, -130, 0.7, 0)
			msg.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
			msg.BackgroundTransparency = 0.1
			msg.TextColor3 = Color3.fromRGB(255, 255, 255)
			msg.Font = Enum.Font.GothamBold
			msg.TextScaled = true
			msg.Text = ("❌ Not enough Coins for %s (%d needed)"):format(itemName, cost)
			msg.Parent = screenGui
			local corner2 = Instance.new("UICorner")
			corner2.CornerRadius = UDim.new(0, 8)
			corner2.Parent = msg
			game:GetService("Debris"):AddItem(msg, 2.5)
		end
	end)
end
