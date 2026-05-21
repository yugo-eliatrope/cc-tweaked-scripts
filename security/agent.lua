local file = fs.open("guard.log", "a")
local function log(msg)
  local time = os.date("%H:%M:%S")
  print("["..time.."] " .. msg)
  file.writeLine("["..time.."] " .. msg)
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

local flight_y = home_y + 1
local current_dir = 0
local state = "IDLE"
local channel_name = "guard_channel"

local target = nil

local function location()
  local x, y, z = gps.locate(2)
  if not x then
    log("Error: GPS signal lost!")
    return nil
  end
  return {x = x, y = y, z = z}
end

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

    if moveType == "up" then
      turtle.attackUp()
    elseif moveType == "down" then
      turtle.attackDown()
    else
      turtle.attack()
    end

    os.sleep(0.1) 

    if attempts >= 2 then
      return false
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
    if target_dir == (current_dir + 1) % 4 then
      turnRight()
    else
      turnLeft()
    end
  end
end

local function gotoPosition(x, y, z)
  local pos = location()
  if not pos then return end

  if pos.x ~= x or pos.y ~= y or pos.z ~= z then
    while pos.y < flight_y do
      if not moveUp() then break end
      pos = location()
    end

    log("Y current: " .. pos.y .. ", target: " .. flight_y)

    local function moveForwardWithBypass()
      while not turtle.forward() do
        log("Path blocked! Climbing to bypass...")
        if not turtle.up() then
          log("Critical Error: Stuck! Cannot move up or forward.")
          return false
        end
        --After climbing, the loop will check turtle.forward() again
      end
      return true
    end

    turnTowards(pos, x, z)
    log("cycle 1")
    while pos.x ~= x and pos.z ~= z do
      moveForwardWithBypass()
      pos = location()
    end

    turnTowards(pos, x, z)
    log("cycle 2")
    while pos.x ~= x or pos.z ~= z do
      moveForwardWithBypass()
      pos = location()
    end

    while pos.y > y do
      if not moveDown() then break end
      pos = location()
    end
    pos = location()
  end

  log("Goal was:   (" .. x .. ", " .. y .. ", " .. z .. ")")
  log("Arrived to: (" .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ")")
end

local function makeStepTowards(x, y, z)
  local curr = location()
  if curr.x == x and curr.y == y and curr.z == z then return end

  turnTowards(curr, x, z)
  moveForward()
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
  local current = location()

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
    local dist = math.abs(current.x - target.x) + math.abs(current.z - target.z)
    if dist > 1 then
      if current.y < flight_y then
        log("Ascending to flight level...")
        moveUp(flight_y - current.y)
      end
      makeStepTowards(target.x, flight_y, target.z)
    else
      setState("ENGAGE")
    end

  elseif state == "ENGAGE" and target then
    turnTowards(current, target.x, target.z)
    log("Engaging target: " .. tostring(target.name) .. " at position X:" .. target.x .. " Y:" .. target.y .. " Z:" .. target.z .. ")")
    log("Current position: X:" .. current.x .. " Y:" .. current.y .. " Z:" .. current.z)
    local gpsPos = location()
    if gpsPos then
      log("GPS position: X:" .. gpsPos.x .. " Y:" .. gpsPos.y .. " Z:" .. gpsPos.z)
    else
      log("GPS signal lost during engagement!")
    end
    turnTowards(current, target.x, target.z)
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
