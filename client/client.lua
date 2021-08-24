
--       GLOBALS      --
local DEBUG = false
-- DO NOT TOUCH THESE --
--BLOCKERS
local ACTIVATE_K9 = false
local DISTANCE_CD = 0
local ACTION_CD = 0
local CLEANUP_CD = 0
local NOTIFY_CD = 0
local MENU_CD = 0
local IN_MENU = false

-- VISUAL OPTIONS
local K9_NAME = "Zero"
local K9_COLOR = 0
local K9_VEST = 0
-- FUNCTIONAL GLOBALS
local K9_ID = false
local K9_IN_VEHICLE = false
local SEARCHING = false
local PLAYING_ANIMATION = false
local DRUGS_FOUND = false
local FOLLOWING = true
-- ^ DO NOT TOUCH THESE ^ --


--[[

ANIMATION SET

]]--
local sit = {
    dict = "creatures@rottweiler@amb@world_dog_sitting@idle_a",
    anim = "idle_b"
}
local laydown = {
    dict = "creatures@rottweiler@amb@sleep_in_kennel@",
    anim = "sleep_in_kennel"
}
local searchhit = {
    dict = "creatures@rottweiler@indication@",
    anim = "indicate_high"
}

--[[

ON PLAYER SELECTED ACTIVE K9 BASED ON RANK

]]--
RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local PLAYER_JOB = QBCore.Functions.GetPlayerData().job

    if DEBUG then print('PLAYER JOB DATA NAME: ' .. PLAYER_JOB.name .. 'GRADE: ' .. PLAYER_JOB.grade.level) end

    if (PLAYER_JOB ~= nil) and PLAYER_JOB.name == "police" and PLAYER_JOB.grade.level >= 2 then
      EnableK9()
    end

end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JOB_DATA)

  local PLAYER_JOB = JOB_DATA

  if DEBUG then print('PLAYER JOB DATA NAME: ' .. PLAYER_JOB.name .. 'GRADE: ' .. PLAYER_JOB.grade.level) end

  if PLAYER_JOB ~= nil and PLAYER_JOB.name == "police" and PLAYER_JOB.grade.level >= 2 then
    EnableK9()
  else
    ACTIVATE_K9 = false
  end
end)

RegisterNetEvent("QBCore:Client:OnPlayerUnload")
AddEventHandler("QBCore:Client:OnPlayerUnload", function()
    --DEACTIVE K9
    DespawnK9()
end)

--[[

MAIN THREAD
DISTANCE CHECK
KEY PRESSES
CLEAN UP CHECKS

]]--


function EnableK9()
    --SET RELATION GROUP TO PREVENT DOG ATTACKS ON YOURSELF
    SetPedRelationshipGroupHash(PlayerPedId(), GetHashKey("PLAYER_POLICE"))
    -- SET TRUE
    ACTIVATE_K9 = true
    --SET RESOURCE NAME
    SendNUIMessage({
        type = "RESOURCE_NAME",
        name = GetCurrentResourceName()
    })
    -- WE DO NOT WANT TO RUN THIS LOOP IF A PLAYER CHANGES OR LOSES ACCESS.
    while ACTIVATE_K9 do
        Citizen.Wait(5)

        -- SEND K9 AFTER TARGET ONLY IF K9 EXISTS
        if K9_ID and IsControlJustPressed(1, K9_CONFIG.Key) and IsPlayerFreeAiming(PlayerId()) and IsDurationComplete(ACTION_CD, 1000) then

            local bool, target = GetEntityPlayerIsFreeAimingAt(PlayerId())
            if bool then
                if IsEntityAPed(target) then
                    FOLLOWING = false
                    ACTION_CD = GetGameTimer()
                    local DOG = NetworkGetEntityFromNetworkId(K9_ID)

                    if IsPedInAnyVehicle(DOG) then
                      K9ToggleVehicle(target)
                    else 
                      K9AttackorFollow(target)
                    end

                end
            end

        end

        -- START LOOP TO CHECK IF WE SHOULD OPEN THE MENU ONLY IF K9 EXISTS
        if K9_ID and IsControlJustPressed(1, K9_CONFIG.Key) and not IsPlayerFreeAiming(PlayerId()) then
           CheckForMenu()
        end

        -- FORCE K9 TO FOLOW
        if K9_ID and IsControlJustReleased(1, K9_CONFIG.Key) and not IsPlayerFreeAiming(PlayerId()) and IsDurationComplete(ACTION_CD, 1000)  then

            if not FOLLOWING then
              K9AttackorFollow(false)
              FOLLOWING = true
           end

        end

        -- TRIGGER THE DISTANCE CHECK FOR THE K9 SPAWNER/DESPAWNER. IT IS TRIGGERED EVERY 5 SECONDS.
        if IsDurationComplete(DISTANCE_CD, 5000) then
          CheckK9Distance()
        end

        -- TRIGGER THE DEATH CHECK EVERY 15 SECONDS AND OTHER CONDITIONS.
        if IsDurationComplete(CLEANUP_CD, 15000) then
          CheckK9Conditions()
        end

    end

