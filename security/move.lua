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
    turnRight()
  end
end

local function gotoPosition(x, y, z)
  local pos = location()
  if pos.x == x and pos.y == y and pos.z == z then return end
  
  if pos.y < flight_y then moveUp(flight_y - pos.y) end
  while pos.x ~= x do
    local dx = (x > pos.x) and 1 or -1
    turnTowards(pos, pos.x + dx, pos.z)
    turtle.forward(math.abs(x - pos.x))
    pos = location()
    if pos.x ~= x then
      log("Probably hit an obstacle")
      turtle.dig()
    end
  end
  while pos.z ~= z do
    local dz = (z > pos.z) and 1 or -1
    turnTowards(pos, pos.x, pos.z + dz)
    turtle.forward(math.abs(z - pos.z))
    pos = location()
    if pos.z ~= z then
      log("Probably hit an obstacle")
      turtle.dig()
    end
  end

  while pos.y > y do moveDown() end
  while pos.y < y do moveUp() end
  pos = location()
  log("Goal was:   (" .. x .. ", " .. y .. ", " .. z .. ")")
  log("Arrived to: (" .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ")")
end

local args = { ... }

local go_x = tonumber(args[1])
local go_y = tonumber(args[2])
local go_z = tonumber(args[3])

gotoPosition(go_x, go_y, go_z)
