local x, y, z = 23, 65, -33

local modem = peripheral.find("modem")
if not modem then
  print("No modem found!")
  return
end

modem.open(gps.CHANNEL_GPS)

print("Starting GPS tower at coordinates: " .. x .. ", " .. y .. ", " .. z)
gps.host(x, y, z)
