
local Lighting = game:GetService("Lighting")
local updateInterval = 1
local timeSpeedPerSecond = 1 / 60 -- 1 hour per real minute
local inGameMinutes = 0

-- Define your shops
local shops = {
	{
		Model = workspace:WaitForChild("Bsmith"),
		OpenHour = 5,
		CloseHour = 15
	},
	{
		Model = workspace:WaitForChild("wizard hut"),
		OpenHour = 9,
		CloseHour = 21
	},
}

-- Initialize each shop's state
for _, shop in pairs(shops) do
	shop.IsOpen = false
end

-- Function to update a single shop's state
local function updateShopState(shop, open)
	for _, part in ipairs(shop.Model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "Sign" then
			part.Transparency = open and 0 or 1
			part.CanCollide = open
		end
	end

	local sign = shop.Model:FindFirstChild("Sign", true)
	if sign then
		if sign:IsA("TextLabel") then
			sign.Text = open and "Open" or "Closed"
		elseif sign:IsA("Part") and sign:FindFirstChildWhichIsA("SurfaceGui") then
			local label = sign:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChildWhichIsA("TextLabel")
			if label then
				label.Text = open and "Open" or "Closed"
			end
		end
	end

	shop.IsOpen = open
end

-- Time loop
while true do
	wait(updateInterval)
	Lighting.ClockTime = (Lighting.ClockTime + timeSpeedPerSecond) % 24
	inGameMinutes = (inGameMinutes + 60) % 1440

	local currentHour = math.floor(inGameMinutes / 60)

	for _, shop in pairs(shops) do
		if currentHour == shop.OpenHour and not shop.IsOpen then
			updateShopState(shop, true)
			print(shop.Model.Name .. " is now OPEN")
		elseif currentHour == shop.CloseHour and shop.IsOpen then
			updateShopState(shop, false)
			print(shop.Model.Name .. " is now CLOSED")
		end
	end
end
