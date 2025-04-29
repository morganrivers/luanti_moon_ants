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

-- return MATERIAL

