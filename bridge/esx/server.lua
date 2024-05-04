if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

function ShowNotification(target, text)
	TriggerClientEvent(GetCurrentResourceName()..":showNotification", target, text)
end

function CheckPermission(source, permission)
    local xPlayer = ESX.GetPlayerFromId(source)
    local name = xPlayer.job.name
    local rank = xPlayer.job.grade
    local group = xPlayer.getGroup()
    if permission.jobs[name] and permission.jobs[name] <= rank then 
        return true
    end
    for i=1, #permission.groups do 
        if group == permission.groups[i] then 
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
    ESX.RegisterUsableItem(...)
end

function AddItem(source, name, count, metadata) -- Metadata is not required.
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.addInventoryItem(name, count)
end

function RemoveItem(source, name, count)
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.removeInventoryItem(name, count)
end

function GetItemCount(source, name)
    local xPlayer = ESX.GetPlayerFromId(source)
    local item = xPlayer.getInventoryItem(name)
    return item and item.count or 0
end

RegisterUsableItem("glowsaber", function(source)
    TriggerClientEvent("pickle_glowsabers:equipGlowsaber", source)
end)