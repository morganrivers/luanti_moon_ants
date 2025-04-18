-- Tiny helper to merge tables (shallow copy).
function table.extend(dest, src)
	for k, v in pairs(src) do dest[k] = v end
	return dest
end