end

--[[ SIMPLE LOOP AND TIME CHECK A DURATION TO OPEN THE MENU WHILE HOLDING THE K9 KEY ]]--
function CheckForMenu()
  MENU_CD = GetGameTimer()
  while IsControlPressed(0, K9_CONFIG.Key) do
    Citizen.Wait(0)

    if IsDurationComplete(MENU_CD, 1500) then
      ACTION_CD = GetGameTimer() + 99 * 1000000
      OpenMenu("OPEN_K9_MENU")
      break
    end

  end
end

--[[ CHECK DISTANCE AND IF WITHIN RANGE DRAW MARKER AND MENU FOR K9 SPAWNER DESPAWNER ]]--
function CheckK9Distance()
  DISTANCE_CD = GetGameTimer()

  local PLAYER = PlayerPedId()
  local PLAYER_COORDS = GetEntityCoords(PLAYER)
  local DISTANCE = #(PLAYER_COORDS - vector3(K9_CONFIG.Location.x, K9_CONFIG.Location.y, K9_CONFIG.Location.z))

  if DISTANCE <= 3 and not IN_MENU then

    while true do

      Citizen.Wait(0)

      if IsDurationComplete(MENU_CD, 1000) then
        PLAYER_COORDS = GetEntityCoords(PLAYER)
        DISTANCE = #(PLAYER_COORDS - vector3(K9_CONFIG.Location.x, K9_CONFIG.Location.y, K9_CONFIG.Location.z))
        if DISTANCE > 4 then
          break
        end
        MENU_CD = GetGameTimer()
      end

      if IsDurationComplete(NOTIFY_CD, 10000) then
        NOTIFY_CD = GetGameTimer()
        QBCore.Functions.Notify("PRESS (F) TO ACCESS KENNEL", "primary", 4000)
      end

      DrawMarker(31, K9_CONFIG.Location.x, K9_CONFIG.Location.y, K9_CONFIG.Location.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 205, 255, 255, false, true, 2, false, false, false, false)

      if IsControlJustPressed(0, 23) then
        IN_MENU = true
        OpenMenu("OPEN_K9_SPAWNER_DESPAWNER")

        break

      end

    end

  end

end

--[[ SIMPLE CHECK THAT WILL REMOVE THE K9)]]--
function CheckK9Conditions()
  CLEANUP_CD = GetGameTimer()
  
  if K9_ID then
    

    local DOG = NetworkGetEntityFromNetworkId(K9_ID)
    local DOG_COORDS = GetEntityCoords(DOG)
    local PLAYER_COORDS = GetEntityCoords(PlayerPedId())
    local DISTANCE = #(DOG_COORDS - PLAYER_COORDS)
    
    if DISTANCE > 100 and not IsPedInAnyVehicle(DOG, false) then
      K9AttackorFollow(false)
    end


    if IsEntityDead(DOG) or IsEntityDead(PlayerPedId()) then
      DespawnK9()
    end

  end
