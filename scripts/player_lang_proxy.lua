-- FezzedOne: This script is needed to correctly handle language items on secondary players. --
function init()
    message.setHandler("hasLangKey", function(_, isLocal, langKey)
        if isLocal then return player.getItemWithParameter("langKey", langKey) end
    end)
    message.setHandler("langKeyCount", function(_, isLocal, langKeyItem)
        if isLocal then return player.hasCountOfItem(langKeyItem, true) end
    end)
end
