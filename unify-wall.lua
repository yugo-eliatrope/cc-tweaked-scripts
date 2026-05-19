local args = { ... }
if #args < 2 then
    print("Usage: replace_wall <width> <height>")
    return
end

local width = tonumber(args[1])
local height = tonumber(args[2])

if not width or not height or width <= 0 or height <= 0 then
    print("Error: Width and height must be positive numbers.")
    return
end

print("Burn Baby Burn!")

local startItem = turtle.getItemDetail()
if not startItem then
    print("Error: Select a slot with the replacement block first.")
    return
end
local targetBlockName = startItem.name

if turtle.getFuelLevel() < (width * height * 2 + width + height) then
    print("Warning: The robot might run out of fuel!")
    print("Current level: " .. turtle.getFuelLevel())
end

local current_x = 0
local current_y = 0

local function ensureBlock()
    local item = turtle.getItemDetail()
    if item and item.name == targetBlockName and item.count > 0 then
        return true
    end
    for slot = 1, 16 do
        local detail = turtle.getItemDetail(slot)
        if detail and detail.name == targetBlockName and detail.count > 0 then
            turtle.select(slot)
            return true
        end
    end
    return false
end

local function checkAndReplace()
    if not ensureBlock() then
        print("Error: Out of target blocks (" .. targetBlockName .. ")!")
        return false
    end

    while true do
        local hasBlock, data = turtle.inspect()
        if not hasBlock then
            turtle.place()
            break
        elseif data.name == targetBlockName then
            break
        else
            turtle.dig()
            os.sleep(0.3)
        end
    end
    return true
end

local function moveUp()
    if turtle.up() then
        current_y = current_y + 1
        return true
    end
    return false
end

local function moveDown()
    if turtle.down() then
        current_y = current_y - 1
        return true
    end
    return false
end

local function shiftRight()
    turtle.turnRight()
    if turtle.forward() then
        current_x = current_x + 1
    else
        print("Error: Obstacle encountered while shifting right!")
    end
    turtle.turnLeft()
end

local function shiftLeft()
    turtle.turnLeft()
    if turtle.forward() then
        current_x = current_x - 1
    else
        print("Error: Obstacle encountered while shifting left!")
    end
    turtle.turnRight()
end

for i = 1, height - 1 do
    if not moveUp() then
        print("Error: Failed to reach the top row. Blocked at Y:"..current_y)
        return
    end
end

for row = 1, height do
    for col = 1, width do
        if not checkAndReplace() then return end
        
        if col < width then
            if row % 2 == 1 then
                shiftRight()
            else
                shiftLeft()
            end
        end
    end
    
    if row < height then
        if not moveDown() then
            print("Error: Movement down blocked at X:"..current_x.." Y:"..current_y)
            return
        end
    end
end

print("Replacement complete. Returning to base...")

while current_y > 0 do
    if not moveDown() then
        print("Critical error during return: path down blocked!")
        break
    end
end

if current_x > 0 then
    turtle.turnLeft()
    for i = 1, current_x do
        while not turtle.forward() do 
            print("Obstacle on the way to base! Waiting...")
            os.sleep(1) 
        end
    end
    turtle.turnRight()
end

print("Robot successfully returned to base!")
