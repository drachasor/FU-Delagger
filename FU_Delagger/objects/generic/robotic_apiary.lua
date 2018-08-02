
require "/objects/generic/fudl_apiaries_common.lua"


function die()
	if storage.Data then
		if storage.Data.bugHarvestGun then
		world.spawnItem(storage.Data.bugHarvestGun.ItemDescriptor, entity.position());
		end
	end
end

function getHives()
	return config.getParameter ("hives")
end

function initloadAdditional()
	storage.Data = storage.Data or nil
	--Messenger().RegisterMessage("GUIOpened", function(_, _) self._guiOpened = true;  end);
	--Messenger().RegisterMessage("GUIClosed", function(_, _) self._guiOpened = false; script.setUpdateDelta(1) end);
	Messenger().RegisterMessage("Load", function(_, _) return storage.Data; end);
	Messenger().RegisterMessage("Save", UpdateUpgradeSlots);
	--animator.setAnimationState("beehatch","open")
end

local update = _update
function update(dt)
	sb.logInfo("doing update")
	_update(dt)
end

function UpdateUpgradeSlots(_,_,data)
	storage.Data = data;
	if storage.Data.bugHarvestGun and not storage.catchBees then
		storage.catchBees = true
	elseif not storage.Data.bugHarvestGun and storage.catchBees then
		storage.catchBees = false
	end
end
function setAnimationState()
	if DigitalNetworkHasOneController() then
		animator.setAnimationState("dslight", "on")
		--sb.logInfo("dslight is on")
	else
		animator.setAnimationState("dslight", "off")
		--sb.logInfo("dslight is off")
	end

	local animate = false
	for _,hive in ipairs(self.hives) do
		animate = animate or hive.active
		local state = hive.active and "active" or "resting"
		if hive.activity then
			if hive.name == "hive3" then
				object.say("hive3! " .. state)
			end
			--sb.logInfo(hive.name .. " is " .. state)
			animator.setAnimationState(hive.name,state)
		else
			--sb.logInfo(hive.name .. "is empty")
			animator.setAnimationState(hive.name,"nohive")
		end
	end
	activeBees = animate and "on" or "off"
	--object.say("Bee Animation is " .. activeBees)
	animator.setAnimationState("bees", activeBees)
end
