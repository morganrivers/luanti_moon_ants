-- ant/movement.lua
local C = dofile(minetest.get_modpath(minetest.get_current_modname()).."/ant/constants.lua")

local M = {}

-- random cardinal start
function M.choose_initial_direction(self)
	local dirs = { {x=1,y=0,z=0}, {x=-1,y=0,z=0}, {x=0,y=0,z=1}, {x=0,y=0,z=-1} }
	self.current_direction = dirs[math.random(1,4)]
	self.steps_taken       = 0
	self.object:set_yaw(minetest.dir_to_yaw(self.current_direction))
end

function M.turn_90_degrees(self)
	local left = (math.random() > 0.7)
	local dir  = self.current_direction
	local newd = left and {x = -dir.z, y=0, z =  dir.x}
	                 or   {x =  dir.z, y=0, z = -dir.x}

	self.current_direction = newd
	self.steps_taken       = 0
	self.object:set_yaw(minetest.dir_to_yaw(newd))
end

function M.adjust_height(self)
	local pos = self.object:get_pos(); if not pos then return end
	local below = {x=pos.x, y=pos.y-0.3, z=pos.z}
	local node  = minetest.get_node_or_nil(below)
	if node and node.name == "air" then return end -- let gravity do it
	local target_y = math.floor(pos.y) + 0.5
	if math.abs(pos.y - target_y) > 0.1 then
		self.object:set_pos({x=pos.x, y=target_y, z=pos.z})
	end
end
function M.pick_random_horizontal(self)
    local dirs = { {x=1,y=0,z=0}, {x=-1,y=0,z=0}, {x=0,y=0,z=1}, {x=0,y=0,z=-1} }
    self.current_direction = dirs[math.random(1,4)]
    self.object:set_yaw(minetest.dir_to_yaw(self.current_direction))
end

return M
