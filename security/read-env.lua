local sensor = peripheral.find("environmentDetector") or peripheral.find("environment_detector")

if not sensor then 
    print("Error: Radar not found!") 
    return 
end

-- Passing the required radius (16 blocks)
local entities = sensor.scanEntities(16) 

if not entities or type(entities) ~= "table" then
    print("Radar returned nothing (nil or empty)")
    return
end

local count = 0
for _ in pairs(entities) do count = count + 1 end
print("Total entities around: " .. count)

-- Print the raw data of the first entity found
for _, e in pairs(entities) do
    print("--- MOB DATA ---")
    for k, v in pairs(e) do
        print(k .. ": " .. tostring(v))
    end
    break
end