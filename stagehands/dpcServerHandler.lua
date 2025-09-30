local function killStagehand()
    stagehand.die()
end

local function logNewMessage(purpose, data)
    if data == nil then
        killStagehand()
    end
    local content = data.content or "N/A"
    local nickname = data.nickname or "N/A"
    local playerUUID = data.playerUid or "N/A"
    sb.logInfo("%s (%s): %s", nickname, playerUUID, content)
end

local function logCommand(purpose, data)
    if data == nil then
        killStagehand()
    end
    sb.logInfo("Player %s running command %s with data %s", data.uuid, purpose, data)
end

local playerLangs, playerCommChannels, playerSecrets, savedLangs, langSubWords = nil, nil, nil, nil, nil
local randSource = nil
--i could make these configurations, but i don't want to
local langLimit = 30          --points value, multiply by 10 for percentage
local channelLimit = 5
local actionRad = 100         -- FezzedOne: Un-hardcoded the action radius.
local loocRad = 2 * actionRad -- actionRad * 2 -- FezzedOne: Un-hardcoded the local OOC radius.
local noiseRad = 50           -- FezzedOne: Un-hardcoded the talking radius.

--it may be worthwhile to set up some kind of pruning system in the future to remove values from inactive characters (2 weeks +)
--these 2 functions should be the only ones that set config files for language and comm channels
--IMPORTANT: confirm that ONLY the requesting player's values change. Do this by copying the table and nullifying the values inside of the uuid
--on return, only return added and removed languages depdending on the command
local function addLang(data)
    local playerUUID = data.uuid
    local playerSecret = data.playerSecret
    local newLang = data.newLang
    playerSecrets = root.getConfiguration("DPC::playerSecrets") or {}
    savedLangs = root.getConfiguration("DPC::savedLangs") or {}
    playerLangs = root.getConfiguration("DPC::playerLangs") or {}

    local serverSavedSecret = playerSecrets[playerUUID] or false
    --update config file if the secret checks out (or is empty)
    if serverSavedSecret == false then
        --establish a new secret and update server
        serverSavedSecret = playerSecret
        playerSecrets[playerUUID] = playerSecret
        root.setConfiguration("DPC::playerSecrets", playerSecrets)
    end


    if playerSecret == serverSavedSecret then
        local serverLangList = playerLangs[playerUUID] or {}
        local pointsLeft = serverLangList["[pointsLeft]"] or langLimit
        if pointsLeft < 1 then
            world.sendEntityMessage(data.player, "dpcServerMessage",
                "Out of points, use /resetLangs to reset your languages.")
            return
        end
        local langProf = serverLangList[newLang.code] or 0
        local newPoints = 0

        newLang.prof = math.max(0, math.min(pointsLeft, newLang.prof))

        if langProf + newLang.prof > 10 then
            newLang.prof = 10 - langProf
        end
        -- newPoints = math.min(pointsLeft, langProf + newLang.prof)
        newPoints = langProf + newLang.prof

        --check here in case people have more than x languages
        pointsLeft = pointsLeft - newLang.prof
        serverLangList[newLang.code] = newPoints
        serverLangList["[pointsLeft]"] = pointsLeft
        playerLangs[playerUUID] = serverLangList
        root.setConfiguration("DPC::playerLangs", playerLangs)

        local learnedName = newLang.code
        if not savedLangs[newLang.code] then
            savedLangs[newLang.code] = {
                name = newLang.name or newLang.code,
                color = newLang.color or nil,
                preset = newLang.preset or nil,
                creator = playerUUID
            }
            root.setConfiguration("DPC::savedLangs", savedLangs)
            learnedName = newLang.name or newLang.code
        else
            learnedName = savedLangs[newLang.code]["name"] or newLang.code
        end
        local returnMsg = "Languages updated, " ..
            newLang.prof ..
            " points added to " ..
            learnedName .. ". [" .. newLang.code .. "] Total: " .. newPoints .. ". Points remaining: " ..
            pointsLeft
        local returnInfo = {
            langKey = newLang.code,
            langName = learnedName,
            langLevel = newPoints,
            message = returnMsg
        }
        world.sendEntityMessage(data.player, "dpcLearnLangReturn", returnInfo)
    end

    --get lang info, add code and prof level to server config
    --if successful add code, name and color to a different config without player association
end

local function editLangPhrase(data)
    --add/remove to langSubWords
    local playerUUID = data.uuid
    local playerSecret = data.playerSecret
    local dCode = data.dCode:upper() or nil
    local phrase = data.phrase
    local replacement = data.replacement or nil
    playerSecrets = root.getConfiguration("DPC::playerSecrets") or {}
    savedLangs = root.getConfiguration("DPC::savedLangs") or {}
    local serverSavedSecret = playerSecrets[playerUUID] or false

    if dCode == nil or not savedLangs[dCode] or savedLangs[dCode].creator ~= playerUUID then
        world.sendEntityMessage(data.player, "dpcServerMessage", "Bad arguments, word replacement aborted.")
        return
    end
    if serverSavedSecret ~= playerSecret or savedLangs[dCode].creator ~= playerUUID then
        world.sendEntityMessage(data.player, "dpcServerMessage", "Bad authentication, word replacement aborted.")
        return
    end


    if not phrase then
        --show all words and replacements
        langSubWords = root.getConfiguration("DPC::langSubWords") or {}
        local rtStr = "^cyan;"
        for k, v in pairs(langSubWords[dCode]) do
            rtStr = rtStr .. " {" .. k .. " -> " .. v .. "}"
        end
        rtStr = rtStr .. "^reset;."
        world.sendEntityMessage(data.player, "dpcServerMessage", rtStr)
        return
    end

    if savedLangs[dCode].creator == playerUUID and serverSavedSecret == playerSecret then
        langSubWords = root.getConfiguration("DPC::langSubWords") or {}
        local wordbank = langSubWords[dCode] or {}

        if phrase and (not replacement or replacement == "remove") then
            wordbank[phrase] = nil
            langSubWords[dCode] = wordbank
            if #wordbank == {} then
                langSubWords[dCode] = nil
            end
            world.sendEntityMessage(data.player, "dpcServerMessage", "Removed phrase: " .. phrase .. ".")
        else
            wordbank[phrase] = replacement
            langSubWords[dCode] = wordbank
            world.sendEntityMessage(data.player, "dpcServerMessage",
                "Added phrase/replacement: " .. phrase .. "/" .. replacement .. ".")
        end
        root.setConfiguration("DPC::langSubWords", langSubWords)
        return
    end
end

local function resetLangs(data)
    local playerUUID = data.uuid
    local playerSecret = data.playerSecret
    playerSecrets = root.getConfiguration("DPC::playerSecrets") or {}
    playerLangs = root.getConfiguration("DPC::playerLangs") or {}
    savedLangs = root.getConfiguration("DPC::savedLangs") or {}

    local serverSavedSecret = playerSecrets[playerUUID] or false

    if (playerSecret and serverSavedSecret) and playerSecret == serverSavedSecret then
        --reset
        local ownerLangs = playerLangs[playerUUID] or {}
        local langCondsMet = true


        playerLangs[playerUUID] = nil
        root.setConfiguration("DPC::playerLangs", playerLangs)

        local newSavedLangs = {}
        for k, v in pairs(savedLangs) do
            if v["creator"] ~= playerUUID then
                newSavedLangs[k] = v
            else
                for uuid, langLib in pairs(playerLangs) do
                    if uuid ~= playerUUID and langLib[k] then
                        newSavedLangs[k] = v
                        break
                    end
                end
            end
            if newSavedLangs == {} then
                langSubWords = root.getConfiguration("DPC::langSubWords") or {}
                langSubWords[k] = nil
                root.setConfiguration("DPC::langSubWords", langSubWords)
            end
        end

        root.setConfiguration("DPC::savedLangs", newSavedLangs)

        world.sendEntityMessage(data.player, "dpcServerMessage",
            "Languages have been reset. Use /learnlang to assign languages.")
    else
        --tell user they are stupid
        world.sendEntityMessage(data.player, "dpcServerMessage", "Languages failed to reset.")
    end
end

local function defaultLang(data)
    local playerUUID = data.uuid
    local playerSecret = data.playerSecret
    local dCode = data.dCode or "!!"
    playerLangs = root.getConfiguration("DPC::playerLangs") or {}
    playerSecrets = root.getConfiguration("DPC::playerSecrets") or {}
    savedLangs = root.getConfiguration("DPC::savedLangs") or {}
    local serverSavedSecret = playerSecrets[playerUUID] or false

    if (playerSecret and serverSavedSecret) and playerSecret == serverSavedSecret and dCode then
        local serverPlayerLangs = playerLangs[playerUUID] or {}
        local langName = savedLangs[dCode] and savedLangs[dCode]['name'] or nil

        if dCode == "!!" then
            langName = "Universal Default"
            -- dCode = nil
        end

        if langName then
            serverPlayerLangs["[DEFAULT]"] = dCode
            playerLangs[playerUUID] = serverPlayerLangs
            root.setConfiguration("DPC::playerLangs", playerLangs)

            world.sendEntityMessage(data.player, "dpcServerMessage",
                "Default language set to \"" .. langName .. "\"")
        end
    else
        --tell user they are stupid
        world.sendEntityMessage(data.player, "dpcServerMessage", "Default assignment failed.")
    end
end

