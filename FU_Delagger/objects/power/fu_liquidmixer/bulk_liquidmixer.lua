require "/objects/generic/digitalstorage_transfers.lua"
require "/DigitalScripts/DigitalStoragePeripheral.lua"
require "/HLib/Classes/Other/ClockLimiter.lua"
require "/HLib/Classes/Item/ItemsTable.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/scripts/delagger_utils.lua"
require "/objects/generic/bulk_base_machine.lua"

function GetRecipes()
    self.recipeTable = root.assetJson('/objects/power/fu_liquidmixer/fu_liquidmixer_recipes.config')
end

function map(l,f)
    local res = {}
    for k,v in pairs(l) do
        res[k] = f(v)
    end
    return res
end

function filter(l,f)
  return map(l, function(e) return f(e) and e or nil end)
end

function getValidRecipes(itTable)
    
    local function subset(t1,t2)
        if next(t2) == nil then
          return false
        end
        if t1 == t2 then
          return true
        end
        for k,_ in pairs(t1) do
            if not t2[k] or t1[k] > t2[k] then
                return false
            end
        end
        return true
    end

    local query = {}
    for _,it in pairs(itTable:GetFlattened()) do
        query[it.ItemDescriptor.name] = it.ItemDescriptor.count
    end

    return filter(self.recipeTable, function(l) return subset(l.inputs, query) end)
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

function getInputs()
    local id = entity.id()
    self.workingRecipe = nil
    self.InputData = ItemsTable(false)
    for i=0,1 do
        local stack = world.containerItemAt(entity.id(),i)
        if stack ~=nil then
            local inItem = Item
            (
                {
                    name = stack.name, 
                    count = stack.count, 
                    parameters = {}
                }
            )
            self.InputData:Add(inItem)
        end
    end
    self.workingRecipe = getValidRecipes(self.InputData)
    if next(self.workingRecipe) then
        _,self.workingRecipe = next(self.workingRecipe)
        return true
    else
        return false
    end
end

function getOutputs()
    GetPower(.1)
    if self.dowork then
        self.bulkMult = self.maxBulkMult
        for _, item in pairs(self.InputData:GetFlattened()) do
            local name = item.ItemDescriptor.name
            local inputMult = self.workingRecipe.inputs[name]
            --sb.logInfo(string.format("item %s count %i input mult %i",name,item.ItemDescriptor.count,inputMult))
            self.bulkMult = math.min(self.bulkMult,math.floor(item.ItemDescriptor.count / inputMult))
        end
        --sb.logInfo(string.format("%i is the bulkmult",self.bulkMult))
        for _, item in pairs(self.InputData:GetFlattened()) do
            local name = item.ItemDescriptor.name
            local inputMult = self.workingRecipe.inputs[name]
            --sb.logInfo(string.format("item %s count %i input mult %i",name,item.ItemDescriptor.count,inputMult))
            --sb.logInfo(string.format("actual item mult is %i", self.bulkMult * inputMult))
            world.containerConsume
            (
                entity.id(), 
                {
                    item = name, 
                    count = self.bulkMult * inputMult
                }
            )
        end
        
        for it,num in pairs (self.workingRecipe.outputs) do
            local item = Item
            (
                {
                    name = it, 
                    count = num * self.bulkMult, 
                    parameters = {}
                },
                true
            )
            self.outputData:Add(item)
        end

        self.timer = config.getParameter("craftingSpeed") * self.bulkMult
        storage.timer = self.timer
        storage.outputData = serialize_itemTable(self.outputData)
        return true
    else
        return false
    end
end