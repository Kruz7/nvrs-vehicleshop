local StringCharset = {}
local NumberCharset = {}

LastVehiclePurchase = {}
RequestTokens = {}

RegisterServerEvent('hospital:server:SetDeathStatus')
AddEventHandler('hospital:server:SetDeathStatus', function(isDead)
    if isDead then
        TriggerClientEvent('nvrs-dealership:close:client', source)
    end
end)

local function GetIdentifiers(src)
    local identifiers = {
        license = nil,
        discord = nil,
        ip = nil
    }
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        local player = Core.Functions.GetPlayer(src)
        if player and player.PlayerData then
            identifiers.license = player.PlayerData.license
        end
    end
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1,8) == "license:" and not identifiers.license then
            identifiers.license = id:sub(9)
        elseif id:sub(1,8) == "discord:" then
            identifiers.discord = id:sub(9)
        elseif id:sub(1,3) == "ip:" then
            identifiers.ip = id:sub(4)
        end
    end
    return identifiers
end

local function LogExploit(src, reason, extra)
    extra = extra or {}
    local ids = GetIdentifiers(src)
    local name = GetPlayerName(src) or "Unknown"
    local anti = Config.AntiExploit or {}
    if anti.EnableWebhook and anti.WebhookUrl ~= "" then
        local embed = {
            {
                ["title"] = "nvrs-vehicleshop exploit detected",
                ["color"] = 16711680,
                ["fields"] = {
                    {["name"] = "Player", ["value"] = string.format("`%s` (%d)", name, src), ["inline"] = true},
                    {["name"] = "License", ["value"] = "`" .. (ids.license or "N/A") .. "`", ["inline"] = false},
                    {["name"] = "Discord", ["value"] = "`" .. (ids.discord or "N/A") .. "`", ["inline"] = true},
                    {["name"] = "IP", ["value"] = "`" .. (ids.ip or "N/A") .. "`", ["inline"] = true},
                    {["name"] = "Reason", ["value"] = reason or "Unknown", ["inline"] = false},
                    {["name"] = "Extra", ["value"] = json.encode(extra), ["inline"] = false}
                },
                ["footer"] = {
                    ["text"] = "nvrs-vehicleshop"
                },
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
        PerformHttpRequest(anti.WebhookUrl, function() end, "POST", json.encode({
            username = "nvrs-vehicleshop",
            embeds = embed
        }), {["Content-Type"] = "application/json"})
    end
end

local function BanPlayerForExploit(src, reason)
    reason = reason or "nvrs-vehicleshop exploit"
    local anti = Config.AntiExploit or {}
    if anti.EnableBan and (CoreName == "qb-core" or CoreName == "qbx_core") then
        local player = Core.Functions.GetPlayer(src)
        if player then
            local ids = GetIdentifiers(src)
            local name = player.PlayerData.name or GetPlayerName(src) or "Unknown"
            MySQL.insert("INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)", {
                name,
                ids.license or "unknown",
                ids.discord or "unknown",
                ids.ip or "unknown",
                reason,
                2147483647,
                "nvrs-vehicleshop"
            })
        end
    end
    DropPlayer(src, reason)
end

local function GenerateRequestToken(length)
    local anti = Config.AntiExploit or {}
    length = length or anti.TokenLength or 10
    local chars = "0123456789"
    local result = {}
    for i = 1, length do
        local rand = math.random(#chars)
        result[i] = chars:sub(rand, rand)
    end
    return table.concat(result)
end

CreateCallback("nvrs-vehicleshop:getRequestToken:server", function(source, cb)
    local token = GenerateRequestToken()
    RequestTokens[source] = token
    cb(token)
end)

RegisterNetEvent('nvrs-vehicleshop:buyVehicle:server', function(acType, vehicle, price, dealershipId, sender, job, requestToken)
    local src = source
    local anti = Config.AntiExploit or {}
    if anti.RequireRequestToken then
        if not requestToken or requestToken ~= RequestTokens[src] then
            LogExploit(src, "Invalid or missing request token", {vehicle = vehicle, price = price, dealershipId = dealershipId})
            BanPlayerForExploit(src, "Vehicle purchase exploit (token)")
            return
        end
        RequestTokens[src] = nil
    end
    local now = os.time()
    local rateLimit = anti.RateLimitSeconds or 5
    if LastVehiclePurchase[src] and (now - LastVehiclePurchase[src]) < rateLimit then
        LogExploit(src, "Too fast vehicle purchase attempt", {vehicle = vehicle, price = price})
        return
    end
    LastVehiclePurchase[src] = now
    local player = GetPlayer(src)
    if not player then
        LogExploit(src, "Invalid player - GetPlayer failed", {})
        return
    end
    dealershipId = tonumber(dealershipId)
    if not dealershipId or not Config.VehicleShops[dealershipId] then
        LogExploit(src, "Invalid dealershipId in purchase attempt", {dealershipId = dealershipId})
        return
    end
    if not Vehicles2 or not Vehicles2[vehicle] then
        LogExploit(src, "Vehicle not found in config for purchase attempt", {vehicle = vehicle})
        return
    end
    local configPrice = Vehicles2[vehicle].price
    if type(price) ~= "number" then
        price = tonumber(price) or configPrice
    end
    if price ~= configPrice then
        LogExploit(src, "Price mismatch between client and config", {
            clientPrice = price,
            configPrice = configPrice,
            vehicle = vehicle
        })
        price = configPrice
    end
    acType = acType == "cash" and "cash" or "bank"
    sender = tonumber(sender)
    if not sender or sender == src then
        LogExploit(src, "Invalid sender or self sender detected", {sender = sender})
        return
    end
    local target = GetPlayer(sender)
    if not target then
        LogExploit(src, "Sender player not found on purchase attempt", {sender = sender})
        return
    end
    if not HasPermission(sender, Config.Permissions) then
        LogExploit(src, "Sender has no required permissions for sale", {sender = sender})
        return
    end
    if job ~= Config.VehicleShops[dealershipId].Management.Job then
        LogExploit(src, "Job mismatch on purchase attempt", {job = job, requiredJob = Config.VehicleShops[dealershipId].Management.Job})
        return
    end
    local playerMoney = GetPlayerMoney(src, acType)
    if playerMoney < price then
        return Notify(src, "You don't have enough money.", 7500, "error")
    end
    if Config.EnableSocietyAccount then
        Config.AddManagementMoney(job, price)
    end
    if target then
        local targetMoney = price * Config.SalesShare / 31
        AddMoney(sender, "bank", targetMoney, "Vehicle sales share")
        Notify(sender, "You earned $" .. targetMoney .. " - " .. vehicle .. ".", 7500, "success")
    end
    local plate = GeneratePlate()
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            player.PlayerData.license,
            player.PlayerData.citizenid,
            vehicle,
            GetHashKey(vehicle),
            '{}',
            plate,
            'pillboxgarage',
            0
        })
    else
        MySQL.insert('INSERT INTO owned_vehicles (owner, plate, vehicle, logs, garage, mods, fuel, engine, body) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            player.identifier,
            plate,
            json.encode({model = joaat(vehicle), plate = plate}),
            '{}',
            'motelgarage',
            vehMods,
            100,
            1000,
            1000
        })
    end
    RemoveMoney(src, acType, price, "vehicle-bought-in-showroom")
    TriggerClientEvent('nvrs-vehicleshop:buyVehicle:client', src, vehicle, plate, dealershipId)
    if Config.VehicleShops[dealershipId].EnableStocks then
        local dealershipData = MySQL.query.await('SELECT * FROM nvrs_vehicleshop_stocks WHERE dealershipId = ?', {dealershipId})
        local anusVal = {}
        for k, v in pairs(dealershipData) do
            for a, b in pairs(v) do
                anusVal[a] = b
            end
        end
        local stocksData = json.decode(anusVal["data"])
        if stocksData and next(stocksData) and next(stocksData) ~= nil then
            for k, v in pairs(stocksData) do
                if v.model == vehicle then
                    v.stock = v.stock - 1
                end
            end
        end
        MySQL.update('UPDATE nvrs_vehicleshop_stocks SET data = ? WHERE dealershipId = ?', {json.encode(stocksData), dealershipId})
    end
end)

