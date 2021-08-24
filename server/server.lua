
RegisterServerEvent("K9:SERVER:SPAWN_K9")
AddEventHandler("K9:SERVER:SPAWN_K9", function()

    local PLAYER = QBCore.Functions.GetPlayer(source).PlayerData

    if PLAYER.job ~= nil and PLAYER.job.name == "police" and PLAYER.job.grade.level >= 2 then

      TriggerClientEvent("K9:CLIENT:SPAWN_K9", source)
    end

end)


RegisterServerEvent("K9:SERVER:SEARCH_PERSON")
AddEventHandler("K9:SERVER:SEARCH_PERSON", function(target)
  
   local PLAYER_CHECK =  HasIllegalItems(target)

   if PLAYER_CHECK then
   	TriggerClientEvent("K9:CLIENT:SEARCH_RESULTS", source, true, 'person')
   end

end)

RegisterServerEvent("K9:SERVER:SEARCH_VEHICLE")
AddEventHandler("K9:SERVER:SEARCH_VEHICLE", function(vehicle, players)

	SearchVehicle(source, vehicle, players)

end)

function SearchVehicle(source, vehicle, players)
  local VEHICLE_RESULTS = nil
  local PLAYER_RESULTS = false

    TriggerEvent("inventory:server:SearchLocalVehicleInventory", vehicle, K9_CONFIG.Items, function (results)
   		VEHICLE_RESULTS = results
	end)

	while VEHICLE_RESULTS == nil do
    	Citizen.Wait(0)
    end

    if not VEHICLE_RESULTS then
		for i = 1, #players do

		local ITEM = HasIllegalItems(players[i])

			if ITEM then
				PLAYER_RESULTS = true
				break
			end
		end
	end

	if VEHICLE_RESULTS or PLAYER_RESULTS then
		TriggerClientEvent("K9:CLIENT:SEARCH_RESULTS", source, true, 'vehicle')
	end
end

function HasIllegalItems(target)
	local Player = QBCore.Functions.GetPlayer(target)

	for i = 1, #K9_CONFIG.Items do

 		local item = Player.Functions.GetItemByName(K9_CONFIG.Items[i])

 		if item ~= nil then
 			return true
 		end
	end

	return false
end

--[[ Not used yet... 
function GetPlayerId(type, id)
    local identifiers = GetPlayerIdentifiers(id)
    for i = 1, #identifiers do
        if string.find(identifiers[i], type, 1) ~= nil then
            return identifiers[i]
        end
    end
    return false
end
]]--