local function langList(data)
    savedLangs = root.getConfiguration("DPC::savedLangs") or nil
    local retStr = ""

    if not savedLangs then
        retStr = "No languages have been created yet."
        return retStr
    else
        retStr = "Languages registered on the server: "
        for code, info in pairs(savedLangs) do
            retStr = retStr .. "^" .. info.color .. ";[" .. code .. "] " .. info.name .. "^reset;, "
        end
        retStr = retStr:sub(1, #retStr - 2)
    end

    world.sendEntityMessage(data.player, "dpcServerMessage", retStr)
end

local function editLang(data)
    local playerUUID = data.uuid
    local playerSecret = data.playerSecret
    local dCode = data.dCode:upper() or nil
    local subject = data.subject:lower() or nil
    local newVal = data.newVal or nil
    -- playerLangs = root.getConfiguration("DPC::playerLangs") or {} --probably won't need this
    playerSecrets = root.getConfiguration("DPC::playerSecrets") or {}
    savedLangs = root.getConfiguration("DPC::savedLangs") or {}
    local serverSavedSecret = playerSecrets[playerUUID] or false

    if serverSavedSecret ~= playerSecret or savedLangs[dCode].creator ~= playerUUID then
        world.sendEntityMessage(data.player, "dpcServerMessage", "Bad authentication, language edit aborted.")
        return
    end

    if not savedLangs[dCode] or savedLangs[dCode].creator ~= playerUUID or not dCode or (subject ~= "color" and subject ~= "name" and subject ~= "preset") or not newVal then
        world.sendEntityMessage(data.player, "dpcServerMessage", "Bad arguments, language edit aborted.")
        return
    end

    if savedLangs[dCode].creator == playerUUID and serverSavedSecret == playerSecret then
        local langFocus = savedLangs[dCode]
        langFocus[subject] = newVal
        savedLangs[dCode] = langFocus
        root.setConfiguration("DPC::savedLangs", savedLangs)
        world.sendEntityMessage(data.player, "dpcServerMessage", "[" .. dCode .. "] " .. subject ..
            " changed to: " .. newVal)
        return
    end
end

local function setFreq(data)
    local playerUUID = data.uuid
    local playerSecret = data.playerSecret
    local activeFreq = data.activeFreq
    playerSecrets = root.getConfiguration("DPC::playerSecrets") or {}
    playerCommChannels = root.getConfiguration("DPC::playerCommChannels") or {}
    local serverSavedSecret = playerSecrets[playerUUID] or false
    --update config file if the secret checks out (or is empty)
    if serverSavedSecret == false then
        --establish a new secret and update server
        serverSavedSecret = playerSecret
        playerSecrets[playerUUID] = playerSecret
        root.setConfiguration("DPC::playerSecrets", playerSecrets)
    end

    if serverSavedSecret == playerSecret and activeFreq["freq"] then
        --update server langs for the player

        playerCommChannels[playerUUID] = activeFreq

        local freqAlias = (activeFreq["alias"] and "(" .. activeFreq["alias"] .. ")") or "(no alias)"
        root.setConfiguration("DPC::playerCommChannels", playerCommChannels)
        world.sendEntityMessage(data.player, "dpcServerMessage",
            "Your radio is now tuned to " .. activeFreq["freq"] .. " " .. freqAlias .. ".")
        return true
    else
        world.sendEntityMessage(data.player, "dpcServerMessage",
            "Authentication failed.")
        return false
    end
end

local function toggleRadio(data)
    local playerUUID = data.uuid
    local playerSecret = data.playerSecret
    playerSecrets = root.getConfiguration("DPC::playerSecrets") or {}
    playerCommChannels = root.getConfiguration("DPC::playerCommChannels") or {}
    local serverSavedSecret = playerSecrets[playerUUID] or false
    --update config file if the secret checks out (or is empty)
    if serverSavedSecret == false then
        --establish a new secret and update server
        serverSavedSecret = playerSecret
        playerSecrets[playerUUID] = playerSecret
        root.setConfiguration("DPC::playerSecrets", playerSecrets)
    end

    if serverSavedSecret == playerSecret then
        local activeFreq = playerCommChannels[playerUUID] or {}
        --update server langs for the player
        local radioState = data.radioState
        activeFreq["enabled"] = not radioState
        playerCommChannels[playerUUID] = activeFreq
        root.setConfiguration("DPC::playerCommChannels", playerCommChannels)

        local freqAlias = (activeFreq["alias"] and "(" .. activeFreq["alias"] .. ")") or "(no alias)"

        local tuningMsg = "."
        if activeFreq["enabled"] then
            local useFreq = activeFreq and activeFreq["freq"] or "0"
            tuningMsg = " and tuned to " .. useFreq .. " " .. freqAlias .. "."
        end

        local stateStr = activeFreq["enabled"] and "on" or "off"

        world.sendEntityMessage(data.player, "dpcServerMessage",
            "Your radio is now " .. stateStr .. tuningMsg)
        return true
    else
        world.sendEntityMessage(data.player, "dpcServerMessage",
            "Authentication failed.")
        return false
    end
end

local function trim(s)
    local l = 1
    while string.sub(s, l, l) == " " do
        l = l + 1
    end
    local r = #s
    while string.sub(s, r, r) == " " do
        r = r - 1
    end
    return string.sub(s, l, r)
end

local function rollDice(die) -- From https://github.com/brianherbert/dice/, with modifications.
    if type(die) == "string" then
        local rolls, sides, modOperation, modifier
        local numberDie = tonumber(die)
        if numberDie then
            sides = math.floor(numberDie)
            if sides < 1 then return nil end
            rolls = 1
            modOperation = "+"
            modifier = 0
        else
            local i, j = string.find(die, "d")
            if not i then
                die = "1d" .. die
                i, j = string.find(die, "d")
            end
            if i == 1 then
                rolls = 1
            else
                rolls = tonumber(string.sub(die, 0, (j - 1)))
            end

            if rolls == nil then return nil end

            local afterD = string.sub(die, (j + 1), string.len(die))
            local i_1, j_1 = string.find(afterD, "%d+")
            local i_2, _ = string.find(afterD, "^[%+%-%*/]%d+")
            local afterSides
            if j_1 and not i_2 then
                sides = tonumber(string.sub(afterD, i_1, j_1))
                j = j_1
                afterSides = string.sub(afterD, (j + 1), string.len(afterD))
            else
                sides = 6
                afterSides = afterD
            end
            if sides < 1 then return nil end

            if string.len(afterSides) == 0 then
                modOperation = "+"
                modifier = 0
            else
                modOperation = string.sub(afterSides, 1, 1)
                modifier = tonumber(string.sub(afterSides, 2, string.len(afterSides)))
            end

            if not modifier then return nil end
        end

        randSource:init()

        local roll, total = 0, 0
        while roll < rolls do
            total = total + randSource:randInt(1, sides)
            roll = roll + 1
        end

        -- Finished with our rolls, now add/subtract our modifier
        if modOperation == "+" then
            total = math.floor(total + modifier)
        elseif modOperation == "-" then
            total = math.floor(total - modifier)
        elseif modOperation == "*" then
            total = math.floor(total * modifier)
        elseif modOperation == "/" then
            total = math.floor(total / modifier)
        else
            return nil
        end

        return total
    else
        return nil
    end
end

local function wordBytes(word)
    word = tostring(word)
    local returnNum = 0
    if not type(word) == "string" then return 0 end
    for char in word:gmatch(".") do
        char = char:lower()
        returnNum = returnNum * 16
        if not math.tointeger(returnNum) then returnNum = math.tointeger(2 ^ 48) end
        returnNum = returnNum + math.abs(string.byte(char) - 100)
    end
    return returnNum
end

local function genRandAlph(byteLC)
    --basically, make alphabet then replace each letter with a sound from the table, then use that for new letters
    local alphabet = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's',
        't', 'u', 'v', 'w', 'x', 'y', 'z' }

    local consonants = { 'b', 'c', 'd', 'f', 'g', 'h', 'k', 'l', 'm', 'n', 'p', 'r', 's', 't', 'v', 'w' }
    local consRare = { 'j', 'q', 'x', 'z' }
    local vowels = { 'a', 'e', 'i', 'o', 'u' }
    -- local vowelsRare = 'y'
    local newAlphabet = {}

    --doubled single consonants
    local consSpecial = { "ck", "qu", "ph", "gh", "dg", "le", "mb", "kn", "wr", "ce", "se", "sc", "ve", "wh",
        "zh", "ze", "tch", "sh", "ch", "th", "ng",
        "l'a", "l'e", "d'a", "d'e", "t'a", "t'e" }
    local vowelSpecial = { "ea", "ai", "ay", "ae", "ie", "ey", "igh", "oa", "ow",
        "ew", "ue", "oo", "ou", "oi", "oy", "ar", "or", "aw", "au", "ore", "oar", "oor", "er", "ir", "ur", "ear",
        "air", "are", "er", "re", "i'a", "e'a" }

    local specialCount = 0

    for _, letter in ipairs(alphabet) do
        randSource:init(byteLC)
        randSource:addEntropy(tonumber(wordBytes(letter)))
        randSource:addEntropy(tonumber(wordBytes("alphabet")))
        local useSpecial = specialCount <= 4 and randSource:randInt(1, 100) <= 15

        randSource:init(byteLC)
        randSource:addEntropy(tonumber(wordBytes(letter)))
        randSource:addEntropy(tonumber(wordBytes("commonality")))
        local commonCheck = randSource:randInt(1, 100)

        if letter:match("[aeiouy]") then
            newAlphabet[letter] = (useSpecial and vowelSpecial[randSource:randInt(1, #vowelSpecial)]) or
                (commonCheck <= 2 and 'y') or
                vowels[randSource:randInt(1, #vowels)]
        else
            newAlphabet[letter] = (useSpecial and consSpecial[randSource:randInt(1, #consSpecial)]) or
                (commonCheck <= 10 and consRare[randSource:randInt(1, #consRare)]) or
                consonants[randSource:randInt(1, #consonants)]
        end
        if useSpecial then specialCount = specialCount + 1 end
    end
    -- sb.logInfo("new alphabet is %s", newAlphabet)
    return newAlphabet
end


local function genPresetAlph(byteLC, consonants, vowels, special)
    local alphabet = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's',
        't', 'u', 'v', 'w', 'x', 'y', 'z' }
    local newAlphabet = {}
    local specialCount = 0

    for _, letter in ipairs(alphabet) do
        randSource:init(byteLC)
        randSource:addEntropy(tonumber(wordBytes(letter)))
        randSource:addEntropy(tonumber(wordBytes("alphabet")))
        local useSpecial = specialCount <= 4 and randSource:randInt(1, 100) <= 15

        randSource:init(byteLC)
        randSource:addEntropy(tonumber(wordBytes(letter)))
        randSource:addEntropy(tonumber(wordBytes("commonality")))
        local commonCheck = randSource:randInt(1, 100)

        if letter:match("[aeiouy]") then
            newAlphabet[letter] = (useSpecial and special[randSource:randInt(1, #special)]) or
                vowels[randSource:randInt(1, #vowels)]
        else
            newAlphabet[letter] = (useSpecial and special[randSource:randInt(1, #special)]) or
                consonants[randSource:randInt(1, #consonants)]
        end
        if useSpecial then specialCount = specialCount + 1 end
    end
    return newAlphabet
end
-- local handleMessage = function(authorEntityId, authorPos, receiverEntityId, receiverUUID, recPos, msgTime, messageDistance, message)
-- data.playerId, authorPos, msgTime, data


--originally i made this a function, but tracking the values is difficult and it's easier to manually set them since there are only 9
local soundTable = {      --with 50 as default | 50% cutoff range
    [-4] = noiseRad / 20, -- 2.5 | 1.25
    [-3] = noiseRad / 10, -- 5 | 2.5
    [-2] = noiseRad / 5,  -- 10 | 5
    [-1] = noiseRad / 2,  --25 | 12.5
    [0] = noiseRad,       -- 50 | 25
    [1] = noiseRad * 1.5, --75 | 37.5
    [2] = noiseRad * 2,   --100 | 50
    [3] = noiseRad * 3,   --150 | 75
    [4] = noiseRad * 4,   --200 | 100
}

--i dont like this but it'll have to do
local volTable = {
    [noiseRad / 20] = -4,
    [noiseRad / 10] = -3,
    [noiseRad / 5] = -2,
    [noiseRad / 2] = -1,
    [noiseRad] = 0, --based on the default range of talking being 50, this should be good
    [noiseRad * 1.5] = 1,
    [noiseRad * 2] = 2,
    [noiseRad * 3] = 3,
    [noiseRad * 4] = 4,
}

local handleMessage = function(authorEntityId, authorUUID, authorPos, msgTime, message)
    local authorLangs = (playerLangs and playerLangs[authorUUID]) or {}
    local activeFreq = (playerCommChannels and playerCommChannels[authorUUID]) or {}
    local replacementDict = langSubWords or {}
    savedLangs = root.getConfiguration("DPC::savedLangs") or {}
    message.text = message.content
    message.content = nil
    local uncapRad = false
    -- local wasGlobal = false
    -- message.global = wasGlobal
    -- local messageDistance = math.huge
    -- local messageDistance = world.magnitude(recPos, authorPos)
    -- messageDistance = world.magnitude(recPos, authorPos)
    -- messageDistance = 30


    -- local actionRad = 200         -- FezzedOne: Un-hardcoded the action radius.
    -- local loocRad = 2 * actionRad -- actionRad * 2 -- FezzedOne: Un-hardcoded the local OOC radius.
    -- local noiseRad = 30           -- FezzedOne: Un-hardcoded the talking radius.
    --*re-hardcodes my radius values*

    local tVol, sVol = message.volume or 0, 0
    local tVolRad = soundTable[tVol]
    local sVolRad = noiseRad
    --iterate through message and get components here
    local curMode = "action"
    local prevMode = "action"
    local prevDiffMode = "action"
    local maxRad = 0     -- Remove the maximum radius restriction from global messages.
    local rawText = message.text
    local textTable = {} --this will eventually be smashed together to make filterText
    local validSum = 0   --number of valid entries in the table
    local cInd = 1       --lua starts at 1 >:(
    local charBuffer = ""
    local noScramble = false
    local languageCode = message.defaultLang or "!!" --the !! shouldn't need to be set, but i'll leave it anyway
    local radioMode = false                          --radio flag
    local commCode = message.defaultFreq or "0"      -- FezzedOne: Comm code.
    local langAlphabets = {}
    local quoteStr = ""
    local slashCount = 0
    local asterCount = 0
    local tickCount = 0

    local modeRadTypes = {
        action = function() return actionRad end,
        quote = function() return tVolRad end,
        sound = function() return sVolRad end,
        pOOC = function() return loocRad end,
        lOOC = function() return loocRad end,
        gOOC = function() return -1 end,
    }

    local function rawSub(sInd, eInd) return rawText:sub(sInd, eInd) end

    --use this to construct the components
    --any component indications (like :+) that remain should stay, use them for coloring if they aren't picked up here and reset after each component
    local function formatInsert(
        str,
        radius,
        type,
        langKey,
        isRadio,
        commCode,
        noScramble
    )
        if langKey == nil then langKey = "!!" end

        table.insert(textTable, {
            text = str,
            radius = radius,
            type = type,
            langKey = langKey,
            isRadio = isRadio,
            commCode = commCode,
            noScramble = noScramble,
        })
    end

    local function parseDefault(letter)
        charBuffer = charBuffer .. letter
        cInd = cInd + 1
    end

    local function newMode(nextMode) --if radius is -1, the insert is instance wide
        if #charBuffer < 1 or charBuffer == '"' or charBuffer == ">" or charBuffer == "<" or (curMode == "quote" and #charBuffer:gsub("%s", "") < 1) then
            prevMode = curMode
            curMode = nextMode
            -- if curMode ~= nextMode then prevDiffMode = curMode end
            return
        end

        local useRad
        useRad = modeRadTypes[curMode]()


        maxRad = math.max(maxRad, useRad)


        --insert replacement words for qutoes in languages here
        if curMode == "quote" and replacementDict[languageCode:upper()] then
            local wordBank = replacementDict[languageCode]
            local b4Buffer = ""
            --check a dict of replacement words for the lang tag
            --check the key (phrase to replace) to see if it exists in the string (case insensitive)
            --run through the string, when a valid word is found (and isn't surrounded by <>), split the string into before the word and after
            --then, insert the replacement in the before string, then add the after string, then repeat
            --if it does, replace it with the value (dont match cases)

            for phrase, replacement in pairs(wordBank) do
                local newBuffer = charBuffer
                local beforeStr = ""
                local afterStr = ""
                local lastIndex = 1
                local findStart, findEnd = charBuffer:lower():find(phrase:lower(), lastIndex)
                while findStart ~= nil do
                    beforeStr = newBuffer:sub(1, findStart - 1)
                    afterStr = (findEnd + 1 <= #newBuffer and newBuffer:sub(findEnd + 1)) or ""

                    if newBuffer:sub(findStart - 1, findStart) ~= "<" and newBuffer:sub(findEnd + 1 or #newBuffer, findEnd + 2) ~= ">" then
                        b4Buffer = b4Buffer .. beforeStr .. "<" .. replacement .. ">"
                        newBuffer = afterStr
                    end
                    lastIndex = findEnd or #newBuffer
                    findStart, findEnd = newBuffer:find(phrase:lower())
                end
                b4Buffer = b4Buffer .. newBuffer
                charBuffer = b4Buffer
                b4Buffer = ""
            end
        end



        if useRad == -1 and maxRad ~= -1 then maxRad = -1 end
        formatInsert(
            charBuffer,
            useRad,
            curMode,
            languageCode,
            radioMode,
            commCode,
            noScramble
        )
        charBuffer = ""
        prevMode = curMode
        -- if curMode ~= nextMode then prevDiffMode = curMode end
        curMode = nextMode
    end

    local defaultKey = message.defaultLang

    local mode_table = {
        ['"'] = function()
            if curMode == "quote" then
                parseDefault("")
                newMode("action")
                noScramble = false
            elseif curMode == "action" then
                newMode("quote")
                noScramble = false
                parseDefault("")
            else
                noScramble = false
                parseDefault('"')
            end
        end,
        ["<"] = function() --i could combine these two, but i don't want to
            local nextChar = rawSub(cInd + 1, cInd + 1)
            if nextChar == "<" then
                local oocBump = 0
                local oocType
                local oocRad
                --local ooc
                local _, oocEnd = rawText:find(">>+", cInd)
                if not oocEnd then
                    local _, oocEnd2 = rawText:find(">", cInd)
                    oocEnd = oocEnd2
                end
                oocEnd = oocEnd or 0
                oocBump = 1
                oocType = "pOOC"
                oocRad = actionRad * 2

                if oocEnd ~= nil then
                    newMode(oocType)
                    charBuffer = charBuffer .. rawSub(cInd, oocEnd)
                    newMode(prevMode)
                else
                    charBuffer = charBuffer .. rawSub(cInd, cInd + oocBump)
                    cInd = cInd + oocBump
                    oocEnd = cInd
                end

                cInd = oocEnd + 1
            else
                if curMode == "quote" then
                    newMode(curMode)
                    noScramble = true
                elseif curMode ~= "sound" and curMode ~= "quote" then --added quotes here so people can do the cool combine vocoder thing <::Pick up that can.::>
                    newMode("sound")
                end
            end
            parseDefault("")
        end,
        [">"] = function()
            if curMode == "quote" then
                parseDefault("")
                newMode(curMode)
                noScramble = false
                -- parseDefault(">")
                -- parseDefault(" ")
            elseif curMode == "sound" then
                parseDefault("")
                -- FezzedOne: Fixed parser bug where a quote was immediately assumed to follow the end of a sound, screwing up state.
                newMode("action")
            end
        end,
        [":"] = function()
            local nextChar = rawSub(cInd + 1, cInd + 1)
            if nextChar == "+" or nextChar == "-" or nextChar == "=" then
                newMode(curMode) --this happens to change volume, but mode isn't actually changing

                local maxAmp = 4 --maximum chars after the colon

                local lStart, lEnd = rawText:find(":%++", cInd)
                local qStart, qEnd = rawText:find(":%-+", cInd)
                local eStart, eEnd = rawText:find(":%=+", cInd)
                local nCStart, nCEnd

                if qStart == nil then qStart = #rawText end
                if qEnd == nil then qEnd = #rawText end
                if lStart == nil then lStart = #rawText end
                if lEnd == nil then lEnd = #rawText end
                if eStart == nil then eStart = #rawText end
                if eEnd == nil then eEnd = #rawText end

                if math.min(eStart, lStart, qStart) == eStart then
                    nCStart = eStart
                    nCEnd = eEnd
                elseif math.min(eStart, lStart, qStart) == lStart then
                    nCStart = lStart
                    nCEnd = lEnd
                elseif math.min(eStart, lStart, qStart) == qStart then
                    nCStart = qStart
                    nCEnd = qEnd
                end

                local doVolume = "none"
                --in these modes, ignore the volume controls
                if
                    curMode == "radio"
                    or curMode == "gOOC"
                    or curMode == "lOOC"
                    or curMode == "pOOC"
                then
                    cInd = nCEnd + 1
                elseif curMode == "action" then
                    local nextInd = rawText:find('["<]', cInd)

                    if nextChar == nil then --if they just put this at the end for some reason
                        cInd = nCEnd + 1
                    elseif nextInd ~= nil then
                        nextChar = rawSub(nextInd, nextInd)
                    end
                    if nextChar == '"' then
                        doVolume = "quote"
                    else
                        doVolume = "sound"
                    end
                else
                    doVolume = curMode
                end

                if doVolume ~= "none" then
                    local sum = 0
                    local nextStr = rawSub(nCStart + 1, nCEnd)

                    if doVolume == "quote" then
                        sum = tVol
                    else
                        sum = sVol
                    end

                    for i in nextStr:gmatch(".") do
                        if i == "+" then
                            sum = sum + 1
                        elseif i == "-" then
                            sum = sum - 1
                        elseif i == "=" then
                            if doVolume == "quote" then
                                sum = message.volume or 0
                                tVolRad = noiseRad
                            else
                                sum = 0
                                sVolRad = noiseRad
                            end
                        end
                    end
                    cInd = nCEnd

                    sum = math.min(math.max(sum, -4), 4)

                    if doVolume == "quote" then
                        tVol = sum
                        tVolRad = soundTable[sum]
                    else
                        sVol = sum
                        sVolRad = soundTable[sum]
                    end
                end
                cInd = nCEnd + 1
            else
                parseDefault(":")
            end
        end,
        ["*"] = function() --leave this for the visual alterations later on
            -- i have this commented out so people can keep asterisks in actions if they want
            -- if curMode == 'action' then
            --   cInd = cInd + 1
            -- else
            --   parseDefault("*")
            -- end
            parseDefault("*")

            if curMode ~= "action" then
                asterCount = asterCount + 1
            end
        end,
        ["/"] = function()
            parseDefault("/")
            slashCount = slashCount + 1
        end,
        ["`"] = function()
            parseDefault("`")
            tickCount = tickCount + 1
        end,
        ["\\"] = function() -- Allow escaping any specially parsed character with `\`.
            local nextChar = rawSub(cInd + 1, cInd + 1)

            if nextChar == "/" or nextChar == "`" then
                parseDefault("\\")
            else
                parseDefault(nextChar)
                cInd = cInd + 1
            end
        end,
        ["("] = function() --check for number of parentheses
            local nextChar = rawSub(cInd + 1, cInd + 1)
            if nextChar == "(" then
                local oocEnd = 0
                local oocBump = 0
                local oocType
                local oocRad
                --commenting this out. Use local mode if you want uncapped local ooc.
                -- if not root.getConfiguration("DynamicProxChat::proximityOoc") then
                --     uncapRad = true
                -- end
                if rawSub(cInd + 2, cInd + 2) == "(" then
                    --global ooc
                    _, oocEnd = rawText:find("%)%)%)+", cInd) --the + catches extra parentheses in case someone adds more than 3
                    oocType = "gOOC"
                    oocBump = 2
                    oocRad = -1
                else
                    --local ooc
                    _, oocEnd = rawText:find("%)%)+", cInd)
                    oocBump = 1
                    oocType = "lOOC"
                    oocRad = actionRad * 2
                end

                if oocEnd ~= nil then
                    newMode(oocType)
                    charBuffer = charBuffer .. rawSub(cInd, oocEnd)
                    newMode(prevMode)
                else
                    charBuffer = charBuffer .. rawSub(cInd, cInd + oocBump)
                    cInd = cInd + oocBump
                    oocEnd = cInd
                end

                cInd = oocEnd + 1
            else
                parseDefault("(")
            end
        end,
        ["{"] = function() --this should function as a global IC message, but finding the playercount is not possible (or i'm stupid) clientside
            --i'm not doing secure radio because you can edit this file and ignore the password requirement with it
            --if you want to do that, just do it over group chat or something
            --this is where a stagehand serverside would be useful. In the future it might be worth exploring that

            --maybe set up multiple radio ranges with multiple brackets? seems kind of pointless imo
            newMode(curMode)
            radioMode = activeFreq["enabled"] or (activeFreq["enabled"] == nil and true)
            uncapRad = true
            parseDefault("{")
        end,
        ["}"] = function()
            if rawSub(cInd + 1, cInd + 1) == '"' and curMode == "quote" then
                parseDefault("}")
                parseDefault('')
                -- parseDefault('"')
                newMode("action")
            elseif rawSub(cInd + 1, cInd + 1) == "}" then -- Check for an extra curly brace to ensure it's included in the radio chunk.
                parseDefault("}")
                parseDefault("}")
                newMode(curMode)
            else
                parseDefault("}")
                newMode(curMode)
            end

            radioMode = false
            -- cInd = cInd + 1
        end,
        ["|"] = function()
            local fStart = cInd
            local fEnd = rawText:find("|", cInd + 1)

            if fStart ~= nil and fEnd ~= nil then
                -- local timeNum = tostring(math.floor(os.time()))
                -- local mixNum = tonumber(timeNum .. math.abs(authorEntityId))
                -- randSource:init(mixNum)
                -- local numMax = rawSub(fStart, fEnd - 1):gsub("%D", "")
                -- local roll = randSource:randInt(1, tonumber(numMax) or 20)
                -- FezzedOne: Replaced dice roller with the more flexible one from FezzedTech.
                local rollNum = rawSub(fStart + 1, fEnd)
                local diceResults = rawSub(fStart + 1, fEnd):gsub("[ ]*", ""):gsub(
                    "(.-)[,|]",
                    function(die) return die .. " = ^rollColor;" .. tostring(rollDice(die) or "n/a") .. "^reset;, " end
                )


                parseDefault("|" .. diceResults:sub(1, -3) .. "|")
                cInd = fEnd + 1
                sb.logInfo("Authentic roll for message by %s (%s)", message.nickname, authorUUID)
            else
                parseDefault("|")
            end
        end,
        ["["] = function()
            -- FezzedOne: Added escape code handling.
            local fStart = cInd
            local fEnd = rawText:find("[^\\]%]", cInd + 1)
            if rawSub(cInd, cInd + 1) == "[[" then
                parseDefault("[[")
                cInd = cInd + 1
            elseif rawSub(cInd, cInd + 1) == "[]" then --this should never happen anymore
                newMode(curMode)
                languageCode = defaultKey
                cInd = cInd + 2
            elseif fStart ~= nil and fEnd ~= nil then
                local newCode = rawSub(fStart + 1, fEnd)
                if languageCode ~= newCode and curMode == "quote" then newMode(curMode) end
                languageCode = newCode:upper()
                if languageCode ~= "!!" and not langAlphabets[languageCode] and savedLangs[languageCode].preset == nil then
                    langAlphabets[languageCode] = genRandAlph(wordBytes(languageCode:upper()))
                end
                cInd = rawText:find("%S", fEnd + 2) or
                    #rawText --set index to the next non whitespace character after the code
            else
                parseDefault("[")
            end
        end,
        default = function(letter)
            charBuffer = charBuffer .. letter
            cInd = cInd + 1
        end,
    }

    local c

    --run this loop to generate textTable, then concatenate
    while cInd <= #rawText do
        c = rawSub(cInd, cInd)

        if mode_table[c] then
            mode_table[c]()
        else
            parseDefault(c)
        end
    end
    newMode(curMode) --makes sure nothing is left out
    local retArr = {
        maxRange = maxRad,
        text = textTable,
        langAlphabets = langAlphabets,
        slashCount = slashCount,
        asterCount = asterCount,
        tickCount = tickCount
    }
    return retArr
end

local function processVisuals(authorEntityId, authorPos, receiverEntityId, receiverUUID, recPos, maxRad, messageDistance,
                              formattedTable, recWorld, langAlphabets, slashCount, tickCount, asterCount, message)
    local activeFreq = (playerCommChannels and playerCommChannels[receiverUUID]) or {}
    local recLangs = (playerLangs and playerLangs[receiverUUID]) or {}
    local savedLangs = savedLangs or {}
    local iEmphColor = message.emphColor or "#d80"
    -- local actionRad = 200
    -- local loocRad = 2 * actionRad
    -- local noiseRad = 30
    local textTable = sb.jsonMerge({}, formattedTable)
    local radioState = activeFreq["enabled"] or (activeFreq["enabled"] == nil and true)
    --*re-hardcodes my radius values*


    local sharesWorld = message.sharesWorld
    local pathDistance = 0
    local doorCount = 0
    local hasPath = false
    local inSight = sharesWorld and
        not world.lineTileCollision(authorPos, recPos, { "Block", "Dynamic" }) --dynamic is for doors
    -- FezzedOne: This will be used to determine whether to hide the nick and portrait.
    message.inSight = inSight
    message.inEarShot = false

    -- FezzedOne: Dynamic collision thickness calculation.
    local collisionA = nil
    if authorPos and sharesWorld and not inSight then
        -- local collisionA = world.lineTileCollisionPoint(authorPos, recPos, { "Block", "Dynamic" }) or nil
        collisionA = world.lineTileCollisionPoint(authorPos, recPos, { "Block" }) or nil
    end
    local wallThickness = 0
    if collisionA then --block collision
        -- FezzedOne: To find wall thickness, run collision checks in opposite directions.
        local collisionB = world.lineTileCollisionPoint(
            recPos,
            authorPos,
            { "Block" }
        ) or { collisionA[1] }
        wallThickness = math.floor(world.magnitude(collisionA[1], collisionB[1]))
        hasPath = true      -- must check for a path anyway
    elseif sharesWorld then --dynamic, used to check if we need to path
        --if this is false, then that means there's nothing in between the two
        --check for path
        hasPath = world.lineTileCollisionPoint(authorPos, recPos, { "Dynamic" }) ~= nil or false
    end

    local function degradeMessage(str, quality)
        local length = #str
        local result = ""
        local start = 1
        local escape = false
        randSource:init()
        while start and start <= length do
            local a = utf8.offset(str, 1, start)
            local b = utf8.offset(str, 2, start)
            local c = str:sub(a, b and b - 1 or nil)
            local after = b
            if not escape then
                if c == "\\" then
                    c = nil
                else
                    local skip = nil
                    if c == "[" then
                        skip = str:find("]", b, true)
                    elseif c == "^" then
                        skip = str:find(";", b, true)
                    end
                    if skip then
                        c = str:sub(a, skip)
                        after = skip + 1
                    end
                end
            end

            if c then
                if escape then
                    escape = false
                elseif after == b and randSource:randUInt(1, 100) > quality and not c:match("[%p%s]") then
                    c = "-"
                end
                result = result .. c
            else
                escape = true
            end

            start = after
        end
        return result
    end



    local function langRandLetters(word, byteLC)
        -- FezzedOne: The wordRoll parameter is now used.
        local vowels = {
            "a",
            "e",
            "i",
            "o",
            "u",
            "y",
        }
        local consonants = {
            "b",
            "c",
            "d",
            "f",
            "g",
            "h",
            "j",
            "k",
            "l",
            "m",
            "n",
            "p",
            "q",
            "r",
            "s",
            "t",
            "v",
            "w",
            "x",
            "z",
        }

        -- FezzedOne: Merge a list into a Lua pattern. Assumes input doesn't contain any characters that need to be escaped.
        local function mergePattern(list)
            local pattern = "["
            for _, char in ipairs(list) do
                pattern = pattern .. char
            end
            return pattern .. "]"
        end

        local pickInd = 0
        local newWord = ""
        local wordLength = #word
        randSource:init(math.tointeger(byteLC))
        randSource:addEntropy(math.tointeger(wordBytes(word)))
        for char in word:gmatch(".") do
            local charLower = char:lower()
            local isLower = char == charLower
            local vowelPattern = mergePattern(vowels)

            if charLower:match(vowelPattern) then
                local randNum = randSource:randInt(1, #vowels)
                char = vowels[randNum]
            elseif not char:match("[%d!\"%$%*%+%,%-%./:%;%?%@%[%\\%]%^_%`~]") then -- Don't mess with punctuation.
                local randNum = randSource:randInt(1, #consonants)
                char = consonants[randNum]
            elseif char:match("%d") then --numbers, randomly choose const or vowels
                local pick = randSource:randInt(1, 2)
                if pick == 1 then
                    char = consonants[randSource:randInt(1, #consonants)]
                else
                    char = vowels[randSource:randInt(1, #vowels)]
                end
            end

            if not isLower then char = char:upper() end
            newWord = newWord .. char
        end
        return newWord
    end



    local function langRepAlph(word, newAlphabet)
        local newWord = ""
        local wordTable = {}
        for char in word:gmatch(".") do
            local charUpper = char:upper()
            local isUpper = char == charUpper
            table.insert(wordTable, {
                ["char"] = char,
                ["upper"] = isUpper
            })
        end

        for index, letterInfo in ipairs(wordTable) do
            local char = letterInfo.char
            local isUpper = letterInfo.upper or false
            local charLower = char:lower()
            local newChar = newAlphabet[charLower] or nil


            if isUpper and newChar then
                if #newChar > 1 and #char == 1 then
                    newChar = newChar:sub(1, 1):upper() .. newChar:sub(2)
                elseif #newChar == 1 or (not wordTable[index - 1] or wordTable[index - 1].upper) and (not wordTable[index + 1] or wordTable[index + 1].upper) then
                    newChar = newChar:upper()
                else
                    newChar = newChar:sub(1, 1):upper() .. newChar:sub(2)
                end
            end
            newWord = newWord .. (newChar or "")
        end
        return newWord
    end

    local function langRandSounds(word, byteLC)
        --later, make an alternative that takes each sound type and has an array of options, may be more expensive to run though
        local consTable = { "b", "bb", "k", "ck", "qu", "dd", "ff", "ph", "gh", "gg", "dge", "ge", "ll", "le", "mm", "mb",
            "nn", "kn", "pp", "rr", "wr", "ss", "ce", "se", "sc", "tt", "ve", "wh", "zz", "ze", "si", "ti", "tch", "c",
            "d", "f", "g", "h", "j", "l", "m", "n", "p", "r", "s", "t", "v", "w", "x", "y", "z", "sh", "ch", "th", "ng" }
        local vowelTable = { "a", "e", "ea", "i", "y", "o", "u", "ai", "ay", "ae", "ee", "ie", "ey", "igh", "oa", "ow",
            "ew", "ue", "oo", "ou", "oi", "oy", "ar", "or", "aw", "au", "ore", "oar", "oor", "er", "ir", "ur", "ear",
            "air", "are", "eer", "ere" }
        local soundTable = { "b", "bb", "k", "ck", "qu", "dd", "ff", "ph", "gh", "gg", "dge", "ge", "ll", "le", "mm",
            "mb",
            "nn", "kn", "pp", "rr", "wr", "ss", "ce", "se", "sc", "tt", "ve", "wh", "zz", "ze", "si", "ti", "tch", "c",
            "d", "f", "g", "h", "j", "l", "m", "n", "p", "r", "s", "t", "v", "w", "x", "y", "z", "sh", "ch", "th", "ng",
            "a", "e", "ea", "i", "y", "o", "u", "ai", "ay", "ae", "ee", "ie", "ey", "igh", "oa", "ow",
            "ew", "ue", "oo", "ou", "oi", "oy", "ar", "or", "aw", "au", "ore", "oar", "oor", "er", "ir", "ur", "ear",
            "air", "are", "eer", "ere" }

        randSource:init(math.tointeger(byteLC))
        randSource:addEntropy(math.tointeger(wordBytes(word)))
        local firstVowel = randSource:randInt(1, #vowelTable)
        randSource:addEntropy(math.tointeger(wordBytes(word)))
        local soundsBefore = math.max(0, randSource:randInt((#word / 3) * -1, #word / 2))
        randSource:addEntropy(math.tointeger(wordBytes(word)))
        local soundsAfter = math.max(0, randSource:randInt((#word / 3) * -1, #word / 2))

        local retWord = ""

        local hasUpper = false
        local allUpper = true
        local vowelCount = 0

        for char in word:gmatch(".") do
            if char ~= char:lower() then
                hasUpper = true
            else
                allUpper = false
            end

            if char:match("[aeiouy]") then
                vowelCount = vowelCount + 1
            end
        end

        vowelCount = math.max(0, vowelCount - 1)

        local vowelPercent = math.floor((vowelCount / #word) * 100)

        for i = soundsBefore * -1, soundsAfter, 1 do
            if i ~= 0 then --if i is 0 then that's the initial vowel
                randSource:init(math.tointeger(byteLC))
                randSource:addEntropy(math.tointeger(wordBytes(word)))
                randSource:addEntropy(i)

                local isVowel = randSource:randInt(0, 100) <= vowelPercent and vowelCount > 0

                if isVowel then
                    retWord = retWord .. vowelTable[randSource:randInt(1, #vowelTable)]
                    vowelCount = vowelCount - 1
                else
                    retWord = retWord .. consTable[randSource:randInt(1, #consTable)]
                end
            else
                retWord = retWord .. vowelTable[firstVowel]
            end
        end

        if #word == 1 then allUpper = false end
        if allUpper then
            retWord = retWord:upper()
        elseif hasUpper then
            retWord = retWord:sub(1, 1):upper() .. retWord:sub(2)
        end

        -- sb.logInfo("Word is: %s", retWord)
        -- sb.logInfo("random info is: before %s, after %s, firstVowel: %s", soundsBefore, soundsAfter,
        --     vowelTable[firstVowel])
        return retWord
    end

    local function word2Sounds(word, byteLC, soundLib) --this has issues with short words, fix later
        --basically get the library of sounds, divide the word length by some value to estimate syllables, then stitch together random sounds
        local wordlength = #word
        local fakeSyls = math.max(1, math.floor(wordlength / 3)) or 1
        local retWord = ""
        local hasUpper = false
        local allUpper = true

        for char in word:gmatch(".") do
            if char ~= char:lower() then
                hasUpper = true
            else
                allUpper = false
            end
        end

        if #word == 1 then allUpper = false end

        for i = 1, fakeSyls, 1 do
            randSource:init(math.tointeger(byteLC + wordBytes(word)))
            randSource:addEntropy(i)
            retWord = retWord .. soundLib[randSource:randInt(1, #soundLib)]
        end

        if allUpper then
            retWord = retWord:upper()
        elseif hasUpper then
            retWord = retWord:sub(1, 1):upper() .. retWord:sub(2)
        end

        return retWord
    end

    local function morseCode(word)
        local digitsToMorse = {
            ["0"] = "-----",
            ["1"] = ".----",
            ["2"] = "..---",
            ["3"] = "...--",
            ["4"] = "....-",
            ["5"] = ".....",
            ["6"] = "-....",
            ["7"] = "--...",
            ["8"] = "---..",
            ["9"] = "----."
        }

        local morseLib = {
            A = ".-",
            B = "-...",
            C = "-.-.",
            D = "-..",
            E = ".",
            F = "..-.",
            G = "--.",
            H = "....",
            I = "..",
            J = ".---",
            K = "-.-",
            L = ".-..",
            M = "--",
            N = "-.",
            O = "---",
            P = ".--.",
            Q = "--.-",
            R = ".-.",
            S = "...",
            T = "-",
            U = "..-",
            V = "...-",
            W = ".--",
            X = "-..-",
            Y = "-.--",
            Z = "--.."
        }
        local result = ""

        for char in word:gmatch(".") do
            if tonumber(char) then
                result = result .. digitsToMorse[char]
            elseif morseLib[char:upper()] then
                --originally decided to include dashes, but i thought it'd look weird
                result = result .. morseLib[char:upper()]
            else
                result = result .. char
            end
        end
        return result
    end

    local presetLib = {
        ["encoded"] = function(word, byteLC, langCode)
            --replace whole words with half their word's length in random digits
            local encLength = math.max(1, math.floor(#word / 2))
            local retWord = ""

            for i = 1, encLength, 1 do
                randSource:init(math.tointeger(byteLC + wordBytes(word) + i))
                retWord = retWord .. randSource:randInt(0, 9)
            end
            randSource:init()
            return retWord
        end,
        ["mongol"] = function(word, byteLC, langCode) --for this, generate a new alphabet entry for the language
            local mongolAlph = langAlphabets[langCode]
            -- local specialWords = {
            --     ["word"] = "Stylized Word",
            -- }

            -- if specialWords[word] then
            --     return specialWords[word]
            -- end


            if #word > 3 then
                word = word:sub(1, 3)
                -- word = word:sub(1, math.max(1, math.ceil(#word - (#word / 2))))
            end

            if not mongolAlph then
                local cons = { "n", "ng", "b", "p", "kh", "gh", "m", "l", "g", "s", "sh", "t", "d", "ch", "j", "y", "r",
                    "v", "f", "ts", "k", "z", "lkn" }
                local vowels = { "a", "e", "i", "o", "ü", "ye", "yo", "ya" }
                local special = { "ne", "ge", "ni", "gi", "nö", "gö", "ba", "bi", "bo", "bö" }
                mongolAlph = genPresetAlph(byteLC, cons, vowels, special)
                langAlphabets[langCode] = mongolAlph
            end
            return langRepAlph(word, mongolAlph)
        end,
        ["crow"] = function(word, byteLC, langCode)
            local soundLib = { "caw", "kaw", "haw", "raah", "ehh", "waah", "ek", "ooo", "woo", "ik", "khu", "huk", "rhoa" }
            local exceptedWords = {}
            if exceptedWords[word] then
                return word
            end

            local hasUpper = false
            local allUpper = true

            for char in word:gmatch(".") do
                if char ~= char:lower() then
                    hasUpper = true
                else
                    allUpper = false
                end
            end
            if #word == 1 then allUpper = false end
            randSource:init(math.tointeger(byteLC))
            randSource:addEntropy(math.tointeger(wordBytes(word)))
            local retWord = soundLib[randSource:randInt(1, #soundLib)]

            if allUpper then
                retWord = retWord:upper()
            elseif hasUpper then
                retWord = retWord:sub(1, 1):upper() .. retWord:sub(2)
            end

            return retWord
        end,
        ["mi"] = function(word, byteLC, langCode)
            local soundLib = { "mi" }
            local exceptedWords = {}
            if exceptedWords[word] then
                return word
            end
            return word2Sounds(word, byteLC, soundLib)
        end,
        ["letters"] = function(word, byteLC, langCode)
            return langRandLetters(word, byteLC)
        end,
        ["sounds"] = function(word, byteLC, langCode)
            return langRandSounds(word, byteLC)
        end,
        ["morse"] = function(word, byteLC, langCode)
            return morseCode(langRandLetters(word, byteLC))
        end
    }

    local function langWordRep(word, langCode, byteLC, preset, newAlphabet)
        local preset = preset or false

        if presetLib[preset] then
            return presetLib[preset](word, byteLC, langCode)
        else
            if not newAlphabet then
                newAlphabet = genRandAlph(wordBytes(langCode:upper()))
            end
            return langRepAlph(word, newAlphabet)
            -- return langRandSounds(word, byteLC)
        end
    end

    local function langSplit(inputstr, sep)
        if sep == nil then sep = "%s" end
        local arg = ""
        local t = {}
        for c in inputstr:gmatch(".") do
            if c:match(sep) then
                -- arg = trim(arg) --shouldn't be necessary
                if #arg > 0 then
                    table.insert(t, { word = arg, nocolor = false })
                end
                table.insert(t, { word = c, nocolor = true, isSep = true })
                arg = ""
            else
                arg = arg .. c
            end
        end
        if #arg > 0 then
            table.insert(t, { word = arg, nocolor = false })
        end
        return t
    end

    local skipLangRecog = {
        ["morse"] = true,
        ["encoded"] = true,
        ["crow"] = true
    }
    local skipRecogWords = {
        ["the"] = true,
        ["of"] = true,
        ["a"] = true,
        ["in"] = true
    }

    local function langScramble(str, prof, langCode, msgColor, langColor, langPreset, newAlphabet)
        local returnStr = ""
        str = str:gsub("  ", " ")
        -- local strDict = langSplit(str, "[%s%p]")
        local strDict = langSplit(str, "[%s!\"%$%*%+%,%-%./:%;%?%@%[%\\%]%^_%`~]") --all punctuation except apostrophe, and whitespace
        local byteLC = wordBytes(langCode)
        local uniqueIdBytes = wordBytes(tostring(receiverEntityId))
        --no need for color, since it's always supplied

        --strDict is a table containing each character to make processing less fucky
        local prevScrambled = false

        for _, value in ipairs(strDict) do
            local word = value.word
            if value.nocolor then
                if prevScrambled and not word:match("[%s]") then
                    word = "^" .. msgColor .. ";" .. word
                    prevScrambled = false
                end
            else
                local replacedWord = false

                if word:match("[<>]") then
                    word = word:gsub("[<>]", "")
                    replacedWord = true
                end

                --run the checks then add
                local wordLength = #word
                local byteWord = wordBytes(word)
                randSource:init(math.tointeger(uniqueIdBytes + byteLC + byteWord))
                local wordRoll = randSource:randInt(1, 100)
                local euler = math.exp(1)
                local rollResult = math.floor(wordRoll * euler ^ ((wordLength - 5) / 5))
                if not replacedWord and (skipLangRecog[langPreset] or skipRecogWords[word:lower()]) and (prof < 5 or rollResult > prof) then
                    --scramble
                    word = langWordRep(word, langCode, byteLC, langPreset, newAlphabet)
                    if not prevScrambled then
                        word = "^" .. langColor .. ";" .. word
                        prevScrambled = true
                    end
                elseif #word > 0 then
                    --no scramble
                    if prevScrambled then
                        word = "^" .. msgColor .. ";" .. word
                        prevScrambled = false
                    end
                end
            end
            returnStr = returnStr .. word
        end
        randSource:init()
        -- return trim(returnStr)
        return returnStr
    end

    local function removeFirstSpace(str)
        local returnStr = str
        local cleanStr = str:gsub("%^[^^;]-;", "")
        if cleanStr:find(" ") == 1 then
            local preSpace = ""
            for c in str:gmatch(".") do
                if c == " " then
                    break
                end
                preSpace = preSpace .. c
            end
            returnStr = preSpace .. str:sub(#preSpace + 2)
        end
        return returnStr
    end

    local quoteFont = message.font or nil
    local actionFont = message.font or nil
    local fontW8 = message.fontW8 or
        true        --default for this is true if no font is specified, since the default does have weight
    local resetFormat =
    "#fff;^font=DB" --white for non sound based chunks --change DB to SB later for semi-bold, has to be done in the font files too
    local msgColor = "#fff;^font=M"

    local baseColorTable = {
        [-4] = "#555",
        [-3] = "#777",
        [-2] = "#999",
        [-1] = "#bbb",
        [0] = "#ddd",
        [1] = "#eee",
        [2] = "#daa",
        [3] = "#d66",
        [4] = "#d00",
    }
    local colorTable = { --transparency is an option here, but it makes things hard to read
        [-4] = "#555",
        [-3] = "#777",
        [-2] = "#999",
        [-1] = "#bbb",
        [0] = "#ddd",
        [1] = "#eee",
        [2] = "#daa",
        [3] = "#d66",
        [4] = "#d00",
    }
    local fontTable = {}

    if message.isOSB then
        -- old font table, had 9 font weights
        -- fontTable = {
        --     [-4] = "^font=T",
        --     [-3] = "^font=EL",
        --     [-2] = "^font=L",
        --     [-1] = "^font=R",
        --     [0] = "^font=M",
        --     [1] = "^font=DB",
        --     [2] = "^font=B",
        --     [3] = "^font=EB",
        --     [4] = "^font=BL",
        -- }
        -- new font table, has 5 font weights
        -- fontTable = {
        --     [-4] = "^font=EL",
        --     [-3] = "^font=EL",
        --     [-2] = "^font=R",
        --     [-1] = "^font=R",
        --     [0] = "^font=M",
        --     [1] = "^font=SB",
        --     [2] = "^font=SB",
        --     [3] = "^font=EB",
        --     [4] = "^font=EB",
        -- }
        fontTable = {
            [-4] = "^font=T",
            [-3] = "^font=EL",
            [-2] = "^font=L",
            [-1] = "^font=R",
            [0] = "^font=M",
            [1] = "^font=SB",
            [2] = "^font=B",
            [3] = "^font=EB",
            [4] = "^font=BL",
        }

        --i hate the nesting here but oh well
        if actionFont then
            resetFormat = "#fff;" .. fontTable[1]:gsub("=", "=" .. actionFont) --white for non sound based chunks
        end

        if quoteFont then
            if fontW8 then
                for index, value in ipairs(fontTable) do
                    fontTable[index] = value:gsub("=", "=" .. quoteFont)
                end
            else
                for index, value in ipairs(fontTable) do
                    fontTable[index] = "^font=" .. quoteFont
                end
            end
            -- resetFormat = "#fff;" .. fontTable[1] --white for non sound based chunks
            msgColor = "#fff;" .. fontTable[0] --white for non sound based chunks
        end

        colorTable = {
            [-4] = colorTable[-4] .. ";" .. fontTable[-4],
            [-3] = colorTable[-3] .. ";" .. fontTable[-3],
            [-2] = colorTable[-2] .. ";" .. fontTable[-2],
            [-1] = colorTable[-1] .. ";" .. fontTable[-1],
            [0] = colorTable[0] .. ";" .. fontTable[0],
            [1] = colorTable[1] .. ";" .. fontTable[1],
            [2] = colorTable[2] .. ";" .. fontTable[2],
            [3] = colorTable[3] .. ";" .. fontTable[3],
            [4] = colorTable[4] .. ";" .. fontTable[4],
        }
    end

    --right now this is bugged and won't carry italics over between scrambled and non-scrambled langs
    --i think the best options is to not touch the font thing in the lang scrambling
    local function colorWithin(str, char, color, prevColor, volume, colorOn, hasChar)
        --this also applies if there's only 1 character in the message
        if not hasChar then
            return {
                ["string"] = str,
                ["italicsOn"] = colorOn
            }
        end

        local volume = volume or 0
        local charBuffer = ""
        local prevChar = ""
        for i in str:gmatch(".") do
            --escape char skips the slash entirely
            if i == char and prevChar ~= "\\" then
                if colorOn == false then
                    if char ~= "`" and message.isOSB then
                        charBuffer = charBuffer .. fontTable[volume] .. "I;"
                    else
                        charBuffer = charBuffer ..
                            "^" .. color .. ";" .. ((message.isOSB and fontTable[volume] .. ";") or "")
                    end
                    colorOn = true
                else
                    if char ~= "`" and message.isOSB then
                        charBuffer = charBuffer .. fontTable[volume] .. ";"
                    else
                        charBuffer = charBuffer ..
                            "^" .. prevColor .. ";" .. ((message.isOSB and fontTable[volume] .. ";") or "")
                    end
                    colorOn = false
                end
            elseif i == "\\" then
                -- sb.logInfo("forward slash found for escape character")
                prevChar = i
            else
                -- sb.logInfo("either escape char is found or no match, char is %s, prevChar is %s",i,prevChar)
                --put this outside the if statement to make the characters appear as well as colors
                charBuffer = charBuffer .. i
                prevChar = i
            end
        end
        return {
            ["string"] = charBuffer,
            ["italicsOn"] = colorOn
        }
    end

    local function cleanDoubleSpaces(str)
        --run a loop with the string, ignore codes (^whatever;), then remove more than one space in a row
        local cleanStr = ""
        local iCount = 1
        local prevChar = ""
        local prevColor = ""

        while iCount <= #str do
            local char = str:sub(iCount, iCount)
            local nextSemi = 0

            if char == "^" then
                nextSemi = str:find(";", iCount)

                if nextSemi ~= nil then
                    local colorCode = str:sub(iCount, nextSemi)
                    if colorCode ~= prevColor then cleanStr = cleanStr .. colorCode end
                    prevColor = colorCode
                    iCount = nextSemi
                end
            elseif char ~= " " or prevChar ~= " " then
                cleanStr = cleanStr .. char
                prevChar = char
            end
            iCount = iCount + 1
        end
        cleanStr = cleanStr:gsub("%{ ", "{")
        cleanStr = cleanStr:gsub(" %}", "}")
        return cleanStr
    end

    --do visual formatting here.
    --for dialogue (NOT sounds), start degrading the quality of the message at 50% of the quotes's radius
    local tableStr = ""
    local prevStr = ""
    local quoteCombo = ""
    local soundCombo = ""
    local prevType = "action"
    local hasValids = false
    local chunkStr = nil
    local chunkType = nil
    local langBank = {}                            --populate with languages in inventory when you find them
    local prevLang = recLangs["[DEFAULT]"] or "!!" --either the player's default language, or !!
    -- local prevCommCode = activeFreq["freq"] or "0"
    local prevCommCode = ""
    local prevRadio = false
    local emphOn = false
    local itemEmphOn = false



    if maxRad ~= -1 and messageDistance > maxRad then
        message.text = ""
    else
        chunkType = nil

        --[[

        --this table is extremely messy, but it's kind of important
        { [1] = { ["text"] = action ,["type"] = action,["radius"] = 200,["isRadio"] = false,["langKey"] = !!,["commCode"] = 0,["noScramble"] = false,["hasLOS"] = true,["msgQuality"] = 100,["valid"] = true,} ,[2] = { ["text"] = quote,["type"] = quote,["radius"] = 30,["isRadio"] = false,["langKey"] = !!,["commCode"] = 0,["noScramble"] = false,["hasLOS"] = true,["msgQuality"] = 100,["valid"] = true,} ,[3] = { ["text"] =  ,["type"] = action,["radius"] = 200,["isRadio"] = false,["langKey"] = !!,["commCode"] = 0,["noScramble"] = false,["hasLOS"] = true,["msgQuality"] = 100,["valid"] = true,} ,[4] = { ["text"] = sound,["type"] = sound,["radius"] = 30,["isRadio"] = false,["langKey"] = !!,["commCode"] = 0,["noScramble"] = false,["hasLOS"] = true,["msgQuality"] = 100,["valid"] = true,} ,}

        { [1] = { ["radius"] = 400,["isRadio"] = false,["commCode"] = 0,["langKey"] = !!,["noScramble"] = false,["valid"] = true,["text"] = ((testing ooc)),["type"] = lOOC,["hasLOS"] = true,["msgQuality"] = 100,} ,}
        ]]

        local newTextTable = {}


        local rollColor = "#"
        local rollLib = { "3", "5", "7", "9", "A", "B", "C", "D", "F" }
        local newColor = ""

        local uidSub = wordBytes(string.sub(receiverUUID, 5, 15))

        randSource:init(math.tointeger(uidSub))
        randSource:addEntropy(wordBytes("Red"))
        newColor = randSource:randInt(1, #rollLib)
        rollColor = rollColor .. rollLib[newColor]
        table.remove(rollLib, newColor)
        -- randSource:init(math.tointeger(uidSub))
        randSource:addEntropy(wordBytes("Green"))
        newColor = randSource:randInt(1, #rollLib)
        rollColor = rollColor .. rollLib[newColor]
        table.remove(rollLib, newColor)
        -- randSource:init(math.tointeger(uidSub))
        randSource:addEntropy(wordBytes("Blue"))
        newColor = randSource:randInt(1, #rollLib)
        rollColor = rollColor .. rollLib[newColor]
        table.remove(rollLib, newColor)

        local pathMade = false
        for _, chunk in ipairs(textTable) do
            -- authorEntityId ~= receiverEntityId and
            if (chunk["type"] == "quote" or chunk["type"] == "sound") and hasPath and not pathMade and chunk["radius"] > messageDistance then
                local path = world.findPlatformerPath(authorPos, recPos, root.monsterMovementSettings("smallflying"))
                if path then
                    hasPath = true
                    --check the path for doors
                    for i, v in pairs(path) do
                        if world.lineTileCollision(v.source.position, v.target.position, { "Dynamic" }) then
                            doorCount = doorCount + 1
                        end
                        pathDistance = pathDistance + world.magnitude(v.source.position, v.target.position)
                    end
                    doorCount = math.ceil(doorCount / 2)
                    pathMade = true
                end
                break
            end
        end

        for _, chunk in ipairs(textTable) do
            chunk["text"] = string.gsub(chunk["text"], "%^rollColor;", "^" .. rollColor .. ";")
            local useRad = tonumber(chunk["radius"])
            local curMode = chunk["type"]
            local radioMode = chunk["isRadio"]
            chunk["msgQuality"] = 100

            if messageDistance > 0 then
                chunk["msgQuality"] = math.min(((useRad / 2) / messageDistance) * 100, 100) --basically, check half the radius and take the percentage of that vs the message distance, cap at 100
                if chunk["msgQuality"] < 0.1 then
                    chunk["msgQuality"] = 0
                end
            end

            chunk["hasLOS"] =
                inSight           --this is literally never used for anything meaningful

            local isValid = false --start with false
            local noPathVol = nil
            local chunkDistance = (pathMade and pathDistance) or messageDistance


            if radioMode and radioState and (activeFreq["freq"] and activeFreq["freq"] == chunk["commCode"] or chunk["commCode"] == 0) then
                inSight = true
            else
                radioMode = false
            end

            if chunkDistance <= useRad or useRad == -1 then                                 --if in range
                isValid = true                                                              --the message is valid
                if inSight == false and curMode == "action" then                            --if i can't see you and the mode is action
                    isValid = false                                                         --the message isn't valid anymore
                elseif inSight == false and (curMode == "quote" or curMode == "sound") then --else, if i can't see you and the mode is quote or sound
                    if authorPos then
                        if sharesWorld and pathMade then                                    --if path is found
                            --replace msg distance with path distance for this chunk
                            noPathVol = volTable[useRad] - (doorCount * 2)
                        else --if the path isn't found
                            if wallThickness <= 2 then
                                noPathVol = volTable[useRad] - (wallThickness * 2)
                            else
                                noPathVol = volTable[useRad] - (wallThickness * 4) --this should never be valid
                            end
                        end
                    elseif authorEntityId ~= receiverEntityId then
                        noPathVol = -4
                    end
                    if noPathVol > 4 then
                        noPathVol = 4
                    elseif noPathVol < -4 then
                        noPathVol = -4
                        isValid = false
                    end
                    useRad = soundTable
                        [noPathVol]                               --set the radius to whatever the soundelevel would be

                    isValid = isValid and chunkDistance <= useRad --set isvalid to the new value if it's still true
                end
            end
            chunk["radius"] = useRad
            if chunkDistance > 0 then
                chunk["msgQuality"] = math.min(((useRad / 2) / chunkDistance) * 100, 100) --basically, check half the radius and take the percentage of that vs the message distance, cap at 100
                if chunk["msgQuality"] < 0.1 then
                    chunk["msgQuality"] = 0
                end
            end


            chunk["valid"] = isValid
            if isValid or radioMode then
                table.insert(newTextTable, chunk)
            end
        end

        table.insert(
            newTextTable,
            { -- FezzedOne: Note to self: This dummy chunk is *required* for correct concatenation.
                text = "",
                radius = "0",
                type = "bad",
                langKey = ":(",
                valid = false,
                msgQuality = 0,
                isRadio = false,
                commCode = "0",
            }
        )

        textTable =
            newTextTable --cut down the table to remove invalid messages. This shortens computing time by a negligable amount

        -- sb.logInfo("textTable is %s", textTable)

        local numChunks = #textTable

        -- [11:29:21.434] [Info] table is {1: {valid: true, isRadio: false, langKey: !!, hasLOS: true, msgQuality: 100, commCode: 0, noScramble: false, type: quote, radius: 30, text: testing /italics }, 2: {valid: true, isRadio: false, langKey: !!, hasLOS: true, msgQuality: 100, commCode: 0, noScramble: false, type: quote, radius: 45, text:  with volume/}, 3: {type: bad, radius: 0, commCode: 0, text: , isRadio: false, msgQuality: 0, langKey: :(, valid: false}}

        local firstBlock = true

        for _, v in ipairs(textTable) do
            if v["hasLOS"] == false and chunkType == "action" then v["valid"] = false end
            if
                v["valid"]
                and v["type"] ~= "pOOC"
                and v["type"] ~= "lOOC"
                and v["type"] ~= "gOOC"
                and not v["isRadio"]
            then
                hasValids = true
            end
        end

        for k, v in ipairs(textTable) do
            local lastChunk = k == numChunks

            if
                v["radius"] == -1 or v["type"] == "gOOC"
            then
                v["valid"] = true
            end

            local rawStr = v["text"]
            -- FezzedOne: Strip out radio brackets. We'll re-add them later.
            v["text"] = rawStr:gsub("^{{", ""):gsub("^{", ""):gsub("}}$", ""):gsub("}$", "")
            if v["isRadio"] and radioState and (activeFreq["freq"] and activeFreq["freq"] == v["commCode"] or v["commCode"] == 0) then
                v["valid"] = true
            else
                v["isRadio"] = false
            end

            chunkStr = v["text"]
            chunkType = v["type"]
            if chunkType == "quote" and v["valid"] then message.inEarShot = true end
            local langKey = tostring(v["langKey"])
            if
                v["valid"] == true
                or (
                    chunkType == "quote"
                    and (
                        (k > 1 and textTable[k - 1]["type"] == "quote")
                        or (k < #textTable and textTable[k + 1]["type"] == "quote")
                    )
                )
            then                  --check if this is surrounded by quotes
                v["valid"] = true --this should be set to true in here, since everything in this block should show up on the screen
                -- remember, noiserad is a const and radius is for the message

                local colorOverride = chunkStr:find("%^%#") ~=
                    nil               --don't touch colors if this is true
                colorOverride = false --manually shutting this off

                local emphChar = ""
                local chunkVolColor = colorTable[volTable[v["radius"]]] --i hope to God nobody makes this happen
                if emphOn then emphChar = "I" else emphChar = "" end
                if itemEmphOn then
                    chunkVolColor = iEmphColor ..
                        ((message.isOSB and ";" .. fontTable[volTable[v["radius"]]]) or "")
                end


                --disguise unheard stuff
                if chunkType == "sound" then
                    if not colorOverride then
                        msgColor = chunkVolColor .. emphChar
                        -- chunkStr = "^" .. msgColor .. ";" .. chunkStr .. "^" .. actionColor .. ";"
                        chunkStr = "^" .. msgColor .. ";" .. chunkStr
                    end
                elseif chunkType == "quote" then
                    msgColor = chunkVolColor .. emphChar

                    if chunkType == "quote" and langKey ~= "!!" then
                        local langProf, langColor, langPreset
                        --checking langbank (and the var existing) is kind of redundant on the server, since i'm passing the giantass config var anyway
                        langProf = (recLangs[langKey] or 0) * 10
                        langColor = (savedLangs[langKey] and savedLangs[langKey]["color"]) or nil
                        langPreset = (savedLangs[langKey] and savedLangs[langKey]["preset"]) or false


                        if (not v["noScramble"]) and langProf < 100 then
                            if not langAlphabets[langKey] and (not langPreset or langPreset:match("[^%s]") == nil) then
                                --this should never happen, but i'll leave it here just in case
                                langAlphabets[langKey] = genRandAlph(wordBytes(langKey:upper()))
                            end
                            local newAlphabet = langAlphabets[langKey]
                            chunkStr = langScramble(chunkStr, langProf, langKey, baseColorTable[volTable[v["radius"]]],
                                langColor, langPreset, newAlphabet)
                        elseif chunkStr:match("[<>]") then
                            chunkStr = chunkStr:gsub("[<>]", "")
                        end
                    end
                    --check message quality
                    if v["msgQuality"] and v["msgQuality"] < 100 and not v["isRadio"] and chunkType == "quote" then
                        chunkStr = degradeMessage(trim(chunkStr), v["msgQuality"])
                    end

                    if not colorOverride then
                        -- chunkStr = "^" .. msgColor .. ";" .. chunkStr .. "^" .. actionColor .. ";"
                        chunkStr = "^" .. msgColor .. ";" .. chunkStr
                    end

                    --add in language indicator
                    if langKey ~= prevLang then
                        --used to be "#fff;^font=M"
                        chunkStr = "^#fff;" .. fontTable[0] .. ";[" .. langKey .. "] " .. chunkStr
                        prevLang = langKey
                    end
                    -- elseif chunkType == "action" then
                    --     chunkStr = "^" .. actionColor .. ";" .. chunkStr
                end
                chunkStr = chunkStr:gsub("%^%#fff%;%^%#fff;", "^#fff;")
                chunkStr = chunkStr:gsub("%^" .. msgColor .. ";%^#fff;", "^#fff;")
                chunkStr = chunkStr:gsub(
                    "%^" .. msgColor .. ";%^" .. msgColor .. ";",
                    "^" .. msgColor .. ";"
                )

                --recolors certain things for emphasis
                local eFontVol = volTable[v["radius"]]
                if chunkType ~= "action" then       --allow asterisks to stay in actions
                    local asterCheck = colorWithin(chunkStr, "*", "#fe7", msgColor, eFontVol, emphOn, asterCount > 1)
                    chunkStr = asterCheck["string"] --yellow
                    emphOn = asterCheck["italicsOn"] or false
                else
                    eFontVol = 1 --change this if the action font is changed
                end
                local slashCheck = colorWithin(chunkStr, "/", "#fe7", msgColor, eFontVol, emphOn, slashCount > 1)
                chunkStr = slashCheck["string"]
                emphOn = slashCheck["italicsOn"] or false
                -- FezzedOne: This now uses backticks.
                local iEmphCheck = colorWithin(chunkStr, "`", iEmphColor, msgColor, eFontVol, itemEmphOn, tickCount > 1)
                itemEmphOn = iEmphCheck["italicsOn"] or false
                chunkStr = iEmphCheck["string"] --orange
            elseif chunkType == "quote" and hasValids and prevType ~= "quote" then
                chunkStr = "Says something."
                v["valid"] = true
                chunkType = "action"
            end

            if v["isRadio"] and v["valid"] then
                local msgColor = "#fff"
                local commKey = v["commCode"]
                if commKey ~= prevCommCode then
                    local commAlias = nil
                    if commKey == activeFreq["freq"] then
                        commAlias = activeFreq["alias"]
                    end

                    chunkStr = "^"
                        .. (commAlias and "#88f" or "#44f")
                        .. ";{" .. (commAlias or commKey) .. "}^" .. msgColor .. "; " .. chunkStr
                    prevCommCode = commKey
                end
            end
            if v["valid"] and chunkStr ~= "" then
                -- if prevRadio and not v["isRadio"] then
                --     chunkStr = (wasGlobal and "}}" or "}") .. chunkStr
                -- elseif v["isRadio"] and not prevRadio then
                --     chunkStr = (wasGlobal and "{{" or "{") .. chunkStr
                -- end
                if prevRadio and not v["isRadio"] then
                    chunkStr = "}" .. chunkStr
                elseif v["isRadio"] and not prevRadio then
                    chunkStr = "{" .. chunkStr
                end
                prevRadio = v["isRadio"]
            end

            --after check, this puts formatted chunks in
            if chunkType ~= "quote" and prevType == "quote" then
                local checkCombo = quoteCombo:gsub("%[%w%w%]", "")

                if not checkCombo:match("[%w%d]") then
                    if prevStr ~= "Says something." and hasValids then
                        quoteCombo = "Says something."
                    else
                        quoteCombo = ""
                    end
                    prevStr = quoteCombo
                else
                    local beginRadio, endRadio = false, false
                    -- if quoteCombo:gsub("%^[^^;]-;", ""):sub(1, 2) == "}}" then
                    --     quoteCombo = quoteCombo:sub(3, -1)
                    --     endRadio = true
                    -- end
                    if quoteCombo:gsub("%^[^^;]-;", ""):sub(1, 1) == "}" then
                        quoteCombo = quoteCombo:sub(2, -1)
                        endRadio = true
                    end
                    -- if quoteCombo:gsub("%^[^^;]-;", ""):sub(1, 2) == "{{" then
                    --     quoteCombo = quoteCombo:sub(3, -1)
                    --     beginRadio = true
                    -- end
                    if quoteCombo:gsub("%^[^^;]-;", ""):sub(1, 1) == "{" then
                        quoteCombo = quoteCombo:sub(2, -1)
                        beginRadio = true
                    end
                    local isEmpty = #(quoteCombo:gsub("%^[^^;]-;", ""):gsub("%s", "")) == 0
                    -- quoteCombo = (endRadio and (wasGlobal and "}} " or "} ") or "")
                    --     .. (beginRadio and (wasGlobal and "{{" or "{") or "")
                    --     .. (isEmpty and "" or '"')
                    --     .. quoteCombo
                    --     .. (isEmpty and "" or '"')
                    quoteCombo = removeFirstSpace(quoteCombo)
                    local localReset = "^" .. resetFormat .. ";"
                    quoteCombo = (endRadio and localReset .. "} " or "")
                        .. (beginRadio and localReset .. "{" or "")
                        .. (isEmpty and "" or localReset .. '"')
                        .. trim(quoteCombo)
                        .. (isEmpty and "" or localReset .. '"')
                end
                tableStr = tableStr .. " " .. quoteCombo
                quoteCombo = ""
            end
            if chunkType ~= "sound" and prevType == "sound" then
                if soundCombo:match("[%w%d]") then
                    local beginRadio, endRadio = false, false
                    if soundCombo:sub(1, 2) == "}}" then
                        soundCombo = soundCombo:sub(3, -1)
                        endRadio = true
                    end
                    if soundCombo:sub(1, 1) == "}" then
                        soundCombo = soundCombo:sub(2, -1)
                        endRadio = true
                    end
                    if soundCombo:sub(1, 2) == "{{" then
                        soundCombo = soundCombo:sub(3, -1)
                        beginRadio = true
                    end
                    if soundCombo:sub(1, 1) == "{" then
                        soundCombo = soundCombo:sub(2, -1)
                        beginRadio = true
                    end
                    local isEmpty = #(soundCombo:gsub("%^[^^;]-;", ""):gsub("%s", "")) == 0
                    -- soundCombo = (endRadio and (wasGlobal and "}} " or "} ") or "")
                    --     .. (beginRadio and (wasGlobal and "{{" or "{") or "")
                    --     .. (isEmpty and "" or "<")
                    --     .. soundCombo
                    --     .. (isEmpty and "" or ">")
                    local localReset = "^" .. resetFormat .. ";"
                    soundCombo = (endRadio and localReset .. "} " or "")
                        .. (beginRadio and localReset .. "{" or "")
                        .. (isEmpty and "" or localReset .. "<")
                        .. soundCombo
                        .. (isEmpty and "" or localReset .. ">")
                    tableStr = tableStr .. " " .. soundCombo
                end
                soundCombo = ""
            end

            if v["valid"] and chunkType == "quote" then
                if quoteCombo:sub(#quoteCombo):match("%p") then
                    --this adds the space after a quote
                    quoteCombo = quoteCombo .. " " .. chunkStr
                else
                    quoteCombo = quoteCombo .. chunkStr
                end
            elseif v["valid"] and chunkType == "sound" then
                if soundCombo:sub(#soundCombo):match("%p") then
                    --this adds the space after a quote
                    soundCombo = soundCombo .. " " .. chunkStr
                else
                    soundCombo = soundCombo .. chunkStr
                end
            elseif v["valid"] then --everything that isn't a sound or a quote goes here
                if firstBlock then
                    tableStr = fontTable[1] .. ";" .. tableStr
                    tableStr = tableStr .. chunkStr
                else
                    tableStr = tableStr .. " " .. chunkStr
                end

                prevStr = chunkStr
            end

            if lastChunk and prevRadio then tableStr = tableStr .. "}" end

            prevType = chunkType
            firstBlock = false
        end
        tableStr = cleanDoubleSpaces(tableStr)     --removes double spaces, ignores colors
        tableStr = tableStr:gsub(' "%s', ' "')
        tableStr = tableStr:gsub("}}%s*{{", "...") --for multiple radios
        tableStr = tableStr:gsub("}%s*{", "...")   --for multiple radios
        tableStr = trim(tableStr)
        message.text = tableStr

        local cleanText = message.text:gsub("%^[^^;]-;", "")

        if #cleanText > 0 then
            -- message.text = fontTable[1] .. ";" .. tableStr
        else
            message.text = ""
            return
        end
    end

    --forced this to always pass at the request of users
    if true or message.inSight then
        message.portrait = message.portrait and message.portrait ~= "" and message.portrait
            or message.connection
    else -- FezzedOne: Remove the portrait from the message if the receiver can't see the sender.
        -- Use a dummy negative connection ID so that a portrait is never "grabbed" by SCC.
        message.connection = -message.connection
        message.portrait = message.connection
        -- Don't need to process the sender ID anymore after this, so we can remove it so that a portrait is no longer displayed.
        message.senderId = nil
    end
    -- this stuff isn't useful for this, i'm not gonna write in xsb support
    -- message.nickname = message.receiverName and (message.nickname .. " -> " .. message.receiverName)
    --     or message.nickname


    -- local result = nil
    -- local promise =
    -- while not promise:finished() do
    --     -- Wait.
    -- end
    -- if promise:succeeded() then result = promise:result() end
    -- return result
    --this is for the client so it skips processing
    message.fromServer = true
    message.processed = true
    local newMsg = {}
    newMsg.mode = message.mode
    newMsg.time = message.time
    newMsg.uuid = message.uuid
    newMsg.text = message.text
    newMsg.portrait = message.portrait
    newMsg.playerUid = message.playerUid
    newMsg.connection = message.connection
    newMsg.nickname = message.nickname
    newMsg.skipRecog = message.skipRecog
    newMsg.recogGroup = message.recogGroup
    newMsg.alias = message.alias
    newMsg.aliasPrio = message.aliasPrio
    newMsg.fakeName = message.fakeName

    newMsg.data = {}
    newMsg.data.replyUUID = message.data and message.data.replyUUID

    if recWorld then
        newMsg.recId = receiverEntityId
        universe.sendWorldMessage(recWorld, "dpc_world_message", newMsg)
    else
        world.sendEntityMessage(receiverEntityId, "scc_add_message", newMsg)
    end
    -- local result = nil
    -- local promise = world.sendEntityMessage(receiverEntityId, "scc_add_message", newMsg)
    -- while not promise:finished() do
    --     -- Wait.
    -- end
    -- if promise:succeeded() then result = promise:result() end
end

local function checkVersion(data)
    local userVersion = data.version
    --hard code this comparison, i don't care
    if userVersion < 200 then
        world.sendEntityMessage(data.player, "dpcServerMessage",
            "^CornFlowerBlue;Dynamic Prox Chat^reset;: Your mod is out of date! Please go install version 1.7.4 to ensure functionality with the server. Use /ignoreversion to suppress this.")
    end
    return
end

local function processMessage(data)
    --get a list of players, then process the message per player before sending it to each
    local isGlobal = data.globalFlag
    local playerList = {}
    local playerWorlds = {}
    local playerUniques = {}


    --temporary addition to see if it stops crashes
    -- isGlobal = false --this didn't fix anything, apparently

    if isGlobal == true or isGlobal == "true" then
        local clientList = universe.clientIds()

        for _, clientId in ipairs(clientList) do
            local playerEntity = clientId * -65536
            table.insert(playerList, playerEntity)
            playerWorlds[playerEntity] = universe.clientWorld(clientId) or false
            playerUniques[playerEntity] = universe.uuidForClient(clientId) or false
        end
    else
        playerList = world.players()
    end

    local authorPos = world.entityPosition(data.playerId)

    --when setting these up, format them as {uuid:{code:prof,code:prof...}} and {uuid:{channel:alias,channel:alias...}}
    --create another config for a limit that's set by the server (never change this with the stagehand), compare it somewhere in processing
    -- langs is previously set
    playerLangs = root.getConfiguration("DPC::playerLangs") or
        {}                                                                      --{uuid:{code{"prof":prof,"color":color},code{"prof":prof,"color":color}...}}
    playerCommChannels = root.getConfiguration("DPC::playerCommChannels") or {} --{uuid:{channel:name,channel:name...}}
    savedLangs = root.getConfiguration("DPC::savedLangs") or {}
    randSource = sb.makeRandomSource()                                          --i dont think this is null safe
    langSubWords = root.getConfiguration("DPC::langSubWords") or
        {}                                                                      -- [code] = {[word] replacement, [word] : replacement}
    local msgTime = os.clock() * 100000000000

    data.defaultFreq = data.defaultComms and data.defaultComms["freq"] or 0

    --run handlemessage once, then processVisuals for each player, should cut down on comp time
    local handleTable = {}
    -- handleMessage(data.playerId, authorPos, msgTime, data)
    local handleStat, returnError = pcall(handleMessage, data.playerId, data.playerUid, authorPos, msgTime, data)
    if handleStat then
        handleTable = returnError
    else
        sb.logWarn(
            "[DynamicProxChat] Error occurred while handling raw message: %s\n  Message data: %s",
            returnError,
            data
        )
    end

    local formattedTable = handleTable.text
    local maxRange = handleTable.maxRange
    local langAlphabets = handleTable.langAlphabets
    local slashCount = handleTable.slashCount or false
    local asterCount = handleTable.asterCount or 0
    local tickCount = handleTable.tickCount or false

    -- process Visuals
    for _, recPlayer in ipairs(playerList) do
        --find distances here, process the msg for the player if it's estimated as valid
        local recPos, msgDistance, recUUID = nil, nil, nil

        if isGlobal then
            msgDistance = math.huge
            recUUID = playerUniques[recPlayer]
            maxRange = -1
        end

        data.sharesWorld = playerWorlds[recPlayer] == playerWorlds[data.playerId]
        if data.sharesWorld then
            recPos = world.entityPosition(
                world.entityExists(recPlayer) and recPlayer
            )
            msgDistance = world.magnitude(recPos, authorPos)
            recUUID = world.entityUniqueId(recPlayer)
        end

        if msgDistance <= maxRange or isGlobal then
            if not data.sharesWorld then msgDistance = math.huge end
            local status, errorMsg = pcall(processVisuals, data.playerId, authorPos, recPlayer, recUUID, recPos, maxRange,
                msgDistance, formattedTable, playerWorlds[recPlayer], langAlphabets, slashCount, tickCount, asterCount,
                data)
            if status then
                --don't return because we want it to loop
                -- return errorMsg
            else
                sb.logWarn(
                    "[DynamicProxChat] Error occurred while formatting visuals for message: %s\n  Message data: %s",
                    errorMsg,
                    data
                )
            end
        end
    end
    local verData = {
        ["version"] = data.version,
        ["player"] = data.playerId
    }
    if not data.ignoreVersion then
        checkVersion(verData)
    end
    -- killStagehand() -- We don't need it anymore
end

function init()
    local purpose = config.getParameter("message") or "nil"
    local data = config.getParameter("data") or "no data"

    if purpose == "sendDynamicMessage" then
        -- world.sendEntityMessage(data.playerId, "dpcServerMessage",
        --     "[DEBUG] Checks are on. Remove them before going to production.")
        --log and process here
        local status, errorMsg = pcall(logNewMessage, purpose, data)
        if status then
            -- sb.logWarn("Status on processMessage %s, errorMsg: %s",status,errorMsg)
            -- return errorMsg
        else
            sb.logWarn(
                "[DynamicProxChat] Error occurred while logging message: %s\n  Message data: %s",
                errorMsg,
                data
            )
            world.sendEntityMessage(data.playerId, "dpcServerMessage", "[DEBUG] DPC Chat failed with error: " .. errorMsg)
        end
        local status, errorMsg = pcall(processMessage, data)
        if status then
            -- sb.logWarn("Status on processMessage %s, errorMsg: %s",status,errorMsg)
            -- return errorMsg
        else
            sb.logWarn(
                "[DynamicProxChat] Error occurred while formatting proximity message: %s\n  Message data: %s",
                errorMsg,
                data
            )
        end
        -- promises:add(processMessage(data))
        --promises is returning as a nil global, not sure why
    elseif purpose == "checkVersion" then
        logCommand(purpose, data)
        local status, errorMsg = pcall(checkVersion, data)
        if status then
            -- sb.logWarn("Status on processMessage %s, errorMsg: %s",status,errorMsg)
            -- return errorMsg
        else
            sb.logWarn(
                "[DynamicProxChat] Error occurred while adding language: %s\n  Message data: %s",
                errorMsg,
                data
            )
        end
    elseif purpose == "editLangPhrase" then
        logCommand(purpose, data)
        local status, errorMsg = pcall(editLangPhrase, data)
        if status then
            -- sb.logWarn("Status on processMessage %s, errorMsg: %s",status,errorMsg)
            -- return errorMsg
        else
            sb.logWarn(
                "[DynamicProxChat] Error occurred while adding replacement word: %s\n  Message data: %s",
                errorMsg,
                data
            )
        end
    elseif purpose == "addLang" then
        logCommand(purpose, data)
        local status, errorMsg = pcall(addLang, data)
        if status then
            -- sb.logWarn("Status on processMessage %s, errorMsg: %s",status,errorMsg)
            -- return errorMsg
        else
            sb.logWarn(
                "[DynamicProxChat] Error occurred while adding language: %s\n  Message data: %s",
                errorMsg,
                data
            )
        end
    elseif purpose == "resetLangs" then
        logCommand(purpose, data)
        local status, errorMsg = pcall(resetLangs, data)
        if status then
            -- sb.logWarn("Status on processMessage %s, errorMsg: %s",status,errorMsg)
            -- return errorMsg
        else
            sb.logWarn(
                "[DynamicProxChat] Error occurred while resetting languages: %s\n  Message data: %s",
                errorMsg,
                data
            )
        end
    elseif purpose == "defaultLang" then
        logCommand(purpose, data)
        local status, errorMsg = pcall(defaultLang, data)
        if status then
            -- sb.logWarn("Status on processMessage %s, errorMsg: %s",status,errorMsg)
            -- return errorMsg
        else
            sb.logWarn(
                "[DynamicProxChat] Error occurred while setting default language: %s\n  Message data: %s",
                errorMsg,
                data
            )
        end
    elseif purpose == "langlist" then
        logCommand(purpose, data)
        local status, errorMsg = pcall(langList, data)
        if status then
            -- sb.logWarn("Status on processMessage %s, errorMsg: %s",status,errorMsg)
            -- return errorMsg
        else
            sb.logWarn(
                "[DynamicProxChat] Error occurred while checking language list: %s\n  Message data: %s",
                errorMsg,
                data
            )
        end
    elseif purpose == "editlang" then
        logCommand(purpose, data)
        local status, errorMsg = pcall(editLang, data)
        if status then
            -- sb.logWarn("Status on processMessage %s, errorMsg: %s",status,errorMsg)
            -- return errorMsg
        else
            sb.logWarn(
                "[DynamicProxChat] Error occurred while editing language: %s\n  Message data: %s",
                errorMsg,
                data
            )
        end
    elseif purpose == "setfreq" then
        logCommand(purpose, data)
        local status, errorMsg = pcall(setFreq, data)
        if status then
            -- sb.logWarn("Status on processMessage %s, errorMsg: %s",status,errorMsg)
            -- return errorMsg
        else
            sb.logWarn(
                "[DynamicProxChat] Error occurred while adding comm channel: %s\n  Message data: %s",
                errorMsg,
                data
            )
        end
    elseif purpose == "toggleradio" then
        logCommand(purpose, data)
        local status, errorMsg = pcall(toggleRadio, data)
        if status then
            -- sb.logWarn("Status on processMessage %s, errorMsg: %s",status,errorMsg)
            -- return errorMsg
        else
            sb.logWarn(
                "[DynamicProxChat] Error occurred while adding comm channel: %s\n  Message data: %s",
                errorMsg,
                data
            )
        end
    else
        -- All the other stuff
        local nickname = data.nickname or "N/A"
        local uuid = data.playerUid or data.uuid or "N/A"
        sb.logInfo("Player " ..
            nickname ..
            " (UUID: " .. uuid .. ") spawned a stagehand with unidentified purpose: " .. purpose)
    end

    killStagehand() -- We don't need it anymore
end