end

-- OPEN MENU --
function OpenMenu(menu)
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = menu
    })

end



--[[ NUI Callbacks ]]--
local switch = {                                          -- break statement
  ["K9_SPAWN"] = function ()
    SpawnK9()
  end,
  ["K9_DESPAWN"] = function () DespawnK9() end,

  ["K9_SAVE"] = function () SaveK9() end,

  ["K9_SIT"] = function () PlayAnimation(sit.dict, sit.anim) FOLLOWING = false end,
  ["K9_LAYDOWN"] = function () PlayAnimation(laydown.dict, laydown.anim) FOLLOWING = false end,
  ["K9_VEHICLE_TOGGLE"] = function () K9ToggleVehicle(false) end,

  ["K9_SEARCH_PERSON"] = function () K9SearchPerson() end,
  ["K9_SEARCH_VEHICLE"] = function () K9SearchVehicle() end,
  ["K9_SEARCH_AREA"] = function () K9SearchArea() end
}

RegisterNUICallback("CLOSE_MENU", function(data)
    IN_MENU = false
    ACTION_CD = GetGameTimer()
    SetNuiFocus(false, false)
end)

RegisterNUICallback("MENU_SELECT", function(data)
    if data.value then
      ACTION_CD = GetGameTimer()
      switch[data.value]()
    end
end)

RegisterNUICallback("MENU_UPDATE", function(data)

    UpdateK9Appearance(data.id, data.type)
end)

RegisterNUICallback("MENU_INPUT", function(data)

    K9_NAME = data.value
end)





--Spawn K9
function SpawnK9()
  if K9_ID then
    DespawnK9()
  end
  TriggerServerEvent("K9:SERVER:SPAWN_K9")
end
-- Spawns and Deletes K9
function DespawnK9()


    if K9_ID then
            local DOG = NetworkGetEntityFromNetworkId(K9_ID)
            if DoesEntityExist(DOG) then
              DeleteEntity(DOG)
            end
    end
    DISTANCE_CD = 0
    ACTION_CD = 0
    MENU_CD = 0
    FOLLOWING = true

    K9_ID = false
    K9_IN_VEHICLE = false
    SEARCHING = false
    PLAYING_ANIMATION = false
    DRUGS_FOUND = false
end

local cam = 0
--- SPAWN EVENT
RegisterNetEvent('K9:CLIENT:SPAWN_K9')
AddEventHandler('K9:CLIENT:SPAWN_K9', function()
  local DOGHASH = GetHashKey(K9_CONFIG.Model)
  RequestModel(DOGHASH);
  while not HasModelLoaded(DOGHASH) do
    Citizen.Wait(1)
    RequestModel(DOGHASH);
  end

  local DOG = CreatePed(28, GetHashKey(K9_CONFIG.Model), K9_CONFIG.Location.x, K9_CONFIG.Location.y, K9_CONFIG.Location.z, 90, true, true)
  --SET NET ID FOR DOG
  K9_ID = NetworkGetNetworkIdFromEntity(DOG)
  --REQEUST CONTROL
  RequestNetworkControl()
  --GET ENTITY
  local DOG = NetworkGetEntityFromNetworkId(K9_ID)
  --set K9 Properties
  SetPedComponentVariation(DOG, 0, 0, K9_COLOR, 0)
  SetPedComponentVariation(DOG, K9_VEST, 0, 1, 0)
  SetBlockingOfNonTemporaryEvents(DOG, true)
  SetPedFleeAttributes(DOG, 0, false)
  SetPedRelationshipGroupHash(DOG, GetHashKey("PLAYER_POLICE"))
  SetPedArmour(DOG, 25)
  SetEntityHeading(DOG, 90)
  -- CREATE CAMERA
  -- Camera
  local coords = GetOffsetFromEntityInWorldCoords(DOG, 2.0, 0, -1.0)
  RenderScriptCams(false, false, 0, 1, 0)
  DestroyCam(cam, false)
  if(not DoesCamExist(cam)) then
      cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
      SetCamActive(cam, true)
      RenderScriptCams(true, false, 0, true, true)
      SetCamCoord(cam, coords.x, coords.y, coords.z + 0.5)
      SetCamRot(cam, 0.0, 0.0, GetEntityHeading(DOG) + 90)
  end
  --OPEN NUI
  IN_MENU = true
  SetNuiFocus(true, true)
  SendNUIMessage({
      type = 'OPEN_K9_OPTIONS',
      k9_name = K9_NAME,
      vest = K9_VEST,
      color = K9_COLOR
  })
end)

