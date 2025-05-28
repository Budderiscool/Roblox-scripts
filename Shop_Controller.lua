local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

-- List of all shops
local shops = {
	{
		Model = workspace:WaitForChild("Bsmith"),
		OpenHour = 9,
		CloseHour = 21,
		ShopArea = workspace:WaitForChild("BsmithArea"),
		TeleportPosition = workspace:WaitForChild("BsmithExit").Position
	},
	-- Add more shops like this
	-- {
	--     Model = workspace:WaitForChild("Butcher"),
	--     OpenHour = 8,
	--     CloseHour = 18,
	--     ShopArea = workspace:WaitForChild("ButcherArea"),
	--     TeleportPosition = workspace:WaitForChild("ButcherExit").Position
	-- },
}

-- Handles showing/hiding the "Closed" model
local function setClosedModelActive(closedModel, active)
	for _, part in ipairs(closedModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = active
			part.Transparency = active and 0 or 1
		elseif part:IsA("Decal") then
			part.Transparency = active and 0 or 1
		end
	end
end

-- Sends players out of the interior zone
local function teleportPlayersOut(shopArea, teleportPos)
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, part in ipairs(shopArea:GetDescendants()) do
				if part:IsA("BasePart") then
					local size = part.Size / 2
					local pos = part.Position
					local p = hrp.Position
					if math.abs(p.X - pos.X) <= size.X and
						math.abs(p.Y - pos.Y) <= size.Y and
						math.abs(p.Z - pos.Z) <= size.Z then
						hrp.CFrame = CFrame.new(teleportPos + Vector3.new(0, 5, 0))
						break
					end
				end
			end
		end
	end
end

-- Main loop to manage shop open/close state
while true do
	wait(10)
	local hour = math.floor(Lighting.ClockTime % 24)

	for _, shop in ipairs(shops) do
		local closedModel = shop.Model:FindFirstChild("Closed")
		if not closedModel then continue end

		local isOpen = hour >= shop.OpenHour and hour < shop.CloseHour

		-- Enable "Closed" model when NOT open
		setClosedModelActive(closedModel, not isOpen)

		-- If closing, teleport players out
		if not isOpen then
			teleportPlayersOut(shop.ShopArea, shop.TeleportPosition)
		end
	end
end
