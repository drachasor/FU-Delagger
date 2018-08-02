require "/HLib/Scripts/HelperScripts.lua"
require "/HLib/Scripts/tableEx.lua"
require "/HLib/Scripts/AdditionalFunctions.lua"
require "/HLib/Classes/GUIElements/Itemslot.lua"
require "/HLib/Classes/Other/LoadData.lua"
require "/HLib/Classes/Other/Messenger.lua"
require "/HLib/Classes/Tasks/Task.lua"
require "/HLib/Classes/Tasks/TaskOperator.lua"
require "/HLib/Classes/Tasks/TaskManager.lua"

local function SaveData()
	Messenger().SendMessageNoResponse
	(
		self._parentEntityId, 
		"Save", 
		{
			bugHarvestGun = self.bugHarvester:GetItem();
		}
	)
end

function bugHarvesterSlot()
	self.bugHarvester:Click();
	SaveData();
end

function uninit()
	Messenger().SendMessageNoResponse(self._parentEntityId, "GUIClosed");
end

function init()
	self._parentEntityId = pane.containerEntityId();
	--Messenger().SendMessageNoResponse(self._parentEntityId, "GUIOpened");
	self._responseLoader = LoadData(self._parentEntityId, "Load");


	self.bugHarvester = Itemslot("bugHarvesterSlot");
	self.bugHarvester:SetFilterFunction(
		function (item)
		  return item.ItemDescriptor.name == "fu_autobeamer3bugs";
		end);
	self.bugHarvester:SetItemLimit(1);
end

function update()
	if self._responseLoader:Call() then
		local data = self._responseLoader:GetData();
		if not data then
		  return;
		end
		self.bugHarvester:SetItem(data.bugHarvestGun);
		script.setUpdateDelta(0);
	end	
end