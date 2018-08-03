--require "/scripts/fu_storageutils.lua"
--require "/scripts/kheAA/transferUtil.lua"


require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Item/ItemsTable.lua"

function storeItem(itemD, firstOutput, spawnLeftovers)
	for i=firstOutput,world.containerSize(entity.id()) - 1 or 0 do
		if itemD and itemD.count > 0 then
			local stack = world.containerItemAt(entity.id(), i) -- get the stack on i		
			if stack then -- not empty
				if stack.name == itemD.name then
					--sb.logInfo(string.format("Merging item %s with total %i at %i",itemD.name,itemD.count,i))
					itemD = world.containerPutItemsAt(entity.id(), itemD, i)
					--itemD = world.containerItemApply(entity.id(), itemD, i)
				end
			else
				itemD = world.containerPutItemsAt(entity.id(), itemD, i)
			end
		else
			break
		end
	end

	if itemD and itemD.count > 0 and spawnLeftovers then
		world.spawnItem(itemD.name, entity.position(), itemD.count)
	end
	
end

function fu_transferItemTable(itTable, firstOutput)
	for _, item in pairs(itTable:GetFlattened()) do
		--removed node too and fu_sendOrS 
		storeItem(item.ItemDescriptor, firstOutput, self.worlddropiffull)
	end
end

function ds_fu_transferItem(item, firstOutput)
	if DigitalNetworkHasOneController() then
		local leftover = DigitalNetworkPushItem(item)
		--removed node too was fu_sendOrStoreItems(0,
		storeItem(leftover.ItemDescriptor, firstOutput, self.worlddropiffull)
	else
		--removed node too and fu_sendOrS 
		storeItem(item.ItemDescriptor, firstOutput, self.worlddropiffull)
	end
end

function ds_fu_transferItemTable(itTable, firstOutput)
	for _, item in pairs(itTable:GetFlattened()) do
		ds_fu_transferItem(item, firstOutput)
	end
end

function transferTask()
	--sb.logInfo("transfer task start")
	ds_fu_transferItemTable(self.outputData, self.firstOutputSlot)
	if self._limiter:Check() then
        coroutine.yield();
	end
	--sb.logInfo("transfer task continue")
	self.outputData = ItemsTable(false)
	self.inputData = ItemsTable(false)
	storage.outputData = nil
end

function outputTableToSelf()
	fu_transferItemTable(self.outputData, self.firstOutputSlot)
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