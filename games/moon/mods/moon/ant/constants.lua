-- ant/constants.lua
local C = {}

C.initial_properties = {
	physical               = true,
	collide_with_objects   = true,
	collisionbox           = {-0.3, -0.01, -0.3, 0.3, 0.25, 0.3},
	visual                 = "sprite",
	textures               = {"ant.png"},
	visual_size            = {x = 1.2, y = 1.2},
	nametag                = "Rover Unit",
	nametag_color          = "#00AAFF",
	is_visible             = true,
}

-- tweakable tunables
C.STEP_BEFORE_TURN   = 10
C.DIG_COOLDOWN_SEC   = 1.0
C.INVENTORY_CAPACITY = 3
C.HUB_SEARCH_RADIUS  = 20
C.RESOURCE_SCAN_RADIUS = 8
C.HUB_REGOLITH_THRESHOLD = 20   -- above this: ignore regolith
C.SPARE_BLOCKS           = 1    -- keep after deposit
C.CLIMB_WANDER_STEPS = 10      -- how long to forget x‑z once underneath

return C