--Set BLIP and Destroy Camera
function SaveK9()
  IN_MENU = false
  local DOG = NetworkGetEntityFromNetworkId(K9_ID)
  local BLIP = AddBlipForEntity(DOG)
  SetBlipAsFriendly(BLIP, true)
  SetBlipSprite(BLIP, 442)
  BeginTextCommandSetBlipName("STRING")
  AddTextComponentString(K9_NAME)
  EndTextCommandSetBlipName(BLIP)
  RenderScriptCams(false, false, 0, 1, 0)
  DestroyCam(cam, false)
  K9AttackorFollow(false)
end
--Update K9 Appearance
function UpdateK9Appearance(id, type)
  -- id = K9_VEST or K9_COLOR | type = "+" or "-"
  -- COLOR 0 - 3
  -- VEST 1 - 8
  if id == 'K9_VEST' then
    if type == '+' then
        K9_VEST = K9_VEST + 1
    else
        K9_VEST = K9_VEST - 1
    end

    if K9_VEST < 1 then K9_VEST = 0 end
    if K9_VEST > 8 then K9_VEST = 8 end
  end

  if id == 'K9_COLOR' then
    if type == '+' then
        K9_COLOR = K9_COLOR + 1
    else
        K9_COLOR = K9_COLOR - 1
    end

    if K9_COLOR < 1 then K9_COLOR = 0 end
    if K9_COLOR > 3 then K9_COLOR = 3 end
  end

  --GET ENTITY
  local DOG = NetworkGetEntityFromNetworkId(K9_ID)
  --set K9 Properties
  SetPedComponentVariation(DOG, 0, 0, K9_COLOR, 0)
  SetPedComponentVariation(DOG, 8, 0, K9_VEST, 0)

  SendNUIMessage({
      type = 'OPEN_K9_OPTIONS',
      k9_name = K9_NAME,
      vest = K9_VEST,
      color = K9_COLOR
  })
end
--Animation set if we found something.
function K9Found(type)
  local time = math.random(1000,2000)
  if(type == 'vehicle') then
    time = math.random(10000,20000)
  end
  Citizen.Wait(time)
  QBCore.Functions.Notify("Drugs found!", "error", 4000)
  SEARCHING = false
  PlayAnimation(searchhit.dict, searchhit.anim)
  Citizen.Wait(3000)
  PlayAnimation(sit.dict, sit.anim)
  FOLLOWING = false
end
--[[
  ATTACK OR FOLLOW
  TOGGLE VEHICLE
  SEARCH PLAYER
  SEARCH VEHICLE
  SEARCH AREA

]]--
function K9AttackorFollow(target)
  ACTION_CD = GetGameTimer()
  local DOG = NetworkGetEntityFromNetworkId(K9_ID)
  if target then
    --Attack
    SetCanAttackFriendly(DOG, true, true);
    TaskPutPedDirectlyIntoMelee(DOG, target, 0.0, -1.0, 0.0, false);
    FOLLOWING = false
    QBCore.Functions.Notify(K9_NAME.." is attacking!", "error", 2000)
  else
    TaskFollowToOffsetOfEntity(DOG, PlayerPedId(), 0.5, 0.0, 0.0, 5.0, -1, 1.0, true);
    FOLLOWING = true
    QBCore.Functions.Notify(K9_NAME.." is following.", "primary", 2000)
  end
