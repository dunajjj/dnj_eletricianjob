local ESX = exports['es_extended']:getSharedObject()
local rprs = {}
local acot = {}

local function gntkn()
    return math.random(111111, 999999) .. "-" .. os.time()
end

ESX.RegisterServerCallback('dnj_eletrician:payc', function(source, cb, paytype)
    local xpl = ESX.GetPlayerFromId(source)
    local price = dnj.carprice

    if not paytype then paytype = 'money' end

    local account = xpl.getAccount(paytype)

    if account.money >= price then
        xpl.removeAccountMoney(paytype, price)
        
        local token = gntkn()
        acot[source] = token
        cb(token)
    else
        cb(false)
    end
end)

RegisterNetEvent('dnj_eletrician:ar')
AddEventHandler('dnj_eletrician:ar', function(token)
    local src = source
    
    if not acot[src] or acot[src] ~= token then
        return
    end

    if not rprs[src] then
        rprs[src] = 0
    end
    rprs[src] = rprs[src] + 1
end)

RegisterNetEvent('dnj_eletrician:py')
AddEventHandler('dnj_eletrician:py', function(token)
    local src = source
    local xpl = ESX.GetPlayerFromId(src)
    
    if not acot[src] or acot[src] ~= token then
    --    DropPlayer(src, 'secure - eletrika.')
        return
    end

    acot[src] = nil
    
    local repairs = rprs[src] or 0
    local perrepair = dnj.payperrepair or 1000
    
    if repairs > 0 then
        local totalpay = repairs * perrepair
        
        exports.ox_inventory:AddItem(src,"money",totalpay)
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Renes',
            description = 'Vydělal jsi $' .. totalpay .. ' za ' .. repairs .. ' oprav.',
            type = 'success'
        })
        
        rprs[src] = 0
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Renes',
            description = 'Neudělal jsi žádnou práci. Vypadni odsud!',
            type = 'error'
        })
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if rprs[src] then
        rprs[src] = nil
    end
    if acot[src] then
        acot[src] = nil
    end
end)