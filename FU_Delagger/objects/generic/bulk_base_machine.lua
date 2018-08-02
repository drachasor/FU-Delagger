require "/objects/generic/digitalstorage_transfers.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require '/scripts/power.lua'
require "/scripts/delagger_utils.lua"
--[[
	Function Groupings For Reference
	--Inputs, Outputs, Recipes
	--Restore Progress
	--Initialization
	--Script Update Functions
	--Task Functions
	--Timing Functions
	--Crafting Animation
	--Save/Advance Progress
	--Restore Progress
	--Power Use
	--Update


	Use:
	Overrides need to be done at least for:
	getOutputs() -- this or getInputs must set self.timer

	If there are recipes and inputs, also override:
	getInputs()  - must return true when recipe found with ingredients
	GetRecipes()

	Animation Overrides:
	CraftingAnimationOn() -- turn on crafting animation
	CraftingAnimationStalled() -- crafting animation for when progess stalled for some reason
	function CraftingAnimationOff() -- turn off crafting animation

	Additonal Overrides:
	AdditionalInits() - other things to do during init()

	AdditionalProgressSave() --override with anything else to be saved
	AdditionalProgressDefault() -- override with things to do when no progress to be saved

	AdditionalProgressLoad() - override with anything else to be loaded when restoring progress
	AdditionalProgressLoadDefaults() - defaults to no load when no progress to restore
]]
--Inputs, Outputs, Recipes
function getInputs()
	return true
	--to be overridden if inputs need to be checked
end

function getOutputs()
	return true
	--to be overridden, starts crafting if it returns true.
	--No work or consumption should be started before this function
end

function GetRecipes()
	--overridden if recipes need to be set
end

--Initialization

function SetPowered()
	--overridden if some other way of determining if device is powered
	if config.getParameter('powertype') then
		power.init()
		self.powerMJS = config.getParameter('isn_requiredPower')
		self.needspower = true
	else
		self.powerMJS = 0
		self.needspower = false
	end
end

function AdditionalInits()
	--overridden for additional inits
end

function constantInits()

	self._limiter = ClockLimiter();
	self._tasks = TaskOperator("Queue",self._limiter,function() DigitalNetworkFailsafeShutdown(); end);
	self.firstOutputSlot = config.getParameter("FirstOutputSlot") or 0
	self.scriptDeltaTable = config.getParameter("ScriptDeltaTable",1)[1]
	self.worlddropiffull = config.getParameter("WorldDropIfFull")
	self.speedIncrease = config.getParameter("SpeedIncrease", 1)
	self.speed = 1
	self.maxBulkMult = config.getParameter("BulkMult", 1) or 30;
	self.deltaTime = 0
	--transferUtil.init() -- grandfathered in from FU scripts
	
end

function init()
	self.loadcomplete = false
	constantInits()
	AdditionalInits()
	setScriptUpdate()
end

--Script Update Functions
function setScriptUpdate()
	script.setUpdateDelta(
		self.scriptDeltaTable.base +
		sb.staticRandomI32Range(
			self.scriptDeltaTable.randMin,
			self.scriptDeltaTable.randMax,
			sb.makeUuid()
		)
	)
end

--Task Functions
function LaunchTasks()
	self._tasks:Launch();
	script.setUpdateDelta(1);
end

function MakeTasks()
	self._tasks:AddTask(Task(coroutine.create(transferTask)));
	CraftingAnimationOff()
	script.setUpdateDelta(1);
end

--Timing Functions

function setShortTimer()
	self.timer = .01
end

function setTimer()
	self.timer = (self.timer or 0) + self.bulkMult
end

--Crafting Animation

function CraftingAnimationOn()
	--override with turning on crafting animation details
end

function CraftingAnimationStalled()
	--override with crafting animation for when progess stalled for some reason
end


function CraftingAnimationOff()
	--override with turning off crafting animation details
end

--Save/Advance Progress

function advanceProgress(saverate, dt)
	if self.deltaTime > saverate then
		self.deltaTime=self.deltaTime - saverate + dt
		--transferUtil.loadSelfContainer() -- from FU
		self.speed = self.speed + self.speedIncrease
		storage.timer = self.timer
		storage.speed = self.speed
		AdditionalProgressSave()
	else
		self.deltaTime = self.deltaTime + dt
		AdditionalProgressDefault()
	end
	
end

function AdditionalProgressSave()
	--override with anything else to be loaded
end

