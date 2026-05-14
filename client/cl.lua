local ESX = exports['es_extended']:getSharedObject()

local startedjob = false
local hascar = false
local hasoutfit = false
local currentveh = nil
local currentjobcoords = nil
local currentblip = nil
local carreturning = false
local completedlocs = {}
local cancollect = false
local cam = nil
local token = nil

function cmac(tentity, callback)
    local ped = cache.ped
    local targetpos = GetOffsetFromEntityInWorldCoords(tentity, 0.0, -1.0, 0.0)
    local theading = GetEntityHeading(tentity)

    local ground, gz = GetgzFor_3dCoord(targetpos.x, targetpos.y, targetpos.z + 10.0, false)
    local finalz = targetpos.z
    if ground then
         finalz = gz
    else
         finalz = GetEntityCoords(ped).z
    end

    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    
    TaskGoStraightToCoord(ped, targetpos.x, targetpos.y, finalz, 1.0, -1, theading, 0.5)

    Citizen.CreateThread(function()
        local timeout = 0
        local ismoving = true
        
        while ismoving do
            local currentpos = GetEntityCoords(ped)
            local dist = #(vector2(currentpos.x, currentpos.y) - vector2(targetpos.x, targetpos.y))

            if dist < 0.6 or timeout > 40 then
                ismoving = false
                
                ClearPedTasks(ped)
                
                SetEntityCoords(ped, targetpos.x, targetpos.y, finalz, false, false, false, false)
                SetEntityHeading(ped, theading)
                FreezeEntityPosition(ped, true)

                if not DoesCamExist(cam) then
                    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                end

                local camcoords = GetOffsetFromEntityInWorldCoords(ped, 2.5, 0.0, 0.0)
                
                SetCamCoord(cam, camcoords.x, camcoords.y, camcoords.z + 0.5)
                PointCamAtPedBone(cam, ped, 31086, 0.0, 0.0, 0.0, true)
                
                SetCamActive(cam, true)
                RenderScriptCams(true, true, 1000, true, true)

                Citizen.Wait(1000)
                
                if callback then callback() end
            end
            
            timeout = timeout + 1
            Citizen.Wait(100)
        end
    end)
end

