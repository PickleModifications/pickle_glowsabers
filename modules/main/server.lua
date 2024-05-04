local Glowsabers = {}

RegisterNetEvent("pickle_glowsabers:updateGlowsaber", function(color)
    local source = source
    if not Glowsabers[source] then return end
    Glowsabers[source].color = color
    TriggerClientEvent("pickle_glowsabers:updateGlowsaber", -1, source, Glowsabers[source])
end)

RegisterNetEvent("pickle_glowsabers:unequipGlowsaber", function()
    local source = source
    if not Glowsabers[source] then return end
    Glowsabers[source] = nil
    TriggerClientEvent("pickle_glowsabers:unequipGlowsaber", -1, source)
    Wait(600)
    if AddItem then
        AddItem(source, "glowsaber", 1)
    end
    TriggerClientEvent("pickle_glowsabers:updateGlowsaber", -1, source, Glowsabers[source])
end)

lib.callback.register("pickle_glowsabers:createGlowsaber", function(source, netId, color)
    local source = source
    if Glowsabers[source] then return end
    if not DoesEntityExist(NetworkGetEntityFromNetworkId(netId)) then return end
    if GetItemCount and GetItemCount(source, "glowsaber") < 1 then return ShowNotification(source, _L("no_item")) end
    Glowsabers[source] = {
        color = color or {255, 0, 0},
        netId = netId
    }
    if RemoveItem then
        RemoveItem(source, "glowsaber", 1)
    end
    TriggerClientEvent("pickle_glowsabers:updateGlowsaber", -1, source, Glowsabers[source])
    return true
end)

CreateThread(function()
    while true do
        for k,v in pairs(Glowsabers) do
            local entity = NetworkGetEntityFromNetworkId(v.netId)
            if not DoesEntityExist(entity) or #(GetEntityCoords(entity) - GetEntityCoords(GetPlayerPed(k))) > 2.0 then
                Glowsabers[k] = nil
                TriggerClientEvent("pickle_glowsabers:updateGlowsaber", -1, k, Glowsabers[k])
            end
        end
        Wait(5000)
    end 
end)