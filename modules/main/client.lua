local Glowsabers = {}
local localGlowsabers = {}
local tempProps = {}
local glowsaberActive = false
local glowsaberEntity = nil

function GetSaberSettings()
    return json.decode(GetResourceKvpString("pickle_glowsabers:settings") or json.encode({color = {255, 0, 0, 255}}))
end

SaberSettings = GetSaberSettings()

function SetSaberSettings(settings)
    SaberSettings = settings
    SetResourceKvp("pickle_glowsabers:settings", json.encode(settings))
end

function RenderGlowsaber(playerPed, glowsaberEntity, color)
    local coords = GetOffsetFromEntityInWorldCoords(glowsaberEntity, 0.0, 0.0, 0.09)
    local coords2 = GetOffsetFromEntityInWorldCoords(glowsaberEntity, 0.0, 0.0, 0.9)
    local rotation = GetEntityRotation(glowsaberEntity, 2)
    local dir = GetEntityForwardVector(glowsaberEntity)
    DrawMarker(1, coords.x, coords.y, coords.z, -dir.x, -dir.y, -dir.z, 0.0, rotation.y, 0.0, 0.035, 0.035, lerp(0.0, 0.85, localGlowsabers[glowsaberEntity].length or 1.0), color[1], color[2], color[3], 255, false, false, 2, false, nil, nil, false)
    DrawMarker(1, coords.x, coords.y, coords.z, -dir.x, -dir.y, -dir.z, 0.0, rotation.y, 0.0, 0.035, 0.035, lerp(0.0, 0.85, localGlowsabers[glowsaberEntity].length or 1.0), color[1], color[2], color[3], 255, false, false, 2, false, nil, nil, false)
    DrawLightWithRangeAndShadow(coords.x, coords.y, coords.z, color[1], color[2], color[3], 1.0, 0.5, 8.0)

    local rayHandle = StartShapeTestRay(coords.x, coords.y, coords.z, coords2.x, coords2.y, coords2.z, -1, playerPed, 0)
    local _, hit, coords, _, _ = GetShapeTestResult(rayHandle)
    if not localGlowsabers[glowsaberEntity].particle and hit then
        localGlowsabers[glowsaberEntity].particle = true
        local ptfxHandle = PlayEffect("core", "ent_brk_sparking_wires", glowsaberEntity, GetOffsetFromEntityGivenWorldCoords(glowsaberEntity, coords.x, coords.y, coords.z), vector3(0.0, 0.0, 0.0), 1.0, false)
        SetTimeout(50, function()
            StopParticleFxLooped(ptfxHandle, true)
            localGlowsabers[glowsaberEntity].particle = false
        end)
    end
end

function EquipGlowsaber()
    if glowsaberActive then return end
    glowsaberActive = true
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    glowsaberEntity = CreateProp(`w_ex_pipebomb`, coords.x, coords.y, coords.z, true, true, true)
    AttachEntityToEntity(glowsaberEntity, playerPed, GetPedBoneIndex(playerPed, 0xDEAD), 0.1, 0.05, 0.0, -70.0, 0.0, -30.0, true, true, false, true, 1, true)
    lib.callback("pickle_glowsabers:createGlowsaber", "", function(success)
        if not success then
            DeleteEntity(glowsaberEntity)
            glowsaberEntity = nil
            glowsaberActive = false
        else
            CreateThread(function()
                local playerPed = PlayerPedId()
                SendNUIMessage({
                    type = "playSound",
                    sound = "saber_on.mp3"
                })
                GiveWeaponToPed(playerPed, `WEAPON_NIGHTSTICK`, 0, false, true)
                while glowsaberActive do 
                    local playerPed = PlayerPedId()
                    SetPedCurrentWeaponVisible(playerPed, false, false, true)
                    SetCurrentPedWeapon(playerPed, `WEAPON_NIGHTSTICK`, true)
                    SetPlayerMeleeWeaponDamageModifier(PlayerId(), 0.15)
                    if IsControlJustPressed(0, 202) then
                        SendNUIMessage({
                            type = "playSound",
                            sound = "saber_off.mp3"
                        })
                        TriggerServerEvent("pickle_glowsabers:unequipGlowsaber")
                    end
                    Wait(0)
                end
            end)
        end
    end, NetworkGetNetworkIdFromEntity(glowsaberEntity), SaberSettings.color)
end

function GetColorString(color)
    return "rgba(" .. color[1] .. ", " .. color[2] .. ", " .. color[3] .. ", " .. round(color[4] / 255, 2) .. ")"
end

function GetAlphaFromString(color)
    local alpha = color:match("rgba%(.+, .+, .+, (.+)%)")
    return tonumber(alpha)
