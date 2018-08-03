require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/objects/generic/digitalstorage_transfers.lua"
require "/HLib/Classes/Other/LoadData.lua"
require "/HLib/Classes/Other/Messenger.lua"

local contents
DEFAULT_HONEY_CHANCE = 0.6
DEFAULT_OFFSPRING_CHANCE = 0.4

--  CONCEPTUAL STUFF
--local lastTimeEdited = os.clock()
--if os.clock() >= lastTimeEdited + timeDiff then
-- do your update conditions.
--end
--use the above to track time for bee maturation while player isnt present
--

function initUniversalConfigData()

	self.spawnDelay = config.getParameter("spawnDelay")				-- A global spawn rate multiplier. Higher is slower.
	self.spawnBeeBrake = config.getParameter("spawnBeeBrake")   	-- Individual spawn rates. Set to nil if none to be spawned.
	self.spawnItemBrake = config.getParameter("spawnItemBrake")		--
	self.spawnHoneyBrake = config.getParameter("spawnHoneyBrake")	--
	self.spawnDroneBrake = config.getParameter("spawnDroneBrake")	--
	self.firstOutputSlot = config.getParameter("FirstOutputSlot") or 0
	self.spawnWait = self.spawnBeeBrake * self.spawnDelay
	self.droneWait = self.spawnDelay * self.spawnDroneBrake
	self.itemWait = self.spawnDelay * self.spawnItemBrake
	self.honeyWait = self.spawnDelay * self.spawnHoneyBrake
	self.honeyAmount = 0
	self.limitDroneCount = config.getParameter("limitDroneCount")	-- whether to limit the number of drones
	self.beeStingChance = config.getParameter("beeStingChance")		-- chance of being stung by the aggressive varieties
	self.beeStingOffset = config.getParameter("beeStingOffset")		-- spawn offset of the sting object (0,0 if not set)
	self.beePowerScaling = config.getParameter("beePowerScaling")	-- scaling factor for cooldown modification in deciding()
	self.miteReduction = config.getParameter("miteReduction",0)
    self.mitePenalty = config.getParameter("mitePenalty",0)
	self.mutationMultiplier = config.getParameter("mutationMultiplier",0)
	self.config = root.assetJson('/objects/bees/apiaries.config')	-- common apiaries configuration
	self.functions = { chooseMinerHoney = chooseMinerHoney, chooseMinerOffspring = chooseMinerOffspring }
end

function initSlotData()
	--to be overriden, for bee and frame slots
end

function initloadAdditional()
end

function getHives()
	--[[
		to be overriden
		Must return table {}
		entries in the form of
		hive1.beeslot1
		hive1.beeslot2
		hive1.frameSlots
	]]
	return {}
end

function initHives()
	self.hives = getHives()
	for i,hive in ipairs(self.hives) do
		hive.cooldowns =
		{
			beeSpawn = 0,
			drone = 0,
			item = 0,
			honey = 0
		}
		hive.actions = {
			doBees = false,
			doDrones = false,
			doItems = false,
			doHoney = false
		}
	end

end

function init()
	animator.setAnimationState("bees", "off")

	initUniversalConfigData()
	initHives()
	initSlotData()
	initloadAdditional()
	self._limiter = ClockLimiter();
	self._tasks = TaskOperator("Queue",self._limiter,function() DigitalNetworkFailsafeShutdown(); end);
	self.worlddropiffull = false

	self.deltaTime=0
	self.productionTime = 0
	self.outputTime = 0
	script.setUpdateDelta(15 + sb.staticRandomI32Range(0, 10, sb.makeUuid()));
	storage.catchBees = storage.catchBees or false
	if storage.outputData then
		self.outputData = deserialize_itemTable(storage.outputData)
		--sb.logInfo("Resuming Crafting");
	else
		self.outputData = ItemsTable(false)
	end
	initAntimiteFrames()
	reset()
end

function initAntimiteFrames()
	self.antimiteFrames = {}
	for frame, mods in pairs(self.config.modifiers) do
		if mods.antimite then
			self.antimiteFrames[frame] = true
		end	
	end
