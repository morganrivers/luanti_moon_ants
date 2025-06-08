local demo_blueprints = dofile(minetest.get_modpath("moon").."/schematics/demo_blueprints.lua")
local detector = moon.islands.detector

local function is_debug_enabled()
	return minetest.settings:get_bool("moon_debug", true)
end

minetest.register_chatcommand("moon_rc_demo", {
	params = "",
	description = "Place an RC circuit demo at your position.",
	privs = {server = true},
	func = function(name, param)
		if not is_debug_enabled() then
			return false, "Debug commands are disabled."
		end
		local player = minetest.get_player_by_name(name)
		if player then
			local pos = vector.add(player:get_pos(), {x=2,y=0,z=0})
			demo_blueprints.place_rc_demo(pos)
			return true, "RC demo placed."
		end
		return false, "Player not found."
	end
})

minetest.register_chatcommand("moon_wheel_demo", {
	params = "",
	description = "Place a wheel assembly demo at your position.",
	privs = {server = true},
	func = function(name, param)
		if not is_debug_enabled() then
			return false, "Debug commands are disabled."
		end
		local player = minetest.get_player_by_name(name)
		if player then
			local pos = vector.add(player:get_pos(), {x=2,y=0,z=0})
			demo_blueprints.place_wheel_demo(pos)
			return true, "Wheel assembly demo placed."
		end
		return false, "Player not found."
	end
})

minetest.register_chatcommand("moon_island_dump", {
	params = "",
	description = "Dump all active simulated islands to server log.",
	privs = {server = true},
	func = function(name, param)
		if not is_debug_enabled() then
			return false, "Debug commands are disabled."
		end
		local log = minetest.log
		local output = {}
		for _, island in pairs(detector.scan_all()) do
			local id = island.id or "<no id>"
			local vcount = #island.voxels
			local dirty = island.dirty and "dirty" or "clean"
			local ports = {}
			if island.ports then
				for _, p in ipairs(island.ports) do
					table.insert(ports, tostring(p.type))
				end
			end
			log("action", ("[moon] Island %s: %d voxels, %s, ports: [%s]"):format(
				id, vcount, dirty, table.concat(ports, ", ")
			))
		end
		return true, "Island dump written to server log."
	end
})
