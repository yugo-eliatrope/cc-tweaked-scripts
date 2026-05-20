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

local enemies = {"zombi", "skeleton", "spider", "creeper", "enderman"}

local function isEnemy(name)
  name = string.lower(tostring(name))
  for _, enemy in pairs(enemies) do
    if string.find(name, enemy) then return true end
  end
  return false
end

log("Radar online. Calibrated at X:"..base_x.." Y:"..base_y.." Z:"..base_z)

local function finClosestEnemy(entities)
  local closest = nil
  local closestDist = math.huge
  for _, e in pairs(entities) do
    if isEnemy(e.name) then
      local dist = math.sqrt(e.x^2 + e.y^2 + e.z^2)
      if dist < closestDist then
        closestDist = dist
        closest = e
      end
    end
  end
  return closest
end

local function updateTarget(t, entities)
  local found = nil
  for _, e in pairs(entities) do
    if e.uuid == t.uuid then
      found = e
      break
    end
  end
  return found
end

local function calcDistance(e)
  return math.sqrt(e.x^2 + e.y^2 + e.z^2)
end

local target = nil
  
while true do
  local entities = sensor.scanEntities(radius)

  if entities then
    if target then
      target = updateTarget(target, entities)
    else
      local closest = finClosestEnemy(entities)
      if not closest then
        log("No enemies detected within radius.")
        target = nil
      else
        target = closest
      end
    end
    if target then
      local abs_x = base_x + math.floor(target.x + 0.5)
      local abs_y = base_y + math.floor(target.y)
      local abs_z = base_z + math.floor(target.z + 0.5)
      rednet.broadcast({type = "target", x = abs_x, y = abs_y, z = abs_z, uuid = target.uuid}, "guard_channel")
      log("Target entity: " .. tostring(target.name) .. " at distance " .. string.format("%.2f", calcDistance(target)))
    end
  end

  if not target then
    rednet.broadcast({type = "clear"}, "guard_channel")
  end

  os.sleep(1)
end