end

function K9ToggleVehicle(target)
  SEARCHING = false
  local DOG = NetworkGetEntityFromNetworkId(K9_ID)
  local VEHICLE = GetVehicleAheadOfPlayer()
  local DOOR = GetClosestVehicleDoor(VEHICLE)
  local PLAYER_COORDS = GetEntityCoords(PlayerPedId())
  local VEHICLE_COORDS = GetEntityCoords(VEHICLE)
  local DOG_COORDS = GetEntityCoords(DOG)
  local SEAT = 0

  if #(VEHICLE_COORDS - DOG_COORDS) < 5 then
    if DOOR == 3 then
      SEAT = "seat_pside_r"
    else
      SEAT = "seat_dside_r"
    end
      if IsEntityAttached(DOG) then
          FOLLOWING = false
          SetEntityInvincible(DOG, true)
          SetPedCanRagdoll(DOG, false)
          --Get Vehicle Coords, Open Rear Passenger Door, Spawn Dog
          local DOOR_COORDS = GetEntryPositionOfDoor(VEHICLE, DOOR);
          local  bool, gZero = GetGroundZFor_3dCoord(DOOR_COORDS.x, DOOR_COORDS.y, PLAYER_COORDS.z+5, false);

          SetVehicleDoorOpen(VEHICLE, DOOR, false, false);
          Citizen.Wait(500)
          AttachEntityToEntity(DOG, VEHICLE, GetEntityBoneIndexByName(VEHICLE, SEAT), 0.0, -0.25, 0.40, 0.0, 0.0, 0, false, false, false, true, 20, true)
          Citizen.Wait(500)
          DetachEntity(DOG, false, false)  
          SetEntityCoords(DOG, DOOR_COORDS.x, DOOR_COORDS.y, gZero, false, false, false, false)
          ClearPedTasks(DOG)
          Citizen.Wait(1500)
          K9AttackorFollow(target)
          SetPedCanRagdoll(DOG, true)
          SetEntityInvincible(DOG, false)
          SetVehicleDoorShut(VEHICLE, DOOR, false)

      else
        FOLLOWING = true
        SetVehicleDoorOpen(VEHICLE, DOOR, false, false)
        Citizen.Wait(1500)
        AttachEntityToEntity(DOG, VEHICLE, GetEntityBoneIndexByName(VEHICLE, SEAT), 0.0, -0.25, 0.40, 0.0, 0.0, 0, false, false, false, true, 20, true)
        PlayAnimation(sit.dict, sit.anim)
        SetVehicleDoorShut(VEHICLE, DOOR, false)

      end
  else
    QBCore.Functions.Notify(K9_NAME.." is not close enough.", "error", 4000)
  end
end

function K9SearchPerson()
    FOLLOWING = false
    local TARGET = GetPlayerSourceAheadOfPlayer()

    if TARGET > 0 then
      TriggerServerEvent("K9:SERVER:SEARCH_PERSON", TARGET)
    else
      QBCore.Functions.Notify(K9_NAME.." unable to locate person.", "error", 4000)
    end
    
end

