--!strict
-- Services
local RunService = game:GetService("RunService")
-- Packages
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Maid"))
local TableUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("TableUtil"))
-- Modules
-- Types
-- Constants
-- Variables
-- References
-- Class
return function(frame: Frame)
	local maid = Maid.new()
	task.spawn(function()
		local character = workspace:FindFirstChild("Rig")
		local goal = workspace:FindFirstChild("Goal")
		if character and goal then
			print("found character and goal")
			assert(character:IsA("Model"))
			assert(goal:IsA("BasePart"))

			local Module = require(script.Parent)
			local rightController = Module.getR15SpringLimbController(
				character, 
				"Arm", 
				"Right", 
				maid, 
				false, 
				false,
				0.15,
				2
			)
			local leftController = Module.getR15EasedLimbController(
				character, 
				"Arm", 
				"Left", 
				maid, 
				false, 
				false,
				1,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.InOut
			)
			maid:GiveTask(RunService.RenderStepped:Connect(function()
				rightController(goal.CFrame)
				leftController(goal.CFrame)
			end))
			maid:GiveTask(function()
				for i, motorName in ipairs(TableUtil.keys(Module.R15_MOTOR_TO_PART)) do
					Module.resetR15Motor(character, motorName :: Module.R15MotorName)
				end
			end)
		end
		task.wait(0.25)
		RunService:Run()
	end)
	return function()
		RunService:Stop()
		maid:Destroy()
	end
end