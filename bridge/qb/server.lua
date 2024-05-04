if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

function ShowNotification(target, text)
	TriggerClientEvent(GetCurrentResourceName()..":showNotification", target, text)
end

function CheckPermission(source, permission)
    local xPlayer = QBCore.Functions.GetPlayer(source).PlayerData
    local name = xPlayer.job.name
    local rank = xPlayer.job.grade.level
    if permission.jobs[name] and permission.jobs[name] <= rank then 
        return true
    end
    for i=1, #permission.groups do 
        if QBCore.Functions.HasPermission(source, permission.groups[i]) then 
            return true 
        end
    end
    for i=1, #permission.ace do 
        if IsPlayerAceAllowed(source, permission.ace[i]) then 
            return true 
        end
    end
end

function RegisterUsableItem(...)
    QBCore.Functions.CreateUseableItem(...)
end

function AddItem(source, name, count, metadata) -- Metadata is not required.
    local source = tonumber(source)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    xPlayer.Functions.AddItem(name, count, nil, metadata)
end

function RemoveItem(source, name, count)
    local source = tonumber(source)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    xPlayer.Functions.RemoveItem(name, count)
end

function GetItemCount(source, name)
    local source = tonumber(source)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    local item = xPlayer.Functions.GetItemByName(name)
    return item and item.amount or 0
end

RegisterUsableItem("glowsaber", function(source)
    TriggerClientEvent("pickle_glowsabers:equipGlowsaber", source)
end)