function K9SearchVehicle()
  FOLLOWING = false
  local VEHICLE = GetVehicleAheadOfPlayer()
  local PLATE = GetVehicleNumberPlateText(VEHICLE)
  local DOG = NetworkGetEntityFromNetworkId(K9_ID)

  if VEHICLE then
    QBCore.Functions.Notify(K9_NAME.." is searching.", "primary", 4000)

    local PLAYERS = {}
    local MAX_SEATS = GetVehicleMaxNumberOfPassengers(VEHICLE) -2

    for i = -1, MAX_SEATS do

      local TARGET = GetPedInVehicleSeat(VEHICLE, i)
      
      if TARGET ~= nil then
          local SERVER_ID = GetPlayerId(TARGET)

          if SERVER_ID > 0 then
            table.insert(PLAYERS, SERVER_ID)
          end
      end

    end
    
    TriggerServerEvent("K9:SERVER:SEARCH_VEHICLE", PLATE, PLAYERS)
    
    SEARCHING = true

      if SEARCHING then
      local OFFSET_1 = GetOffsetFromEntityInWorldCoords(VEHICLE, 2.0, -2.0, 0.0)
      TaskGoToCoordAnyMeans(DOG, OFFSET_1.x, OFFSET_1.y, OFFSET_1.z, 5.0, 0, false, 1, 10.0)
      Citizen.Wait(5000)
      end

      if SEARCHING then
      local OFFSET_2 = GetOffsetFromEntityInWorldCoords(VEHICLE, 2.0, 2.0, 0.0)
      TaskGoToCoordAnyMeans(DOG, OFFSET_2.x, OFFSET_2.y, OFFSET_2.z, 5.0, 0, false, 1, 10.0)
      Citizen.Wait(5000)
      end

      if SEARCHING then
      local OFFSET_3 = GetOffsetFromEntityInWorldCoords(VEHICLE, -2.0, 2.0, 0.0)
      TaskGoToCoordAnyMeans(DOG, OFFSET_3.x, OFFSET_3.y, OFFSET_3.z, 5.0, 0, false, 1, 10.0)
      Citizen.Wait(5000)
      end

      if SEARCHING then
      local OFFSET_4 = GetOffsetFromEntityInWorldCoords(VEHICLE, -2.0, -2.0, 0.0)
      TaskGoToCoordAnyMeans(DOG, OFFSET_4.x, OFFSET_4.y, OFFSET_4.z, 5.0, 0, false, 1, 10.0)
      Citizen.Wait(5000)
      end

      SEARCHING = false
  else
      QBCore.Functions.Notify("No vehicle, try again.", "error", 4000)
  end
end

function K9SearchArea()

  local PLAYERS = GetPlayersInRadius(20,75)

  for i = 1, #PLAYERS do
      FOLLOWING = false
      QBCore.Functions.Notify(K9_NAME.." found a scent.", "primary", 4000)
      local DOG = NetworkGetEntityFromNetworkId(K9_ID)
      local DOG_COORDS = GetEntityCoords(DOG)
      local COORDS = GetEntityCoords(PLAYERS[i])
      TaskGoToCoordAnyMeans(DOG, COORDS.x, COORDS.y, COORDS.z, 5.0, 0, false, 1, 10.0)

      while #(DOG_COORDS - COORDS) > 2 do
        Citizen.Wait(1000)
        DOG_COORDS = GetEntityCoords(DOG)
        if FOLLOWING then
          break
        end
      end

      if FOLLOWING then
        QBCore.Functions.Notify(K9_NAME.." is no longer tracking.", "primary", 4000)
        break
      end
      QBCore.Functions.Notify(K9_NAME.." lost the scent.", "primary", 4000)
      K9AttackorFollow(false)
      Citizen.Wait(2000)
  end

end

RegisterNetEvent('K9:CLIENT:SEARCH_RESULTS')
AddEventHandler('K9:CLIENT:SEARCH_RESULTS', function(status, type)
  if status then

    K9Found(type)
  end
end)

--[[

    TOOLING

]]--
function IsDurationComplete(time, duration)

  local difference = GetGameTimer() - time
  if difference >= duration then
    return true
  else
    return false
  end

end

-- Gets Control Of Ped
function RequestNetworkControl()
    NetworkRequestControlOfNetworkId(K9_ID)
    while not NetworkHasControlOfNetworkId(K9_ID) do
        Citizen.Wait(500)
        NetworkRequestControlOfNetworkId(K9_ID)
    end