end

function GetGlowsaberObject(source)
    local glowsaber = Glowsabers[source]
    if not glowsaber then return end
    if not NetworkDoesNetworkIdExist(glowsaber.netId) then return end
    local entity = NetToObj(glowsaber.netId)
    if not DoesEntityExist(entity) then return end
    return entity
end

function RemoveGlowsaber()
    if glowsaberActive then
        TriggerServerEvent("pickle_glowsabers:unequipGlowsaber")
    end
end

CreateThread(function()
    local touching = false
    local playerSource = GetPlayerServerId(PlayerId())
    while true do
        local wait = 1500
        local playerPed = PlayerPedId()
        if glowsaberActive and Glowsabers[playerSource] then
            if not localGlowsabers[glowsaberEntity] then
                localGlowsabers[glowsaberEntity] = {
                    length = 0.0,
                    particle = false
                }
            end
            if localGlowsabers[glowsaberEntity].length < 1.0 and not localGlowsabers[glowsaberEntity].lengthReverse then
                localGlowsabers[glowsaberEntity].length = localGlowsabers[glowsaberEntity].length + 0.02
            elseif localGlowsabers[glowsaberEntity].length > 0.0 and localGlowsabers[glowsaberEntity].lengthReverse then
                localGlowsabers[glowsaberEntity].length = localGlowsabers[glowsaberEntity].length - 0.02
            end
            if DoesEntityExist(GetVehiclePedIsIn(playerPed, false)) then
                RemoveGlowsaber()
            end
            RenderGlowsaber(playerPed, glowsaberEntity, Glowsabers[playerSource].color)
            wait = 0
        end
        for k,v in pairs(Glowsabers) do
            local player = GetPlayerFromServerId(k)
            local ped = GetPlayerPed(player)
            local coords = GetEntityCoords(ped)
            if #(coords - GetEntityCoords(playerPed)) < Config.RenderDistance and k ~= playerSource then
                local entity = GetGlowsaberObject(k)
                if entity then
                    if not localGlowsabers[entity] then
                        localGlowsabers[entity] = {
                            length = 0.0,
                            particle = false
                        }
                    end
                    if localGlowsabers[entity].length < 1.0 and not localGlowsabers[entity].lengthReverse then
                        localGlowsabers[entity].length = localGlowsabers[entity].length + 0.02
                    elseif localGlowsabers[entity].length > 0.0 and localGlowsabers[entity].lengthReverse then
                        localGlowsabers[entity].length = localGlowsabers[entity].length - 0.02
                    end
                    wait = 0
                    RenderGlowsaber(ped, entity, v.color)
                end
            end
        end
        Wait(wait)
    end
end)

RegisterCommand("glowsabersettings", function()
    local input = lib.inputDialog(_L("saber_title"), {
        {type = 'color', format = "rgba", label = _L("saber_color"), default = GetColorString(SaberSettings.color)},
    })
    if not input then return end
    local rgb = lib.math.torgba(input[1])
    local alpha = GetAlphaFromString(input[1])
    SaberSettings.color = {math.ceil(rgb.x), math.ceil(rgb.y), math.ceil(rgb.z), alpha * 255}
    SetSaberSettings(SaberSettings)
    TriggerServerEvent("pickle_glowsabers:updateGlowsaber", SaberSettings.color)
end)

RegisterNetEvent("pickle_glowsabers:updateGlowsaber", function(source, glowsaber)
    Glowsabers[source] = glowsaber
    if not glowsaber and source == GetPlayerServerId(PlayerId()) then
        glowsaberActive = false
        DeleteEntity(glowsaberEntity)
        SetCurrentPedWeapon(PlayerPedId(), `WEAPON_UNARMED`, true)
    end
end)

RegisterNetEvent("pickle_glowsabers:equipGlowsaber", function()
    EquipGlowsaber()
end)
    
RegisterNetEvent("pickle_glowsabers:unequipGlowsaber", function(source)
    if not Glowsabers[source] then return end
    local entity = GetGlowsaberObject(source)
    if entity then
        if not localGlowsabers[entity] then 
            localGlowsabers[entity] = {}
        end
        localGlowsabers[entity].lengthReverse = true
    end
end)

AddEventHandler('gameEventTriggered', function(event, args)
    if event ~= "CEventNetworkEntityDamage" or GetEntityType(args[1]) ~= 1 or NetworkGetPlayerIndexFromPed(args[1]) ~= PlayerId() then return end
    if not IsEntityDead(PlayerPedId()) then return end
    RemoveGlowsaber()
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        if glowsaberEntity then
            DeleteEntity(glowsaberEntity)
            glowsaberEntity = nil
        end
    end
end)