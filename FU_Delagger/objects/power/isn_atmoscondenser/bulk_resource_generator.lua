require "/objects/generic/digitalstorage_transfers.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/scripts/util.lua"
require "/scripts/power.lua"
require "isn_resource_generator.lua"

-- You might notice there's no timer here.
-- The time between outputs and power consumption is determined by
-- the object's "scriptDelta".

-- Added in the deltaTime variable as it's common in any lua code which
-- interacts with Item Transference Device (transferUtil) code.
local deltaTime	-- Making it local is faster than leaving it global.

function init()
    transferUtil.init()
    object.setInteractive(true)
    self.powerConsumption = config.getParameter("isn_requiredPower")
    power.init()

    self.maxWeight = {}
    self.outputMap = {}

    initMap(world.type())
end

function initMap(worldtype)
    -- Set up output here so it won't take up time later
    local outputConfig = config.getParameter("outputs")
    local outputTable = outputConfig[worldtype] or outputConfig["default"]
    if type(outputTable) == "string" then
        outputTable = outputConfig[outputTable]
    end
    local weights = config.getParameter("namedWeights")
    self.maxWeight[worldtype] = 0
    self.outputMap[worldtype] = {}
    for _,table in ipairs(outputTable or {}) do
        local weight = weights[table.weight] or table.weight
        self.maxWeight[worldtype] = self.maxWeight[worldtype] + weight
        self.outputMap[worldtype][weight] = table.items
    end
end

function update(dt)
    
    power.update(dt)
	
	-- Notify ITD but no faster than once per second.
	if not deltaTime or (deltaTime > 1) then
		deltaTime = 0
		transferUtil.loadSelfContainer()
		deltaTime = deltaTime + dt
	end

	local worldtype = world.type()
	if worldtype == 'unknown' then
		worldtype = world.getProperty("ship.celestial_type") or worldtype
	end
	if not self.outputMap[worldtype] then
		initMap(worldtype)
	end
	
    local output = nil
    local rarityroll = math.random(1, self.maxWeight[worldtype])

    -- Goes through the list adding values to the range as it goes.
    -- This keeps the chance ratios while allowing the list to be in any order.
    local total = 0
    for weight,table in pairs(self.outputMap[worldtype]) do
        total = total + weight
        if rarityroll <= total then
            output = util.randomFromList(table)
            break
        end
    end

    if output and clearSlotCheck(output) and power.consume(self.powerConsumption) then
        animator.setAnimationState("machineState", "active")
        world.containerAddItems(entity.id(), output)
    else
        animator.setAnimationState("machineState", "idle")
    end
end

function clearSlotCheck(checkname)
  return world.containerItemsCanFit(entity.id(), checkname) > 0
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