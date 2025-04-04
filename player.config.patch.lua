function patch(playerConfig)
    if xsb then playerConfig.genericScriptContexts.sccDynamicChat = "/scripts/player_lang_proxy.lua" end
    return playerConfig
end
