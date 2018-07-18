require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require '/scripts/power.lua'

require "/scripts/fu_storageutils.lua"
require "/scripts/kheAA/transferUtil.lua"

--Conversions

function string2boolean(str)
	if str.toLowerCase() == "false" then
		return false
	else
		return true
	end
end

--Probability

function BinomialSuccesses(trials, chance)
	local successes = 0
	local rnd = math.random()
	for i=1,trials do
		if rnd < chance then
			successes = successes + 1
		end
		rnd = math.random()
	end
	return successes
end

--Array Storage

function serialize_flatArray(flatArray)
	local arrayString = {}
	i = 1
	for key, entry in pairs(flatArray) do
		--sb.logInfo(string.format("Converting %s number %s to string", item.ItemDescriptor.name, item.ItemDescriptor.count))
		arrayString[i] = string.format("%s::::%s\n",tostring(key),tostring(entry))
		i = i + 1
	end
	return table.concat(arrayString)
end

function deserialize_flatArray(flatArrayString)
	array = {}
	for key,entry in string.gmatch(flatArrayString, "([%-_%w]*)::::([%-_%w]*)\n") do
		--sb.logInfo(string.format("Adding %s number %s to table", item, number))
		array[key] = entry
	end
	return array
end

function serialize_indexArray(indexArray)
	local arrayString = {}
	i = 1
	for index, entry in pairs(indexArray) do
		--sb.logInfo(string.format("Converting index %s entry %s to string", tostring(index), tostring(entry)))
		local stringEntry = string.format("%s::::%s\n",tostring(index),tostring(entry))
		--sb.logInfo(stringEntry)
		arrayString[i] = stringEntry
		i = i + 1
	end
	return table.concat(arrayString)
end

function deserialize_indexArray(indexArrayString)
	array = {}
	for index,entry in string.gmatch(indexArrayString, "([%-_.%w]*)::::([%-_.%w]*)\n") do
		--sb.logInfo(string.format("Adding index %s entry %s to table", tostring(index), tostring(entry)))
		array[tonumber(index)] = tonumber(entry)
	end
	return array
end