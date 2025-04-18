minetest.log("action", "[ANTS MOD] Registering ant entity")

minetest.register_entity("moon:ant", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.2, -0.01, -0.2, 0.2, 0.2, 0.2},
        visual = "sprite",
        textures = {"default_grass.png"},  -- use a placeholder
        visual_size = {x = 0.5, y = 0.5},
        nametag = "ANT",
        nametag_color = "#FF0000",
    },

    on_step = function(self, dtime)
        self.timer = (self.timer or 0) + dtime
        if self.timer > 2 then
            self.timer = 0
            local yaw = math.random() * math.pi * 2
            self.object:set_yaw(yaw)
            local vel = self.object:get_velocity()
            self.object:set_velocity({
                x = math.cos(yaw),
                y = vel.y,
                z = math.sin(yaw),
            })
        end
    end,
})
