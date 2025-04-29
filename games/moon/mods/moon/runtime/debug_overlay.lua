-- runtime/debug_overlay.lua
-- Client-side overlay showing debug info (voltages, rpm, island bounds)

local S = minetest.get_translator and minetest.get_translator("moon") or function(s) return s end

local debug_overlay = {}

local enable_overlay = minetest.settings:get_bool("moon_debug_overlay", false)
local overlays = {}  -- island_id -> {bbox, dirty, voxels, data}
local show_overlay = false

-- Store the current debug data received from the server
local function update_overlay(island_id, bbox, dirty, voxels, data)
	overlays[island_id] = {
		bbox = bbox,
		dirty = dirty,
		voxels = voxels,
		data = data,
		timestamp = minetest.get_us_time()
	}
end

-- Remove overlays for vanished islands (timeout: 2s)
local function prune_overlays()
	local now = minetest.get_us_time()
	for id,ov in pairs(overlays) do
		if now - (ov.timestamp or 0) > 2e6 then
			overlays[id] = nil
		end
	end
end

-- Color by dirty state
local function island_color(dirty)
	if dirty then
		return {r=255, g=64, b=64, a=128}
	else
		return {r=64, g=255, b=128, a=80}
	end
end

-- Draw bounding boxes for all overlays
local function draw_island_boxes()
	for id,ov in pairs(overlays) do
		local minp = ov.bbox.min
		local maxp = ov.bbox.max
		local col = island_color(ov.dirty)
		minetest.add_entity({
			x = (minp.x + maxp.x + 1) * 0.5,
			y = (minp.y + maxp.y + 1) * 0.5,
			z = (minp.z + maxp.z + 1) * 0.5
		}, "moon:debug_box", {
			min = minp,
			max = maxp,
			color = col
		})
	end
end

-- Tooltip helpers
local function format_voxel_tooltip(pos, data)
	if not data then return "" end
	local tip = ""
	if data.voltage then
		tip = tip .. S("Voltage: @1 V", string.format("%.3f", data.voltage)) .. "\n"
	end
	if data.rpm then
		tip = tip .. S("Shaft: @1 rpm", string.format("%.1f", data.rpm)) .. "\n"
	end
	if data.temp then
		tip = tip .. S("Temp: @1 K", string.format("%.1f", data.temp)) .. "\n"
	end
	return tip
end

-- HUD: when player points at a voxel, show its debug info (if present)
local hud_id = nil
local last_tip = ""

local function update_voxel_tooltip()
	local player = minetest.localplayer
	if not player then return end
	local pointed = minetest.get_pointed_thing()
	if not pointed or pointed.type ~= "node" then
		if hud_id then
			player:hud_remove(hud_id)
			hud_id = nil
			last_tip = ""
		end
		return
	end
	local pos = pointed.under
	for _,ov in pairs(overlays) do
		if ov.voxels then
			for _,vpos in ipairs(ov.voxels) do
				if vpos.x == pos.x and vpos.y == pos.y and vpos.z == pos.z then
					local tip = format_voxel_tooltip(pos, ov.data and ov.data[minetest.pos_to_string(pos)])
					if tip ~= last_tip then
						if hud_id then player:hud_remove(hud_id) end
						hud_id = player:hud_add({
							hud_elem_type = "text",
							position = {x=0.5, y=0.9},
							offset = {x=0, y=0},
							text = tip,
							alignment = {x=0, y=0},
							number = 0xFFFFFF,
							scale = {x=200, y=30}
						})
						last_tip = tip
					end
					return
				end
			end
		end
	end
	if hud_id then
		player:hud_remove(hud_id)
		hud_id = nil
		last_tip = ""
	end
end

-- Register debug_box entity for drawing bounding boxes (client-side only)
minetest.register_entity("moon:debug_box", {
	initial_properties = {
		visual = "cube",
		visual_size = {x=1, y=1, z=1},
		collisionbox = {0,0,0,0,0,0},
		pointable = false,
		physical = false,
		glow = 10,
		textures = {
			"moon_overlay.png^[multiply:#FFFFFF80",
			"moon_overlay.png^[multiply:#FFFFFF80",
			"moon_overlay.png^[multiply:#FFFFFF80",
			"moon_overlay.png^[multiply:#FFFFFF80",
			"moon_overlay.png^[multiply:#FFFFFF80",
			"moon_overlay.png^[multiply:#FFFFFF80",
		},
	},
	on_activate = function(self, staticdata, dtime_s)
		local meta = self:get_luaentity().meta or self.object:get_properties().meta
		if not meta then self.object:remove() return end
		local minp = meta.min
		local maxp = meta.max
		local size = {
			x = maxp.x - minp.x + 1,
			y = maxp.y - minp.y + 1,
			z = maxp.z - minp.z + 1
		}
		self.object:set_properties({
			visual_size = size,
			textures = {
				"moon_overlay.png^[multiply:"..
					string.format("#%02X%02X%02X%02X",
						meta.color.r, meta.color.g, meta.color.b, meta.color.a),
				"moon_overlay.png^[multiply:"..
					string.format("#%02X%02X%02X%02X",
						meta.color.r, meta.color.g, meta.color.b, meta.color.a),
				"moon_overlay.png^[multiply:"..
					string.format("#%02X%02X%02X%02X",
						meta.color.r, meta.color.g, meta.color.b, meta.color.a),
				"moon_overlay.png^[multiply:"..
					string.format("#%02X%02X%02X%02X",
						meta.color.r, meta.color.g, meta.color.b, meta.color.a),
				"moon_overlay.png^[multiply:"..
					string.format("#%02X%02X%02X%02X",
						meta.color.r, meta.color.g, meta.color.b, meta.color.a),
				"moon_overlay.png^[multiply:"..
					string.format("#%02X%02X%02X%02X",
						meta.color.r, meta.color.g, meta.color.b, meta.color.a),
			}
		})
	end,
	on_step = function(self, dtime)
		self.timer = (self.timer or 0) + dtime
		if self.timer > 1 then
			self.object:remove()
		end
	end,
})

-- Packet handler: receive overlay debug info from server
minetest.register_on_modchannel_message(function(channel_name, sender, message)
	if channel_name ~= "moon:debug_overlay" then return end
	local ok, chunk = pcall(minetest.parse_json, message)
	if not ok or type(chunk) ~= "table" then return end
	-- chunk: { island_id, bbox={min={x=,y=,z=},max={x=,y=,z=}}, dirty, voxels={...}, data={pos_str->info} }
	update_overlay(chunk.island_id, chunk.bbox, chunk.dirty, chunk.voxels, chunk.data)
end)

-- Toggle overlay with chat command
minetest.register_chatcommand("moon_debug_overlay", {
	description = S("Toggle primitive-engine debug overlay"),
	func = function()
		show_overlay = not show_overlay
		minetest.chat_send_player(minetest.localplayer:get_name(),
			S("Debug overlay: @1", tostring(show_overlay)))
		return true
	end,
})

-- Main clientstep hook
minetest.register_globalstep(function(dtime)
	if not enable_overlay and not show_overlay then return end
	prune_overlays()
	draw_island_boxes()
	update_voxel_tooltip()
end)

return debug_overlay