end

function deciding(hive)
	--[[
	cooldowns.beeSpawn
	cooldowns.drone
	cooldowns.item
	cooldowns.honey

	modifiers.honey
	modifiers.drone
	modifiers.item
	modifiers.hivePower

	returns
	actions.doBees
	actions.doDrones
	actions.doItems
	actions.doHoney
	]]
	--local location = entity.position()
	--world.debugText("H:" .. (self.spawnHoneyCooldown or 'nil').. "/I:" .. (self.spawnItemCooldown or 'nil') .. "/D:" .. (self.spawnDroneCooldown or 'nil') .. "/B:" .. (self.spawnBeeCooldown or 'nil'),{location[1],location[2]-0.5},"orange")
	-- object.say("H:" .. self.spawnHoneyCooldown .. "/I:" .. self.spawnItemCooldown .. "/ D:" .. self.spawnDroneCooldown .. "/B:" .. self.spawnBeeCooldown)

	-- counting down and looking for events like spawning a bee, an item or honey
	-- also applies the effects if something has to spawn (increasing cooldown, slowing things down)
	-- if any brake is false, no spawn and no cooldown for that type
	
	-- FIXME: beeModifier?

	local totalBeePower = (self.beePower + hive.power) * self.beePowerScaling      ---beepower sets how much the cool down reduces each tick.

	if self.spawnWait then
		if hive.cooldowns.beeSpawn <= 0 then
			if not storage.catchBees then -- only do the break if there's no bee gun
				self.spawnWait = self.spawnWait * 2   	---each time a bee is spawned, the next bee takes longer, unless the world reloads. (Reduce Lag)
			end
			hive.actions.doBees = true
			hive.cooldowns.beeSpawn = self.spawnWait - hive.modifiers.honey   ----these self.xModifiers reduce the cooldown by a static amount, only increased by frames.
		else
			hive.actions.doBees = false
			hive.cooldowns.beeSpawn = hive.cooldowns.beeSpawn - totalBeePower
		end
	end
	if hive.cooldowns.drone <= 0 then
		hive.actions.doDrones = true
		hive.cooldowns.drone= ( self.droneWait ) - hive.modifiers.drone
	else
		hive.actions.doDrones = false
		hive.cooldowns.drone = hive.cooldowns.drone- totalBeePower
	end

	if hive.cooldowns.item <= 0 then
		hive.actions.doItems = true
		hive.cooldowns.item = self.itemWait - hive.modifiers.item
	else
		hive.actions.doItems = false
		hive.cooldowns.item = hive.cooldowns.item - totalBeePower
	end

	if hive.cooldowns.honey <= 0 then
		hive.actions.doHoney = true
		hive.cooldowns.honey = self.honeyWait - hive.modifiers.honey
	else
		hive.actions.doHoney= false
		hive.cooldowns.honey = hive.cooldowns.honey - totalBeePower
	end
end


function reset()   ---When bees are not present, this sets a slightly increased timer for when bees are added again.
	self.beePower = 0
	--contents = world.containerItems(entity.id())
end


function frame(hive)
	--[[
		modifiers.honey
		modifiers.drone
		modifiers.item
		modifiers.mutationIncrease
		modifiers.antimite
		modifiers.combs
	]]
	local mods = { combs = {} }

	for key, slot in ipairs(hive.frameSlots) do
		apiary_doFrame(mods, world.containerItemAt(entity.id(),slot - 1))
	end
	hive.modifiers.drone = mods.droneModifier or 0
	hive.modifiers.honey = mods.honeyModifier or 0
	hive.modifiers.item = mods.itemModifier or 0
	hive.modifiers.mutationIncrease = mods.mutationIncrease or 0
	hive.modifiers.antimite = mods.antimite

	if mods.forceTime and mods.forceTime ~= 0 then
		hive.modifiers.daytime = mods.forceTime > 0
		--sb.logInfo("Force Daytime is " .. tostring(hive.modifiers.daytime))
	end

	hive.modifiers.combs = mods.combs
