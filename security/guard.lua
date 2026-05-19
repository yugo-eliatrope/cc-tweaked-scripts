local modem = peripheral.find("modem")
local sensor = peripheral.find("sensor")

if modem then rednet.open(peripheral.getName(modem)) end
if not sensor then
    print("Error: Advanced Peripherals Entity Sensor not found!")
    return
end

local radius = 15
local home_x, home_y, home_z = gps.locate(2)
if not home_x then
    print("Error: GPS signal lost. Cannot establish Home Base.")
    return
end

local min_x, max_x = home_x - radius, home_x + radius
local min_z, max_z = home_z - radius, home_z + radius
local flight_y = home_y + 2

local current_x, current_y, current_z = home_x, home_y, home_z
local state = "IDLE"
local current_target = nil

local blacklist = {
    ["minecraft:zombie"] = true,
    ["minecraft:skeleton"] = true,
    ["minecraft:spider"] = true,
    ["minecraft:creeper"] = true,
    ["minecraft:enderman"] = true
}

local function updatePos(dx, dy, dz)
    current_x = current_x + dx
    current_y = current_y + dy
    current_z = current_z + dz
end

local function tryMove(moveFunc, dx, dy, dz)
    if moveFunc() then
        updatePos(dx, dy, dz)
        return true
    end
    turtle.dig()
    turtle.attack()
    if moveFunc() then
        updatePos(dx, dy, dz)
        return true
    end
    return false
end

local function moveUp() return tryMove(turtle.up, 0, 1, 0) end
local function moveDown() return tryMove(turtle.down, 0, -1, 0) end
local function moveForward(dx, dz) return tryMove(turtle.forward, dx, 0, dz) end

local function turnTowards(target_x, target_z)
    local dx = target_x - current_x
    local dz = target_z - current_z
    
    if math.abs(dx) > math.abs(dz) then
        if dx > 0 then
            while turtle.getDirection() ~= 1 do turtle.turnRight() end
        else
            while turtle.getDirection() ~= 3 do turtle.turnRight() end
        end
    else
        if dz > 0 then
            while turtle.getDirection() ~= 2 do turtle.turnRight() end
        else
            while turtle.getDirection() ~= 0 do turtle.turnRight() end
        end
    end
end

local function gotoAbsolute(tx, ty, tz)
    while current_y < flight_y do
        if not moveUp() then break end
    end

    while current_x ~= tx do
        local dx = (tx > current_x) and 1 or -1
        turnTowards(current_x + dx, current_z)
        if not moveForward(dx, 0) then break end
    end

    while current_z ~= tz do
        local dz = (tz > current_z) and 1 or -1
        turnTowards(current_x, current_z + dz)
        if not moveForward(0, dz) then break end
    end

    while current_y > ty do
        if not moveDown() then break end
    end
end

local function scanForThreats()
    local entities = sensor.sense()
    for _, entity in pairs(entities) do
        if blacklist[entity.name] then
            if entity.x >= min_x and entity.x <= max_x and entity.z >= min_z and entity.z <= max_z then
                return entity
            end
        end
    end
    return nil
end

local function beaconLoop()
    local last_x, last_y, last_z = -1, -1, -1
    while true do
        local x, y, z = gps.locate(2)
        if x and (x ~= last_x or y ~= last_y or z ~= last_z) then
            if modem then
                rednet.broadcast({type = "drone_telemetry", x = x, y = y, z = z, state = state}, "security_channel")
            end
            last_x, last_y, last_z = x, y, z
        end
        os.sleep(10)
    end
end

local function aiLoop()
    while true do
        if turtle.getFuelLevel() < 100 or turtle.getItemCount(15) > 0 then
            state = "RETURN_TO_BASE"
        end

        if state == "IDLE" then
            os.sleep(2)
            current_target = scanForThreats()
            if current_target then
                state = "INTERCEPT"
            else
                if math.random() > 0.7 then state = "PATROL_MOVE" end
            end

        elseif state == "PATROL_MOVE" then
            local p_x = math.random(min_x, max_x)
            local p_z = math.random(min_z, max_z)
            gotoAbsolute(p_x, flight_y, p_z)
            state = "IDLE"

        elseif state == "INTERCEPT" then
            if current_target then
                gotoAbsolute(current_target.x, flight_y, current_target.z)
                local dist = math.abs(current_x - current_target.x) + math.abs(current_z - current_target.z)
                
                local verify = scanForThreats()
                if verify and verify.name == current_target.name then
                    current_target = verify
                    if dist <= 2 then
                        state = "ENGAGE"
                    end
                else
                    current_target = nil
                    state = "RETURN_TO_BASE"
                end
            else
                state = "RETURN_TO_BASE"
            end

        elseif state == "ENGAGE" then
            if current_target then
                turnTowards(current_target.x, current_target.z)
                turtle.attack()
                
                local still_alive = false
                local entities = sensor.sense()
                for _, e in pairs(entities) do
                    if e.uuid == current_target.uuid then still_alive = true break end
                end
                
                if not still_alive then
                    while turtle.suck() do end
                    current_target = nil
                    state = "RETURN_TO_BASE"
                end
            else
                state = "RETURN_TO_BASE"
            end

        elseif state == "RETURN_TO_BASE" then
            gotoAbsolute(home_x, home_y, home_z)
            
            for slot = 1, 16 do
                turtle.select(slot)
                if turtle.refuel(0) then
                    turtle.refuel()
                else
                    turtle.dropDown()
                end
            end
            turtle.select(1)
            state = "IDLE"
        end
    end
end

parallel.waitForAny(beaconLoop, aiLoop)
