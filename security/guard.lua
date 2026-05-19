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
local current_dir = 0
local state = "IDLE"
local current_target = nil

local function log(msg)
    local time = os.date("%H:%M:%S")
    print("["..time.."] " .. msg)
end

local function setState(newState)
    if state ~= newState then
        log("STATE: " .. state .. " -> " .. newState)
        state = newState
    end
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
    local attempts = 0
    while not moveFunc() do
        attempts = attempts + 1
        turtle.dig()
        if turtle.attack() then
            log("Attacked something while moving.")
        end
        os.sleep(0.5)
        if attempts > 10 then
            log("WARNING: Stuck trying to move " .. moveType)
        end
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
    local entities, err = sensor.scanEntities(radius)
    
    if not entities then 
        if err then 
            log("SENSOR ERROR: " .. tostring(err)) 
        end
        return nil 
    end

    for _, entity in pairs(entities) do
        if isEnemy(entity.name) then
            local abs_x = current_x + math.floor(entity.x + 0.5)
            local abs_y = current_y + math.floor(entity.y + 0.5)
            local abs_z = current_z + math.floor(entity.z + 0.5)
            
            if abs_x >= min_x and abs_x <= max_x and abs_z >= min_z and abs_z <= max_z then
                entity.abs_x = abs_x
                entity.abs_y = abs_y
                entity.abs_z = abs_z
                log("TARGET LOCKED: " .. entity.name .. " at X:" .. abs_x .. " Z:" .. abs_z)
                return entity
            end
        end
    end
    return nil
end

log("Guard Protocol Active. Base: (0,0,0)")

while true do
    if turtle.getFuelLevel() < 3000 or turtle.getItemCount(15) > 0 then
        setState("RETURN_TO_BASE")
    end

    if state == "IDLE" then
        os.sleep(2)
        current_target = scanForThreats()
        if current_target then
            setState("INTERCEPT")
        else
            if math.random() > 0.8 then setState("PATROL_MOVE") end
        end

    elseif state == "PATROL_MOVE" then
        local p_x = math.random(min_x, max_x)
        local p_z = math.random(min_z, max_z)
        gotoAbsolute(p_x, flight_y, p_z)
        setState("IDLE")

    elseif state == "INTERCEPT" then
        if current_target then
            gotoAbsolute(current_target.abs_x, flight_y, current_target.abs_z)
            local dist = math.abs(current_x - current_target.abs_x) + math.abs(current_z - current_target.abs_z)
            
            local verify = scanForThreats()
            if verify and verify.name == current_target.name then
                current_target = verify
                if dist <= 2 then setState("ENGAGE") end
            else
                log("Target lost.")
                current_target = nil
                setState("RETURN_TO_BASE")
            end
        else
            setState("RETURN_TO_BASE")
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
                log("Threat neutralized.")
                os.sleep(0.5)
                while turtle.suck() do end
                current_target = nil
                setState("RETURN_TO_BASE")
            end
        else
            setState("RETURN_TO_BASE")
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
        setState("IDLE")
    end
end