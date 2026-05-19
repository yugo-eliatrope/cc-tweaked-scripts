local modem = peripheral.find("modem")
if not modem then
    print("Error: Modem not found!")
    return
end
rednet.open(peripheral.getName(modem))

local drones = {}

local function drawUI()
    term.clear()
    term.setCursorPos(1, 1)
    print("=================== SECURITY MONITOR ===================")
    print(string.format("%-8s | %-15s | %-25s", "DRONE ID", "STATUS", "COORDINATES (X, Y, Z)"))
    print("--------------------------------------------------------")
    
    for id, data in pairs(drones) do
        local coords = string.format("%d, %d, %d", data.x, data.y, data.z)
        print(string.format("Drone #%-3d | %-15s | %-25s", id, data.state, coords))
    end
    print("--------------------------------------------------------")
end

term.clear()
term.setCursorPos(1, 1)
print("Receiver online. Waiting for drone telemetry...")

while true do
    local senderId, message, protocol = rednet.receive("security_channel")
    if protocol == "security_channel" and type(message) == "table" and message.type == "drone_telemetry" then
        drones[senderId] = {
            state = message.state,
            x = message.x,
            y = message.y,
            z = message.z
        }
        drawUI()
    end
end