function AdditionalProgressDefault()
	--override with anything else in the default
end

--Restore Progress

function loadProgress()
	if storage.outputData then
		--sb.logInfo("init: load saved")
		self.running = true
		self.timer = storage.timer
		self.speed = storage.speed
		self.outputData = deserialize_itemTable(storage.outputData)
		self.inputData = ItemsTable(false)
		AdditionalProgressLoad()
	else
		--sb.logInfo("init: load defaults")
		self.outputData = ItemsTable(false)
		self.inputData = ItemsTable(false)
		self.speed = 1
		self.running = false
		setShortTimer()
		AdditionalProgressLoadDefaults()
	end
end

function AdditionalProgressLoad()
	--override with anything else to be loaded
end

function AdditionalProgressLoadDefaults()
	--override with anything else to give default values to
end

--Power Use
function GetPower(dt)
	if dt > 2 then
		--if for some reason more than 2 seconds have passed, something odd has happened
		--sb.logInfo("More time than expected passed (over 2 seconds) between power grabs")
		dt = 2
	end
	if self.needspower and self.running then
		--sb.logInfo("needs power and running")
		self.dowork = power.consume(self.powerMJS * dt)
		if self.dowork then
			--sb.logInfo("Doing Work")
			if not self.haspower then
				-- if we didn't have power, now we do, so turn on crafting animation
				self.haspower = true
				CraftingAnimationOn()
			end
		else
			--sb.logInfo("lacks power and running")
			self.haspower = false
			CraftingAnimationStalled()
		end
	elseif not self.needspower and self.running then
		--sb.logInfo("Doesn't need power and running")
		self.dowork = true
	else
		self.dowork = false
		--don't change timer if we are working and have no power
	end
end

--Update

function update(dt)
	if not self.loadcomplete then
		loadProgress()
		SetPowered()
		GetRecipes()
		self.loadcomplete = true
	end

	self._limiter:Restart()
		--self._tasks:Restart();
	--sb.logInfo("update")
	advanceProgress(1, dt)
	--[[
		advanceProgress saves progress ever X seconds, where X is the number passed to it
	In delagger_utils.lua
		Also every X seconds:
		Increments speed by self.speed + self.speedIncreass
		Otherwise:
		Increments deltatime
	Always: Decrements self.timer by dt*self.speed
	]]

	if self._tasks:HasTasks() then
		--sb.logInfo("launch tasks")
		LaunchTasks() -- launches tasks, sets script updatedelta to 1
	else
		if self.running then
			GetPower(dt)
			if self.dowork then
				--sb.logInfo("Running, have power, advancing timer")
				self.timer = self.timer - dt * self.speed
			end
		else
			--sb.logInfo("Not running, advancing timer")
			self.timer = self.timer - dt
		end

		if self.timer <= 0 then
				-- only grab more power if no tasks
				--updates setting on self.do_work
			--sb.logInfo("time to do stuff")
			--sb.logInfo(tostring(self.outputData))
			if self.dowork then
				--sb.logInfo("work done")
				--This means we have completed current work
				self.running = false -- no longer need power
				self.dowork = false -- no longer doing work

				CraftingAnimationOff()
				if DigitalNetworkHasOneController() then
					--sb.logInfo("on DS network")
					MakeTasks()
				else
					--sb.logInfo("there is no DS network")
					outputTableToSelf()
				end
			elseif self.running then
				--sb.logInfo("processing")
				--if running, but no dowork, that means no power
				--currently do nothing
			else
				--Not running, which means we need to get work to do
				setScriptUpdate()
				--sb.logInfo("time for inputs")
				if getInputs() then
					self.running = true
					if getOutputs() then
						CraftingAnimationOn() -- we're crafting!
					else
						self.running = false
					end
				else
					setShortTimer() --start time over
				end
			end
		end
	end
end

local _outputTableToSelf = outputTableToSelf
function outputTableToSelf()
	_outputTableToSelf()
	setShortTimer()
end

local _transferTask = transferTask
function transferTask()
	_transferTask()
	setShortTimer()
end

function DigitalNetworkPreUpdateControllers(count, mode)
	if count == 1 then
		self._tasks:RemoveTasks();
		outputTableToSelf()
		--sb.logInfo("ds prepostupdate")
	end
end
function DigitalNetworkPostUpdateControllers(count, mode)
	if count == 1 then
		--sb.logInfo("ds postupdate")
		setScriptUpdate()
	end
end
