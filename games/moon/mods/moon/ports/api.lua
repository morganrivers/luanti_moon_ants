local registry = require("ports.registry")

local api = {}

-- Internal: table of { [port_id] = { callback_fn, ... } }
local change_callbacks = {}

-- Write to a port latch and trigger change callbacks
function api.write(id, field, value)
  local port = registry.lookup(id)
  if not port then
    return false, "port not found"
  end
  local state = port.state
  if state[field] ~= value then
    state[field] = value
    -- Mark hosting island dirty: external runtime/islands integration expected
    if change_callbacks[id] then
      for _, fn in ipairs(change_callbacks[id]) do
        fn(id, field, value)
      end
    end
    return true
  end
  return false
end

-- Read a port latch value
function api.read(id, field)
  local port = registry.lookup(id)
  if not port then
    return nil, "port not found"
  end
  return port.state[field]
end

-- Subscribe to port latch changes for debug overlay or test harnesses
function api.on_change(id, callback_fn)
  if not change_callbacks[id] then
    change_callbacks[id] = {}
  end
  table.insert(change_callbacks[id], callback_fn)
end

-- For registry cleanup: remove all callbacks for a port
function api._remove_callbacks(id)
  change_callbacks[id] = nil
end

return api