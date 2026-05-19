local sensor = peripheral.find("environmentDetector") or peripheral.find("environment_detector")

if not sensor then 
    print("Error: Radar not found!") 
    return 
end

print("Found peripheral: " .. peripheral.getName(sensor))

if not sensor.scanEntities then
    print("FATAL ERROR: scanEntities method is MISSING!")
    print("Available methods in your version:")
    for k, v in pairs(sensor) do
        print("- " .. tostring(k))
    end
    return
end

local result, err = sensor.scanEntities(16)

print("Return Type: " .. type(result))
print("Return Value: " .. tostring(result))

if err then
    print("HIDDEN MOD ERROR: " .. tostring(err))
end

if type(result) == "table" then
    local count = 0
    for k, v in pairs(result) do count = count + 1 end
    print("Table size (entities): " .. count)
    
    if count > 0 then
        for _, e in pairs(result) do
            print("Found: " .. tostring(e.name))
            break
        end
    end
end