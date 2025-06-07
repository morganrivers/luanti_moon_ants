-- ant/resource.lua
local C = dofile(minetest.get_modpath(minetest.get_current_modname()).."/ant/constants.lua")

local R = {}

function R.find_nearest_hub(self, radius)
	radius = radius or C.HUB_SEARCH_RADIUS
	local pos = self.object:get_pos(); if not pos then return nil end
	local hubs = minetest.find_nodes_in_area(
		{x=pos.x-radius, y=pos.y-radius, z=pos.z-radius},
		{x=pos.x+radius, y=pos.y+radius, z=pos.z+radius},
		{"moon:nest_core"}
	)
	local best, bestd = nil, radius*2
	for _,hp in ipairs(hubs) do
		local d = vector.distance(pos, hp)
		if d < bestd then bestd, best = d, hp end
	end
	return best
end

function R.on_punch(self, puncher, time_from_last_punch, tool_capabilities, dir)
    local steps_text = "Steps in current direction: " .. self.steps_taken
    local inv_text = "Regolith: " .. self.inventory.regolith .. "/" .. self.max_regolith
    
    local dir_name = "Unknown"
    if self.current_direction then
        if self.current_direction.x > 0 then dir_name = "East"
        elseif self.current_direction.x < 0 then dir_name = "West"
        elseif self.current_direction.z > 0 then dir_name = "North"
        elseif self.current_direction.z < 0 then dir_name = "South"
        end
    end
    
    local status = self.returning and "Returning to hub" or "Digging"
    
    local pos = self.object:get_pos()
    local pos_text = "Position: " .. minetest.pos_to_string(pos)
    
    minetest.chat_send_player(puncher:get_player_name(), 
        "Rover Status: " .. status .. "\n" .. 
        inv_text .. "\n" .. 
        steps_text .. "\nDirection: " .. dir_name .. 
        "\n" .. pos_text)
    return true
end

return R
