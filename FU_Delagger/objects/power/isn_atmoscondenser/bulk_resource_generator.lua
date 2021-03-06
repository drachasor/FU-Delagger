require "/objects/generic/digitalstorage_transfers.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/scripts/delagger_utils.lua"
require "/objects/generic/bulk_base_machine.lua"

-- You might notice there's no timer here.
-- The time between outputs and power consumption is determined by
-- the object's "scriptDelta".

-- Added in the deltaTime variable as it's common in any lua code which
-- interacts with Item Transference Device (transferUtil) code.

function GetRecipes()
    self.weightMap = config.getParameter("namedWeights")
    self.outputMap = {}
    self.worldtype = world.type()
    if self.worldtype == 'unknown' then
		self.worldtype = world.getProperty("ship.celestial_type") or worldtype
	end
    -- Set up output here so it won't take up time later
    local outputConfig = config.getParameter("outputs")
    local outputTable = outputConfig[self.worldtype] or outputConfig["default"]
    if type(outputTable) == "string" then
        outputTable = outputConfig[outputTable]
    end
    
    self.outputMap[self.worldtype] = {}
    for _,table in ipairs(outputTable or {}) do
        self.outputMap[self.worldtype][table.weight] = table.items
    end
end

function AdditionalProgressLoad()
	--sb.logInfo("loading partial output")
	for key,val in pairs(storage.partialOutput) do
		--sb.logInfo(string.format("Adding index %s entry %s to table", tostring(key), tostring(val)))
	end
end

function AdditionalProgressLoadDefaults()
    if not storage.partialOutput then
        storage.partialOutput = {}
        for weight,_ in pairs(self.weightMap) do
            storage.partialOutput[weight] = 0
        end
    end
end

function getOutputs()
	GetPower(.1)
	if self.dowork then
        for weight,table in pairs(self.outputMap[self.worldtype]) do
            local chance = self.weightMap[weight] / 100
            storage.partialOutput[weight] = (chance * self.maxBulkMult) + storage.partialOutput[weight]
            if storage.partialOutput[weight] >= #table then
                local amount
                amount,storage.partialOutput[weight] = math.modf(
                    storage.partialOutput[weight] / #table
                )
                for _,it in pairs(table) do
                    self.outputData:Add
                    (
                        Item(
                            {name = it,
                            count = amount,
                            parameters = {}},
                            true
                        )
                    )
                end
            elseif weight ~= "common" and weight ~= "uncommon" then
                --sb.logInfo("Rare Item test")
                if storage.partialOutput[weight] >= 1 then
                    storage.partialOutput[weight] = storage.partialOutput[weight] - 1
                    local item = table[math.random(1,#table)]
                    self.outputData:Add
                    (
                        Item(
                            {name = item,
                            count = 1,
                            parameters = {}},
                            true
                        )
                    )
                end
            end
        end
        storage.outputData = serialize_itemTable(self.outputData)
        self.timer = self.maxBulkMult * 2

        return true
    end
    return false
end

function CraftingAnimationOn()
	animator.setAnimationState("machineState", "active")
end

function CraftingAnimationStalled()
	animator.setAnimationState("machineState", "idle")
end


function CraftingAnimationOff()
	animator.setAnimationState("machineState", "idle")
end