--[[
	sb.logInfo ('apiary ' .. entity.id() .. ': drone ' .. self.droneModifier .. ', honey ' .. self.honeyModifier .. ', item ' .. self.itemModifier .. ', muta ' .. self.mutationIncrease)
	for key, slot in ipairs(self.frameSlots) fo
		if contents[slot] then sb.logInfo ('apiary ' .. entity.id() .. ' contains ' .. contents[slot].name) end
	end
--]]
end


function apiary_doFrame(mods, item)
--- Check the type of frame. Adjust variables-------------
--- A 600 cooldown, with 30 beepower, is now reduced to a 570 cooldown. 30 beepower = 60 reduced per second, or 9.5 seconds, instead of 10.
	if item and item.name then
		local patch

		-- Production rate modifiers etc.
		patch = self.config.modifiers[item.name]
		if patch then
			for key, value in pairs(patch) do
				if not value or value == true then
					mods[key] = value
				else
					mods[key] = (mods[key] or 0) + value
				end
			end
		end

		-- Miner bees' ore combs
		patch = self.config.ores[item.name]
		if patch then
			mods.combs[patch] = (mods.combs[patch] or 0) + 1
		end
	end
end


function splitQueenDrone(s)
	
	if s:len() > 5 then
		local beeclass = s:sub(-5)
		if beeclass == 'drone' or beeclass == 'queen' then
			local beetype = s:sub(1,-6)
			return {name=s,type=beetype,class=beeclass}
		end
	end
	return nil
end

function getEquippedBees(hive)

	local bee1item = world.containerItemAt(entity.id(),hive.bee1Slot - 1)
	local bee2item = world.containerItemAt(entity.id(),hive.bee2Slot - 1)
	--[[
	sb.logInfo("Slot 1: " .. tostring(hive.bee1Slot))
	sb.logInfo("Slot 2: " .. tostring(hive.bee2Slot))
	for i=0,8 do
		local item = world.containerItemAt(entity.id(),i)
		local name = "nothing"
		if item then name = item.name end
		sb.logInfo("Slot " .. tostring(i) .. " item: " .. name)
	end
	]]
	local bee1 = bee1item and splitQueenDrone(bee1item.name)
	local bee2 = bee2item and splitQueenDrone(bee2item.name)
	if not bee1 or not bee2 then
		hive.queen = nil
		hive.drone = nil
		hive.power = 0
		return
	end -- nothing there

	--local bee1 = bee1item and splitQueenDrone(bee1item.name)
	bee1.slot = hive.bee1Slot
	bee1.item = bee1item
	--local bee2 = bee2item and splitQueenDrone(bee2item.name)
	bee2.slot = hive.bee2Slot
	bee2.item = bee2item

	if bee1.class == "queen" and bee2.class == "drone" then		
		hive.queen = bee1
		hive.drone = bee2
	elseif bee1.class == "drone" and bee2.class == "queen" then
		hive.queen = bee2
		hive.drone = bee1
	else
		hive.power = 0 -- default	
		hive.queen = nil
		hive.drone = nil
		return
	end
	hive.power = math.ceil(math.sqrt(hive.drone.item.count) + 10)

	expelQueens(hive.queen.slot)
end


function spaceForBees()
	local bees = world.monsterQuery(entity.position(), 25, { callScript = 'getClass', callScriptResult = 'bee' })
	local apiaries = world.entityQuery(entity.position(), 25, { withoutEntityId = entity.id(), callScript = 'getClass', callScriptResult = 'apiary' })
	return #bees < 15 + 2 * #apiaries
end


function getClass()
	return 'apiary'
end

function trySpawnBee(hive,chance)
	-- tries to spawn bees if we haven't in this round
	-- Type is normally things "normal" or "bone", as the code inputs them in workingBees() or breedingBees(), this function uses them to spawn bee monsters. "normalbee" for example.
	-- chance is a float value between 0.00 (will never spawn) and 1.00 (will always spawn)
	if hive.actions.doBees and math.random(100) <= 100 * chance and spaceForBees() then
		if storage.catchBees then
			local chance = math.random()
			local bee
			if chance < .5 then
				bee = hive.species .. "drone"
			else
				bee = hive.species .. "queen"
			end
			self.outputData:Add(Item({ name=bee, count = 1, parameters={}}), true)
		else
			world.spawnMonster(hive.species .. "bee", object.toAbsolutePosition({ 2, 3 }), { level = 1 })
		end
		hive.actions.doBees = false
	end
	return true
