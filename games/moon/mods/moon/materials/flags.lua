#!/usr/bin/env luajit
-- local ie = minetest.request_insecure_environment()
-- local bit = minetest.request_bit()

-- mods/moon/lib/bit.lua  (pure Lua, no C side)

-- return bit

-- flags.lua (top of file)
-- local ie = minetest.request_insecure_environment()
-- if not ie then
--     error("[moon] Please add this mod to secure.trusted_mods so we can load 'bit'")
-- end

-- local bit = ie.require("bit")  -- LuaJIT bit-ops library
local bit = dofile(minetest.get_modpath("moon") .. "/lib/bit.lua")



-- LOCAL bit = require("bit")   -- LuaJIT’s bit library
MATERIAL = {}

-- Bit-flag constants for base material roles
MATERIAL.CONDUCTOR   = 0x01  -- Electrically conductive
MATERIAL.INSULATOR   = 0x02  -- Electrically insulating
MATERIAL.FERROMAG    = 0x04  -- Ferromagnetic
MATERIAL.STRUCTURAL  = 0x08  -- Load-bearing / rigid
MATERIAL.FLUID       = 0x10  -- Flows, not rigid (liquid/gas/powder)
MATERIAL.REACTIVE    = 0x20  -- Will undergo reactions (chemically/metastable)

-- Common flag combinations
MATERIAL.METAL      = bit.bor(MATERIAL.CONDUCTOR, MATERIAL.STRUCTURAL)
MATERIAL.DIELECTRIC = bit.bor(MATERIAL.INSULATOR, MATERIAL.STRUCTURAL)
MATERIAL.MAGNETIC   = bit.bor(MATERIAL.FERROMAG, MATERIAL.STRUCTURAL)
MATERIAL.ELECTROLYTE= bit.bor(MATERIAL.CONDUCTOR, MATERIAL.FLUID, MATERIAL.REACTIVE)
MATERIAL.POWDER     = bit.bor(MATERIAL.FLUID, MATERIAL.REACTIVE)
MATERIAL.INERT_FLUID= bit.bor(MATERIAL.FLUID, MATERIAL.INSULATOR)

-- Mechanical components with visual pose updates
MATERIAL.WHEEL      = bit.bor(MATERIAL.STRUCTURAL, 0x40)  -- includes MECHANICAL_POSE flag (bit 6)
MATERIAL.SHAFT      = bit.bor(MATERIAL.STRUCTURAL, 0x40)  -- includes MECHANICAL_POSE flag (bit 6)
MATERIAL.CAPACITOR  = MATERIAL.DIELECTRIC

return MATERIAL

