-- Ants mod initialization
minetest.log("action", "[ANTS MOD] INITIALIZING!")
-- dofile(minetest.get_modpath("ants") .. "/ant.lua")

-- Register a command to spawn ants for testing
minetest.register_chatcommand("spawn_ant", {
    description = "Spawn an ant entity",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if player then
            local pos = player:get_pos()
            pos.y = pos.y + 1  -- Spawn slightly above player
            minetest.add_entity(pos, "ants:ant")
            return true, "Ant spawned!"
        end
        return false, "Player not found"
    end
})

minetest.log("action", "[ANTS MOD] LOADED SUCCESSFULLY - REGISTERED ENTITY: ants:ant")