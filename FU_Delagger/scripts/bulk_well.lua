require "/objects/generic/digitalstorage_transfers.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/scripts/delagger_utils.lua"
require "/objects/generic/bulk_base_machine.lua"

function AdditionalProgressLoad()
	--sb.logInfo("loading partial output")
	self.partialOutput = deserialize_indexArray(storage.partialOutput)
	for key,val in pairs(self.partialOutput) do
		--sb.logInfo(string.format("Adding index %s entry %s to table", tostring(key), tostring(val)))
	end
end

function AdditionalProgressLoadDefaults()
	self.partialOutput = {}
	for i=1,#self.outputItems do
		self.partialOutput[i] = 0
	end
end

function AdditionalInits()
	self.bulkMult = 30 -- self.maxBulkMult
  self.outputItems = config.getParameter('wellslots')
end

function setTimer()
	
end

function getOutputs()
  for i=1,#self.outputItems do
    local amount
    local partial
		amount,partial = math.modf(
			self.outputItems[i].rate * self.bulkMult + 
			self.partialOutput[i]
		)

		self.partialOutput[i] = partial
--[[
    sb.logInfo(string.format("item %s amount %i with remainder %.6f over time %i",
      self.outputItems[i].name,
			amount,
			self.partialOutput[i],
      self.bulkMult
    ));]]
    self.outputData:Add(
      Item({name = self.outputItems[i].name, count = amount, parameters = {}}, true)
    )
  end
  storage.outputData = serialize_itemTable(self.outputData)
	storage.partialOutput = serialize_indexArray(self.partialOutput)
	self.timer = self.bulkMult

	return true
end