require "/objects/generic/digitalstorage_transfers.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/objects/generic/centrifuge_recipes.lua"
require "/scripts/delagger_utils.lua"
require "/objects/generic/bulk_base_machine.lua"



function AdditionalInits()
	self.itemChances = config.getParameter("itemChances")
	self.inputSlot = config.getParameter("inputSlot",1)
	storage.combsProcessed = storage.combsProcessed or { count = 0 }
	self.combsPerJar = 3 -- ref. recipes
	self.craftingSpeed = config.getParameter("craftDelay")

	object.setInteractive(true)
end

function GetRecipes()
	--sb.logInfo("Loading Recipes")
	self.centrifugeType = config.getParameter("centrifugeType") or error("centrifugeType is undefined in .object file") -- die horribly
	self.recipeTable = getRecipes() --from centrifuge_recipes.lua
	--if self.recipeTable == nil then   --sb.logInfo("No Recipes!") end
	self.recipeTypes = self.recipeTable.recipeTypes[self.centrifugeType]

end

function AdditionalProgressSave()
	if storage.combsProcessed and storage.combsProcessed.count > 0 then
		-- discard the stash if unclaimed by a jarrer within a reasonable time (1 second)
		storage.combsProcessed.stale = (storage.combsProcessed.stale or (self.initialCraftDelay * 2)) - dt
		if storage.combsProcessed.stale == 0 then
			drawHoney() -- effectively clear the stash, stopping the jarrer from getting it
		end
  end
end

function AdditionalProgressLoad()

end

function AdditionalProgressLoadDefaults()
end

function CraftingAnimationOn()
	animator.setAnimationState("centrifuge", "working")
end

function CraftingAnimationStalled()
	animator.setAnimationState("centrifuge", "idle")
end


function CraftingAnimationOff()
	animator.setAnimationState("centrifuge", "idle")
end

function GetItemRecipe(item)
	--sb.logInfo("Centrifuge: Looking up item recipe")
	if item ~= nil then
		for i=#self.recipeTypes,1,-1 do
				if self.recipeTable[self.recipeTypes[i]][item.name] then
					self.outputItems = self.recipeTable[self.recipeTypes[i]][item.name]
					--sb.logInfo("Found item recipe")
			return true
			end
		end
	end
  return false
end

function getInputs()
	--sb.logInfo("Centrifuge: Getting inputs")
	for i=0,self.inputSlot-1 do
		self.inputItem = world.containerItemAt(entity.id(),i)
		if GetItemRecipe(self.inputItem) then
			self.bulkMult = math.min(self.maxBulkMult,self.inputItem.count)
			return true
    	end
	end
	return false
end

function GetItem()
	local rnd = math.random()
	for itname, chancePair in pairs(self.outputItems) do
		local chanceBase,chanceDivisor = table.unpack(chancePair)
		local chance = self.itemChances[chanceBase] / chanceDivisor
		if rnd < chance then
			return itname
		end
		rnd = rnd - chance
	end
	return nil
end

function getOutputs()
	--sb.logInfo("Centrifuge: Getting outputs")
	GetPower(.1)
	if self.dowork then
		--sb.logInfo("Centrifuge: Starting Crafting")
		world.containerConsume(
			entity.id(),
			{
				name = self.inputItem.name, 
				count = self.bulkMult
			}
		)
		self.timer = self.craftingSpeed * self.bulkMult
		stashHoney(self.inputItem.name, self.bulkMult)
	
		math.randomseed(os.time())
	
		for i=1,self.bulkMult do
			local itname = GetItem()
			if itname then
				local outputItem = Item
				(
					{
						name = itname, 
						count = 1, 
						parameters = {}
					}, 
					true
				)
				self.outputData:Add(outputItem)
			end
		end
		storage.outputData = serialize_itemTable(self.outputData)
		return true
	end
	--sb.logInfo("Centrifuge: Don't Craft")
	self.inputItem = nil
	return false

end

function stashHoney(comb, number)
	-- For any nearby jarrer (if this is an industrial centrifuge),
	-- Record that we've processed a comb.
	-- The stashed type is the jar object name for the comb type.
	-- If the stashed type is different, reset the count.

	local jar = honeyCheck and honeyCheck(comb)

	if jar then
		if storage.combsProcessed == nil then storage.combsProcessed = { count = 0 } end
		if storage.combsProcessed.type == jar then
			storage.combsProcessed.count = math.min(storage.combsProcessed.count + number)
			storage.combsProcessed.stale = nil
		else
			storage.combsProcessed = { type = jar, count = number }
		end
		----sb.logInfo("STASH: %s %s", storage.combsProcessed.count,storage.combsProcessed.type)
	end
end

-- Called by the honey jarrer
function drawHoney()
  if not storage.combsProcessed or storage.combsProcessed.count == 0 then return nil end
  local ret = storage.combsProcessed
  storage.combsProcessed = { count = 0 }
  ----sb.logInfo("STASH: Withdrawing")
  return ret
end