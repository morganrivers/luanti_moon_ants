-- islands/queue.lua
-- Priority queue scheduling islands for solver passes while skipping idle chunks

dofile(minetest.get_modpath("moon") .. "/constants.lua")

queue = {}
queue.__index = queue

-- Min-heap, keyed by next_tick_time.
local function sift_up(heap, idx)
  while idx > 1 do
    local parent = math.floor(idx / 2)
    if heap[idx][1] < heap[parent][1] then
      heap[idx], heap[parent] = heap[parent], heap[idx]
      idx = parent
    else
      break
    end
  end
end

local function sift_down(heap, idx)
  local len = #heap
  while true do
    local left = idx * 2
    local right = left + 1
    local smallest = idx
    if left <= len and heap[left][1] < heap[smallest][1] then
      smallest = left
    end
    if right <= len and heap[right][1] < heap[smallest][1] then
      smallest = right
    end
    if not (smallest == idx) then
      heap[idx], heap[smallest] = heap[smallest], heap[idx]
      idx = smallest
    else
      break
    end
  end
end

local function island_id(island)
  -- Use the table address as a unique id.
  return tostring(island)
end

-- M = {} -- DMR changed from "M" to queue

-- The heap: { {next_tick_time, island}, ... }
local heap = {}
-- Map: island_id_str -> heap index
local index_map = {}

-- Push or update an island's scheduled time.
function queue.push_or_update(island, next_tick_time)
  local id = island_id(island)
  local idx = index_map[id]
  if idx then
    -- Update scheduled time and re-heapify
    local old_time = heap[idx][1]
    heap[idx][1] = next_tick_time
    if next_tick_time < old_time then
      sift_up(heap, idx)
    else
      sift_down(heap, idx)
    end
  else
    -- New entry
    local entry = {next_tick_time, island}
    heap[#heap + 1] = entry
    index_map[id] = #heap
    sift_up(heap, #heap)
  end
end

-- Remove an island from the queue (e.g. if destroyed/unloaded)
function queue.remove(island)
  local id = island_id(island)
  local idx = index_map[id]
  if not idx then return end
  local last = #heap
  if not (idx == last) then
    heap[idx] = heap[last]
    local moved_island = heap[idx][2]
    index_map[island_id(moved_island)] = idx
    heap[last] = nil
    index_map[id] = nil
    -- Fix heap property
    sift_up(heap, idx)
    sift_down(heap, idx)
  else
    heap[last] = nil
    index_map[id] = nil
  end
end

-- Returns a table of all islands scheduled at or before 'now'.
function queue.pop_due(now)
  local due = {}
  while #heap > 0 and heap[1][1] <= now do
    local entry = heap[1]
    local id = island_id(entry[2])
    table.insert(due, entry[2])
    -- Remove root, replace with last element, re-heapify
    local last = heap[#heap]
    heap[1] = last
    if last then
      index_map[island_id(last[2])] = 1
    end
    heap[#heap] = nil
    index_map[id] = nil
    sift_down(heap, 1)
  end
  return due
end

-- For debugging: return the scheduled time for a given island
function queue.scheduled_time(island)
  local id = island_id(island)
  local idx = index_map[id]
  if idx then
    return heap[idx][1]
  end
  return nil
end

-- For debugging: count of scheduled islands
function queue.size()
  return #heap
end


