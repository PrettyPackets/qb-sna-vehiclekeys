local QBCore = exports['qb-core']:GetCoreObject()
local VehicleList = {}
local PrettyLib = exports['PrettyLib']:Init()

local function ChangeLocks(plate)
	local result = MySQL.single.await('SELECT `lock` FROM player_vehicles WHERE plate = ?', { plate })
	if result then
		local lock = result.lock
		if lock then
			lock = lock + 1
		else
			lock = 4321
		end
		MySQL.update('UPDATE player_vehicles SET `lock` = ? WHERE plate = ?', {lock, plate})
	end
end

function tprint (tbl, indent)
	if not indent then indent = 0 end
	for k, v in pairs(tbl) do
	  formatting = string.rep("  ", indent) .. k .. ": "
	  if type(v) == "table" then
		print(formatting)
		tprint(v, indent+1)
	  elseif type(v) == 'boolean' then
		print(formatting .. tostring(v))      
	  else
		print(formatting .. v)
	  end
	end
  end

local function GiveKey(plate, model, player, src)
	local result = MySQL.single.await('SELECT `lock` FROM player_vehicles WHERE plate = ?', { plate })
	if result then
		local lock = result.lock
		local info = {}
		if lock then
			info.lock = lock
			info.plate = plate
			info.model = model
			PrettyLib.Inventory.AddItemMeta(src, 'vehiclekey', 1, info, "VehicleKeys")
			TriggerClientEvent('QBCore:Notify', src, Lang:t("message.key_received"), 'success')
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t("message.not_initialized"), 'error')
		end
	end
end

RegisterNetEvent('qb-vehiclekeys:server:BuyVehicle', function(plate, model)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	ChangeLocks(plate)
	Wait(100)
	GiveKey(plate, model, Player, src)
end)

RegisterNetEvent('qb-vehiclekeys:server:GiveTempKey', function(plate)
	local src = source
    local citizenid = QBCore.Functions.GetPlayer(src).PlayerData.citizenid

    if not VehicleList[plate] then VehicleList[plate] = {} end
    VehicleList[plate][citizenid] = true
	TriggerClientEvent('QBCore:Notify', src, Lang:t("message.temp_key_received"))

end)

RegisterNetEvent('qb-vehiclekeys:server:ChangeLocks', function(data)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local plate = data.plate
	local cashBalance = Player.PlayerData.money["cash"]

    if Player then
		if cashBalance >= Config.ResetPrice then
			Player.Functions.RemoveMoney("cash", Config.ResetPrice, "Reset-Locks")
			ChangeLocks(plate)
			TriggerClientEvent('QBCore:Notify', src, Lang:t("message.locks_reset"), 'success')
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t("message.not_enough_money"), 'error')
		end
	end

end)

RegisterNetEvent('qb-vehiclekeys:server:GiveKey', function(data)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local plate = data.plate
	local model = data.model
	local cashBalance = Player.PlayerData.money["cash"]

    if Player then
		if cashBalance >= Config.KeyPrice then
			Player.Functions.RemoveMoney("cash", Config.KeyPrice, "Get-Key")
			GiveKey(plate, model, Player, src)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t("message.not_enough_money"), 'error')
		end
	end
end)

RegisterNetEvent('qb-vehiclekeys:server:breakLockpick', function(itemName)
	local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not (itemName == "lockpick" or itemName == "advancedlockpick") then return end
	PrettyLib.Inventory.RemoveItem(src, itemName, 1, "Lockpick Break")
end)

RegisterNetEvent('qb-vehiclekeys:server:RemoveKey', function(plate)
	local src = source
	local items = PrettyLib.Inventory.ItemSlotSearch(src, 'vehiclekey')
	if items then
		for k,v in pairs(items) do
			if v.metadata.plate == plate then
				PrettyLib.Inventory.RemoveItemSlot(src, 'vehiclekey', 1, v.slot, 'Remove Vehicle Key')
			end
		end
	end
end)

QBCore.Functions.CreateCallback('qb-vehiclekeys:server:HasKey', function(source, cb, plate)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
    local citizenid = QBCore.Functions.GetPlayer(src).PlayerData.citizenid
	local ok = false
    if Player then
		if VehicleList[plate] and VehicleList[plate][citizenid] then
			cb(true)				
		else
			local items = PrettyLib.Inventory.ItemSlotSearch(src, 'vehiclekey')
			if items then
				for k,v in pairs(items) do
					if v.metadata.plate == plate then
						local result = MySQL.single.await('SELECT `lock` FROM player_vehicles WHERE plate = ?', { plate })
						if result then
							local lock = result.lock
							if v.metadata.lock == lock then
								ok = true
							end
						else
							ok = true
						end
					end
				end
			end
			cb(ok)		
		end
	end
end)

QBCore.Functions.CreateCallback('qb-vehiclekeys:server:GetPlayerVehicles', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local Vehicles = {}

    MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result[1] then
            for _, v in pairs(result) do
                local VehicleData = QBCore.Shared.Vehicles[v.vehicle]

                local fullname
                if VehicleData["brand"] ~= nil then
                    fullname = VehicleData["brand"] .. " " .. VehicleData["name"]
                else
                    fullname = VehicleData["name"]
                end
                Vehicles[#Vehicles+1] = {
                    fullname = fullname,
                    brand = VehicleData["brand"],
                    model = VehicleData["name"],
                    plate = v.plate,
                    state = v.state,
                    fuel = v.fuel,
                    engine = v.engine,
                    body = v.body
                }
            end
            cb(Vehicles)
        else
            cb(nil)
        end
    end)
end)
