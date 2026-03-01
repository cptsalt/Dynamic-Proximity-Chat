-- FezzedOne: This script is needed to correctly handle language items on secondary players. Now also handles name tags on xStarbound. --
local function getNames()
    local currentName = status.statusProperty("currentName")
    currentName = type(currentName) == "string" and currentName
    local defaultName = status.statusProperty("defaultName")
    defaultName = type(defaultName) == "string" and defaultName
    return currentName, defaultName
end

function init()
    message.setHandler("hasLangKey", function(_, isLocal, langKey)
        if isLocal then
            return player.getItemWithParameter("langKey", langKey)
        end
    end)
    message.setHandler("langKeyCount", function(_, isLocal, langKeyItem)
        if isLocal then
            return player.hasCountOfItem(langKeyItem, true)
        end
    end)
    message.setHandler("getCommCodes", function(_, isLocal)
        if isLocal then
            return player.getProperty("DynProxChat::commCodes") or {
                ["0"] = "Default"
            }
        end
    end)
    message.setHandler("setCommCodes", function(_, isLocal, data)
        if data.fromServer then
            player.setProperty("DynProxChat::commCodes", data.newCommCodes or {
                ["0"] = "Default"
            })
            chat.addMessage("Comm code " .. data.option .. " removed. " .. data.slotsOpen .. " comm presets remaining.")
        else
            return player.setProperty("DynProxChat::commCodes", data or {
                ["0"] = "Default"
            })
        end

    end)
    message.setHandler("dpcServerMessage", function(_, _, status)
        if status then
            chat.addMessage(status)
        end
    end)
    message.setHandler("dpcLearnLangReturn", function(_, _, data)
        if data then
            local langKey = data.langKey
            local langName = data.langName
            local langLevel = data.langLevel
            local message = data.message

            local learnedLangs = player.getProperty("DPC::learnedLangs") or {}
            learnedLangs[langKey] = {
                name = langName,
                prof = langLevel
            }
            player.setProperty("DPC::learnedLangs", learnedLangs)

            chat.addMessage(message)
        end
    end)
    message.setHandler("getDefaultCommCode", function(_, isLocal, newDefault)
        if isLocal then
            local default = player.getProperty("DynProxChat::defaultCommCode")
            if default ~= nil then
                return default
            else
                return "0"
            end
        end
    end)
    message.setHandler("setDefaultCommCode", function(_, isLocal, newDefault)
        if isLocal then
            if newDefault == nil then
                newDefault = "0"
            end
            return player.setProperty("DynProxChat::defaultCommCode", newDefault)
        end
    end)
    message.setHandler("showRecog", function(_, _, aliasInfo)
        local recoged = player.getProperty("DPC::recognizedPlayers") or {}
        local playerUid = aliasInfo.UUID or nil
        if not playerUid then
            return false
        end
        local playerRecog = recoged[playerUid] or nil
        if not playerRecog or (playerRecog and playerRecog.aliasPrio <= aliasInfo.priority) then
            -- check priority, apply if new is higher
            playerRecog = {
                ["savedName"] = aliasInfo.alias,
                ["manName"] = nil,
                ["aliasPrio"] = aliasInfo.priority
            }
            recoged[playerUid] = playerRecog
            player.setProperty("DPC::recognizedPlayers", recoged)
            return true
        end
    end)
    message.setHandler("receiverName", function(_, isLocal)
        if isLocal then
            local _, defaultName = getNames()
            return defaultName
        end
    end)

    message.setHandler("dpcStagehandExists", function(_, isLocal)
        player.setProperty("DPC::serverValid", true)
    end)

    message.setHandler("dpcGetRecogs", function(_, isLocal)
        if isLocal then
            return player.getProperty("DPC::recognizedPlayers") or {}
        end
    end)

    message.setHandler("dpcSetRecogs", function(_, isLocal, newRecogs)
        if isLocal then
            player.setProperty("DPC::recognizedPlayers", newRecogs)
        end
    end)

    local currentName, defaultName = getNames()
    if not defaultName then
        status.setStatusProperty("defaultName", player.name())
    end

    if player.setName then
        local defaultName = status.statusProperty("defaultName")
        if type(defaultName) == "string" then
            player.setName(defaultName)
        end
        status.setStatusProperty("defaultName", nil)
    end
end

function uninit()
end
