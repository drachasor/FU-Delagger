require "/objects/generic/apiary_common.lua"
require "/objects/generic/digitalstorage_transfers.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"

local deltaTime=0

local _init = init
function init()
  if _init then
    _init()
  end
	--sb.logInfo("loaded");
	self._limiter = ClockLimiter();
	self._tasks = TaskOperator("Queue",self._limiter,function() DigitalNetworkFailsafeShutdown(); end);
	self.avoidSlots = config.getParameter("AvoidSlots", 1)
	self.worlddropiffull = false

	self.productionTime = 0
	self.outputTime = 0
	script.setUpdateDelta(15 + sb.staticRandomI32Range(0, 10, sb.makeUuid()));
	if storage.outputData then
		self.outputData = deserialize_itemTable(storage.outputData)
		--sb.logInfo("Resuming Crafting");
	else
		self.outputData = ItemsTable(false)
	end

end

function flowerCheck()
	local flowers
	local noFlowersYet = self.beePower 			

	for i, p in pairs(self.config.flowers) do
		flowers = world.objectQuery(entity.position(), 80, {name = p})
		if flowers ~= nil then
			self.beePower = self.beePower + math.min(#flowers,10)
		end
	end
	
	if self.beePower == noFlowersYet then
		self.beePower = -1				
	elseif self.beePower >= 60 then
		self.beePower = 60
	end

	local beePowerSay = "FC:bP = " .. self.beePower
	local location = entity.position()
	world.debugText(beePowerSay,{location[1],location[2]+1.5},"orange")
	-- object.say(beePowerSay)
end

function trySpawnDrone(chance,type,amount)
	local _amount = amount or 1

	if self.doDrones and math.random(100) <= 100 * chance then
		local bonus, reduce = droneStarter()
		if reduce then
			world.containerConsume(entity.id(), {name =type .. "drone", count = math.random(5), data={}})
		end
		amount = amount or (math.random(2) + bonus)
		self.outputData:Add(Item({ name=type .. "drone", count = _amount, parameters={}}), true)
		self.doDrones = false
	end
end


function trySpawnMutantDrone(chance,type,amount)
	local _amount = amount or 1

	if self.doDrones and math.random(100) <= 100 * (chance + self.mutationIncrease) then
		self.outputData:Add(Item({ name=type .. "drone", count = _amount, parameters={}}), true)
		self.doDrones = false -- why was this doItems?
	end
end


function trySpawnItems(chance,type,amount)
	-- analog to trySpawnBee() for items (like goldensand)
	local _amount = amount or 1

	if self.doItems and math.random(100) <= 100 * chance then
		self.outputData:Add(Item({ name=type, count = _amount, parameters={}}), true)
		self.doItems = false
	end
end


function trySpawnHoney(chance,honeyType,amount)
	local _amount = amount or 1

	if not self.doHoney then return nil end  --if the apiary isn't spawning honey, do nothing
	amount = amount or 1  --- if not specified, just spawn 1 honeycomb.
	local flowerIds = world.objectQuery(entity.position(), 25, {name="beeflower", order="nearest"})  --find all flowers within range

	if (math.random(100) / (#flowerIds * 3 + 100) ) <= chance then   --- The more flowers in range, the more likely honey is to spawn. Honey still spawns 1 at a time, at the same interval
		self.outputData:Add(Item({ name=honeyType .. "comb", count = _amount + self.honeyAmount, parameters={}}), true)
		self.doHoney = false
	end
end
--[[]
function expelQueens(type)   ---Checks how many queens are in the apiary, either under the first or second bee slot, and removes all but 1. The rest will be dropped on the ground. Only functions when the apiary is working.
	contents = world.containerItems(entity.id())
	local queenLocate = type .. "queen"  ---Input the used bee type, and create a string such as "normal" .. "queen" = "normalqueen"

	local slot = nil
	if contents[self.queenSlot].name == queenLocate then	
		slot = self.queenSlot
	elseif contents[self.droneSlot].name == queenLocate then	
		slot = self.droneSlot
	end

	if slot and contents[slot].count > 1 then								---how many queens, exactly?
		local queenname = contents[slot].name								---sets the variable queenname to be use for queen removal
		local queenremoval = (contents[slot].count - 1) 						---How many queens are we removing?
		world.containerConsumeAt(entity.id(), slot - 1, queenremoval)  					---PEACE OUT, YA QUEENS -- slot-1 because of indexing differences (Lua's from 1 v. Starbound internal from 0)
		world.spawnItem(queenname, object.toAbsolutePosition({ 1, 2 }), queenremoval)			--- Oh, hi. Why are you on the ground? SHE THREW YOU OUT? THAT BITCH!
	end
end
]]

function beeSting()
	if math.random(100) < 100 * self.beeStingChance then
		local location = entity.position()
		if self.beeStingOffset then
			world.spawnProjectile("stingstatusprojectile", { location[1] + self.beeStingOffset[1], location[2] + self.beeStingOffset[2]}, entity.id())
		else
			world.spawnProjectile("stingstatusprojectile", location, entity.id())
		end
	end
end

function old_update(dt)
	updateTotalMites()

		if not deltaTime or (deltaTime > 1) then
				deltaTime=0
		if self.totalMites and self.totalMites>0 then
			transferUtil.unloadSelfContainer()
		else
			transferUtil.loadSelfContainer()
		end
		else
				deltaTime=deltaTime+dt
		end
	contents = world.containerItems(entity.id())
	daytimeCheck()

	if not contents[self.queenSlot] or not contents[self.droneSlot] then
		-- removing bees will reset the timers
		if self.beePower ~= 0 then
			reset()
		else
			animator.setAnimationState("bees", "off")
			return
		end
	end

	frame() 	--Checks to see if a frame in installed.
	flowerCheck()   -- checks flowers
	deciding()


	if not self.doBees and not self.doItems and not self.doHoney and not self.doDrones then
		-- no need to search for the bees if there is nothing to do with them
		if self.beePower > 0 then
			self.beePower = 0
		elseif self.beePower < 0 then
			animator.setAnimationState("bees", "off")
			return
		end
	end

	miteInfection()	-- Try to spawn mites.

	if not workingBees() then
		-- If bees aren't a match, check to see if the bee types are meant for breeding.
		breedingBees()
	end

	setAnimationState()
end

local _update = update;
function update(dt)
	--sb.logInfo("starting update")
	self._limiter:Restart();
	if self._tasks:HasTasks() then
		--sb.logInfo("have tasks")
		self._tasks:Launch();
		script.setUpdateDelta(1);
	else
		--sb.logInfo("no tasks")
		self.productionTime = self.productionTime + dt
		if (self.outputTime > 10) then
			--sb.logInfo("time for output")
			self.outputTime = self.outputTime - 10 + dt
			if self.outputData:GetItemsCount() > 0 and not self._tasks:HasTasks() then
				--sb.logInfo("no tasks, making one for output?")
				if DigitalNetworkHasOneController() then
					--sb.logInfo("making task, connected to controller")
					self._tasks:AddTask(Task(coroutine.create(transferTask)));
					script.setUpdateDelta(1);
				else
					--sb.logInfo("No controller, outputting to self")
					outputTableToSelf()
				end
			end
		else
			--sb.logInfo("not time for output")
			self.outputTime  = self.outputTime + dt
			script.setUpdateDelta(15 + sb.staticRandomI32Range(0, 10, sb.makeUuid()));
		end
		if self.productionTime > 2.33 then
			--sb.logInfo("time to produce")
			script.setUpdateDelta(15 + sb.staticRandomI32Range(0, 10, sb.makeUuid()));
			self.productionTime = self.productionTime - 2.33

			--Update
			_update(dt)
			--Update Done

			if (deltaTime > 1) then
				--sb.logInfo("backing up output")
				storage.outputData = serialize_itemTable(self.outputData)
			end
		end
	end
end

local _transferTask = transferTask
function transferTask()
	_transferTask()
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
		script.setUpdateDelta(15 + sb.staticRandomI32Range(0, 10, sb.makeUuid()));
	end
end
