local file = fs.open("guard_log.txt", "a")
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

local flight_y = home_y + 2
local current_dir = 0
local state = "IDLE"
local channel_name = "guard_channel"

local function location()
  local x, y, z = gps.locate(2)
  if not x then
    log("Error: GPS signal lost!")
    return nil
  end
  return {x = x, y = y, z = z}
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
  if pos.x ~= x or pos.y ~= y or pos.z ~= z then
    if pos.y < flight_y then moveUp(flight_y - pos.y) end
    log("Y current: " .. pos.y .. ", target: " .. flight_y)
    turnTowards(pos, x, z)
    log("cycle 1")
    while pos.x ~= x and pos.z ~= z do
      log("POS:" .. pos.x .. "," .. pos.z .. " TAR:" .. x .. "," .. z)
      turtle.forward()
      pos = location()
    end
    turnTowards(pos, x, z)
    log("cycle 2")
    while pos.x ~= x or pos.z ~= z do
      log("POS:" .. pos.x .. "," .. pos.z .. " TAR:" .. x .. "," .. z)
      turtle.forward()
      pos = location()
    end
    while pos.y > y do moveDown() end
    while pos.y < y do moveUp() end
    pos = location()
  end
  log("Goal was:   (" .. x .. ", " .. y .. ", " .. z .. ")")
  log("Arrived to: (" .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ")")
end

local args = { ... }

local go_x = tonumber(args[1])
local go_y = tonumber(args[2])
local go_z = tonumber(args[3])

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

calibrateCompass()
gotoPosition(go_x, go_y, go_z)
