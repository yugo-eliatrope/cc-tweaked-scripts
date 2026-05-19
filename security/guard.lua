local sensor = peripheral.find("environmentDetector") or peripheral.find("environment_detector")

if not sensor then
    print("Error: Advanced Peripherals Environment Detector not found!")
    return
end

local radius = 15
local min_x, max_x = -radius, radius
local min_z, max_z = -radius, radius
local flight_y = 2

local current_x, current_y, current_z = 0, 0, 0
local current_dir = 0 -- 0: North (-Z), 1: East (+X), 2: South (+Z), 3: West (-X)
local state = "IDLE"
local current_target = nil

local blacklist = {
    ["minecraft:zombie"] = true,
    ["minecraft:skeleton"] = true,
    ["minecraft:spider"] = true,
    ["minecraft:creeper"] = true,
    ["minecraft:enderman"] = true
}

local function turnLeft()
    turtle.turnLeft()
    current_dir = (current_dir - 1) % 4
    if current_dir < 0 then current_dir = current_dir + 4 end
end

local function turnRight()
    turtle.turnRight()
    current_dir = (current_dir + 1) % 4
end

local function tryMove(moveFunc, moveType)
    while not moveFunc() do
        turtle.dig()
        turtle.attack()
        os.sleep(0.5)
    end
    
    if moveType == "up" then 
        current_y = current_y + 1
    elseif moveType == "down" then 
        current_y = current_y - 1
    elseif moveType == "forward" then
        if current_dir == 0 then current_z = current_z - 1
        elseif current_dir == 1 then current_x = current_x + 1
        elseif current_dir == 2 then current_z = current_z + 1
        elseif current_dir == 3 then current_x = current_x - 1
        end
    end
    return true
end

local function moveUp() return tryMove(turtle.up, "up") end
local function moveDown() return tryMove(turtle.down, "down") end
local function moveForward() return tryMove(turtle.forward, "forward") end

local function turnTowards(target_x, target_z)
    local dx = target_x - current_x
    local dz = target_z - current_z
    local target_dir = current_dir
    
    if math.abs(dx) > math.abs(dz) then
        target_dir = (dx > 0) and 1 or 3
    else
        target_dir = (dz > 0) and 2 or 0
    end
    
    while current_dir ~= target_dir do
        turnRight()
    end
end

local function gotoAbsolute(tx, ty, tz)
    while current_y < flight_y do moveUp() end

    while current_x ~= tx do
        local dx = (tx > current_x) and 1 or -1
        turnTowards(current_x + dx, current_z)
        moveForward()
    end

    while current_z ~= tz do
        local dz = (tz > current_z) and 1 or -1
        turnTowards(current_x, current_z + dz)
        moveForward()
    end

    while current_y > ty do moveDown() end
end

local function scanForThreats()
    local entities = sensor.scanEntities(radius)
    if not entities then return nil end

    for _, entity in pairs(entities) do
        if blacklist[entity.name] then
            local abs_x = current_x + math.floor(entity.x + 0.5)
            local abs_y = current_y + math.floor(entity.y + 0.5)
            local abs_z = current_z + math.floor(entity.z + 0.5)
            
            if abs_x >= min_x and abs_x <= max_x and abs_z >= min_z and abs_z <= max_z then
                entity.abs_x = abs_x
                entity.abs_y = abs_y
                entity.abs_z = abs_z
                return entity
            end
        end
    end
    return nil
end

while true do
    if turtle.getFuelLevel() < 50 or turtle.getItemCount(15) > 0 then
        state = "RETURN_TO_BASE"
    end

    if state == "IDLE" then
        os.sleep(2)
        current_target = scanForThreats()
        if current_target then
            state = "INTERCEPT"
        else
            if math.random() > 0.8 then state = "PATROL_MOVE" end
        end

    elseif state == "PATROL_MOVE" then
        local p_x = math.random(min_x, max_x)
        local p_z = math.random(min_z, max_z)
        gotoAbsolute(p_x, flight_y, p_z)
        state = "IDLE"

    elseif state == "INTERCEPT" then
        if current_target then
            gotoAbsolute(current_target.abs_x, flight_y, current_target.abs_z)
            local dist = math.abs(current_x - current_target.abs_x) + math.abs(current_z - current_target.abs_z)
            
            local verify = scanForThreats()
            if verify and verify.name == current_target.name then
                current_target = verify
                if dist <= 2 then state = "ENGAGE" end
            else
                current_target = nil
                state = "RETURN_TO_BASE"
            end
        else
            state = "RETURN_TO_BASE"
        end

    elseif state == "ENGAGE" then
        if current_target then
            turnTowards(current_target.abs_x, current_target.abs_z)
            turtle.attack()
            
            local still_alive = false
            local entities = sensor.scanEntities(radius)
            if entities then
                for _, e in pairs(entities) do
                    if e.name == current_target.name and math.abs(e.x) <= 2 and math.abs(e.z) <= 2 then 
                        still_alive = true 
                        current_target.abs_x = current_x + math.floor(e.x + 0.5)
                        current_target.abs_z = current_z + math.floor(e.z + 0.5)
                        break 
                    end
                end
            end
            
            if not still_alive then
                os.sleep(0.5)
                while turtle.suck() do end
                current_target = nil
                state = "RETURN_TO_BASE"
            end
        else
            state = "RETURN_TO_BASE"
        end

    elseif state == "RETURN_TO_BASE" then
        gotoAbsolute(0, 0, 0)
        
        while current_dir ~= 0 do turnRight() end
        
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
