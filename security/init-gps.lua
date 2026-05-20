local x = 10
local y = 5
local z = 10

parallel.waitForAny(
  function()
    shell.run("gps host" .. " " .. x .. " " .. y .. " " .. z)
  end,
  function()
    print("GPS tower initialized at X:" .. x .. " Y:" .. y .. " Z:" .. z)
  end
)
