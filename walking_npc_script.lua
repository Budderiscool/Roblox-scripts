local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local hrp = npc:WaitForChild("HumanoidRootPart")

-- Target parts
local jobPart = workspace:WaitForChild("JobPart")
local homePart = workspace:WaitForChild("HomePart")

-- Waypoint folders
local toJobWaypoints = workspace:FindFirstChild("ToJobWaypoints")
local toHomeWaypoints = workspace:FindFirstChild("ToHomeWaypoints")

-- Services
local Lighting = game:GetService("Lighting")
local PathfindingService = game:GetService("PathfindingService")

-- Constants
local jobStart = 9 * 60
local jobEnd = 17 * 60
local ARRIVAL_DISTANCE = 8

-- Movement state
local isMoving = false
local currentTarget = nil
local hasInitialized = false

-- Get ordered waypoints
local function getOrderedWaypoints(folder)
	if not folder then return {} end
	local waypoints = {}
	for _, child in pairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			local index = tonumber(string.match(child.Name, "%d+"))
			if index then
				waypoints[index] = child
			end
		end
	end

	local ordered = {}
	for i = 1, #waypoints do
		if waypoints[i] then
			table.insert(ordered, waypoints[i])
		end
	end
	return ordered
end

-- Walk through waypoints
local function walkThroughWaypoints(waypoints, targetPart)
	for i, wp in ipairs(waypoints) do
		if currentTarget ~= targetPart then
			print("Target changed. Stop walking.")
			break
		end

		print("Going to waypoint", wp.Name)
		humanoid:MoveTo(wp.Position)

		local arrived = false
		local startTime = tick()
		while tick() - startTime < 20 do
			if (hrp.Position - wp.Position).Magnitude <= ARRIVAL_DISTANCE then
				arrived = true
				break
			end
			if humanoid.MoveToFinished:Wait(0.1) then
				if (hrp.Position - wp.Position).Magnitude <= ARRIVAL_DISTANCE then
					arrived = true
					break
				end
				humanoid:MoveTo(wp.Position) -- retry
			end
		end

		if not arrived then
			print("Timeout at waypoint", wp.Name)
		end

		task.wait(0.5)
	end
end

-- Walk to final destination
local function walkToTarget(targetPart)
	if isMoving then return end
	isMoving = true
	print("Walking to", targetPart.Name)

	local waypoints = {}
	if targetPart == jobPart then
		waypoints = getOrderedWaypoints(toJobWaypoints)
	elseif targetPart == homePart then
		waypoints = getOrderedWaypoints(toHomeWaypoints)
	end

	-- Set currentTarget here
	currentTarget = targetPart

	-- Waypoint path
	if #waypoints > 0 then
		print("Using", #waypoints, "waypoints")
		walkThroughWaypoints(waypoints, targetPart)
	end

	-- Pathfinding to final destination
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentJumpHeight = 10,
	})

	local success = pcall(function()
		path:ComputeAsync(hrp.Position, targetPart.Position)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		for i, wp in ipairs(path:GetWaypoints()) do
			if currentTarget ~= targetPart then break end
			if wp.Action == Enum.PathWaypointAction.Jump then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			humanoid:MoveTo(wp.Position)
			humanoid.MoveToFinished:Wait(5)
		end
	else
		print("Pathfinding failed. Moving directly.")
		humanoid:MoveTo(targetPart.Position)
		humanoid.MoveToFinished:Wait(10)
	end

	-- Final orientation
	if (hrp.Position - targetPart.Position).Magnitude <= ARRIVAL_DISTANCE then
		print("Arrived at", targetPart.Name)
		local lookDir = targetPart.CFrame.LookVector
		local dir = Vector3.new(lookDir.X, 0, lookDir.Z)
		if dir.Magnitude > 0.1 then
			hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + dir)
		end
	else
		print("Didn't quite arrive. Distance:", math.floor((hrp.Position - targetPart.Position).Magnitude))
	end

	isMoving = false
end

-- MAIN LOOP
while true do
	local minutes = Lighting:GetMinutesAfterMidnight()
	local newTarget

	if minutes >= jobStart and minutes < jobEnd then
		newTarget = jobPart
	else
		newTarget = homePart
	end

	if not hasInitialized then
		hasInitialized = true
		currentTarget = newTarget
		print("Initialized NPC at:", newTarget.Name)
	end

	if newTarget ~= currentTarget and not isMoving then

		local h = math.floor(minutes / 60)
		local m = minutes % 60
		print(string.format("Time: %02d:%02d - Heading to %s", h, m, newTarget.Name))

		task.spawn(function()
			walkToTarget(newTarget)
		end)
	end

	task.wait(5)
end
