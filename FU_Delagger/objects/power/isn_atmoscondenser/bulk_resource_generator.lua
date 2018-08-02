require "/scripts/util.lua"
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
    local weights = config.getParameter("namedWeights")
    self.outputMap[self.worldtype] = {}
    for _,table in ipairs(outputTable or {}) do
        local weight = weights[table.weight] or table.weight
        self.outputMap[self.worldtype][weight] = table.items
    end
end

function AdditionalProgressLoad()
	--sb.logInfo("loading partial output")
	for key,val in pairs(self.partialOutput) do
		sb.logInfo(string.format("Adding index %s entry %s to table", tostring(key), tostring(val)))
	end
end

function AdditionalProgressLoadDefaults()
    if not storage.partialOutput then
        for weight,table in pairs(self.outputMap[self.worldtype]) do
            storage.partialOutput[weight] = 0
        end
    end
end

function AdditionalInits()
    self.bulkMult = 30 -- self.maxBulkMult
end


function getOutputs()

    for weight,table in pairs(self.outputMap[self.worldtype]) do
        self.partialOutput[weight] = (weight/100 * self.bulkMult) + self.partialOutput[weight]

        if self.partialOutput[weight] > #table then
            local amount
            amount,self.partialOutput[weight] = math.modf(
                self.partialOutput[weight] / #table
            )
            for _,it in table do
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
        elseif not weight == "common" and not weight == "uncommon" then
            if self.partialOutput[weight] > 1 then
                storage.partialOutput[weight] = storage.partialOutput[weight] - 1
                self.outputData:Add
                (
                    Item(
                        {name = util.randomFromList(table),
                        count = 1,
                        parameters = {}},
                        true
                    )
                )
            end
        end

        self.outputData:Add(
      Item({name = self.outputItems[i].name, count = amount, parameters = {}}, true)
    )
    end
    storage.outputData = serialize_itemTable(self.outputData)
    self.timer = self.bulkMult * 120

	return true
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