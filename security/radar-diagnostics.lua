local sensor = peripheral.find("environmentDetector") or peripheral.find("environment_detector")

if not sensor then 
    print("Error: Radar peripheral not found!") 
    return 
end

-- Testing with a solid 16 radius
local entities, err = sensor.scanEntities(16)

if err then
    print("MOD ERROR: " .. tostring(err))
    return
end

if not entities or type(entities) ~= "table" then
    print("Result is nil or empty table.")
    return
end

local count = 0
for _ in pairs(entities) do count = count + 1 end
print("Total entities detected: " .. count)

-- Print raw format of the first detected entity
for _, e in pairs(entities) do
    print("--- RAW ENTITY DATA ---")
    for k, v in pairs(e) do
        print(k .. ": " .. tostring(v))
    end
    break
end