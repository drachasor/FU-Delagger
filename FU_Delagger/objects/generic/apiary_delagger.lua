

require "/objects/generic/fudl_apiaries_common.lua"

function initSlotData()
	--self.queenSlot = config.getParameter ("queenSlot")				-- Apiary inventory slot number (indexed from 1)
	--self.droneSlot = config.getParameter ("droneSlot")				--
	--self.frameSlots = config.getParameter ("frameSlots")	
end

function getHives()

	return
	{{
		bee1Slot = config.getParameter ("queenSlot"), 
		bee2Slot = config.getParameter ("droneSlot"), 
		frameSlots = config.getParameter ("frameSlots")
	}}

end