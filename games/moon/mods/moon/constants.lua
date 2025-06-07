-- constants.lua
-- Central numerical constants (voxel size, tick length, solver limits, bit masks) imported by every module

constants = {}

-- Simulation timing
constants.TICK_LENGTH      = 0.05      -- seconds per simulation tick (aligns with Minetest physics tick)
constants.IDLE_INTERVAL    = 1.0       -- seconds to sleep before re-evaluating idle islands

-- Voxel/geometry
constants.VOXEL_EDGE       = 0.05      -- meters (each primitive-engine voxel edge length)
constants.VOXEL_VOLUME     = constants.VOXEL_EDGE ^ 3

-- Limits
constants.MAX_ISLAND_NODES = 4096      -- max voxels per simulation island
constants.MAX_BONDS_PER_VX = 6         -- each voxel can have at most 6 bonds (one per face)
constants.MAX_SOLVER_ITERS = 32        -- max iterations for any iterative solver (e.g., electrical)
constants.MAX_PORTS        = 2^24      -- arbitrary; can be increased if needed

-- Numeric sentinels
constants.NIL_NODE_ID      = 0xFFFF    -- sentinel for no node (uint16)
constants.NIL_PORT_ID      = 0      -- port id 0 means "no port" (uint64)
constants.NIL_BOND_ID      = 0xFFFFFFFF -- sentinel for no bond (uint32)
constants.NIL_ISLAND_ID    = 0      -- island id 0 means "no island" (uint64)

-- Solver-specific
constants.RF_RANGE         = 16        -- meters; max radio frequency port range

-- Bit positions for voxel flag words (uint8)
constants.FLAG_CONDUCTOR   = 0 -- 1 << 0
constants.FLAG_INSULATOR   = 1 -- 1 << 1
constants.FLAG_FERROMAG    = 2 -- 1 << 2
constants.FLAG_STRUCTURAL  = 3 -- 1 << 3
constants.FLAG_FLUID       = 4 -- 1 << 4
constants.FLAG_REACTIVE    = 5 -- 1 << 5
-- bits 6 and 7 reserved

-- Bit masks for voxel flags (for convenience)
constants.BIT_CONDUCTOR    = 1 -- << constants.FLAG_CONDUCTOR # DMR: commented this out.. unsure if correct
constants.BIT_INSULATOR    = 1 -- << constants.FLAG_INSULATOR # DMR: commented this out.. unsure if correct
constants.BIT_FERROMAG     = 1 -- << constants.FLAG_FERROMAG # DMR: commented this out.. unsure if correct
constants.BIT_STRUCTURAL   = 1 -- << constants.FLAG_STRUCTURAL # DMR: commented this out.. unsure if correct
constants.BIT_FLUID        = 1 -- << constants.FLAG_FLUID # DMR: commented this out.. unsure if correct
constants.BIT_REACTIVE     = 1 -- << constants.FLAG_REACTIVE # DMR: commented this out.. unsure if correct

return constants
