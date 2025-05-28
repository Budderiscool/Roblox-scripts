local Lighting = game:GetService("Lighting")
local secondsPerInGameMinute = 1 -- 1 real second = 1 in-game minute
local minutesInADay = 24 * 60 -- 1440 minutes
local cycleTime = minutesInADay * secondsPerInGameMinute -- 1440 seconds = 24 minutes
local initialTime = 8 * 65 -- 8:00 AM (480 minutes)

-- Initialize time
Lighting:SetMinutesAfterMidnight(initialTime)
print("Time initialized to 8:00 AM")

-- Update cycle
local function updateCycle()
	local startTime = tick() - (initialTime * secondsPerInGameMinute)
	while true do
		local elapsed = (tick() - startTime) % cycleTime
		local timeOfDay = (elapsed / cycleTime) * minutesInADay
		Lighting:SetMinutesAfterMidnight(timeOfDay)
		task.wait(0.1)
	end
end

coroutine.resume(coroutine.create(updateCycle))
