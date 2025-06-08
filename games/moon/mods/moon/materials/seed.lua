local registry = materials.registry
local flags = materials.flags

local function add_metal(id, rho, density)
	registry.add(id, {
		name = id,
		flags = flags.METAL,
		rho = rho,
		epsilon_r = 1.0,
		mu_r = 1.0,
		density = density,
		baseline_T = 293.15,
		reaction_id = 0,
	})
end

-- Copper
add_metal("Cu", 1.68e-8, 8960)

-- Steel
add_metal("Steel", 1.43e-7, 7850)

-- Carbon
registry.add("C", {
	name = "C",
	flags = flags.STRUCTURAL,
	rho = 3.5e-5,
	epsilon_r = 1.0,
	mu_r = 1.0,
	density = 2267,
	baseline_T = 293.15,
	reaction_id = 0,
})

-- Vacuum
registry.add("Vac", {
	name = "Vac",
	flags = flags.INSULATOR,
	rho = 1e20,
	epsilon_r = 1.0,
	mu_r = 1.0,
	density = 1.0,
	baseline_T = 293.15,
	reaction_id = 0,
})
