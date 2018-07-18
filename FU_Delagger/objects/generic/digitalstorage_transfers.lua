require "/scripts/fu_storageutils.lua"
require "/scripts/kheAA/transferUtil.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Item/ItemsTable.lua"

function fu_transferItemTable(itTable, avoidSlots)
	for _, item in pairs(itTable:GetFlattened()) do
		fu_sendOrStoreItems(0,item.ItemDescriptor, avoidSlots, self.worlddropiffull)
	end
end

function ds_fu_transferItem(item, avoidSlots)
	if DigitalNetworkHasOneController() then
		local leftover = DigitalNetworkPushItem(item)
		fu_sendOrStoreItems(0,leftover.ItemDescriptor, avoidSlots, self.worlddropiffull)
	else
		fu_sendOrStoreItems(0,item.ItemDescriptor, avoidSlots, self.worlddropiffull)
	end
end

function ds_fu_transferItemTable(itTable, avoidSlots)
	for _, item in pairs(itTable:GetFlattened()) do
		ds_fu_transferItem(item, avoidSlots)
	end
end

function transferTask()
	--sb.logInfo("transfer task start")
	ds_fu_transferItemTable(self.outputData, self.avoidSlots)
	if self._limiter:Check() then
        coroutine.yield();
	end
	--sb.logInfo("transfer task continue")
	self.outputData = ItemsTable(false)
	self.inputData = ItemsTable(false)
	storage.outputData = nil
end

function outputTableToSelf()
	fu_transferItemTable(self.outputData, self.avoidSlots)
	self.outputData = ItemsTable(false)
	self.inputData = ItemsTable(false)
	storage.outputData = nil
end

function serialize_itemTable(itTable)
	local tableString = {}
	for i, item in pairs(itTable:GetFlattened()) do
		--sb.logInfo(string.format("Converting %s number %s to string", item.ItemDescriptor.name, item.ItemDescriptor.count))
		tableString[i] = string.format("%s:%s\n",item.ItemDescriptor.name,item.ItemDescriptor.count or "1")
	end
	return table.concat(tableString)
end

function deserialize_itemTable(itemTableString)
	itTable = ItemsTable(false)
	for item,number in string.gmatch(itemTableString, "([%-_%w]*):(%d+)\n") do
		--sb.logInfo(string.format("Adding %s number %s to table", item, number))
		itTable:Add(Item({name = item,count = tonumber(number) or 1,parameters = {}}), true)
	end
	return itTable
end