end


function trySpawnMutantBee(hive,chance)
	if doBees and math.random(100) <= 100 * (chance + self.mutationIncrease) and spaceForBees() then
		if storage.catchBees then
			local chance = math.random()
			local bee
			if chance < .5 then
				bee = hive.species .. "drone"
			else
				bee = hive.species .. "queen"
			end
			self.outputData:Add(Item({ name=bee, count = 1, parameters={}}), true)
		else
			world.spawnMonster(hive.species .. "bee", object.toAbsolutePosition({ 2, 3 }), { level = 1 })
		end
		--self.doBees = false
		return false
	end
	return true
end

function trySpawnDrone(hive,chance)
	if hive.actions.doDrones and math.random(100) <= 100 * chance then
		local bonus, reduce = droneStarter(hive.drone)
		if reduce then
			world.containerConsume(entity.id(), {name =hive.drone.name, count = math.random(5), data={}})
		end
		amount = amount or (math.random(2) + bonus)
		if hive.drone.item.count < 1000 then
			world.containerPutItemsAt(entity.id(), {name=drone.name,count=amount}, hive.drone.slot - 1)
		else
			self.outputData:Add(Item({ name=hive.drone.name, count = amount, parameters={}}), true)
		end
		return false
	end
	return true
end


function trySpawnMutantDrone(hive,chance,amount)
	local _amount = amount or 1
	if hive.actions.doDrones and math.random(100) <= 100 * (chance + self.mutationIncrease) then
		self.outputData:Add(Item({ name=hive.species .. "drone", count = _amount, parameters={}}), true)
		return false
	end
	return true
end


function trySpawnItems(hive, chance,type,amount)
	-- analog to trySpawnBee() for items (like goldensand)
	local _amount = amount or 1
	if hive.actions.doItems and math.random(100) <= 100 * chance then
		self.outputData:Add(Item({ name=type, count = _amount, parameters={}}), true)
		return false
	end
	return true
end


