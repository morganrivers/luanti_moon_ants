local tests = {}

-- Register a test
function tests.test(name, fn)
    local status, err = pcall(fn)
    if status then
        print("[PASS]", name)
    else
        print("[FAIL]", name)
        print("       " .. tostring(err))
    end
end

-- Run all tests
function tests.run()
    print("Running tests...")
    -- add require statements here for your test files
    require("tests.test_bonds")
    require("tests.test_materials")
    require("tests.test_ports")
end

return tests
