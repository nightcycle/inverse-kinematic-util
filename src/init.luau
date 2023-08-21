--!strict
local _Package = script
local _Packages = _Package.Parent

-- Services
local RunService = game:GetService("RunService")

-- Packages
local GeometryUtil = require(_Packages:WaitForChild("GeometryUtil"))
local CFrameUtil = require(_Packages:WaitForChild("CFrameUtil"))
local Maid = require(_Packages:WaitForChild("Maid"))
local Spring = require(_Packages:WaitForChild("Spring"))
local CurveUtil = require(_Packages:WaitForChild("CurveUtil"))
local TableUtil = require(_Packages:WaitForChild("TableUtil"))
local Sketcher = require(_Packages:WaitForChild("Sketcher"))

-- Modules

-- Types
type Spring = Spring.Spring
export type R15MotorName = "Root" | "Waist" | "Neck" | "RightShoulder" | "LeftShoulder" | "RightElbow" | "LeftElbow" | "RightWrist" | "LeftWrist" | "RightHip" | "LeftHip" | "RightKnee" | "LeftKnee" | "RightAnkle" | "LeftAnkle"
export type R15PartName = "HumanoidRootPart" | "LowerTorso" | "Head" | "UpperTorso" | "RightUpperArm" | "RightLowerArm" | "RightHand" | "LeftUpperArm" | "LeftLowerArm" | "LeftHand" | "RightUpperLeg" | "RightLowerLeg" | "RightFoot" | "LeftUpperLeg" | "RightLowerLeg" | "RightFoot"
export type LimbSide = "Left" | "Right"
export type LimbType = "Leg" | "Arm"
type Maid = Maid.Maid

-- Constants
local SMALL = 0.00000001
local YIELD_DURATION = 15
local RIG_ATTACHMENT_SUFFIX = "RigAttachment"
local STEP_SIGNAL = RunService.Heartbeat
local EQ_EPS = 0.01
local EQ_DIST = 0.05
local IS_VERBOSE = false

