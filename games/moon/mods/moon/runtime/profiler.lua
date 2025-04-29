-- runtime/profiler.lua
local minetest = minetest

local solvers = {
  "electrical",
  "logic",
  "mechanical",
  "thermal",
  "chemistry",
  "rf",
  "material_flow",
  "mining",
}

-- Island size buckets: 1-3, 4-7, 8-15, 16-31, 32-63, 64-127, 128+
local size_buckets = {
  {min=1, max=3},
  {min=4, max=7},
  {min=8, max=15},
  {min=16, max=31},
  {min=32, max=63},
  {min=64, max=127},
  {min=128, max=math.huge},
}
local function get_bucket(size)
  for i, b in ipairs(size_buckets) do
    if size >= b.min and size <= b.max then return i end
  end
  return #size_buckets
end

-- profiler_data[solver][bucket] = {sum=total_us, n=samples, avg=μs}
local profiler_data = {}
for _, solver in ipairs(solvers) do
  profiler_data[solver] = {}
  for i=1,#size_buckets do
    profiler_data[solver][i] = {sum=0, n=0, avg=0}
  end
end

-- Sliding window: only last N samples per bucket
local MAX_SAMPLES = 64

local function record_time(solver, island_size, elapsed_us)
  local bucket = get_bucket(island_size)
  local bucket_data = profiler_data[solver][bucket]
  bucket_data.sum = bucket_data.sum + elapsed_us
  bucket_data.n = bucket_data.n + 1
  if bucket_data.n > MAX_SAMPLES then
    -- Decay oldest sample: approximate by subtracting avg
    bucket_data.sum = bucket_data.sum - bucket_data.avg
    bucket_data.n = MAX_SAMPLES
  end
  bucket_data.avg = bucket_data.sum / bucket_data.n
end

-- Wrappers for each solver: profiler.wrap(solver_name, func)
local profiler = {}

function profiler.wrap(solver_name, fn)
  return function(island, dt, ...)
    local start = minetest.get_us_time()
    local ret = {fn(island, dt, ...)}
    local elapsed = minetest.get_us_time() - start
    local island_size = 0
    if type(island) == "table" and island.voxels then
      if type(island.voxels) == "table" and not island.voxels.__len then
        -- Count keys if not array
        local n = 0
        for _ in pairs(island.voxels) do n = n + 1 end
        island_size = n
      else
        island_size = #island.voxels
      end
    end
    if island_size > 0 then
      record_time(solver_name, island_size, elapsed)
    end
    return table.unpack(ret)
  end
end

function profiler.get_stats()
  -- Returns a table: stats[solver][bucket] = {avg=..., n=...}
  local stats = {}
  for _, solver in ipairs(solvers) do
    stats[solver] = {}
    for i, b in ipairs(size_buckets) do
      local d = profiler_data[solver][i]
      stats[solver][i] = {
        avg = math.floor(d.avg + 0.5),
        n = d.n,
        min = b.min,
        max = b.max,
      }
    end
  end
  return stats
end

local function bucket_label(i)
  local b = size_buckets[i]
  if b.max == math.huge then
    return ("%d+"):format(b.min)
  else
    return ("%d-%d"):format(b.min, b.max)
  end
end

minetest.register_chatcommand("moon_profiler", {
  description = "Show primitive-engine solver CPU usage (μs) by island size",
  privs = {server=true},
  func = function(name)
    local stats = profiler.get_stats()
    local lines = {}
    table.insert(lines, "Primitive Engine Solver Profiling (avg μs over last "..MAX_SAMPLES.." samples):")
    local header = "Solver         "
    for i=1,#size_buckets do
      header = header .. ("| %8s "):format(bucket_label(i))
    end
    table.insert(lines, header)
    for _, solver in ipairs(solvers) do
      local row = ("% -14s"):format(solver)
      for i=1,#size_buckets do
        local d = stats[solver][i]
        if d.n > 0 then
          row = row .. ("| %8d "):format(d.avg)
        else
          row = row .. "|         "
        end
      end
      table.insert(lines, row)
    end
    minetest.chat_send_player(name, table.concat(lines, "\n"))
    return true
  end
})

return profiler
