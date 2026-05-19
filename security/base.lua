local modem = peripheral.find("modem")
local sensor = peripheral.find("environmentDetector") or peripheral.find("environment_detector")

if not modem or not sensor then
    print("Error: Modem or Environment Detector not found!")
    return
end

rednet.open(peripheral.getName(modem))

local base_x, base_y, base_z = gps.locate(2)
if not base_x then
    print("Error: GPS signal lost. Radar cannot calibrate.")
    return
end

local radius = 16

local function log(msg)
    local time = os.date("%H:%M:%S")
    print("["..time.."] " .. msg)
end

local function isEnemy(name)
    if type(name) ~= "string" then return false end
    name = string.lower(name)
    return string.find(name, "zombi") or 
           string.find(name, "skeleton") or 
           string.find(name, "spider") or 
           string.find(name, "creeper") or
           string.find(name, "enderman")
end

log("Radar online. Calibrated at X:"..base_x.." Y:"..base_y.." Z:"..base_z)

local function finClosestEntity(entities)
    local closest = nil
    local closestDist = math.huge
    for _, e in pairs(entities) do
        local dist = math.sqrt(e.x^2 + e.y^2 + e.z^2)
        if dist < closestDist then
            closestDist = dist
            closest = e
        end
    end
    return closest, closestDist
end

while true do
    local entities = sensor.scanEntities(radius)
    local target_found = false

    if entities then
        local closest, closestDist = finClosestEntity(entities)
        local abs_x = base_x + math.floor(closest.x + 0.5)
        local abs_y = base_y + math.floor(closest.y)
        local abs_z = base_z + math.floor(closest.z + 0.5)
        rednet.broadcast({type = "target", x = abs_x, y = abs_y, z = abs_z, uuid = closest.uuid}, "guard_channel")
        log("Closest entity: " .. tostring(closest.name) .. " at distance " .. string.format("%.2f", closestDist))
        target_found = true
    end

    if not target_found then
        rednet.broadcast({type = "clear"}, "guard_channel")
    end

    os.sleep(1)
end