function trySpawnHoney(hive,chance,honeyType,amount)
	local _amount = amount or 1

	if not hive.actions.doHoney then return nil end  --if the apiary isn't spawning honey, do nothing
	amount = amount or 1  --- if not specified, just spawn 1 honeycomb.
	local flowerIds = world.objectQuery(entity.position(), 25, {name="beeflower", order="nearest"})  --find all flowers within range

	if (math.random(100) / (#flowerIds * 3 + 100) ) <= chance then   --- The more flowers in range, the more likely honey is to spawn. Honey still spawns 1 at a time, at the same interval
		self.outputData:Add(Item({ name=honeyType .. "comb", count = _amount + self.honeyAmount, parameters={}}), true)
		return false
	end
	return true
end


function droneStarter(droneinfo)
	-- Spawn more drones in newer apiaries.
	-- Drone QTY:  1-40       41-80
	-- Spawn QTY:  +2         +1     (This adds to the function trySpawnDrone: amount)
	local bonus, reduce = 0, false
	drone = world.containerItemAt(entity.id(),droneinfo.slot - 1)
	if drone then
		--local beeQuanity = (drone.count)      -- I subtracted 1 since the queen inflates the total. Keep in mind either slot could be drones, easiest to add them and then subtract.
		if drone.count < 81 then
			bonus = math.ceil((81 - drone.count) / 40)
		elseif self.limitDroneCount == true and drone.count > 200 then
			reduce = true
		end
	end

	return bonus, reduce
end

function expelQueens(queenslot)   ---Checks how many queens are in the apiary, either under the first or second bee slot, and removes all but 1. The rest will be dropped on the ground. Only functions when the apiary is working.

	queen = world.containerItemAt(entity.id(),queenslot - 1)
	if queen then
		if queenslot and queen.count > 1 then
			local queenremoval = (queen.count - 1)
			world.containerConsumeAt(entity.id(), queenslot - 1, queenremoval)
			world.spawnItem(queen.name, object.toAbsolutePosition({ 1, 2 }), queenremoval)
		end
	end
end

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

function vegetableCheck()
	local vegetables
	local noFlowersYet = self.beePower 			

	for i, p in pairs(self.config.vegetables) do
		vegetables = world.objectQuery(entity.position(), 80, {name = p})
		if vegetables ~= nil then
			self.beePower = self.beePower + math.ceil(math.sqrt(#vegetables) / 2)
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

function fruitCheck()
	local fruits
	local noFlowersYet = self.beePower 			

	for i, p in pairs(self.config.fruits) do
		fruits = world.objectQuery(entity.position(), 80, {name = p})
		if fruits ~= nil then
			self.beePower = self.beePower + math.ceil(math.sqrt(#fruits) / 2)
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

function checkAntimiteFrames (hive)
	-- then we check how many mite-killing frames are present
	hive.totalamiteFrames = 0
	for _,slot in pairs(hive.frameSlots) do
		local item = world.containerItemAt(entity.id(),slot - 1)
		if item then
			if self.antimiteFrames[item.name] then
				hive.totalamiteFrames= hive.totalamiteFrames + item.count
			end
		end
	end
end

function updateTotalMites()
    self.totalMites = 0
    contents = world.containerItems(entity.id())
    if not contents then return end

    for _,item in pairs(contents) do
        if item.name=="vmite" then
            self.totalMites= (self.totalMites + item.count) - self.miteReduction + self.mitePenalty
        end
    end
end

function miteInfection(hive) 
    local vmiteFitCheck = world.containerItemsCanFit(entity.id(), { name= "vmite", count = 1, data={}})   --see if the container has room for more mites
    local fmiteFitCheck = world.containerItemsCanFit(entity.id(), { name= "firemite", count = 1, data={}})

    checkAntimiteFrames(hive)

    -- mite settings get applied
    local baseMiteChance = 0.4 + math.random(2) + (self.totalMites/10) 
    if baseMiteChance > 100 then baseMiteChance = 100 end

    local baseMiteReproduce = (1 + (self.totalMites /40))
    local baseMiteKill = 2 * (hive.totalamiteFrames /24)
    if baseMiteKill < 1 then baseMiteKill = 1 end
    
    local baseDiceRoll = math.random(200)
    local baseSmallDiceRoll = math.random(100)
    local baseLargeDiceRoll = math.random(1000)
    
     --Infection stops spreading if the frame is an anti-mite frame present. It this is the case, we also roll to see if we get a bugshell when we kill the mite. 
    if hive.modifiers.antimite then  
        world.containerConsume(entity.id(), { name= "vmite", count = math.min(baseMiteKill,self.totalMites), data={}})
        if baseSmallDiceRoll < 10 and self.totalMites > 12 then   --chance to spawn bugshell when killing mites
          world.containerAddItems(entity.id(), { name="bugshell", count = baseMiteKill/2, data={}})
        end
    elseif (self.totalMites >= 360) and (baseDiceRoll < baseMiteChance) then
        --animator.playSound("addMite")         
    elseif (self.totalMites >= 10) and (baseSmallDiceRoll < baseMiteChance *4) and (vmiteFitCheck > 0) then
        world.containerAddItems(entity.id(), { name="vmite", count = baseMiteReproduce, data={}}) 
        self.totalMites = self.totalMites + baseMiteReproduce
        self.beePower = self.beePower - (1 + self.totalMites/20)
    elseif (baseDiceRoll < baseMiteChance) and (vmiteFitCheck > 0) then
        world.containerAddItems(entity.id(), { name="vmite", count = baseMiteReproduce, data={}})
        self.totalMites = self.totalMites + baseMiteReproduce
        self.beePower = self.beePower - (1 + self.totalMites/20)
    end
end

function daytimeCheck()
	self.daytime = world.timeOfDay() < 0.45 or world.type() == 'playerstation' --we made day earlier
end

function getHiveTime(hive)
	if hive.modifiers.daytime then
		--sb.logInfo("Daytime Check: " .. tostring(hive.modifiers.daytime))
		return hive.modifiers.daytime
	else
		--sb.logInfo("Daytime Check: " .. tostring(self.daytime))
		return self.daytime
	end
end


function setAnimationState()
	local animate = false
	for _,hive in ipairs(self.hives) do
		animate = animate or hive.active
	end
	activeBees = animate and "on" or "off"
	--object.say("Bee Animation is " .. activeBees)
	animator.setAnimationState("bees", activeBees)
end


function hiveActivity(hive)
	if hive.queen and hive.drone then
		local when = self.config.spawnList[hive.queen.type].active or 'day'
		local now = getHiveTime(hive) and 'day' or 'night'
		if hive.queen.type == hive.drone.type then
			hive.active = self.beePower > 0 and 
			(
				when == now or
				when == "always"
			)
			hive.activity = "working"
			hive.species = hive.queen.type
			return hive.active
		else 
			local species = self.config.breeding[hive.queen.type .. hive.drone.type] or 
				self.config.breeding[hive.drone.type .. hive.queen.type]
			if species ~= nil then
				hive.active = self.beePower > 0 and 
				(
					when == "day"
				)
				hive.activity = "breeding"
				hive.species = species
				return hive.active
			end			
		end
	end
	hive.active = false
	hive.activity = nil
	return hive.active
end


function updateBeeProduction(dt)
	updateTotalMites()

    if self.deltaTime > 1 then
        self.deltaTime = self.deltaTime - 1
    else
        self.deltaTime = self.deltaTime + dt
    end

	daytimeCheck()
	flowerCheck()   -- checks flowers
	--object.say("Bee Power: " .. self.beePower)	
	for i,hive in ipairs(self.hives) do
		hive.modifiers = {
			honey = 0,
			drone = 0,
			item = 0,
			mutationIncrease = 0,
			antimite = 0,
			combs = 0,
			hivePower = 0,
			daytime = nil
		}
		frame(hive)	--Checks to see if a frame in installed.
		getEquippedBees(hive)
		if hiveActivity(hive) then
			--object.say("Hive Power: " .. hive.power)	
			
			deciding(hive)
		
			if hive.actions.doBees or hive.actions.doItems or hive.actions.doHoney or hive.actions.doDrones then
				miteInfection(hive)	-- Try to spawn mites.
		
				if hive.activity == "working" then
					workingBees(hive)
				elseif hive.activity == "breeding" then
					breedingBees(hive)
				end
			end
		end
		
	end
	setAnimationState()
	reset()
end


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
			updateBeeProduction(dt)
			--Update Done

			if (self.deltaTime > 1) then
				--sb.logInfo("backing up output")
				storage.outputData = serialize_itemTable(self.outputData)
			end
		end
	end
end


function chooseMinerHoney(config,hive)
	if not hive.actions.doHoney then return nil end

	-- Pick a type at random from those found.
	local minerFrames = 0
	local types = {}
	for frame, count in pairs(hive.modifiers.combs) do
		minerFrames = minerFrames + count
		if count > 0 then table.insert(types, frame) end
	end

	if minerFrames == 0 then return nil end

	-- boosted chance of spawning a comb: extra chance is 50% or 75% of the difference between default and 1
	local chance = config.chance or DEFAULT_HONEY_CHANCE
	chance = chance + (1 - chance) * (minerFrames * 2 - 1) / (minerFrames * 2)

	-- generally, chance of a special ore comb is 1/3 if 1 miner-affecting frame or 1/2 if 2
	-- TODO: nerf diamond comb production
	if math.random() > 1 / (4 - minerFrames) then
--		sb.logInfo('may spawn minercomb, chance = %s', chance)
		return { chance = chance }
	end

	-- equal chance of which frame affects the comb type
	-- some may unsuccessfully affect the comb type; in that case, the default type is produced
--	sb.logInfo('may spawn frame-affected comb, chance = %s', chance)
	local type = types[math.random(#types)]
	if self.config.oreSuccess[type] and math.random() > self.config.oreSuccess[type] then
		type = nil
	end
	return { type = type, chance = chance }
end


function chooseMinerOffspring(config, hive)
	if hive.modifiers.mutationIncrease == 0 then 
	  return nil 
	end
	
	if math.random() > hive.modifiers.mutationIncrease then
	--sb.logInfo('may spawn miner bees')
		return nil
	end
	
	--sb.logInfo('may spawn strange bees')
	local threat = world.threatLevel() or 1
	local chance = config.chance or DEFAULT_HONEY_CHANCE
	if (math.random(100) <= 10 * (chance + hive.modifiers.mutationIncrease)) then
	  world.spawnMonster("fuevilbee", object.toAbsolutePosition({ 0, 3 }), { level = threat, aggressive = true })
	elseif (math.random(100) <= 5 * (chance + hive.modifiers.mutationIncrease)) then
	  world.spawnMonster("elderbee", object.toAbsolutePosition({ 0, 3 }), { level = threat, aggressive = true })
	elseif (math.random(100) <= 2 * (chance + hive.modifiers.mutationIncrease)) then
	  world.spawnMonster("fearmoth", object.toAbsolutePosition({ 0, 3 }), { level = threat, aggressive = true })
	end
	
	return { type = 'radioactive', chance = config.chance, bee = (config.bee or 1) * 1.1, drone = (config.drone or 1) * 0.9 } -- tip a little more in favour of world over hive
	
end

function workingBees(hive)
	if self.config.spawnList[hive.queen.type] then
		local workConfig = self.config.spawnList[hive.queen.type]

			if hive.actions.doHoney then
				-- read config; call functions returning config if specified
				local honey = workConfig.honey and 
				(
					hive.actions.doHoney and 
					workConfig.honey.func and 
					self.functions[workConfig.honey.func] and 
					self.functions[workConfig.honey.func](workConfig.honey, hive) or 
					workConfig.honey
				) or {}

				-- get type and chances, handling fallbacks
				local honeyType   = honey.type       or (workConfig.honey     and workConfig.honey.type      ) or hive.queen.type
				local honeyChance = honey.chance     or (workConfig.honey     and workConfig.honey.chance    ) or DEFAULT_HONEY_CHANCE

				trySpawnHoney(hive,honeyChance, honeyType)
			end

			local function doBeeOrDrone(type, spawnFunc,hive)
				-- read workConfig; call functions returning workConfig if specified
				local offspring = workConfig.offspring and 
				(
					workConfig.offspring.func and 
					self.functions[workConfig.offspring.func] and 
					self.functions[workConfig.offspring.func]
					(
						workConfig.offspring, 
						hive, 
						type
					) or workConfig.offspring
				) or {}

				-- get type and chances, handling fallbacks
				local chance = offspring.chance or 
				(
					workConfig.offspring and 
					workConfig.offspring.chance
				) or DEFAULT_OFFSPRING_CHANCE

				chance       = chance * (offspring[type] or (workConfig.offspring and workConfig.offspring[type]) or 1)

				spawnFunc(hive,chance)
			end

			if hive.actions.doBees   then doBeeOrDrone('bee',   trySpawnBee  ,hive) end
			if hive.actions.doDrones then doBeeOrDrone('drone', trySpawnDrone,hive) end

			if workConfig.items and hive.actions.doItems then
				for item, chance in pairs(workConfig.items) do
					trySpawnItems(hive,chance, item)
				end
			end

			if workConfig.sting then beeSting() end

		-- found a match, so just return now indicating success
	end
end


function breedingBees(hive)
--			sb.logInfo ('Checking ' .. bee1Type .. ' + ' .. bee2Type)
--			animator.setAnimationState("bees", "on")
	trySpawnHoney(hive,0.2, "normal")
	trySpawnMutantBee(hive,0.25)
	trySpawnMutantDrone(hive,0.20)
	hive.beeActiveWhen = "day"

	
	miteInfection() -- additional chance for infection when breeding
        
	hive.beeActiveWhen = "unknown"
	self.beePower = -1
	return false
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