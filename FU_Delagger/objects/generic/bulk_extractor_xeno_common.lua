require "/objects/generic/digitalstorage_transfers.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/objects/generic/extractor_xeno_common.lua"

local recipes
local deltaTime=0

local _init = init
function init()
	if _init then
		_init()
		self._limiter = ClockLimiter();
		self._tasks = TaskOperator("Queue",self._limiter,function() DigitalNetworkFailsafeShutdown(); end);
		self.firstOutputSlot = config.getParameter("FirstOutputSlot")
		self.worlddropiffull = true

		self.speedincrease = config.getParameter("SpeedIncrease", 1)
		self.speed = 1

		self.inputData = ItemsTable(false)
		if storage.bulkmode then
			self.bulkmode = storage.bulkmode
		else
			self.bulkmode = true
		end

		if storage.outputData then
			self.bulkMult = storage.mult
			self.timer = storage.timer
			self.outputData = deserialize_itemTable(storage.outputData)
			--sb.logInfo("Resuming Crafting");
			CraftingAnimationOn()
		else
			self.outputData = ItemsTable(false)
		end
		--[[if storage.outputData then
			self.outputData = storage.outputData
		else
			self.outputData = ItemsTable(false)
		end--]]
	end
end

function setInputs(result, max_mult)
	--sb.logInfo("inputoutputs")
	for inItem, v in pairs(result.inputs) do
		-- if we ever do multiple inputs, FIXME undo partial consumption on failure
		local input_available = world.containerAvailable(entity.id(),{item = inItem})
		if (input_available >= techlevelMap(v)) and
				(not powered or power.consume(config.getParameter('isn_requiredPower'))) then
			self.bulkMult = math.min
				(
					max_mult,
					math.floor
					(
						input_available / tonumber(techlevelMap(v))
					)
				)
			--sb.logInfo(inItem);
			--sb.logInfo(tostring(self.bulkMult));
			--
			local inputItem = Item
			(
				{
					name = inItem, 
					count = tonumber(techlevelMap(v)) * self.bulkMult, 
					parameters = {}
				}, 
				true
			)
			self.inputData:Add(inputItem)
		else
			--sb.logInfo("inputoutputs are false")
			self.inputData = ItemsTable(false)
			return false
		end
	end
	return true
end

function setOutputs(result)
	--sb.logInfo("inputoutputs")
	local output = result.outputs
		for outItem,w in pairs(output) do
			--sb.logInfo(outItem);
			--sb.logInfo(w)
			--sb.logInfo(tostring(techlevelMap(w)))
			--sb.logInfo(tostring(self.bulkMult))
			--sb.logInfo(tostring(techlevelMap(w) * self.bulkMult))
			local outputItem = Item({name = outItem, count = tonumber(techlevelMap(w)) * self.bulkMult, parameters = {}}, true)
			self.outputData:Add(outputItem)
			--self.outputData[outItem] = {name = outItem, count = tonumber(techlevelMap(w)) * self.bulkMult}
		end
end

function CraftingAnimationOn()
	animator.setAnimationState("samplingarrayanim", "working")
	if self.light then
		object.setLightColor(self.light)
	end
	storage.activeConsumption = true
end

function CraftingAnimationOff()
	animator.setAnimationState("samplingarrayanim", "idle")
	if self.light then
		object.setLightColor({0, 0, 0, 0})
	end
	self.timer = self.mintick
	storage.activeConsumption = false
end

function startCrafting(result)
	if next(result) == nil then
		return false
	else
		--sb.logInfo("recipe found, crafting function");
		self.speed = 1
		_, result = next(result)
		if setInputs(result,30) then
			setOutputs(result)
			for _, item in pairs(self.inputData:GetFlattened()) do
				world.containerConsume(entity.id(),item.ItemDescriptor)
			end
			self.inputData = ItemsTable(false)
			storage.mult = self.bulkMult
			storage.outputData = serialize_itemTable(self.outputData)
			--sb.logInfo(storage.outputData)
		end
		--[[
		for k, v in pairs(result.inputs) do
			-- if we ever do multiple inputs, FIXME undo partial consumption on failure
			if not (world.containerAvailable(entity.id(),{item = k}) >= techlevelMap(v) and 
					(not powered or power.consume(config.getParameter('isn_requiredPower'))) and 
					world.containerConsume(entity.id(), {item = k , count = techlevelMap(v)})) then
				return false
			end
		end
		]]
        self.timerMod = config.getParameter("fu_timerMod")
		self.timer = self.bulkMult * (((techlevelMap(result.timeScale) or 1) * getTimer(self.techLevel)) + self.timerMod)
		CraftingAnimationOn()
		storage.timer = self.timer
		--sb.logInfo("crafting");
		return true
	end			  
end

function update(dt)
	self._limiter:Restart();
  	--self._tasks:Restart();
	if not self.mintick then init() end
	if deltaTime > 1 then
		storage.timer = self.timer
		deltaTime=0
		transferUtil.loadSelfContainer()
		self.speed = self.speed + self.speedincrease
	else
		deltaTime=deltaTime+dt
	end
	self.timer = self.timer - dt * self.speed
	if self._tasks:HasTasks() then
		--sb.logInfo("launch tasks")
		self._tasks:Launch();
		script.setUpdateDelta(1);
	elseif self.timer <= 0 then
		--sb.logInfo("time to do stuff")
		--sb.logInfo(tostring(self.outputData))
		if self.outputData:GetItemsCount() > 0 then
			--sb.logInfo("time for outputs")
			if DigitalNetworkHasOneController() then
				--sb.logInfo("on DS network")
				self._tasks:AddTask(Task(coroutine.create(transferTask)));
				CraftingAnimationOff()
				script.setUpdateDelta(1);
			else
				--sb.logInfo("there is no DS network")
				outputTableToSelf()
			end
		else
			script.setUpdateDelta(5);
			--sb.logInfo("time for inputs")
			if not startCrafting(getValidRecipes(getInputContents())) then
				--sb.logInfo("no crafting")
				CraftingAnimationOff()
			end
		end
	end
	if powered then
	  power.update(dt)
	end
end

local _outputTableToSelf = outputTableToSelf
function outputTableToSelf()
	_outputTableToSelf()
	self.bulkMult = 1
	self.timer = self.mintick 
end

local _transferTask = transferTask
function transferTask()
	_transferTask()
	self.bulkMult = 1
	self.timer = self.mintick
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
		script.setUpdateDelta(5);
	end
end

