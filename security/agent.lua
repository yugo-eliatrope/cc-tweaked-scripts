local function log(msg)
  local time = os.date("%H:%M:%S")
  print("["..time.."] " .. msg)
end

local modem = peripheral.find("modem")
if not modem then
  log("Error: Modem not found!")
  return
end
rednet.open(peripheral.getName(modem))

local home_x, home_y, home_z = gps.locate(2)
if not home_x then
  log("Error: GPS signal lost. Cannot establish Home Base.")
  return
end

local flight_y = home_y + 2
local current_dir = 0
local state = "IDLE"
local channel_name = "guard_channel"

local target = nil

local function setState(newState)
  if state ~= newState then
    log("STATE: " .. state .. " -> " .. newState)
    state = newState
  end
end

local function turnLeft()
  turtle.turnLeft()
  current_dir = current_dir - 1
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

local function turnTowards(pos, x, z)
  local dx = x - pos.x
  local dz = z - pos.z
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

local function gotoPosition(x, y, z)
  local pos = gps.locate(2)
  if pos.x == x and pos.y == y and pos.z == z then return end
  
  while pos.y < flight_y do moveUp() end
  while pos.x ~= x do
    local dx = (x > pos.x) and 1 or -1
    turnTowards(pos, pos.x + dx, pos.z)
    turtle.forward(Math.abs(x - pos.x))
    pos = gps.locate(2)
    if pos.x ~= x then
      log("Probably hit an obstacle")
      turtle.dig()
    end
  end
  while pos.z ~= z do
    local dz = (z > pos.z) and 1 or -1
    turnTowards(pos, pos.x, pos.z + dz)
    turtle.forward(Math.abs(z - pos.z))
    pos = gps.locate(2)
    if pos.z ~= z then
      log("Probably hit an obstacle")
      turtle.dig()
    end
  end

  while pos.y > y do moveDown() end
  while pos.y < y do moveUp() end
end

local function makeStepTowards(x, y, z)
  local current_x, current_y, current_z = gps.locate(2)
  if current_x == x and current_y == y and current_z == z then return end
  
  if current_x ~= x or current_z ~= z then
    while current_y < flight_y do moveUp() end

    local dx = (x > current_x) and 1 or -1
    local dz = (z > current_z) and 1 or -1
    
    if math.abs(x - current_x) > math.abs(z - current_z) then
      turnTowards(current_x + dx, current_z)
      moveForward()
    else
      turnTowards(current_x, current_z + dz)
      moveForward()
    end
  end
end

local function calibrateCompass()
  if turtle.forward() then
    local nx, ny, nz = gps.locate(2)
    if nz < home_z then current_dir = 0
    elseif nx > home_x then current_dir = 1
    elseif nz > home_z then current_dir = 2
    elseif nx < home_x then current_dir = 3
    end
    log("Compass calibrated. Facing direction: " .. current_dir)
    turtle.back()
  end
end

local function isOnBase()
  local x, y, z = gps.locate(2)
  return x == home_x and y == home_y and z == home_z
end

local function refuel()
  while turtle.getFuelLevel() < 1000 do
    if turtle.suckUp() then turtle.refuel() else os.sleep(5) end
  end
end

log("Drone Online. Base: X:"..home_x.." Z:"..home_z)
log("Calibrating compass...")
calibrateCompass()
log("Waiting for radar coordinates...")

local returningForService = false

while true do
  local id, msg = rednet.receive(channel_name, 0.5)
  local current_x, current_y, current_z = gps.locate(2)

  if not returningForService and msg and type(msg) == "table" then
    if msg.type == "target" then
      if msg.uuid ~= (target and target.uuid) then
        log("New target acquired: " .. tostring(msg.x) .. ", " .. tostring(msg.y) .. ", " .. tostring(msg.z))
      end
      target = msg
      setState("INTERCEPT")
    elseif msg.type == "clear" then
      log("Radar reports clear.")
      target = nil
      setState("RETURN_TO_BASE")
    end
  end

  if turtle.getFuelLevel() < 500 then
    if not returningForService then
      returningForService = true
      log("Low fuel level.")
      if isOnBase() then
        log("Refueling on base.")
        refuel()
      else
        if state ~= "RETURN_TO_BASE" then
          log("Not on base. Returning for refuel.")
          setState("RETURN_TO_BASE")
        end
      end
    end
  end

  if turtle.getItemCount(15) > 0 then
    if not returningForService then
      returningForService = true
      log("Inventory full. Returning to base.")
      if state ~= "RETURN_TO_BASE" then setState("RETURN_TO_BASE") end
    end
  end

  if state == "INTERCEPT" and target then
    local dist = math.abs(current_x - target.x) + math.abs(current_z - target.z)
    if dist > 1 then
      makeStepTowards(target.x, flight_y, target.z)
    else
      setState("ENGAGE")
    end

  elseif state == "ENGAGE" and target then
    turnTowards(target.x, target.z)
    log("Engaging target: " .. tostring(target.name) .. " at position X:" .. target.x .. " Y:" .. target.y .. " Z:" .. target.z .. ")")
    log("Current position: X:" .. current_x .. " Y:" .. current_y .. " Z:" .. current_z)
    local gpsPos = gps.locate(2)
    if gpsPos then
      log("GPS position: X:" .. gpsPos .. " Y:" .. gpsPos .. " Z:" .. gpsPos)
    else
      log("GPS signal lost during engagement!")
    end
    turnTowards(target.x, target.z)
    turtle.attack()
    turtle.attackUp()
    turtle.attackDown()

  elseif state == "RETURN_TO_BASE" then
    gotoPosition(home_x, home_y, home_z)
    while current_dir ~= 0 do turnRight() end
    
    for slot = 1, 16 do
      turtle.select(slot)
      if not turtle.refuel(0) and turtle.getItemCount(slot) > 0 then
        turtle.dropDown()
      end
    end
    turtle.select(1)
    
    refuel()
    returningForService = false
    
    setState("IDLE")
  end
end
