local sensor = peripheral.find("environmentDetector") or peripheral.find("environment_detector")

if not sensor then 
    print("Ошибка: Радар не найден!") 
    return 
end

local entities = sensor.scanEntities() -- Пробуем вызвать без указания радиуса

if not entities or type(entities) ~= "table" then
    print("Радар ничего не вернул (nil)")
    return
end

local count = 0
for _ in pairs(entities) do count = count + 1 end
print("Всего сущностей вокруг: " .. count)

-- Выводим структуру первой попавшейся сущности
for _, e in pairs(entities) do
    print("--- ДАННЫЕ МОБА ---")
    for k, v in pairs(e) do
        print(k .. ": " .. tostring(v))
    end
    break
end