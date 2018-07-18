require "/objects/generic/digitalstorage_transfers.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require '/scripts/power.lua'
require "/scripts/delagger_utils.lua"
require "/objects/generic/bulk_base_machine.lua"

function AdditionalInits()
  self.timerInitial = config.getParameter ("fu_timer", 1)
  self.extraConsumptionChance = config.getParameter ("fu_extraConsumptionChance", 0)
  self.craftingSpeed = self.timerInitial
end

--[[
storage.currentinput = nil
storage.currentoutput = nil
storage.bonusoutputtable = nil
storage.activeConsumption = false
]]

function GetRecipes()
	self.recipeTable = config.getParameter("inputsToOutputs")
	self.bonusTable = config.getParameter("bonusOutputs")
end

function CraftingAnimationOn()
	animator.setAnimationState("furnaceState", "active")
end

function CraftingAnimationStalled()
	animator.setAnimationState("furnaceState", "idle")
end


function CraftingAnimationOff()
	animator.setAnimationState("furnaceState", "idle")
end

function getInputs()
	local it = world.containerItemAt(entity.id(),0)
	if it then
		if it.count >= 2 and self.recipeTable[it.name] then
			self.inputData:Add
			(
				Item
				(
					{
						name = it.name,
						count = it.count, 
						parameters = {}
					}
				)
			)
			return true
		end
	end
	return false
end

function getBonusOutputs(name)
	for itname, value in pairs(self.bonusTable[name]) do
		local chance = value/100
		local count =  BinomialSuccesses(self.bulkMult, chance)
		--sb.logInfo(string.format("Bonus item: %s, chance %.2f,max count %i",itname,chance,self.bulkMult))
		--sb.logInfo(string.format("Bonus item: %s count %i",itname,count))
		self.outputData:Add
			(
				Item
				(
					{
						name = itname,
						count = count, 
						parameters = {}
					}, 
					true
				)
			)
	end
end

function getOutputs()
	GetPower(.1)
	if self.dowork then
		math.randomseed(os.time())

		--get consume amounts and normal output amount
		for _,it in pairs(self.inputData:GetFlattened()) do
			self.bulkMult = 0
			local consumeAmt = 0
			local outputAmt = 0
			local input = it.ItemDescriptor
			local name = input.name
			while consumeAmt <= input.count - 2 and self.bulkMult <= self.maxBulkMult do
				--sb.logInfo("BulkFurnace: Determinining Exact Input/Output Amounts")
				self.bulkMult = self.bulkMult + 1
				consumeAmt = consumeAmt + 2
				outputAmt = outputAmt + math.random(1,2)
				if math.random() <= self.extraConsumptionChance and consumeAmt <= input.count - 2 then
					consumeAmt = consumeAmt + 2
				end
			end
		

			input.count = consumeAmt
			world.containerConsume
			(
				entity.id(),
				{
					name = name, 
					count = consumeAmt
				}
			)
			self.outputData:Add
			(
				Item
				(
					{
						name = self.recipeTable[name],
						count = outputAmt, 
						parameters = {}
					}, 
					true
				)
			)
			getBonusOutputs(name)
		end
		storage.outputData = serialize_itemTable(self.outputData)
		self.timer = self.craftingSpeed * self.bulkMult
		return true
	end
	self.inputItem = nil
	return false
end