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
        os.exit()
    end

    while true do
        local hasBlock, data = turtle.inspect()
        if not hasBlock then
            turtle.place()
            break
        elseif data.name == targetBlockName then
            break
        else
            local dug = turtle.dig()

            if not dug then
                if turtle.place() then
                    break
                else
                    print("Error: Cannot remove or overwrite block: " .. data.name)
                    os.exit()
                end
            end

            os.sleep(0.3)
        end
    end
end

local function tryMove(moveFunc, digFunc, attackFunc)
    while not moveFunc() do
        if digFunc then digFunc() end
        if attackFunc then attackFunc() end
        os.sleep(0.5)
    end
end

local function moveUp()
    tryMove(turtle.up, turtle.digUp, turtle.attackUp)
    current_y = current_y + 1
end

local function moveDown()
    tryMove(turtle.down, turtle.digDown, turtle.attackDown)
    current_y = current_y - 1
end

local function moveForward()
    tryMove(turtle.forward, turtle.dig, turtle.attack)
end

local function shiftRight()
    turtle.turnRight()
    moveForward()
    current_x = current_x + 1
    turtle.turnLeft()
end

local function shiftLeft()
    turtle.turnLeft()
    moveForward()
    current_x = current_x - 1
    turtle.turnRight()
end

for i = 1, height - 1 do
    moveUp()
end

for row = 1, height do
    for col = 1, width do
        checkAndReplace()
        
        if col < width then
            if row % 2 == 1 then
                shiftRight()
            else
                shiftLeft()
            end
        end
    end
    
    if row < height then
        moveDown()
    end
end

print("Replacement complete. Returning to base...")

while current_y > 0 do
    moveDown()
end

if current_x > 0 then
    turtle.turnLeft()
    for i = 1, current_x do
        moveForward()
    end
    turtle.turnRight()
end

print("Robot successfully returned to base!")