function Round(value, numDecimalPlaces)
    if not numDecimalPlaces then return math.floor(value + 0.5) end
    local power = 10 ^ numDecimalPlaces
    return math.floor((value * power) + 0.5) / (power)
end

CreateCallback('nvrs-vehicleshop:generatePlate:server', function(source, cb)
    local plate = GeneratePlate()
    cb(plate)
end)

function GeneratePlate()
    local plate = RandomInt(1) .. RandomStr(2) .. RandomInt(3) .. RandomStr(2)
    local result = MySQL.scalar.await('SELECT plate FROM ' .. Table .. ' WHERE plate = ?', {plate})
    if result then
        return GeneratePlate()
    else
        return plate:upper()
    end
end

for i = 48, 57 do NumberCharset[#NumberCharset + 1] = string.char(i) end
for i = 65, 90 do StringCharset[#StringCharset + 1] = string.char(i) end
for i = 97, 122 do StringCharset[#StringCharset + 1] = string.char(i) end

function RandomStr(length)
    if length <= 0 then return '' end
    return RandomStr(length - 1) .. StringCharset[math.random(1, #StringCharset)]
end

function RandomInt(length)
    if length <= 0 then return '' end
    return RandomInt(length - 1) .. NumberCharset[math.random(1, #NumberCharset)]
end

if Config.AutoDatabaseCreator then
    Citizen.CreateThread(function()
        while CoreReady == false do Citizen.Wait(0) end
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nvrs_vehicleshop_stocks` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `dealershipId` int(11) DEFAULT NULL,
            `data` longtext DEFAULT NULL,
            PRIMARY KEY (`id`)
            ) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;]], {}, function(rowsChanged)
        end)
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `nvrs_vehicleshop_showroom_vehicles` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `dealershipId` int(11) DEFAULT NULL,
            `data` longtext NOT NULL,
            PRIMARY KEY (`id`)
            ) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;]], {}, function(rowsChanged)
        end)
    end)
end

RegisterNetEvent('nvrs-vehicleshop:updateDealershipStockData:server', function(dealershipId, stocksData)
    local dealershipData = MySQL.query.await('SELECT * FROM nvrs_vehicleshop_stocks WHERE dealershipId = ?', {dealershipId})
    if dealershipData[1] then
        MySQL.update('UPDATE nvrs_vehicleshop_stocks SET data = ? WHERE dealershipId = ?', {json.encode(stocksData), dealershipId})
    else
        MySQL.insert('INSERT INTO nvrs_vehicleshop_stocks (dealershipId, data) VALUES (:dealershipId, :data)', {
            dealershipId = dealershipId,
            data = json.encode(stocksData)
        })
    end
end)

CreateCallback('nvrs-vehicleshop:getVehStock:server', function(source, cb, dealershipId)
    local dealershipData = MySQL.query.await('SELECT * FROM nvrs_vehicleshop_stocks WHERE dealershipId = ?', {dealershipId})
    local anusVal = {}
    for k, v in pairs(dealershipData) do
        for a, b in pairs(v) do
            anusVal[a] = b
        end
    end
    local stocksData = json.decode(anusVal["data"])
    if stocksData and next(stocksData) and next(stocksData) ~= nil then
        local stocks = {}
        for k, v in pairs(stocksData) do
            table.insert(stocks, {
                model = v.model,
                stock = v.stock
            })
        end
        cb(stocks)
    else
        cb(0)
    end
end)

local testVehicles = {}

RegisterNetEvent('nvrs-vehicleshop:startTest:server')
AddEventHandler('nvrs-vehicleshop:startTest:server', function(netId)
    testVehicles[netId] = {
        playerId = source
    }
end)

RegisterNetEvent('nvrs-vehicleshop:finishTest:server')
AddEventHandler('nvrs-vehicleshop:finishTest:server', function(netId)
    if testVehicles[netId] then
        testVehicles[netId] = nil
    end
end)

AddEventHandler('entityRemoved', function(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if testVehicles[netId] then
        TriggerClientEvent('nvrs-vehicleshop:finishTest:client', testVehicles[netId].playerId)
        testVehicles[netId] = nil
    end
end)

RegisterNetEvent('nvrs-vehicleshop:updateShowroomVehicles:server', function(dealershipId, data)
    local showroomData = MySQL.query.await('SELECT * FROM nvrs_vehicleshop_showroom_vehicles WHERE dealershipId = ?', {dealershipId})
    if showroomData[1] then
        MySQL.update('UPDATE nvrs_vehicleshop_showroom_vehicles SET data = ? WHERE dealershipId = ?', {json.encode(data), dealershipId})
    else
        MySQL.insert('INSERT INTO nvrs_vehicleshop_showroom_vehicles (dealershipId, data) VALUES (?, ?)', {dealershipId, json.encode(data)})
    end
end)

CreateCallback('nvrs-vehicleshop:getShowroomData:server', function(source, cb, dealershipId)
    local showroomTable = {}
    local showroomDatas = MySQL.query.await('SELECT * FROM nvrs_vehicleshop_showroom_vehicles WHERE dealershipId = ?', {dealershipId})
    if showroomDatas[1] then
        if next(showroomDatas) and next(showroomDatas) ~= nil then
            for k, v in pairs(showroomDatas) do
                for a, b in pairs(json.decode(v.data)) do
                    table.insert(showroomTable, {
                        dealershipId = dealershipId,
                        coords = vector4(b.coords.x, b.coords.y, b.coords.z, b.coords.w),
                        vehicleModel = b.vehicleModel,
                        spotId = b.spotId
                    })
                end
            end
        end
    end
    cb(showroomTable)
end)

RegisterNetEvent('nvrs-vehicleshop:sendRequestText:server', function(sender, target, price, model, dealershipId)
    TriggerClientEvent('nvrs-vehicleshop:sendRequestText:client', target, sender, price, model, dealershipId)
end)

RegisterNetEvent('nvrs-vehicleshop:declinePayment:server', function(sender)
    Notify(sender, "Request declined.", 7500, "error")
end)

AddEventHandler('playerDropped', function()
    for k, v in pairs(testVehicles) do
        if v.playerId == source then
            TriggerClientEvent('nvrs-vehicleshop:deleteVehicle:client', -1, k)
        end
    end
    LastVehiclePurchase[source] = nil
    RequestTokens[source] = nil
end)

RegisterNetEvent('nvrs-vehicleshop:deleteVehicleShowroom:server', function(dealershipId, spotId, newModel)
    for _, playerId in ipairs(GetPlayers()) do
        local numPlayerId = tonumber(playerId)
        if numPlayerId ~= source then
            local myPed = GetPlayerPed(numPlayerId)
            local myPedCoords = GetEntityCoords(myPed)
            local dealershipCoords = vector3(Config.VehicleShops[dealershipId].ShowroomVehicles[1].coords.x, Config.VehicleShops[dealershipId].ShowroomVehicles[1].coords.y, Config.VehicleShops[dealershipId].ShowroomVehicles[1].coords.z)
            local dist = #(myPedCoords - dealershipCoords)
            if dist <= 40 then
                TriggerClientEvent('nvrs-vehicleshop:deleteVehicleShowroom:client', numPlayerId, dealershipId, spotId, newModel, true)
            else
                TriggerClientEvent('nvrs-vehicleshop:deleteVehicleShowroom:client', numPlayerId, dealershipId, spotId, newModel, false)
            end
        end
    end
end)

CreateCallback('nvrs-vehicleshop:checkIsPlayerHasPerm:server', function(source, cb)
    cb(HasPermission(source, Config.Permissions))
end)