function stopcm()
    local ped = cache.ped
    RenderScriptCams(false, true, 1000, true, true)
    if DoesCamExist(cam) then
        DestroyCam(cam, false)
    end
    cam = nil
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
end

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local ped = cache.ped
        local pcoords = GetEntityCoords(ped)
        
        if startedjob and not hascar and not carreturning then
            local tcoords = vector3(dnj.rentprop.coords.x, dnj.rentprop.coords.y, dnj.rentprop.coords.z + 2.2)
            if #(pcoords - tcoords) < 20.0 then
                sleep = 0
                DrawMarker(2, tcoords.x, tcoords.y, tcoords.z, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 0, 0, 150, true, true, 2, nil, nil, false)
            end
        end

        local clothmarker = (hascar and not hasoutfit) or (carreturning and not DoesEntityExist(currentveh) and hasoutfit)
        if clothmarker then
            local tcoords = vector3(dnj.clothingchange.coords.x, dnj.clothingchange.coords.y, dnj.clothingchange.coords.z + 2.8)
            if #(pcoords - tcoords) < 20.0 then
                sleep = 0
                DrawMarker(2, tcoords.x, tcoords.y, tcoords.z, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 0, 0, 150, true, true, 2, nil, nil, false)
            end
        end

        if DoesEntityExist(currentveh) and not IsPedInVehicle(ped, currentveh, false) then
            local vcoords = GetEntityCoords(currentveh)
            if #(pcoords - vcoords) < 20.0 then
                sleep = 0
                DrawMarker(2, vcoords.x, vcoords.y, vcoords.z + 3.5, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 0, 0, 150, true, true, 2, nil, nil, false)
            end
        end

        Citizen.Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    local npcmodel = lib.requestModel(dnj.npc.model)
    local npc = CreatePed(4, npcmodel, dnj.npc.coords.x, dnj.npc.coords.y, dnj.npc.coords.z - 1.0, dnj.npc.coords.w, false, true)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)

    exports.ox_target:addLocalEntity(npc, {
        {
            name = 'est',
            icon = 'fa-solid fa-bolt',
            label = 'Začít práci',
            canInteract = function() return not startedjob and not cancollect end,
            onSelect = function()
                startedjob = true
                lib.notify({title = 'Renes', description = 'Potřebuji opravit pár elektřických krabic. Jdi zaplatit poplatek za auto.', type = 'info', duration = 10000})
            end
        },
        {
            name = 'clt',
            icon = 'fa-solid fa-money-bill',
            label = 'Vzít výplatní pásku',
            canInteract = function() return cancollect end,
            onSelect = function()
                TriggerServerEvent('dnj_eletrician:py', token)
                startedjob = false
                cancollect = false
                token = nil
                completedlocs = {}
                lib.notify({title = 'Renes', description = 'Díky za pomoc! Šichta ti prozatím skončila...', type = 'success'})
            end
        }
    })

    local rentprop = CreateObject(dnj.rentprop.model, dnj.rentprop.coords.x, dnj.rentprop.coords.y, dnj.rentprop.coords.z, false, false, false)
    SetEntityHeading(rentprop, dnj.rentprop.coords.w)
    FreezeEntityPosition(rentprop, true)

    exports.ox_target:addLocalEntity(rentprop, {
        {
            name = 'rent',
            icon = 'fa-solid fa-car',
            label = 'Zaplatit auto ('..dnj.carprice..'$)',
            canInteract = function() return startedjob and not hascar and not carreturning end,
            onSelect = function()
                local input = lib.inputDialog('Platba zálohy ($'..dnj.carprice..')', {
                    {
                        type = 'select',
                        label = 'Vyberte způsob platby',
                        options = {
                            { value = 'money', label = 'Hotovost' },
                            { value = 'bank', label = 'Banka' }
                        },
                        required = true
                    }
                })

                if not input then return end
                local accountType = input[1]

                cmac(rentprop, function()
                    ESX.TriggerServerCallback('dnj_eletrician:payc', function(cbtoken)
                        if cbtoken then
                            token = cbtoken
                            local ped = cache.ped
                            lib.requestAnimDict('missheistdockssetup1ig_5@base')
                            TaskPlayAnim(ped, 'missheistdockssetup1ig_5@base', 'workers_talking_base_dockworker1', 8.0, 8.0, 4000, 49, 0, false, false, false)

                            Citizen.Wait(4000)

                            lib.requestModel(dnj.carspawn.model)
                            currentveh = CreateVehicle(dnj.carspawn.model, dnj.carspawn.coords.x, dnj.carspawn.coords.y, dnj.carspawn.coords.z, dnj.carspawn.coords.w, true, false)
                            hascar = true
                            SetVehicleNumberPlateText(currentveh, "ELEC"..tostring(math.random(100,999)))
                            
                            stopcm()
                            lib.notify({title = 'Renes', description = 'Auto máš připraveno. Jdi se převléct a pak začni práci!', type = 'success', duration = 10000})
                        else
                            stopcm()
                            lib.notify({title = 'Renes', description = 'Ty vole! Ty nemáš prachy ani na auto...', type = 'error', duration = 8500})
                        end
                    end, accountType)
                end)
            end
        }
    })

    local cloths = CreateObject(dnj.clothingchange.model, dnj.clothingchange.coords.x, dnj.clothingchange.coords.y, dnj.clothingchange.coords.z, false, false, false)
    SetEntityHeading(cloths, dnj.clothingchange.coords.w)
    FreezeEntityPosition(cloths, true)

    exports.ox_target:addLocalEntity(cloths, {
        {
            name = 'chng',
            label = 'Převléknout',
            icon = 'fa-solid fa-shirt',
            canInteract = function() return hascar and not hasoutfit end,
            onSelect = function()
                cmac(cloths, function()
                    local ped = cache.ped
                    lib.requestAnimDict('clothingtie')
                    TaskPlayAnim(ped, 'clothingtie', 'try_tie_neutral_a', 8.0, 8.0, 4000, 49, 0, false, false, false)
                    Citizen.Wait(4000)
                    
                    TriggerEvent('skinchanger:getSkin', function(skin)
                        if skin.sex == 0 then
                            TriggerEvent('skinchanger:loadClothes', skin, dnj.uniform.male)
                        else
                            TriggerEvent('skinchanger:loadClothes', skin, dnj.uniform.female)
                        end
                    end)
                    hasoutfit = true
                    
                    stopcm()
                    lib.notify({title = 'Renes', description = 'Teď jdi do auta a počkej na zakázku. Dlho to trvat nebude...', type = 'info', duration = 10000})
                end)
            end
        },
        {
            name = 'sakidzdopici',
            label = 'Převléknout do civilu',
            icon = 'fa-solid fa-user-tie',
            canInteract = function() return carreturning and not DoesEntityExist(currentveh) and hasoutfit end,
            onSelect = function()
                cmac(cloths, function()
                    local ped = cache.ped
                    lib.requestAnimDict('clothingtie')
                    TaskPlayAnim(ped, 'clothingtie', 'try_tie_neutral_a', 8.0, 8.0, 4000, 49, 0, false, false, false)
                    
                    Citizen.Wait(4000)

                    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                        TriggerEvent('skinchanger:loadSkin', skin)
                    end)
                    hasoutfit = false
                    cancollect = true
                    carreturning = false
                    
                    stopcm()
                    lib.notify({title = 'Renes', description = 'Jdi si pro výplatní pásku..', type = 'success', duration = 8500})
                end)
            end
        }
    })
