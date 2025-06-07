-- tiny pure-Lua bit-operations for Lua 5.1  (public domain)
local bit = {}

local floor, ldexp = math.floor, math.ldexp   -- ldexp(x, n) == x * 2^n

local function mask32(x)   return x % 2^32 end                 -- keep 32 bits
local function band(a,b)   local r = 0
    for i = 0,31 do
        local bit = 2^i
        if (a % (bit*2) >= bit) and (b % (bit*2) >= bit) then
            r = r + bit
        end
    end
    return r
end

local function bor(a,b)    local r = 0
    for i = 0,31 do
        local bit = 2^i
        if (a % (bit*2) >= bit) or (b % (bit*2) >= bit) then
            r = r + bit
        end
    end
    return r
end

local function bxor(a,b)   return bor(a, b) - band(a, b) end
local function lshift(a,n) return mask32(a * 2^n) end
local function rshift(a,n) return floor(a / 2^n) end

bit.band, bit.bor, bit.bxor = band, bor, bxor
bit.lshift, bit.rshift      = lshift, rshift

return bit