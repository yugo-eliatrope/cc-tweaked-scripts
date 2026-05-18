local args = { ... }
if #args < 2 then
    print("Usage: wall <width> <height>")
    return
end

local width = tonumber(args[1])
local height = tonumber(args[2])

if not width or not height or width <= 0 or height <= 0 then
    print("Error: Width and height must be positive numbers.")
    return
end

if turtle.getFuelLevel() < (width * height + width + height) then
    print("Warning: The robot might run out of fuel!")
    print("Current level: " .. turtle.getFuelLevel())
end

local current_x = 0
local current_y = 0

local function ensureBlock()
    if turtle.getItemCount() == 0 then
        for slot = 1, 16 do
            if turtle.getItemCount(slot) > 0 then
                turtle.select(slot)
                return true
            end
        end
        return false
    else
        return true
    end
end

local function checkAndPlace()
    if not ensureBlock() then
        print("Error: Out of blocks in inventory!")
        return false
    end
    
    if not turtle.detect() then
        turtle.place()
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

for col = 1, width do
    if col % 2 == 1 then
        for row = 1, height do
            if not checkAndPlace() then return end
            if row < height then
                if not moveUp() then
                    print("Error: Movement up blocked at X:"..current_x.." Y:"..current_y)
                    return
                end
            end
        end
    else
        for row = 1, height do
            if not checkAndPlace() then return end
            if row < height then
                if not moveDown() then
                    print("Error: Movement down blocked at X:"..current_x.." Y:"..current_y)
                    return
                end
            end
        end
    end

    if col < width then
        shiftRight()
    end
end

print("Construction complete. Returning to base...")

while current_y > 0 do
    if not moveDown() then
        print("Critical error during return: path down blocked!")
        break
    end
end

if current_x > 0 then
    turtle.turnLeft()
    for i = 1, current_x do
        if not turtle.forward() then
            print("Obstacle on the way to base! Waiting...")
            while not turtle.forward() do os.sleep(1) end
        end
    end
    turtle.turnRight()
end

print("Robot successfully returned to base!")