end)

lib.onCache('vehicle', function(value)
    if not hasoutfit or not startedjob or carreturning then return end
    
    if value and value == currentveh then
        Citizen.CreateThread(function()
            Citizen.Wait(5000)
            
            local pped = cache.ped
            if IsPedInVehicle(pped, currentveh, false) then
                local alert = lib.alertDialog({
                    header = 'Renes',
                    content = 'Máme pro tebe novou zakázku. Přijímáš?',
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = "Potvrdit",
                        cancel = "Zrušit"
                    }
                })

                if alert == 'confirm' then
                    startjob()
                else
                    cjob()
                end
            end
        end)
    end
end)

function startjob()
    if currentblip then RemoveBlip(currentblip) end
    
    local locindex = math.random(1, #dnj.locs)
    local tries = 0
    while completedlocs[locindex] and tries < 50 do
        locindex = math.random(1, #dnj.locs)
        tries = tries + 1
    end
    
    currentjobcoords = dnj.locs[locindex]
    
    currentblip = AddBlipForCoord(currentjobcoords)
    SetBlipSprite(currentblip, 354)
    SetBlipColour(currentblip, 11)
    SetBlipRoute(currentblip, true)
    
    lib.notify({title = 'Renes', description = 'Jdi na GPS.', type = 'success', duration = 10000})

    exports.ox_target:addSphereZone({
        coords = currentjobcoords,
        radius = 1.0,
        options = {
            {
                name = 'repair_elec',
                icon = 'fa-solid fa-screwdriver',
                label = 'Opravit rozvodnou skříň',
                onSelect = function()
                    local ped = cache.ped
                    
                    FreezeEntityPosition(ped, true)
                    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_WELDING", 0, true)
                    
                    local camjob = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                    local camcoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, -1.2, 0.6)
                    SetCamCoord(camjob, camcoords.x, camcoords.y, camcoords.z)
                    PointCamAtPedBone(camjob, ped, 24818, 0.0, 0.0, 0.0, true)
                    SetCamActive(camjob, true)
                    RenderScriptCams(true, true, 500, true, true)

                    TriggerEvent('Mx::StartMinigameElectricCircuit', '50%', '50%', '1.0', '30vmin', '1.ogg', function()
                        ClearPedTasks(ped)
                        RenderScriptCams(false, true, 500, true, true)
                        DestroyCam(camjob, false)
                        FreezeEntityPosition(ped, false)
                        
                        lib.notify({title = 'Renes', description = 'Dobře ty! Pokračuj v práci...', type = 'success', duration = 7500})
                        TriggerServerEvent('dnj_eletrician:ar', token)
                        completedlocs[locindex] = true
                        RemoveBlip(currentblip)
                        currentblip = nil
                        currentjobcoords = nil
                        
                        lib.notify({title = 'Renes', description = 'Vrať se do auta a čekej na další zakázku...', type = 'info', duration = 10000})
                    end)
                end
            }
        }
    })
end

function cjob()
    if currentblip then RemoveBlip(currentblip) end
    currentjobcoords = nil
    carreturning = true
    
    local returncoords = dnj.carspawn.coords
    currentblip = AddBlipForCoord(returncoords.x, returncoords.y, returncoords.z)
    SetBlipSprite(currentblip, 164)
    SetBlipColour(currentblip, 4)
    SetBlipRoute(currentblip, true)

    lib.notify({title = 'Renes', description = 'Vrať se tam kde jsi začal.', type = 'info', duration = 10000})

    Citizen.CreateThread(function()
        local textuishown = false
        while carreturning and DoesEntityExist(currentveh) do
            local sleep = 1000
            local pcoords = GetEntityCoords(cache.ped)
            local dist = #(pcoords - vector3(returncoords.x, returncoords.y, returncoords.z))

            if dist < 10.0 then
                sleep = 0
                if IsPedInVehicle(cache.ped, currentveh, false) then
                    if not textuishown then
                        lib.showTextUI('[E] Vrátit vozidlo')
                        textuishown = true
                    end
                    if IsControlJustPressed(0, 38) then
                        DeleteEntity(currentveh)
                        currentveh = nil
                        hascar = false
                        RemoveBlip(currentblip)
                        lib.hideTextUI()
                        lib.notify({title = 'Renes', description = 'Jdi se převléknout do civilu', type = 'info', duration = 10000})
                    end
                end
            else
                if textuishown then
                    lib.hideTextUI()
                    textuishown = false
                end
            end
            Citizen.Wait(sleep)
        end
    end)
end