end

-- Gets Players
function GetPlayers()
    local players = {}
    for i = 0, 256 do
        if NetworkIsPlayerActive(i) then
            table.insert(players, i)
        end
    end
    return players
end

-- Set K9 Animation (Sit / Laydown)
function PlayAnimation(dict, anim)
  RequestAnimDict(dict)
  while not HasAnimDictLoaded(dict) do
      Citizen.Wait(0)
  end
  local DOG = NetworkGetEntityFromNetworkId(K9_ID)
  TaskPlayAnim(DOG, dict, anim, 8.0, -8.0, -1, 2, 0.0, 0, 0, 0)
end

-- Gets Player ID
function GetPlayerId(target_ped)
    local players = GetPlayers()
    for a = 1, #players do

        local ped = GetPlayerPed(players[a])
        local server_id = GetPlayerServerId(players[a])
        if target_ped == ped then
            return server_id
        end
    end
    return 0
end

-- Gets Player ID
function GetPlayersInRadius(min, max)
    local PLAYERS = GetPlayers()
    local IN_RANGE = {}
    for a = 1, #PLAYERS do
        
        local PED = GetPlayerPed(PLAYERS[a])
        local PED_COORDS = GetEntityCoords(PED)
        local PLAYER_COORDS = GetEntityCoords(PlayerPedId())
        local DISTANCE = #(PED_COORDS - PLAYER_COORDS)

        if DISTANCE <= max and DISTANCE >= min then
          table.insert(IN_RANGE, PED)
        end  

    end
    return IN_RANGE
end

-- Gets Vehicle Ahead Of Player
function GetVehicleAheadOfPlayer()
    local PLAYER = PlayerPedId()
    local COORDS = GetEntityCoords(PLAYER)
    local OFFSET = GetOffsetFromEntityInWorldCoords(PLAYER, 0.0, 3.0, 0.0)
    local RAY = StartShapeTestCapsule(COORDS.x, COORDS.y, COORDS.z, OFFSET.x, OFFSET.y, OFFSET.z, 5, 10, PLAYER, 7)
    local RETURN, HIT, ENDCOORDS, SURFACE, VEHICLE = GetShapeTestResult(RAY)

    if HIT then
        return VEHICLE
    else
        return false
    end
end

function GetPlayerSourceAheadOfPlayer()
    local PLAYER = PlayerPedId()
    local COORDS = GetEntityCoords(PLAYER)
    local OFFSET = GetOffsetFromEntityInWorldCoords(PLAYER, 0.0, 2.0, 0.0)
    local RAY = StartShapeTestCapsule(COORDS.x, COORDS.y, COORDS.z, OFFSET.x, OFFSET.y, OFFSET.z, 0.5, 12, PLAYER, 7)
    local RETURN, HIT, ENDCOORDS, SURFACE, PED = GetShapeTestResult(RAY)

    if HIT then
        return GetPlayerId(PED)
    else
        return false
    end

end

-- Gets Closest Door To Player
function GetClosestVehicleDoor(vehicle)
  local PLAYER = GetEntityCoords(PlayerPedId(), false)
  local BACKLEFT = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, "door_dside_r"))
  local BACKRIGHT = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, "door_pside_r"))
  local BLDISTANCE = #(PLAYER - BACKLEFT)
  local BRDISTANCE = #(PLAYER - BACKRIGHT)

    local FOUND_DOOR = false

    if BLDISTANCE < BRDISTANCE then
        FOUND_DOOR = 2
    else
        FOUND_DOOR = 3
    end

    return FOUND_DOOR
end

--prevent world spawn of ped model
AddEventHandler('populationPedCreating', function(x, y, z, model, setters)
    if model == 'a_c_shepherd' and K9_CONFIG.Prevent then
      CancelEvent()
    end
end)
