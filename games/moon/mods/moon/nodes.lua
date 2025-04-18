minetest.register_node("moon:regolith", {
    description = "Moon Regolith",
    tiles = {"default_gravel.png"},
    groups = {crumbly = 1},
})

-- Light colored regolith for crater rims and ejecta
minetest.register_node("moon:light_regolith", {
    description = "Light Moon Regolith",
    tiles = {"default_silver_sand.png"},
    groups = {crumbly = 1},
})

-- Dark regolith for crater bottoms
minetest.register_node("moon:dark_regolith", {
    description = "Dark Moon Regolith",
    tiles = {"default_stone.png^[colorize:#555555:120"},
    groups = {crumbly = 1},
})

-- Exposed bedrock for deep crater bottoms
minetest.register_node("moon:bedrock", {
    description = "Moon Bedrock",
    tiles = {"default_stone.png^[colorize:#444444:120"},
    groups = {cracky = 2},
})
