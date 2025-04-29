-- constants.lua
-- Central numerical constants (voxel size, tick length, solver limits, bit masks) imported by every module

local C = {}

-- Simulation timing
C.TICK_LENGTH      = 0.05      -- seconds per simulation tick (aligns with Minetest physics tick)
C.IDLE_INTERVAL    = 1.0       -- seconds to sleep before re-evaluating idle islands

-- Voxel/geometry
C.VOXEL_EDGE       = 0.05      -- meters (each primitive-engine voxel edge length)
C.VOXEL_VOLUME     = C.VOXEL_EDGE ^ 3

-- Limits
C.MAX_ISLAND_NODES = 4096      -- max voxels per simulation island
C.MAX_BONDS_PER_VX = 6         -- each voxel can have at most 6 bonds (one per face)
C.MAX_SOLVER_ITERS = 32        -- max iterations for any iterative solver (e.g., electrical)
C.MAX_PORTS        = 2^24      -- arbitrary; can be increased if needed

-- Numeric sentinels
C.NIL_NODE_ID      = 0xFFFF    -- sentinel for no node (uint16)
C.NIL_PORT_ID      = 0ULL      -- port id 0 means "no port" (uint64)
C.NIL_BOND_ID      = 0xFFFFFFFF -- sentinel for no bond (uint32)
C.NIL_ISLAND_ID    = 0ULL      -- island id 0 means "no island" (uint64)

-- Solver-specific
C.RF_RANGE         = 16        -- meters; max radio frequency port range

-- Bit positions for voxel flag words (uint8)
C.FLAG_CONDUCTOR   = 0 -- 1 << 0
C.FLAG_INSULATOR   = 1 -- 1 << 1
C.FLAG_FERROMAG    = 2 -- 1 << 2
C.FLAG_STRUCTURAL  = 3 -- 1 << 3
C.FLAG_FLUID       = 4 -- 1 << 4
C.FLAG_REACTIVE    = 5 -- 1 << 5
-- bits 6 and 7 reserved

-- Bit masks for voxel flags (for convenience)
C.BIT_CONDUCTOR    = 1 -- << C.FLAG_CONDUCTOR # DMR: commented this out.. unsure if correct
C.BIT_INSULATOR    = 1 -- << C.FLAG_INSULATOR # DMR: commented this out.. unsure if correct
C.BIT_FERROMAG     = 1 -- << C.FLAG_FERROMAG # DMR: commented this out.. unsure if correct
C.BIT_STRUCTURAL   = 1 -- << C.FLAG_STRUCTURAL # DMR: commented this out.. unsure if correct
C.BIT_FLUID        = 1 -- << C.FLAG_FLUID # DMR: commented this out.. unsure if correct
C.BIT_REACTIVE     = 1 -- << C.FLAG_REACTIVE # DMR: commented this out.. unsure if correct

return C