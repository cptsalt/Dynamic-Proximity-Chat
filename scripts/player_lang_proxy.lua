-- FezzedOne: This script is needed to correctly handle language items on secondary players. --
function init()
    message.setHandler("hasLangKey", function(_, isLocal, langKey)
        if isLocal then return player.getItemWithParameter("langKey", langKey) end
    end)
    message.setHandler("langKeyCount", function(_, isLocal, langKeyItem)
        if isLocal then return player.hasCountOfItem(langKeyItem, true) end
    end)
    message.setHandler("getCommCodes", function(_, isLocal)
        if isLocal then return player.getProperty("DynProxChat::commCodes") or { ["0"] = false } end
    end)
    message.setHandler("setCommCodes", function(_, isLocal, newCommCodes)
        if isLocal then return player.setProperty("DynProxChat::commCodes", newCommCodes or { ["0"] = false }) end
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
            if newDefault == nil then newDefault = "0" end
            return player.setProperty("DynProxChat::defaultCommCode", newDefault)
        end
    end)
end
