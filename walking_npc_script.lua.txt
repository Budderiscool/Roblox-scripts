local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local hrp = npc:WaitForChild("HumanoidRootPart")

-- Target parts
local jobPart = workspace:WaitForChild("JobPart")
local homePart = workspace:WaitForChild("HomePart")

-- Waypoint folders (optional - will use direct pathfinding if not found)
local toJobWaypoints = workspace:FindFirstChild("ToJobWaypoints")
local toHomeWaypoints = workspace:FindFirstChild("ToHomeWaypoints")

local Lighting = game:GetService("Lighting")
local PathfindingService = game:GetService("PathfindingService")

-- Time constants (matching your time system)
local jobStart = 9 * 60    -- 9:00 AM (540 minutes)
local jobEnd = 17 * 60     -- 5:00 PM (1020 minutes)

-- Movement variables
local currentTarget = nil
local isMoving = false
local ARRIVAL_DISTANCE = 8 -- How close to get to waypoints/target (increased)
local hasInitialized = false -- Track if we've set initial position

-- Function to get waypoints in order
local function getOrderedWaypoints(waypointFolder)
	if not waypointFolder then return {} end

	local waypoints = {}
	for _, child in pairs(waypointFolder:GetChildren()) do
		if child:IsA("BasePart") then
			-- Extract number from name (e.g., "Waypoint1", "Point2", "WP3")
			local number = tonumber(string.match(child.Name, "%d+"))
			if number then
				waypoints[number] = child
			end
		end
	end

	-- Convert to ordered array
	local orderedWaypoints = {}
	for i = 1, #waypoints do
		if waypoints[i] then
			table.insert(orderedWaypoints, waypoints[i])
		end
	end

	return orderedWaypoints
end

-- Function to walk through waypoints
local function walkThroughWaypoints(waypoints, finalTarget)
	for i, waypoint in ipairs(waypoints) do
		if currentTarget ~= finalTarget then
			print("Target changed, stopping waypoint following")
			break -- Target changed, stop following this path
		end

		print("Walking to waypoint " .. i .. ": " .. waypoint.Name)

		-- Walk to this waypoint
		humanoid:MoveTo(waypoint.Position)

		-- Wait for arrival with timeout
		local arrived = false
		local startTime = tick()
		local timeout = 20 -- increased timeout

		while tick() - startTime < timeout do
			local distance = (hrp.Position - waypoint.Position).Magnitude
			if distance <= ARRIVAL_DISTANCE then
				arrived = true
				print("Reached waypoint " .. i .. " (distance: " .. math.floor(distance) .. ")")
				break
			end

			-- Check if humanoid stopped moving (might be stuck)
			if humanoid.MoveToFinished.Event:Wait(0.1) then
				local finalDistance = (hrp.Position - waypoint.Position).Magnitude
				if finalDistance <= ARRIVAL_DISTANCE then
					arrived = true
					print("Reached waypoint " .. i .. " via MoveToFinished")
					break
				else
					print("MoveToFinished but still far from waypoint " .. i .. " (distance: " .. math.floor(finalDistance) .. "), retrying...")
					humanoid:MoveTo(waypoint.Position) -- Try again
				end
			end
		end

		if arrived then
			task.wait(1) -- Brief pause at waypoint
		else
			local currentDistance = (hrp.Position - waypoint.Position).Magnitude
			print("Timeout at waypoint " .. i .. " (distance: " .. math.floor(currentDistance) .. "), continuing anyway...")
		end
	end
end

-- Enhanced pathfinding function with waypoints
local function walkToTarget(targetPart)
	if isMoving then return end
	isMoving = true

	print("NPC walking to: " .. targetPart.Name)

	-- Determine which waypoints to use
	local waypoints = {}
	if targetPart == jobPart then
		waypoints = getOrderedWaypoints(toJobWaypoints)
		if #waypoints > 0 then
			print("Using " .. #waypoints .. " waypoints to reach job")
		end
	elseif targetPart == homePart then
		waypoints = getOrderedWaypoints(toHomeWaypoints)
		if #waypoints > 0 then
			print("Using " .. #waypoints .. " waypoints to reach home")
		end
	end

	-- Follow waypoints if they exist
	if #waypoints > 0 then
		walkThroughWaypoints(waypoints, targetPart)

		-- After waypoints, go to final target
		if currentTarget == targetPart then
			print("Following waypoints complete, going to final target...")
		end
	end

	-- Final movement to target (either after waypoints or direct if no waypoints)
	if currentTarget == targetPart then
		-- Create path to final target
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentJumpHeight = 10,
		})

		-- Compute path
		local success, errorMessage = pcall(function()
			path:ComputeAsync(hrp.Position, targetPart.Position)
		end)

		if success and path.Status == Enum.PathStatus.Success then
			local pathWaypoints = path:GetWaypoints()

			-- Follow each pathfinding waypoint
			for i, waypoint in ipairs(pathWaypoints) do
				-- Stop if target changed
				if currentTarget ~= targetPart then
					break
				end

				-- Handle jumping
				if waypoint.Action == Enum.PathWaypointAction.Jump then
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end

				-- Move to waypoint
				humanoid:MoveTo(waypoint.Position)

				-- Wait for arrival or timeout
				local reached = humanoid.MoveToFinished:Wait(5)
				if not reached then
					print("Timeout at pathfinding waypoint " .. i .. ", continuing...")
				end
			end
		else
			-- Pathfinding failed, try direct movement
			print("Pathfinding failed, trying direct movement to " .. targetPart.Name)
			humanoid:MoveTo(targetPart.Position)
			humanoid.MoveToFinished:Wait(10)
		end

		-- Final check and orientation
		local finalDistance = (hrp.Position - targetPart.Position).Magnitude
		if finalDistance <= ARRIVAL_DISTANCE then
			print("NPC arrived at " .. targetPart.Name)

			-- Face the same direction as the target part
			if targetPart.CFrame then
				local targetDirection = targetPart.CFrame.LookVector
				local horizontalDirection = Vector3.new(targetDirection.X, 0, targetDirection.Z)
				if horizontalDirection.Magnitude > 0.1 then
					local newCFrame = CFrame.lookAt(hrp.Position, hrp.Position + horizontalDirection)
					hrp.CFrame = newCFrame
				end
			end
		else
			print("NPC didn't quite reach " .. targetPart.Name .. " (distance: " .. math.floor(finalDistance) .. ")")
		end
	end

	isMoving = false
end

-- Main loop
while true do
	local currentTime = Lighting:GetMinutesAfterMidnight()
	local targetPart

	-- Determine where NPC should be based on time
	if currentTime >= jobStart and currentTime < jobEnd then
		targetPart = jobPart
	else
		targetPart = homePart
	end

	-- Initialize position on first run (make sure NPC starts at home)
	if not hasInitialized then
		hasInitialized = true
		currentTarget = homePart -- Start at home
		print("NPC initialized at home")
	end

	-- If target changed, start moving
	if targetPart ~= currentTarget then
		currentTarget = targetPart

		local timeString
		local hours = math.floor(currentTime / 60)
		local minutes = currentTime % 60
		timeString = string.format("%02d:%02d", hours, minutes)

		print("Time: " .. timeString .. " - NPC needs to go to " .. targetPart.Name)

		-- Start walking in a new thread
		task.spawn(function()
			walkToTarget(targetPart)
		end)
	end

	-- Check every 5 seconds (more frequent checking)
	task.wait(5)
end
