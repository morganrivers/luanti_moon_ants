local ports = ports
local util = util

local dev_items = {}

-- Helper: Adds a port to a node face with default state
local function attach_port(itemstack, placer, pointed, port_class, default_state)
	if pointed.type ~= "node" then return itemstack end
	local pos = pointed.under
	local face = minetest.dir_to_facedir(vector.subtract(pointed.above, pointed.under))
	local id = ports.registry.add(util.hash(pos), face, port_class, default_state)
	if placer and placer:is_player() then
		minetest.chat_send_player(placer:get_player_name(), "Port ID "..tostring(id).." attached.")
	end
	if not minetest.is_creative_enabled(placer:get_player_name()) then
		itemstack:take_item()
	end
	return itemstack
end

-- POWER port tool
minetest.register_craftitem("moon:power_port_tool", {
	description = "Power Port Tool (DEV)",
	inventory_image = "moon_power_port_tool.png",
	on_place = function(itemstack, placer, pointed)
		return attach_port(
			itemstack, placer, pointed,
			moon.PORT.POWER,
			{voltage=0, current_A=0}
		)
	end,
})

-- ACTUATOR port tool
minetest.register_craftitem("moon:actuator_port_tool", {
	description = "Actuator Port Tool (DEV)",
	inventory_image = "moon_actuator_port_tool.png",
	on_place = function(itemstack, placer, pointed)
		return attach_port(
			itemstack, placer, pointed,
			moon.PORT.ACTUATOR,
			{command=0}
		)
	end,
})

-- SENSOR port tool
minetest.register_craftitem("moon:sensor_port_tool", {
	description = "Sensor Port Tool (DEV)",
	inventory_image = "moon_sensor_port_tool.png",
	on_place = function(itemstack, placer, pointed)
		return attach_port(
			itemstack, placer, pointed,
			moon.PORT.SENSOR,
			{value=0}
		)
	end,
})

return dev_items