-- Variables
-- References
-- Private Functions
function fuzzyCompareCFrame(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < EQ_DIST and a.XVector:FuzzyEq(b.XVector, EQ_EPS) and a.YVector:FuzzyEq(b.YVector, EQ_EPS) and a.ZVector:FuzzyEq(b.ZVector, EQ_EPS)
end

function getOriginCFrame(origin: Vector3, goal: Vector3, bendNormal: Vector3): CFrame
	local lookVector = (goal - origin).Unit

	local rightVector = (-lookVector):Cross(bendNormal.Unit)
	local upVector = (-lookVector):Cross(rightVector)
	rightVector = upVector:Cross(-lookVector)

	return CFrame.fromMatrix(origin, rightVector, upVector, lookVector)
end

function getR15AttachmentName(motorName: R15MotorName): string
	return motorName..RIG_ATTACHMENT_SUFFIX
end
-- Class
local InverseKinematicsUtil = {}
InverseKinematicsUtil.R15_PART_PARENT = {
	Head = "UpperTorso",
	UpperTorso = "LowerTorso",
	LowerTorso = "HumanoidRootPart",
	HumanoidRootPart = nil,
	RightUpperArm = "UpperTorso",
	LeftUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	LeftLowerArm = "LeftUpperArm",
	RightHand = "RightLowerArm",
	LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso",
	LeftUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	LeftLowerLeg = "LeftUpperLeg",
	RightFoot = "RightLowerLeg",
	LeftFoot = "LeftLowerLeg",
} :: {[R15PartName]: R15PartName?}

InverseKinematicsUtil.R15_PART_CHILDREN = {
	Head = {},
	UpperTorso = {"Head", "RightUpperArm", "LeftUpperArm"},
	LowerTorso = {"UpperTorso", "RightUpperLeg", "LeftLowerLeg"},
	HumanoidRootPart = {"LowerTorso"},
	RightUpperArm = {"RightLowerArm"},
	LeftUpperArm = {"LeftLowerArm"},
	RightLowerArm = {"RightHand"},
	LeftLowerArm = {"LeftHand"},
	RightHand = {},
	LeftHand = {},
	RightUpperLeg = {"RightLowerArm"},
	LeftUpperLeg = {"LeftLowerArm"},
	RightLowerLeg = {"RightFoot"},
	LeftLowerLeg = {"LeftFoot"},
	RightFoot = {},
	LeftFoot = {},
} :: {[R15PartName]: {[number]: R15PartName}}

InverseKinematicsUtil.R15_PART_LINEAGE = {
	Head = {"UpperTorso", "LowerTorso", "HumanoidRootPart"},
	UpperTorso = {"LowerTorso", "HumanoidRootPart"},
	LowerTorso = {"HumanoidRootPart"},
	HumanoidRootPart = {},
	RightUpperArm = {"UpperTorso", "LowerTorso", "HumanoidRootPart"},
	LeftUpperArm = {"UpperTorso", "LowerTorso", "HumanoidRootPart"},
	RightLowerArm = {"RightUpperArm", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
	LeftLowerArm = {"LeftUpperArm", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
	RightHand = {"RightLowerArm", "RightUpperArm", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
	LeftHand = {"LeftLowerArm", "LeftUpperArm", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
	RightUpperLeg = {"LowerTorso", "HumanoidRootPart"},
	LeftUpperLeg = {"LowerTorso", "HumanoidRootPart"},
	RightLowerLeg = {"RightUpperLeg", "LowerTorso", "HumanoidRootPart"},
	LeftLowerLeg = {"LeftUpperLeg", "LowerTorso", "HumanoidRootPart"},
	RightFoot = {"RightLowerLeg", "RightUpperLeg", "LowerTorso", "HumanoidRootPart"},
	LeftFoot = {"LeftLowerLeg", "LeftUpperLeg", "LowerTorso", "HumanoidRootPart"},
} :: {[R15PartName]: {[number]: R15PartName}}

InverseKinematicsUtil.R15_MOTOR_PARENT = {
	Neck = "Waist",
	Waist = "Root",
	Root = nil,
	RightShoulder = "Waist",
	LeftShoulder = "Waist",
	RightElbow = "RightShoulder",
	LeftElbow = "LeftShoulder",
	RightWrist = "RightElbow",
	LeftWrist = "LeftElbow",
	RightHip = "Root",
	LeftHip = "Root",
	RightKnee = "RightHip",
	LeftKnee = "LeftHip",
	RightAnkle = "RightKnee",
	LeftAnkle = "LeftKnee",
} :: {[R15MotorName]: R15MotorName?}

InverseKinematicsUtil.R15_MOTOR_CHILDREN = {
	Neck = {},
	Waist = {"Neck", "LeftShoulder", "RightShoulder"},
	Root = {"Waist", "LeftHip", "RightHip"},
	RightShoulder = {"RightElbow"},
	LeftShoulder = {"LeftElbow"},
	RightElbow = {"RightWrist"},
	LeftElbow = {"LeftWrist"},
	RightWrist = {},
	LeftWrist = {},
	RightHip = {"RightKnee"},
	LeftHip = {"LeftKnee"},
	RightKnee = {"RightAnkle"},
	LeftKnee = {"LeftAnkle"},
	RightAnkle = {},
	LeftAnkle = {},
} :: {[R15MotorName]: {[number]:R15MotorName}}

InverseKinematicsUtil.R15_MOTOR_LINEAGE = {
	Neck = {"Waist", "Root"},
	Waist = {"Root"},
	Root = {},
	RightShoulder = {"Waist", "Root"},
	LeftShoulder = {"Waist", "Root"},
	RightElbow = {"RightShoulder", "Waist", "Root"},
	LeftElbow = {"LeftShoulder", "Waist", "Root"},
	RightWrist = {"RightElbow", "RightShoulder", "Waist", "Root"},
	LeftWrist = {"LeftElbow", "LeftShoulder", "Waist", "Root"},
	RightHip = {"Root"},
	LeftHip = {"Root"},
	RightKnee = {"RightHip", "Root"},
	LeftKnee = {"LeftHip", "Root"},
	RightAnkle = {"RightKnee", "RightHip", "Root"},
	LeftAnkle = {"LeftKnee", "LeftHip", "Root"},
} :: {[R15MotorName]: {[number]:R15MotorName}}

InverseKinematicsUtil.R15_MOTOR_TO_PART = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	RightWrist = "RightHand",
	LeftWrist = "LeftHand",
	RightHip = "RightUpperLeg",
	LeftHip = "LeftUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftKnee = "LeftLowerLeg",
	RightAnkle = "RightFoot",
	LeftAnkle = "LeftFoot",
} :: {[R15MotorName]: R15PartName}

InverseKinematicsUtil.R15_PART_TO_MOTOR = {
	Head = "Neck",
	HumanoidRootPart = nil,
	LowerTorso = "Root",
	UpperTorso = "Waist",
	RightUpperArm = "RightShoulder",
	LeftUpperArm = "LeftShoulder",
	RightLowerArm = "RightElbow",
	LeftLowerArm = "LeftElbow",
	RightHand = "RightWrist",
	LeftHand = "LeftWrist",
	RightUpperLeg = "RightHip",
	LeftUpperLeg = "LeftHip",
	RightLowerLeg = "RightKnee",
	LeftLowerLeg = "LeftKnee",
	RightFoot = "RightAnkle",
	LeftFoot = "LeftAnkle",
} :: {[R15PartName]: R15MotorName?}


function InverseKinematicsUtil.getSafeGoalDistance(origin: Vector3, goal: Vector3, upperSegmentLength: number, lowerSegmentLength: number): number
	local distance = (goal - origin).Magnitude
	if distance > upperSegmentLength + lowerSegmentLength then
		distance = upperSegmentLength + lowerSegmentLength - SMALL
	end
	if distance + upperSegmentLength < lowerSegmentLength then
		distance = lowerSegmentLength - upperSegmentLength + SMALL
	end
	if distance + lowerSegmentLength < upperSegmentLength then
		distance = upperSegmentLength - lowerSegmentLength + SMALL
	end
	return distance
end

function InverseKinematicsUtil.solveOriginAngle(safeGoalDistance: number, upperSegmentLength: number, lowerSegmentLength: number): number
	return GeometryUtil.getAngleABThroughLawOfCos(
		safeGoalDistance,
		upperSegmentLength,
		lowerSegmentLength
	)
end

-- function InverseKinematicsUtil.solveMiddleAngle(originAngle: number, lowerSegmentLength: number, safeGoalDistance: number): number
-- 	return GeometryUtil.getAngleCAThroughLawOfSin(
-- 		lowerSegmentLength,
-- 		safeGoalDistance,
-- 		originAngle
-- 	)
-- end

function InverseKinematicsUtil.findR15Part(character: Model, partName: R15PartName): BasePart?
	local part: Instance? = character:FindFirstChild(partName)
	if part ~= nil then
		assert(part:IsA("BasePart"), `{partName} is not a BasePart under {character:GetFullName()}`)
		return part
	end
	return nil
end

function InverseKinematicsUtil.getR15Part(character: Model, partName: R15PartName, maxYieldUntilError: number?): BasePart
	local part: Instance? = character:WaitForChild(partName, maxYieldUntilError or YIELD_DURATION)
	assert(part and part:IsA("BasePart"), `bad part {partName} under {character:GetFullName()}`)
	return part
end

function InverseKinematicsUtil.findR15Motor(character: Model, motorName: R15MotorName): Motor6D?
	local partName: R15PartName? = InverseKinematicsUtil.R15_MOTOR_TO_PART[motorName]
	assert(partName ~= nil, `bad motor name {motorName}`)
	local part = InverseKinematicsUtil.findR15Part(character, partName)
	if part then
		local motor = part:FindFirstChild(motorName)
		if motor then
			assert(motor:IsA("Motor6D"), `{motor} is not a Motor6D under {part:GetFullName()}`)
			return motor
		end
		return nil
	end
	return nil
end

function InverseKinematicsUtil.getR15Motor(character: Model, motorName: R15MotorName, maxYieldUntilError: number?): Motor6D
	local partName: R15PartName? = InverseKinematicsUtil.R15_MOTOR_TO_PART[motorName]
	assert(partName ~= nil, `bad motor name {motorName}`)
	local part = InverseKinematicsUtil.getR15Part(character, partName, maxYieldUntilError)
	local motor = part:WaitForChild(motorName, maxYieldUntilError or YIELD_DURATION)
	assert(motor and motor:IsA("Motor6D"), `bad {motorName} under {part:GetFullName()}`)
	return motor
end

function InverseKinematicsUtil.findR15PartLineage(character: Model, partName: R15PartName, includeInitialPart: boolean): {[number]: BasePart}?
	local partLineage = InverseKinematicsUtil.R15_PART_LINEAGE[partName]
	assert(partLineage, `bad R15 part name: {partName}`)

	local parts: {[number]: BasePart} = {}

	for i, ancestorPartName in ipairs(partLineage) do
		local ancestorPart = InverseKinematicsUtil.findR15Part(character, ancestorPartName :: R15PartName)
		if ancestorPart then
			table.insert(parts, ancestorPart)
		else
			return nil
		end
	end

	if includeInitialPart then
		local part = InverseKinematicsUtil.findR15Part(character, partName)
		if part then
			table.insert(parts, 1, part)
		else
			return nil
		end
	end

	return parts
end

function InverseKinematicsUtil.getR15PartLineage(character: Model, partName: R15PartName, includeInitialPart: boolean, maxYieldUntilError: number?): {[number]: BasePart}
	local partLineage = InverseKinematicsUtil.R15_PART_LINEAGE[partName]
	assert(partLineage, `bad R15 part name: {partName}`)

	local parts: {[number]: BasePart} = {}

	for i, ancestorPartName in ipairs(partLineage) do
		table.insert(parts, InverseKinematicsUtil.getR15Part(character, ancestorPartName :: R15PartName, maxYieldUntilError))
	end

	if includeInitialPart then
		table.insert(parts, 1, InverseKinematicsUtil.getR15Part(character, partName, maxYieldUntilError))
	end

	return parts
end

function InverseKinematicsUtil.findR15MotorLineage(character: Model, motorName: R15MotorName, includeInitialMotor: boolean): {[number]: Motor6D}?
	local motorLineage = InverseKinematicsUtil.R15_MOTOR_LINEAGE[motorName]
	assert(motorLineage, `bad R15 motor name: {motorName}`)

	local motors: {[number]: Motor6D} = {}

	

	for i, ancestorMotorName in ipairs(motorLineage) do
		local ancestorMotor = InverseKinematicsUtil.findR15Motor(character, ancestorMotorName :: R15MotorName)
		if ancestorMotor then
			table.insert(motors, ancestorMotor)
		else
			return nil
		end
	end

	if includeInitialMotor then
		local motor = InverseKinematicsUtil.findR15Motor(character, motorName)
		if motor then
			table.insert(motors, 1, motor)
		else
			return nil
		end
	end

	return motors
end

function InverseKinematicsUtil.findR15MotorParent(character: Model, motorName: R15MotorName): Motor?
	local parentName: R15MotorName? = InverseKinematicsUtil.R15_MOTOR_PARENT[motorName]
	if not parentName then return nil end
	assert(parentName)
	return InverseKinematicsUtil.findR15Motor(character, parentName)
end

function InverseKinematicsUtil.getR15MotorParent(character: Model, motorName: R15MotorName, maxYieldUntilError: number?): Motor?
	local parentName: R15MotorName? = InverseKinematicsUtil.R15_MOTOR_PARENT[motorName]
	if not parentName then return nil end
	assert(parentName)
	return InverseKinematicsUtil.getR15Motor(character, parentName, maxYieldUntilError)
end


function InverseKinematicsUtil.findR15PartParent(character: Model, partName: R15PartName): BasePart?
	local parentName: R15PartName? = InverseKinematicsUtil.R15_PART_PARENT[partName]
	if not parentName then return nil end
	assert(parentName)
	return InverseKinematicsUtil.findR15Part(character, parentName)
end

function InverseKinematicsUtil.getR15PartParent(character: Model, partName: R15PartName, maxYieldUntilError: number?): BasePart?
	local parentName: R15PartName? = InverseKinematicsUtil.R15_PART_PARENT[partName]
	if not parentName then return nil end
	assert(parentName)
	return InverseKinematicsUtil.getR15Part(character, parentName, maxYieldUntilError)
end

function InverseKinematicsUtil.getR15MotorLineage(character: Model, motorName: R15MotorName, includeInitialMotor: boolean, maxYieldUntilError: number?): {[number]: Motor6D}
	local motorLineage = InverseKinematicsUtil.R15_MOTOR_LINEAGE[motorName]
	assert(motorLineage, `bad R15 motor name: {motorName}`)

	local motors: {[number]: Motor6D} = {}

	for i, ancestorMotorName in ipairs(motorLineage) do
		local ancestorMotor = InverseKinematicsUtil.getR15Motor(character, ancestorMotorName :: R15MotorName, maxYieldUntilError)
		table.insert(motors, ancestorMotor)
	end

	if includeInitialMotor then
		local motor = InverseKinematicsUtil.getR15Motor(character, motorName, maxYieldUntilError)
		table.insert(motors, 1, motor)
	end

	return motors
end

function InverseKinematicsUtil.findR15MotorChildren(character: Model, motorName: R15MotorName): {[number]: Motor6D}
	local motorChildren = InverseKinematicsUtil.R15_MOTOR_CHILDREN[motorName]
	assert(motorChildren, `bad R15 motor name: {motorName}`)

	local motors: {[number]: Motor6D} = {}

	for i, childMotorName in ipairs(motorChildren) do
		local childMotor = InverseKinematicsUtil.findR15Motor(character, childMotorName :: R15MotorName)
		if childMotor then
			table.insert(motors, childMotor)
		end
	end

	return motors
end

function InverseKinematicsUtil.getR15MotorChildren(character: Model, motorName: R15MotorName, maxYieldUntilError: number?): {[number]: Motor6D}
	local motorLineage = InverseKinematicsUtil.R15_MOTOR_CHILDREN[motorName]
	assert(motorLineage, `bad R15 motor name: {motorName}`)

	local motors: {[number]: Motor6D} = {}

	for i, childMotorName in ipairs(motorLineage) do
		local childMotor = InverseKinematicsUtil.getR15Motor(character, childMotorName :: R15MotorName, maxYieldUntilError)
		table.insert(motors, childMotor)
	end

	return motors
end

function InverseKinematicsUtil.findInitialC1(character: Model, motorName: R15MotorName): CFrame?
	local partName = InverseKinematicsUtil.R15_MOTOR_TO_PART[motorName]
	local part = InverseKinematicsUtil.findR15Part(character, partName :: R15PartName)
	if part then
		local attachmentName = getR15AttachmentName(motorName)
		local attachment = part:FindFirstChild(attachmentName)
		if attachment then
			assert(attachment:IsA("Attachment"), `{character:GetFullName()}'s rig attachment {attachmentName} is not an attachment, it's a {attachment.ClassName}`)
			return attachment.CFrame
		end
	end
	return nil
end

function InverseKinematicsUtil.getInitialC1(character: Model, motorName: R15MotorName, maxYieldUntilError: number?): CFrame
	local partName: R15PartName = InverseKinematicsUtil.R15_MOTOR_TO_PART[motorName]
	local part = InverseKinematicsUtil.getR15Part(character, partName, maxYieldUntilError)
	local attachmentName = getR15AttachmentName(motorName)
	local attachment = part:WaitForChild(attachmentName, maxYieldUntilError or YIELD_DURATION)

	assert(attachment, `rig attachment of name {attachmentName} is missing from {character:GetFullName()}`)
	assert(attachment:IsA("Attachment"), `{character:GetFullName()}'s rig attachment {attachmentName} is not an attachment, it's a {attachment.ClassName}`)
	
	return attachment.CFrame
end

function InverseKinematicsUtil.findInitialC0(character: Model, motorName: R15MotorName): CFrame?
	local partName: R15PartName = InverseKinematicsUtil.R15_MOTOR_TO_PART[motorName]
	local parentPartName: R15PartName? = InverseKinematicsUtil.R15_PART_PARENT[partName]
	assert(parentPartName, `bad parent part name for {partName}`)
	local parentPart = InverseKinematicsUtil.findR15Part(character, parentPartName)
	if parentPart then
		local attachmentName = getR15AttachmentName(motorName)
		local attachment = parentPart:FindFirstChild(attachmentName)
		if attachment then
			assert(attachment:IsA("Attachment"), `{character:GetFullName()}'s rig attachment {attachmentName} is not an attachment, it's a {attachment.ClassName}`)
			return attachment.CFrame
		end
	end
	return nil
end

function InverseKinematicsUtil.getInitialC0(character: Model, motorName: R15MotorName, maxYieldUntilError: number?): CFrame
	local partName: R15PartName = InverseKinematicsUtil.R15_MOTOR_TO_PART[motorName]
	local parentPartName: R15PartName? = InverseKinematicsUtil.R15_PART_PARENT[partName]
	assert(parentPartName, `bad parent part name for {partName}`)
	local parentPart = InverseKinematicsUtil.getR15Part(character, parentPartName, maxYieldUntilError)
	local attachmentName = getR15AttachmentName(motorName)
	local attachment = parentPart:WaitForChild(attachmentName, maxYieldUntilError or YIELD_DURATION)

	assert(attachment, `rig attachment of name {attachmentName} is missing from {character:GetFullName()}`)
	assert(attachment:IsA("Attachment"), `{character:GetFullName()}'s rig attachment {attachmentName} is not an attachment, it's a {attachment.ClassName}`)
	
	return attachment.CFrame
end

function InverseKinematicsUtil.resetR15Motor(character: Model, motorName: R15MotorName)
	local motor = InverseKinematicsUtil.findR15Motor(character, motorName)
	if motor then
		local c0 = InverseKinematicsUtil.findInitialC0(character, motorName)
		if c0 then
			motor.C0 = c0
		end
		local c1 = InverseKinematicsUtil.findInitialC1(character, motorName)
		if c1 then
			motor.C1 = c1
		end
	end
end

function InverseKinematicsUtil.deviateR15Motor(character: Model, motorName: R15MotorName, deltaCFrame: CFrame)
	local motor = InverseKinematicsUtil.findR15Motor(character, motorName)
	if motor then
		local c0 = InverseKinematicsUtil.findInitialC0(character, motorName)
		if c0 then
			motor.C0 = c0 * deltaCFrame
		end
		local c1 = InverseKinematicsUtil.findInitialC1(character, motorName)
		if c1 then
			motor.C1 = c1
		end
	end
end

function InverseKinematicsUtil.transformR15Motor(character: Model, motorName: R15MotorName, deltaCFrame: CFrame)
	local motor = InverseKinematicsUtil.findR15Motor(character, motorName)
	if motor then
		motor.Transform = deltaCFrame
	end
end

function InverseKinematicsUtil.findR15MotorTransform(character: Model, motorName: R15MotorName): CFrame?
	local motor = InverseKinematicsUtil.findR15Motor(character, motorName)
	if motor then
		return motor.Transform
	end
	return nil
end

function InverseKinematicsUtil.findR15MotorDeviation(character: Model, motorName: R15MotorName): CFrame?
	local motor = InverseKinematicsUtil.findR15Motor(character, motorName)
	if motor then
		local c0 = InverseKinematicsUtil.findInitialC0(character, motorName)
		if c0 then
			return c0:Inverse() * motor.C0
		end
	end
	return nil
end

function InverseKinematicsUtil.findR15MotorWorldCFrame(character: Model, motorName: R15MotorName, includeDeviation: boolean): CFrame?
	local motorLineage = InverseKinematicsUtil.findR15MotorLineage(character, motorName, true)
	if motorLineage then
		local motorAncestorPath = TableUtil.reverse(motorLineage)
		local originCFrame: CFrame?
		local hrp = character.PrimaryPart
		if not hrp then return end
		assert(hrp)
		originCFrame = hrp.CFrame
		assert(originCFrame)
		local priorMotor: Motor6D?
		for i, ancestorMotor in ipairs(motorAncestorPath) do
			local C0: CFrame?
			if includeDeviation then
				C0 = ancestorMotor.C0
			else
				C0 = InverseKinematicsUtil.findInitialC0(character, ancestorMotor.Name :: R15MotorName)
			end
			if not C0 then
				return nil
			end
			assert(C0)

			if priorMotor then
				local pC1: CFrame?
				if includeDeviation then
					pC1 = priorMotor.C1
				else
					pC1 = InverseKinematicsUtil.findInitialC1(character, priorMotor.Name :: R15MotorName)
				end
				if not pC1 then
					return nil
				end
				assert(pC1)
				originCFrame = originCFrame * pC1:Inverse() * C0
			else
				originCFrame = originCFrame * C0
			end
			priorMotor = ancestorMotor
		end
		return originCFrame
	end
	return nil
end

function InverseKinematicsUtil.findR15MotorTransformedWorldCFrame(character: Model, motorName: R15MotorName, includeDeviation: boolean): CFrame?
	local motorLineage = InverseKinematicsUtil.findR15MotorLineage(character, motorName, true)
	if motorLineage then
		local motorAncestorPath = TableUtil.reverse(motorLineage)
		local originCFrame: CFrame?
		local hrp = character.PrimaryPart
		if not hrp then return end
		assert(hrp)
		originCFrame = hrp.CFrame
		assert(originCFrame)
		local priorMotor: Motor6D?
		for i, ancestorMotor in ipairs(motorAncestorPath) do
			local C0: CFrame?
			if includeDeviation then
				C0 = ancestorMotor.C0
			else
				C0 = InverseKinematicsUtil.findInitialC0(character, ancestorMotor.Name :: R15MotorName)
			end
			if not C0 then
				return nil
			end
			assert(C0)

			if priorMotor then
				local pC1: CFrame?
				if includeDeviation then
					pC1 = priorMotor.C1
				else
					pC1 = InverseKinematicsUtil.findInitialC1(character, priorMotor.Name :: R15MotorName)
				end
				if not pC1 then
					return nil
				end
				assert(pC1)
				originCFrame = originCFrame * pC1:Inverse() * C0 * ancestorMotor.Transform
			else
				originCFrame = originCFrame * C0 * ancestorMotor.Transform
			end
			priorMotor = ancestorMotor
		end
		return originCFrame
	end
	return nil
end


function InverseKinematicsUtil.findR15PartWorldCFrame(character: Model, partName: R15PartName, includeDeviation: boolean): CFrame?
	if partName == "HumanoidRootPart" then
		local hrp = character.PrimaryPart
		if hrp then
			return hrp.CFrame
		else
			return nil
		end
	end

	local part = InverseKinematicsUtil.findR15Part(character, partName)
	if part then
		local motorName: R15MotorName? = InverseKinematicsUtil.R15_PART_TO_MOTOR[partName]
		assert(motorName, `bad part name {partName}`)

		local motorCF = InverseKinematicsUtil.findR15MotorWorldCFrame(character, motorName, includeDeviation)
		if motorCF then
			local C1: CFrame?
			if includeDeviation then
				local motor = InverseKinematicsUtil.findR15Motor(character, motorName)
				if motor then
					C1 = motor.C1
				else
					return nil
				end
			else
				C1 = InverseKinematicsUtil.findInitialC1(character, motorName)
			end

			assert(C1)
			
			return motorCF * C1:Inverse()
		end

	end


	return nil
end

function InverseKinematicsUtil.findR15PartTransformedWorldCFrame(character: Model, partName: R15PartName, includeDeviation: boolean): CFrame?
	if partName == "HumanoidRootPart" then
		local hrp = character.PrimaryPart
		if hrp then
			return hrp.CFrame
		else
			return nil
		end
	end

	local part = InverseKinematicsUtil.findR15Part(character, partName)
	if part then
		local motorName: R15MotorName? = InverseKinematicsUtil.R15_PART_TO_MOTOR[partName]
		assert(motorName, `bad part name {partName}`)

		local motorCF = InverseKinematicsUtil.findR15MotorTransformedWorldCFrame(character, motorName, includeDeviation)
		if motorCF then
			local C1: CFrame?
			if includeDeviation then
				local motor = InverseKinematicsUtil.findR15Motor(character, motorName)
				if motor then
					C1 = motor.C1
				else
					return nil
				end
			else
				C1 = InverseKinematicsUtil.findInitialC1(character, motorName)
			end

			assert(C1)
			
			return motorCF * C1:Inverse()
		end

	end

	return nil
end

function InverseKinematicsUtil.getR15LimbPartNames(limbType: LimbType, limbSide: LimbSide): {[number]: R15PartName}
	return {
		`{limbSide}Upper{limbType}` :: R15PartName,
		`{limbSide}Lower{limbType}` :: R15PartName,
		`{limbSide}{if limbType == "Arm" then "Hand" else "Foot"}` :: R15PartName
	}
end

function InverseKinematicsUtil.getR15LimbMotorNames(limbType: LimbType, limbSide: LimbSide): {[number]: R15MotorName}
	local limbPartNames = InverseKinematicsUtil.getR15LimbPartNames(limbType, limbSide)

	local upperPart: R15PartName = limbPartNames[1]
	local lowerPart: R15PartName = limbPartNames[2]
	local finalPart: R15PartName = limbPartNames[3]

	local upperMotor: R15MotorName? = InverseKinematicsUtil.R15_PART_TO_MOTOR[upperPart]
	local lowerMotor: R15MotorName? = InverseKinematicsUtil.R15_PART_TO_MOTOR[lowerPart]
	local finalMotor: R15MotorName? = InverseKinematicsUtil.R15_PART_TO_MOTOR[finalPart]

	assert(upperMotor, `bad motor for part {upperPart}`)
	assert(lowerMotor, `bad motor for part {lowerPart}`)
	assert(finalMotor, `bad motor for part {finalPart}`)

	return {
		upperMotor,
		lowerMotor,
		finalMotor
	}
end
function InverseKinematicsUtil.getR15MotorSegmentOffset(character: Model, terminalMotorName: R15MotorName): CFrame?
	if terminalMotorName == "Root" then
		return nil
	end
	local parentMotorName: R15MotorName? = InverseKinematicsUtil.R15_MOTOR_PARENT[terminalMotorName]
	assert(parentMotorName)

	local parentC1 = InverseKinematicsUtil.findInitialC1(character, parentMotorName)
	local terminalC0 = InverseKinematicsUtil.findInitialC0(character, terminalMotorName)
	
	if parentC1 and terminalC0 then
		return parentC1:Inverse() * terminalC0
	else
		return nil
	end
end

function InverseKinematicsUtil.getR15MotorSegmentLength(character: Model, terminalMotorName: R15MotorName): number?
	local segmentOffset = InverseKinematicsUtil.getR15MotorSegmentOffset(character, terminalMotorName)
	if segmentOffset then
		return segmentOffset.Position.Magnitude
	else
		return nil
	end
end

function InverseKinematicsUtil.getR15JointController(character: Model, motorName: R15MotorName, maid: Maid, useTransform: boolean): (target: CFrame?) -> ()
	local goal: CFrame = CFrame.new(0,0,0)
	local controller = function(target: CFrame?)
		if not target then
			target = CFrame.new(0,0,0)
		end
		assert(target)
		if fuzzyCompareCFrame(target, goal) then return end
		goal = target
	end

	maid:GiveTask(STEP_SIGNAL:Connect(function()
		if useTransform then
			InverseKinematicsUtil.transformR15Motor(character, motorName, goal)
		else
			InverseKinematicsUtil.deviateR15Motor(character, motorName, goal)
		end
	end))

	return controller
end

function InverseKinematicsUtil.getR15SpringJointController(
	character: Model, 
	motorName: R15MotorName,
	maid: Maid, 
	useTransform: boolean,
	dampingRatio: number,
	frequency: number
): (target: CFrame?) -> ()
	local goal: CFrame = CFrame.new(0,0,0)
	local prior: CFrame = CFrame.new(0,0,0)

	local springGoal = 0
	local spring = Spring.new(dampingRatio, frequency, springGoal)

	local function getAlpha(): number
		local alpha = 0
		if springGoal == 0 then -- goal is 
			alpha = 1-spring:Get()
		else
			alpha = spring:Get()
		end
		return alpha
	end

	local function getCurrent(): CFrame
		return CurveUtil.lerp(prior, goal, getAlpha())
	end

	local controller = function(target: CFrame?)
		if not target then
			target = CFrame.new(0,0,0)
		end
		assert(target)
		if fuzzyCompareCFrame(target, goal) then return end
		local current = getCurrent()
		if springGoal == 0 then
			springGoal = 1
		else
			springGoal = 0
		end
		spring:Set(springGoal)
		prior = current
		goal = target
	end

	maid:GiveTask(STEP_SIGNAL:Connect(function(deltaTime: number)
		spring:Step(deltaTime)

		if useTransform then
			InverseKinematicsUtil.transformR15Motor(character, motorName, getCurrent())
		else
			InverseKinematicsUtil.deviateR15Motor(character, motorName, getCurrent())
		end
	end))

	return controller
end

function InverseKinematicsUtil.getR15EasedJointController(
	character: Model, 
	motorName: R15MotorName,
	maid: Maid, 
	useTransform: boolean,
	duration: number,
	easingStyle: Enum.EasingStyle,
	easingDirection: Enum.EasingDirection
): (target: CFrame?) -> ()
	local goal: CFrame = CFrame.new(0,0,0)
	local prior: CFrame = CFrame.new(0,0,0)

	local easeGoal = 0
	local easeCurrent = 0

	local function getAlpha(): number
		local alpha = 0
		if easeGoal == 0 then -- goal is 
			alpha = 1-easeCurrent
		else
			alpha = easeCurrent
		end
		return alpha
	end

	local function getCurrent(): CFrame
		return CurveUtil.lerp(prior, goal, CurveUtil.ease(getAlpha(), easingStyle, easingDirection))
	end

	local controller = function(target: CFrame?)
		if not target then
			target = CFrame.new(0,0,0)
		end
		assert(target)
		if fuzzyCompareCFrame(target, goal) then return end
		local current = getCurrent()
		if easeGoal == 0 then
			easeGoal = 1
		else
			easeGoal = 0
		end
		prior = current
		goal = target
	end

	maid:GiveTask(STEP_SIGNAL:Connect(function(deltaTime: number)
		local easeDelta = deltaTime / duration
		if easeGoal == 0 then
			easeCurrent -= easeDelta
		else
			easeCurrent += easeDelta
		end
		easeCurrent = math.clamp(easeCurrent, 0, 1)

		if useTransform then
			InverseKinematicsUtil.transformR15Motor(character, motorName, getCurrent())
		else
			InverseKinematicsUtil.deviateR15Motor(character, motorName, getCurrent())
		end
	end))

	return controller
end

function getCleanBaseWorldCFrame(character: Model, motorName: R15MotorName, worldOffset: CFrame): CFrame?
	local transformedMotorCFrame = InverseKinematicsUtil.findR15MotorTransformedWorldCFrame(character, motorName, true)
	if transformedMotorCFrame then
		transformedMotorCFrame *= worldOffset 
		local currrentDeviation = InverseKinematicsUtil.findR15MotorDeviation(character, motorName)
		local currentTransform = InverseKinematicsUtil.findR15MotorTransform(character, motorName)

		if currrentDeviation and currentTransform then
			return transformedMotorCFrame * currentTransform:Inverse() * currrentDeviation:Inverse()
		end
	end
	return nil
end

function getLimbGoals(
	character: Model, 
	goal: CFrame, 
	detatchToReachGoal: boolean, 
	upperLimbMotorName: R15MotorName, 
	lowerLimbMotorName: R15MotorName, 
	finalLimbMotorName: R15MotorName--,
	-- sketcher: Sketcher.Sketcher
): (CFrame?, CFrame?, CFrame?)
	
	local limbWidth: number?
	local upperPart = InverseKinematicsUtil.findR15Part(character, InverseKinematicsUtil.R15_MOTOR_TO_PART[upperLimbMotorName])
	if upperPart then
		limbWidth = upperPart.Size.X
	end

	local upperLimbLength = InverseKinematicsUtil.getR15MotorSegmentLength(character, lowerLimbMotorName)
	local lowerLimbLength = InverseKinematicsUtil.getR15MotorSegmentLength(character, finalLimbMotorName)
	-- local upperLimbMotorCFrame = InverseKinematicsUtil.findR15MotorTransformedWorldCFrame(character, upperLimbMotorName, true)
	-- local lowerLimbMotorCFrame = InverseKinematicsUtil.findR15MotorTransformedWorldCFrame(character, lowerLimbMotorName, true)

	local originCFrame = InverseKinematicsUtil.findR15MotorTransformedWorldCFrame(character, upperLimbMotorName, true)
	local cleanOriginCFrame = getCleanBaseWorldCFrame(character, upperLimbMotorName, CFrame.new(Vector3.zero))
	local rootCF = InverseKinematicsUtil.findR15PartWorldCFrame(character, "HumanoidRootPart", false)

	if limbWidth and upperLimbLength and lowerLimbLength and rootCF and originCFrame and cleanOriginCFrame then
		local limbXOffset = 0.5 * limbWidth * if upperLimbMotorName:find("Right") then -1 else 1		

		local bendNormal = if finalLimbMotorName:find("Ankle") then goal.LookVector else -goal.UpVector


		goal += limbXOffset * goal.RightVector


		local distance = (cleanOriginCFrame.Position - goal.Position).Magnitude

		local safeGoalDistance = InverseKinematicsUtil.getSafeGoalDistance(cleanOriginCFrame.Position, goal.Position, upperLimbLength, lowerLimbLength)
		local originPosition: Vector3 = cleanOriginCFrame.Position
		-- if detatchToReachGoal and safeGoalDistance ~= distance then
		-- 	local aimNormal = (goal.Position - upperLimbMotorCFrame.Position).Unit
		-- 	local deltaDist =  safeGoalDistance - distance
		-- 	originPosition = upperLimbMotorCFrame.Position + deltaDist * aimNormal
		-- else
			-- originPosition = upperLimbMotorCFrame.Position
		-- end

		local originAngle = InverseKinematicsUtil.solveOriginAngle(
			safeGoalDistance, 
			upperLimbLength, 
			lowerLimbLength
		)
		if IS_VERBOSE then print(`safeGoalDistance {safeGoalDistance}, uL {upperLimbLength} lL {lowerLimbLength}`) end
		
		local originAimVector = (goal.Position - originPosition).Unit
		local lV = -originAimVector --(rV:Cross(uV))
		local rV = bendNormal:Cross(-lV)
		local uV = (-lV):Cross(rV)
		rV = uV:Cross(-lV)
		uV = rV:Cross(-lV)
		
		if detatchToReachGoal and distance > safeGoalDistance then
			originPosition = cleanOriginCFrame.Position + originAimVector * (distance - lowerLimbLength - upperLimbLength)
		end

		local originRootCF = CFrame.fromMatrix(
			originPosition,
			rV,
			uV,
			lV
		) * CFrame.Angles(math.rad(90),0,0)
		
		if detatchToReachGoal and distance > safeGoalDistance then
			originAngle = 0
		end

		local originTargetWorldCF = originRootCF * CFrame.Angles(-originAngle,0,0)
	
		local originTransform = cleanOriginCFrame:Inverse() * originTargetWorldCF

		-- sketcher:SetRay(originPosition, originAimVector.Unit*safeGoalDistance, Color3.new(1,0,1), 0.1)
		-- sketcher:SetRay(upperLimbMotorCFrame.Position, bendNormal*5, Color3.new(1,1,0), 0.1)
		
		-- sketcher:SetLabel(originRootCF.Position, `{math.round(math.deg(originAngle))}`, Color3.new(1,0,0), 17)

		local midAngle = (2*originAngle)
		
		-- sketcher:SetLabel(lowerLimbMotorCFrame.Position, `{math.round(math.deg(midAngle))}`, Color3.new(0,1,0), 17)
	
		local middleTransform = CFrame.Angles(midAngle, 0, 0)

		local finalAngle = if finalLimbMotorName:find("Ankle") then -originAngle else 0
		local finalTransform = CFrame.Angles(finalAngle, 0, 0)

		if originTransform and middleTransform and finalTransform then
			if IS_VERBOSE then print(`origin {math.round(math.deg(originAngle))}, mid {math.round(math.deg(midAngle))}`) end
			return originTransform, middleTransform, finalTransform
		end
		if IS_VERBOSE then print(`not all transforms found`) end
	else
		if IS_VERBOSE then print(`not all parameters found: {upperLimbLength} {lowerLimbLength} {rootCF} {originCFrame} {cleanOriginCFrame}`) end
	end
	return nil, nil, nil
end

function InverseKinematicsUtil.getR15LimbController(
	character: Model, 
	limbType: LimbType,
	limbSide: LimbSide,
	maid: Maid, 
	useTransform: boolean,
	detatchToReachGoal: boolean
): (aim: CFrame?) -> ()
	local limbMotorNames = InverseKinematicsUtil.getR15LimbMotorNames(limbType, limbSide)

	local upperLimbMotorName: R15MotorName = limbMotorNames[1]
	local lowerLimbMotorName: R15MotorName = limbMotorNames[2]
	local finalLimbMotorName: R15MotorName = limbMotorNames[3]

	local upperLimbController = InverseKinematicsUtil.getR15JointController(character, upperLimbMotorName, maid, useTransform)
	local lowerLimbController = InverseKinematicsUtil.getR15JointController(character, lowerLimbMotorName, maid, useTransform)
	local finalLimbController = InverseKinematicsUtil.getR15JointController(character, finalLimbMotorName, maid, useTransform)

	local goal: CFrame?

	-- local sketcher = maid:GiveTask(Sketcher.new())


	maid:GiveTask(STEP_SIGNAL:Connect(function(deltaTime: number): ()
		-- sketcher:Clear()
		if goal then
			if IS_VERBOSE then print(`\nattempting solve`) end
			local originTransform, middleTransform, finalTransform = getLimbGoals(character, goal, detatchToReachGoal, upperLimbMotorName, lowerLimbMotorName, finalLimbMotorName)--, sketcher)
			if originTransform and middleTransform and finalTransform then
				upperLimbController(originTransform)
				lowerLimbController(middleTransform)
				finalLimbController(finalTransform)
				return nil
			end
			if IS_VERBOSE then print(`solve failed`) end
		else
			if IS_VERBOSE then print(`no goal`) end
		end
		upperLimbController(nil)
		lowerLimbController(nil)
		finalLimbController(nil)
	end))

	return function(aim: CFrame?)
		if IS_VERBOSE then print(`updating aim`) end
		goal = aim
	end
end

function InverseKinematicsUtil.getR15SpringLimbController(
	character: Model, 
	limbType: LimbType,
	limbSide: LimbSide,
	maid: Maid, 
	useTransform: boolean,
	detatchToReachGoal: boolean,
	dampingRatio: number,
	frequency: number
): (aim: CFrame?) -> ()
	local limbMotorNames = InverseKinematicsUtil.getR15LimbMotorNames(limbType, limbSide)

	local upperLimbMotorName: R15MotorName = limbMotorNames[1]
	local lowerLimbMotorName: R15MotorName = limbMotorNames[2]
	local finalLimbMotorName: R15MotorName = limbMotorNames[3]

	local upperLimbController = InverseKinematicsUtil.getR15SpringJointController(character, upperLimbMotorName, maid, useTransform, dampingRatio, frequency)
	local lowerLimbController = InverseKinematicsUtil.getR15SpringJointController(character, lowerLimbMotorName, maid, useTransform, dampingRatio, frequency)
	local finalLimbController = InverseKinematicsUtil.getR15SpringJointController(character, finalLimbMotorName, maid, useTransform, dampingRatio, frequency)

	local goal: CFrame?

	maid:GiveTask(STEP_SIGNAL:Connect(function(deltaTime: number): ()
		if goal then
			if IS_VERBOSE then print(`\nattempting solve`) end
			local originTransform, middleTransform, finalTransform = getLimbGoals(character, goal, detatchToReachGoal, upperLimbMotorName, lowerLimbMotorName, finalLimbMotorName)
			if originTransform and middleTransform and finalTransform then
				upperLimbController(originTransform)
				lowerLimbController(middleTransform)
				finalLimbController(finalTransform)
				return nil
			end
			if IS_VERBOSE then print(`solve failed`) end
		else
			if IS_VERBOSE then print(`no goal`) end
		end
		upperLimbController(nil)
		lowerLimbController(nil)
		finalLimbController(nil)
	end))

	return function(aim: CFrame?)
		if IS_VERBOSE then print(`updating aim`) end
		goal = aim
	end
end

function InverseKinematicsUtil.getR15EasedLimbController(
	character: Model, 
	limbType: LimbType,
	limbSide: LimbSide,
	maid: Maid, 
	useTransform: boolean,
	detatchToReachGoal: boolean,
	duration: number,
	easingStyle: Enum.EasingStyle,
	easingDirection: Enum.EasingDirection
): (aim: CFrame?) -> ()
	local limbMotorNames = InverseKinematicsUtil.getR15LimbMotorNames(limbType, limbSide)

	local upperLimbMotorName: R15MotorName = limbMotorNames[1]
	local lowerLimbMotorName: R15MotorName = limbMotorNames[2]
	local finalLimbMotorName: R15MotorName = limbMotorNames[3]

	local upperLimbController = InverseKinematicsUtil.getR15EasedJointController(character, upperLimbMotorName, maid, useTransform, duration, easingStyle, easingDirection)
	local lowerLimbController = InverseKinematicsUtil.getR15EasedJointController(character, lowerLimbMotorName, maid, useTransform, duration, easingStyle, easingDirection)
	local finalLimbController = InverseKinematicsUtil.getR15EasedJointController(character, finalLimbMotorName, maid, useTransform, duration, easingStyle, easingDirection)

	local goal: CFrame?

	maid:GiveTask(STEP_SIGNAL:Connect(function(deltaTime: number): ()
		if goal then
			if IS_VERBOSE then print(`\nattempting solve`) end
			local originTransform, middleTransform, finalTransform = getLimbGoals(character, goal, detatchToReachGoal, upperLimbMotorName, lowerLimbMotorName, finalLimbMotorName)
			if originTransform and middleTransform and finalTransform then
				upperLimbController(originTransform)
				lowerLimbController(middleTransform)
				finalLimbController(finalTransform)
				return nil
			end
			if IS_VERBOSE then print(`solve failed`) end
		else
			if IS_VERBOSE then print(`no goal`) end
		end
		upperLimbController(nil)
		lowerLimbController(nil)
		finalLimbController(nil)
	end))

	return function(aim: CFrame?)
		if IS_VERBOSE then print(`updating aim`) end
		goal = aim
	end
end

return InverseKinematicsUtil