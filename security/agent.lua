local modem = peripheral.find("modem")
if not modem then
    print("Error: Modem not found!")
    return
end
rednet.open(peripheral.getName(modem))

local home_x, home_y, home_z = gps.locate(2)
if not home_x then
    print("Error: GPS signal lost. Cannot establish Home Base.")
    return
end

local flight_y = home_y + 2
local current_x, current_y, current_z = home_x, home_y, home_z
local current_dir = 0
local state = "IDLE"

local target_x, target_y, target_z = nil, nil, nil

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
            log("Hit obstacle.")
        end
        os.sleep(0.3)
        if attempts > 5 then return false end
    end
    
    if moveType == "up" then current_y = current_y + 1
    elseif moveType == "down" then current_y = current_y - 1
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

local function turnTowards(tx, tz)
    local dx = tx - current_x
    local dz = tz - current_z
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
    if current_x == tx and current_y == ty and current_z == tz then return end
    
    if current_x ~= tx or current_z ~= tz then
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
    end

    while current_y > ty do moveDown() end
    while current_y < ty do moveUp() end
end

log("Drone Online. Base: X:"..home_x.." Z:"..home_z)
log("Waiting for radar coordinates...")

-- Перед запуском черепаха должна смотреть на Север (-Z)
-- Калибровка компаса через движение
if turtle.forward() then
    local nx, ny, nz = gps.locate(2)
    if nz < home_z then current_dir = 0
    elseif nx > home_x then current_dir = 1
    elseif nz > home_z then current_dir = 2
    elseif nx < home_x then current_dir = 3
    end
    turtle.back()
end

while true do
    local id, msg = rednet.receive("guard_channel", 0.5)
    
    if msg and type(msg) == "table" then
        if msg.type == "target" then
            target_x = msg.x
            target_y = msg.y
            target_z = msg.z
            if state == "IDLE" then setState("INTERCEPT") end
        elseif msg.type == "clear" then
            if state == "INTERCEPT" or state == "ENGAGE" then
                log("Radar reports clear.")
                target_x = nil
                while turtle.suck() do end
                setState("RETURN_TO_BASE")
            end
        end
    end

    if turtle.getFuelLevel() < 500 or turtle.getItemCount(15) > 0 then
        if state ~= "RETURN_TO_BASE" then setState("RETURN_TO_BASE") end
    end

    if state == "INTERCEPT" and target_x then
        local dist = math.abs(current_x - target_x) + math.abs(current_z - target_z)
        if dist > 1 then
            gotoAbsolute(target_x, flight_y, target_z)
        else
            setState("ENGAGE")
        end

    elseif state == "ENGAGE" and target_x then
        turnTowards(target_x, target_z)
        turtle.attack()
        turtle.attackUp()
        turtle.attackDown()

    elseif state == "RETURN_TO_BASE" then
        gotoAbsolute(home_x, home_y, home_z)
        while current_dir ~= 0 do turnRight() end
        
        for slot = 1, 16 do
            turtle.select(slot)
            if not turtle.refuel(0) and turtle.getItemCount(slot) > 0 then
                turtle.dropDown()
            end
        end
        turtle.select(1)
        
        while turtle.getFuelLevel() < 1000 do
            if turtle.suckUp() then turtle.refuel() else os.sleep(5) end
        end
        
        setState("IDLE")
    end
end