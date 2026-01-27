require("/interface/scripted/starcustomchat/plugin.lua")

-- Need this to copy message tables.
local function copy(obj, seen)
    if type(obj) ~= "table" then
        return obj
    end
    if seen and seen[obj] then
        return seen[obj]
    end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do
        res[copy(k, s)] = copy(v, s)
    end
    return res
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

local function sccrpInstalled()
    if root.assetExists then
        return root.assetExists("/interface/scripted/starcustomchat/plugins/proximitychat/proximity.lua")
    else
        return not not root.assetOrigin("/interface/scripted/starcustomchat/plugins/proximitychat/proximity.lua")
    end
end

local function getNames()
    local currentName = status.statusProperty("currentName")
    currentName = type(currentName) == "string" and currentName
    local defaultName = status.statusProperty("defaultName")
    defaultName = type(defaultName) == "string" and defaultName
    return currentName, defaultName
end

dynamicprox = PluginClass:new({
    name = "dynamicprox"
})

local DynamicProxPrefix = "^DynamicProx,reset;"
local AuthorIdPrefix = "^author="
local DefaultLangPrefix = ",defLang="
local TagSuffix = ",reset;"
local AnnouncementPrefix = "^clear;!!^reset;"
local randSource = sb.makeRandomSource()
local DEBUG = false
local DEBUG_PREFIX = "[DynamicProx::Debug] "

function dynamicprox:init()
    self:_loadConfig()
    local currentName, _ = getNames()
    if player.setNametag then
        player.setNametag(currentName or "")
    end
    self.cursorChar = nil
    root.setConfiguration("DPC::ignoreVersion", nil)

    self.unchecked = true
end

function dynamicprox:uninit()
    -- FezzedOne: Ensures the player's name tag on OpenStarbound isn't left invisible or as a custom tag if DPC is uninstalled.
    if player.setNametag then
        player.setNametag()
    end
end

function dynamicprox:addCustomCommandPreview(availableCommands, substr)
    if string.find("/learnlang", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/learnlang",
            description = "commands.learnlang.desc",
            data = "/learnlang"
        })
    elseif string.find("/showlangs", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/showlangs",
            description = "commands.showlangs.desc",
            data = "/showlangs"
        })
    elseif string.find("/langlist", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/langlist",
            description = "commands.langlist.desc",
            data = "/langlist"
        })
    elseif string.find("/editlang", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/editlang",
            description = "commands.editlang.desc",
            data = "/editlang"
        })
    elseif string.find("/resetlangs", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/resetlangs",
            description = "commands.resetlangs.desc",
            data = "/resetlangs"
        })
    elseif string.find("/defaultlang", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/defaultlang",
            description = "commands.defaultlang.desc",
            data = "/defaultlang"
        })
    elseif string.find("/addtypo", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/addtypo",
            description = "commands.addtypo.desc",
            data = "/addtypo"
        })
    elseif string.find("/removetypo", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/removetypo",
            description = "commands.removetypo.desc",
            data = "/removetypo"
        })
    elseif string.find("/toggletypos", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/toggletypos",
            description = "commands.toggletypos.desc",
            data = "/toggletypos"
        })
    elseif string.find("/checktypo", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/checktypo",
            description = "commands.checktypo.desc",
            data = "/checktypo"
        })
    elseif string.find("/showtypos", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/showtypos",
            description = "commands.showtypos.desc",
            data = "/showtypos"
        })
    elseif string.find("/togglehints", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/togglehints",
            description = "commands.togglehints.desc",
            data = "/togglehints"
        })
    elseif string.find("/toggleradio", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/toggleradio",
            description = "commands.toggleradio.desc",
            data = "/toggleradio"
        })
    elseif string.find("/freq", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/freq",
            description = "commands.freq.desc",
            data = "/freq"
        })
    elseif string.find("/chatbubble", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/chatbubble",
            description = "commands.chatbubble.desc",
            data = "/chatbubble"
        })
    elseif string.find("/skiprecog", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/skiprecog",
            description = "commands.skiprecog.desc",
            data = "/skiprecog"
        })
    elseif string.find("/resetrecog", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/resetrecog",
            description = "commands.resetrecog.desc",
            data = "/resetrecog"
        })
    elseif string.find("/grouprecog", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/grouprecog",
            description = "commands.grouprecog.desc",
            data = "/grouprecog"
        })
    elseif string.find("/font", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/font",
            description = "commands.font.desc",
            data = "/font"
        })
    elseif string.find("/chid", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/chid",
            description = "commands.chid.desc",
            data = "/chid"
        })
    elseif string.find("/addnick", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/addnick",
            description = "commands.addnick.desc",
            data = "/addnick"
        })
    elseif string.find("/clearnick", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/clearnick",
            description = "commands.clearnick.desc",
            data = "/clearnick"
        })
    elseif string.find("/addalias", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/addalias",
            description = "commands.addalias.desc",
            data = "/addalias"
        })
    elseif string.find("/resetalias", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/resetalias",
            description = "commands.resetalias.desc",
            data = "/resetalias"
        })
    elseif string.find("/showalias", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/showalias",
            description = "commands.showalias.desc",
            data = "/showalias"
        })
    elseif string.find("/apply", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/apply",
            description = "commands.apply.desc",
            data = "/apply"
        })
    elseif string.find("/nametag", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/nametag",
            description = "commands.nametag.desc",
            data = "/nametag"
        })
    elseif string.find("/ignoreversion", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/ignoreversion",
            description = "commands.ignoreversion.desc",
            data = "/ignoreversion"
        })
    elseif string.find("/talkvol", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/talkvol",
            description = "commands.talkvol.desc",
            data = "/talkvol"
        })
    elseif string.find("/editlangphrase", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/editlangphrase",
            description = "commands.editlangphrase.desc",
            data = "/editlangphrase"
        })
    elseif string.find("/emphcolor", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/emphcolor",
            description = "commands.emphcolor.desc",
            data = "/emphcolor"
        })
    elseif string.find("/togglejoinmsgs", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/togglejoinmsgs",
            description = "commands.togglejoinmsgs.desc",
            data = "/togglejoinmsgs"
        })
    end
end

local function splitStr(inputstr, sep) -- replaced this with a less efficient linear search in order to be system agnostic
    if sep == nil then
        sep = "%s"
    end
    local arg = ""
    local t = {}
    local qFlag = false
    for c in inputstr:gmatch(".") do
        if c:match(sep) and not qFlag and #arg > 0 then
            arg = trim(arg)
            table.insert(t, arg)
            arg = ""
        elseif c == '"' then -- "test word" 1 makes "test word" and " 1"
            if qFlag then
                table.insert(t, arg)
                qFlag = false
                arg = ""
            else
                qFlag = true
            end
        elseif not c:match(sep) or (c:match(sep) and qFlag) then
            arg = arg .. c
        end
    end
    table.insert(t, arg)
    return t
end

local function getDefaultLang(onServer)
    local defaultKey
    if onServer or false then
        defaultKey = player.getProperty("DPC::defaultLang") or "!!"
    else
        local langItem = player.getItemWithParameter("defaultLang", true) -- checks for an item with the "defaultLang" parameter
        if langItem == nil then
            defaultKey = "!!"
        else
            defaultKey = langItem["parameters"]["langKey"] or "!!"
        end
    end
    return defaultKey
end

local function setTextHint(mode, override)
    local override = override or false
    if override or mode ~= "Prox" or root.getConfiguration("DPC::hideHints") then
        widget.setText("lblTextboxHint", starcustomchat.utils.getTranslation("chat.textbox.hint"))
        return
    end

    local defaultLang = getDefaultLang(root.getConfiguration("dpcOverServer") or false)

    local hintStr = ""
    if defaultLang ~= "!!" then
        hintStr = hintStr .. "Default Lang: [" .. defaultLang .. "], "
    end
    local autoCorVal = (root.getConfiguration("DPC::typos") and root.getConfiguration("DPC::typos")["typosActive"] and
                           "on") or "off"
    hintStr = hintStr .. "Autocorrect " .. autoCorVal

    local radioState = ""

    if player.getProperty("DPC::radioState") == false then
        radioState = ", Radio off"
    end

    hintStr = hintStr .. radioState

    hintStr = starcustomchat.utils.getTranslation("chat.textbox.hint") .. " ^#777;(" .. hintStr .. ")"

    widget.setText("lblTextboxHint", hintStr)
end

local function checktypo(toggle)
    local typoTable = root.getConfiguration("DPC::typos") or {}

    if toggle then
        typoTable["typosActive"] = not typoTable["typosActive"]
    end

    root.setConfiguration("DPC::typos", typoTable)
    setTextHint("Prox")
    local typoStatus = (typoTable["typosActive"] and "on") or "off"
    return "Typo correction is " .. typoStatus
end

-- this messagehandler function runs if the chat preview exists
function dynamicprox:registerMessageHandlers(shared) -- look at this function in irden chat's editchat thing
    starcustomchat.utils.setMessageHandler("/proxdebug", function(_, _, data)
        if string.lower(data) == "on" then
            DEBUG = true
            return "^green;ENABLED^reset; debug mode for Dynamic Proximity Chat"
        elseif string.lower(data) == "off" then
            DEBUG = false
            return "^red;DISABLED^reset; debug mode for Dynamic Proximity Chat"
        else
            return "Debug mode for Dynamic Proximity Chat is " .. (DEBUG and "^green;ENABLED" or "^red;DISABLED") ..
                       "^reset;. To change this setting, pass ^orange;on^reset; or ^orange;off^reset; to this command."
        end
    end)
    starcustomchat.utils.setMessageHandler("/togglejoinmsgs", function(_, _, data)
        local showConnection = root.getConfiguration("DPC::showConnection") or false
        showConnection = not showConnection
        root.setConfiguration("DPC::showConnection", showConnection)

        local statusStr = showConnection and "shown" or "hidden"
        return "Connection messages are now " .. statusStr
    end)
    starcustomchat.utils.setMessageHandler("/showtypos", function(_, _, data)
        local typoTable = root.getConfiguration("DPC::typos") or {}
        if typoTable == nil then
            return "You have no corrections or typos saved. Use /addtypo to make one."
        end

        local rtStr = "Typos and corrections:^#2ee;"
        local tyTableLen = 0
        local typosActive = "off"
        for k, v in pairs(typoTable) do
            if k ~= "typosActive" then
                rtStr = rtStr .. " {" .. k .. " -> " .. v .. "}"
                tyTableLen = tyTableLen + 1
            elseif v then
                typosActive = "on"
            end
        end
        rtStr = rtStr .. "^reset;. Typo correction is " .. typosActive .. "."

        if tyTableLen == 0 then
            rtStr = "You have no corrections or typos saved. Use /addtypo to make one."
        end
        return rtStr
    end)
    starcustomchat.utils.setMessageHandler("/checktypo", function(_, _, data)
        return checktypo(false)
    end)
    starcustomchat.utils.setMessageHandler("/toggletypos", function(_, _, data)
        return checktypo(true)
    end)
    starcustomchat.utils.setMessageHandler("/addtypo", function(_, _, data)
        -- add a typo correction to the typos table in player data, or replace it if it already exists
        -- local typo, correction = chat.parseArguments(data)
        local splitArgs = splitStr(data, " ")
        local typo, correction = splitArgs[1], splitArgs[2]

        if typo == nil or correction == nil then
            return "Missing arguments for /addtypo, need {typo, correction}"
        end
        local typoTable = root.getConfiguration("DPC::typos") or {}

        typoTable[typo] = correction
        root.setConfiguration("DPC::typos", typoTable)
        return 'Typo "' .. typo .. '" added as "' .. correction .. '".'
    end)
    starcustomchat.utils.setMessageHandler("/removetypo", function(_, _, data)
        -- add a typo correction to the typos table in player data, or replace it if it already exists
        -- local typo = chat.parseArguments(data)
        local typo = splitStr(data, " ")[1]
        local typoTable = root.getConfiguration("DPC::typos", typoTable)

        if typo == nil then
            return "Missing arguments for /removetypo, need {typo}"
        end

        if typoTable then
            typoTable[typo] = nil
            root.setConfiguration("DPC::typos", typoTable)
            return 'Typo "' .. typo .. '" removed.'
        else
            return "No typos found."
        end
    end)

    starcustomchat.utils.setMessageHandler("/learnlang", function(_, _, data)
        local splitArgs = splitStr(data, " ")
        local langKey, langLevel, langName, color, preset = (splitArgs[1] or nil), (tonumber(splitArgs[2]) or 10),
            (splitArgs[3] or nil), (splitArgs[4] or nil), (splitArgs[5] or nil)

        if not langKey or #langKey < 1 then
            return "Missing arguments for /learnlang, need {code, prof, [name], [hex color], [preset]}"
        end

        langKey = langKey:upper()
        langKey = langKey:gsub("[%[%]]", "")

        local learnedLangs = player.getProperty("DPC::learnedLangs") or {}
        if color == "random" or color == "false" or color == nil then
            local hexDigits = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
            -- local randSource = sb.makeRandomSource()
            local hexMin = 4 -- make the minimum so people can still see stuff in case of weird random shit where you get lots of low values

            -- totally random value here, since it's generating for a server file
            randSource:init()
            color = ""
            while #color < 6 do
                local randNum1 = randSource:randInt(hexMin, #hexDigits)
                local randNum2 = randSource:randInt(hexMin, #hexDigits)
                color = color .. hexDigits[randNum1] .. hexDigits[randNum2]
                table.remove(hexDigits, randNum1) -- remove the primary value, since the secondary is not as strong i'm okay with it being re-used
            end
            color = "#" .. color
        else
            if not color:match("#") then
                color = "#" .. color
            end
            if #color > 7 then
                color = color:sub(1, 7)
            end
        end

        langLevel = math.max(0, math.min(langLevel, 10))

        local langInfo = {
            name = langName or langKey,
            code = langKey,
            prof = langLevel,
            color = color,
            preset = preset
        }

        local playerSecret = player.getProperty("DPC::playerCheck") or false
        if not playerSecret then
            playerSecret = sb.makeUuid()
            player.setProperty("DPC::playerCheck", playerSecret)
            player.setProperty("DPC:playerCheck", nil)
        end

        local addInfo = {
            player = player.id(),
            uuid = player.uniqueId(),
            playerSecret = playerSecret,
            newLang = langInfo
        }
        starcustomchat.utils.createStagehandWithData("dpcServerHandler", {
            message = "addLang",
            data = addInfo
        })
    end)
    starcustomchat.utils.setMessageHandler("/showlangs", function(_, _, data)
        local learnedLangs = player.getProperty("DPC::learnedLangs") or nil
        local defaultLang = player.getProperty("DPC::defaultLang") or nil

        if not learnedLangs then
            return "You have no learned languages."
        end

        local rtStr = "Languages:^#2ee;"
        for k, v in pairs(learnedLangs) do
            rtStr = rtStr .. " " .. v["name"] .. " [" .. k .. "]" .. ": " .. v["prof"] * 10 .. "%,"
        end
        if defaultLang then
            rtStr = rtStr .. "^reset; Default language: ^#2ee;[" .. defaultLang .. "]^reset;"
        end
        return rtStr
    end)
    starcustomchat.utils.setMessageHandler("/langlist", function(_, _, data)
        -- send a stagehand request to see a list of all languages on the server
        local addInfo = {
            player = player.id(),
            uuid = player.uniqueId()
        }
        starcustomchat.utils.createStagehandWithData("dpcServerHandler", {
            message = "langlist",
            data = addInfo
        })
    end)
    starcustomchat.utils.setMessageHandler("/editlang", function(_, _, data)
        -- send a stagehand request to see a list of all languages on the server
        local splitArgs = splitStr(data, " ")
        local dCode, subject, newVal, extra = splitArgs[1]:upper() or nil, splitArgs[2]:lower() or nil,
            splitArgs[3] or nil, splitArgs[4] or nil

        if not dCode or (subject ~= "color" and subject ~= "name" and subject ~= "preset") or not newVal then
            return "Bad arguments, use (code, subject, new value)."
        end

        if extra then
            return "Extra argument provided, remember to use quotes if making changes with multiple words."
        end

        local playerSecret = player.getProperty("DPC::playerCheck") or false
        if not playerSecret then
            playerSecret = sb.makeUuid()
            player.setProperty("DPC::playerCheck", playerSecret)
            player.setProperty("DPC:playerCheck", nil)
        end

        local addInfo = {
            player = player.id(),
            uuid = player.uniqueId(),
            playerSecret = playerSecret,
            dCode = dCode,
            subject = subject,
            newVal = newVal
        }
        starcustomchat.utils.createStagehandWithData("dpcServerHandler", {
            message = "editlang",
            data = addInfo
        })
    end)

    starcustomchat.utils.setMessageHandler("/resetlangs", function(_, _, data)
        local resetCheck = splitStr(data, " ")[1]
        local playerSecret = player.getProperty("DPC::playerCheck") or false

        if not playerSecret then
            return "No languages set for this character. Use /learnlang to make some."
        end

        if resetCheck == "reset" then
            player.setProperty("DPC::learnedLangs", nil)
            player.setProperty("DPC::defaultLang", nil)
            local addInfo = {
                player = player.id(),
                uuid = player.uniqueId(),
                playerSecret = playerSecret
            }
            starcustomchat.utils.createStagehandWithData("dpcServerHandler", {
                message = "resetLangs",
                data = addInfo
            })
            setTextHint("Prox")
        else
            return "Missing confirmation: Ensure that \"reset\" is included in this command to confirm the reset."
        end
    end)
    starcustomchat.utils.setMessageHandler("/defaultlang", function(_, _, data)
        local splitArgs = splitStr(data, " ") or nil
        local defaultCode = splitArgs[1] or nil

        if #defaultCode < 1 or not defaultCode then
            local defLang = player.getProperty("DPC::defaultLang") or nil
            if defLang then
                return "Current default language code is [" .. player.getProperty("DPC::defaultLang") .. "]."
            end
            return "You have no default language set."
        end
        -- set the default key in the learnedlangs table
        defaultCode = defaultCode:upper()
        defaultCode = defaultCode:gsub("[%[%]]", "")
        local playerSecret = player.getProperty("DPC::playerCheck") or false
        local learnedLangs = player.getProperty("DPC::learnedLangs") or false

        if not learnedLangs or not playerSecret then
            return "No languages set. Use /learnlang to learn languages."
        elseif defaultCode ~= "!!" and not learnedLangs[defaultCode] then
            return "Langauge \"" .. defaultCode .. "\" not known, aborting assignment."
        end

        local playerSecret = player.getProperty("DPC::playerCheck") or false
        local addInfo = {
            player = player.id(),
            uuid = player.uniqueId(),
            playerSecret = playerSecret,
            dCode = defaultCode
        }
        starcustomchat.utils.createStagehandWithData("dpcServerHandler", {
            message = "defaultLang",
            data = addInfo
        })

        player.setProperty("DPC::defaultLang", defaultCode)
        setTextHint("Prox") -- we're gonna assume that the server works
    end)
    starcustomchat.utils.setMessageHandler("/togglehints", function(_, _, data)
        local newHintsVal = not root.getConfiguration("DPC::hideHints")
        local hintsDisplay = (newHintsVal and "off") or "on"
        root.setConfiguration("DPC::hideHints", newHintsVal)
        setTextHint("Prox")
        return "Hint display " .. hintsDisplay
    end)
    starcustomchat.utils.setMessageHandler("/toggleradio", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local radioState = player.getProperty("DPC::radioState")
            if radioState == nil then
                radioState = true
            end
            player.setProperty("DPC::radioState", not radioState)
            setTextHint("Prox")
            local playerSecret = player.getProperty("DPC::playerCheck") or false

            if not playerSecret then
                playerSecret = sb.makeUuid()
                player.setProperty("DPC::playerCheck", playerSecret)
            end

            local addInfo = {
                player = player.id(),
                uuid = player.uniqueId(),
                playerSecret = playerSecret,
                radioState = radioState
            }
            starcustomchat.utils.createStagehandWithData("dpcServerHandler", {
                message = "toggleradio",
                data = addInfo
            })
            return
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/freq", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local args = splitStr(data, " ")
            local newFreq, freqAlias = args[1] or nil, args[2] or nil
            if not tonumber(newFreq) then
                local activeFreq = player.getProperty("DPC::activeFreq") or nil
                if activeFreq then
                    local freqAlias = (activeFreq["alias"] and "(" .. activeFreq["alias"] .. ")") or "(no alias)"
                    return "Active frequency is: " .. activeFreq["freq"] .. " " .. freqAlias .. "."
                else
                    return "No frequency has been set, use /freq to make one."
                end
            end

            -- freq is valid, pass it to the player property to override
            --[[structure, since there's only one active:
            activeFreq = {
                [code] => 123,
                [alias] => optional name
            }
            --may do this one, might not, idk yet
            savedFreqs = {
            ["code"] => alias,
            ...
            }
            ]]

            local activeFreq = {
                ["freq"] = newFreq,
                ["alias"] = freqAlias
            }
            player.setProperty("DPC::activeFreq", activeFreq)

            local playerSecret = player.getProperty("DPC::playerCheck") or false

            if not playerSecret then
                playerSecret = sb.makeUuid()
                player.setProperty("DPC::playerCheck", playerSecret)
            end

            local addInfo = {
                player = player.id(),
                uuid = player.uniqueId(),
                playerSecret = playerSecret,
                activeFreq = activeFreq
            }
            starcustomchat.utils.createStagehandWithData("dpcServerHandler", {
                message = "setfreq",
                data = addInfo
            })
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/chatbubble", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local bubbleSetting = not (root.getConfiguration("DPC::chatBubble") or false)
            root.setConfiguration("DPC::chatBubble", bubbleSetting)

            local retStr = "not "
            if bubbleSetting then
                retStr = ""
            end

            return "Chat bubbles will " .. retStr .. "appear when sending messages."
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/skiprecog", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local skipStatus = not (player.getProperty("DPC::skipRecog") or false)
            player.setProperty("DPC::skipRecog", skipStatus)

            local retStr = "not "
            if skipStatus then
                retStr = ""
            end

            return "Your character's name will " .. retStr .. "be automatically recognized by other players."
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/resetrecog", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local resetConf = splitStr(data, " ")[1]
            if resetConf ~= "reset" then
                return
                    "Are you sure you want to reset recognized characters? Repeat this command with \"reset\" as the argument to confirm."
            end

            player.setProperty("DPC::recognizedPlayers", nil)
            player.setProperty("DPC::playerNicks", nil)
            player.setProperty("DPC::recogGroup", nil)
            return "Your recognized characters, nicknames and groups have been reset."
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/grouprecog", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local group = splitStr(data, " ")[1] or nil
            local curGroup = player.getProperty("DPC::recogGroup") or "none"

            if not group or #group < 1 then
                return "Your current recognition group is " .. curGroup
            elseif group == "none" or group == "reset" then
                player.setProperty("DPC::recogGroup", nil)
                return "Your recognition group was reset."
            end
            player.setProperty("DPC::recogGroup", group)
            return "Your recognition group was changed from " .. curGroup .. " to " .. group .. "."
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/font", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            -- no font support yet
            -- if true then
            --     return "Fonts aren't supported (yet), wait until [next version]"
            -- end
            -- 1st arg is type, 2nd arg is font
            local splitArgs = splitStr(data, " ")
            local type, font = splitArgs[1] or nil, splitArgs[2] or nil

            if type ~= "general" and type ~= "quote" then
                return "Incorrect type supplied, use \"general\" or \"quote\"."
            end

            if font == "reset" or font == "exo" then
                -- apply player property to tell people what font is used for general/quotes
                player.setProperty("DPC::" .. type .. "Font", nil)
                player.setProperty("DPC::" .. type .. "Weight", nil)
                return "Reset " .. type .. " font."
            end

            -- sb.logInfo("font is %s, lib entry is %s", font, self.fontLib[font])

            if self.fontLib and self.fontLib[font] then
                -- apply player property to tell people what font is used for general/quotes
                player.setProperty("DPC::" .. type .. "Font", self.fontLib[font]["font"])
                if self.fontLib[font]["weight"] then
                    player.setProperty("DPC::" .. type .. "Weight", self.fontLib[font]["weight"])
                else
                    player.setProperty("DPC::" .. type .. "Weight", false)
                end
                return "Set " .. type .. " font to: ^font=" .. self.fontLib[font]["font"] .. ";" .. font .. "^reset;"
            end
            return "Font \"" .. font .. "\" not found."
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/chid", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            -- do a playerQuery at the aim position , then use world.entityUniqueId
            local cursorPlayer = world.playerQuery(player.aimPosition(), 0)[1] or nil
            if not cursorPlayer then
                return "No player detected on the cursor, try again."
            end

            if cursorPlayer == player.id() then
                return "You can't select yourself for /chid, pick someone else."
            end

            local chidName = world.entityName(cursorPlayer)
            local chidTable = {
                ["entityId"] = cursorPlayer,
                ["UUID"] = world.entityUniqueId(cursorPlayer)
            }

            self.cursorChar = chidTable
            return "Character selected."
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    -- add a nickanme command that lets you apply a custom name to the selected chid character
    starcustomchat.utils.setMessageHandler("/addnick", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local splitArgs = splitStr(data, " ")
            local newNick = splitArgs[1] or nil
            if not newNick or #tostring(newNick) < 1 then
                return "No nickname provided, try again."
            end

            local chid = self.cursorChar or nil
            if not chid then
                return "No character selected, move your cursor over one and use /chid to select them."
            end
            chid = chid.UUID
            local nicks = player.getProperty("DPC::playerNicks") or {}
            nicks[chid] = tostring(newNick)
            player.setProperty("DPC::playerNicks", nicks)

            self.cursorChar = nil

            return "Character assigned nickname " .. newNick .. ", selection released."
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/clearnick", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local chid = self.cursorChar or nil
            if not chid then
                return "No character selected, move your cursor over one and use /chid to select them."
            end
            chid = chid.UUID
            local nicks = player.getProperty("DPC::playerNicks") or {}
            if nicks[chid] then
                nicks[chid] = nil

                self.cursorChar = nil
                player.setProperty("DPC::playerNicks", nicks)
                return "Reset nickname for character, selection released."
            else
                return "No nickname found."
            end
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/addalias", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            -- the different splitting caused problems with negative numbers, reverted
            local splitArgs = splitStr(data, " ")
            local alias, aliasPrio = splitArgs[1] or nil, splitArgs[2] or nil
            if (not alias or #tostring(alias) < 1) or (not aliasPrio) then
                return "Missing arguments, you must include an alias and priority."
            end

            if tonumber(aliasPrio) and (tonumber(aliasPrio) < -9 or tonumber(aliasPrio) > 9) then
                return "Priority out of bounds, select a priority between -9 and 9."
            end

            if tonumber(aliasPrio) == 0 then
                return "Cannot assign a priority 0 alias (this is reserved for your character's name)."
            end
            if aliasPrio == "?" then
                player.setProperty("DPC::unknownAlias", alias)
                return "Unknown alias set as: " .. alias
            end
            local playerAliases = player.getProperty("DPC::aliases") or {}

            if not tonumber(aliasPrio) then
                return "Invalid priority, use a number or '?' for assignment."
            end

            aliasPrio = aliasPrio:format("%i")

            playerAliases[aliasPrio] = tostring(alias)
            local _, defaultName = getNames()
            playerAliases["0"] = xsb and defaultName or world.entityName(player.id())
            player.setProperty("DPC::aliases", playerAliases)
            return "Alias " .. alias .. " added with priority " .. aliasPrio
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/resetalias", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local resetConf = splitStr(data, " ")[1]
            if resetConf == "reset" then
                player.setProperty("DPC::aliases", nil)
                player.setProperty("DPC::unknownAlias", nil)
                return "Aliases reset."
            else
                return "Missing confirmation, use \"reset\" to confirm the reset."
            end
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/showalias", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            -- print out all of the aliases
            local retStr = ""
            local playerAliases = player.getProperty("DPC::aliases") or nil
            if not playerAliases then
                return "No aliases exist, use /addalias to make some."
            end

            for prioNum = -10, 10, 1 do
                local prio = tostring(prioNum)
                local alias = playerAliases[prio]
                if prioNum == 0 then
                    local canonicalName = world.entityName(player.id())
                    retStr = retStr .. "[" .. prio .. ": " .. canonicalName .. "] "
                elseif alias then
                    retStr = retStr .. "[" .. prio .. ": " .. alias .. "] "
                end
            end

            retStr = trim(retStr)
            local unknownAlias = player.getProperty("DPC::unknownAlias") or "^#999;???^reset;"
            return "Aliases are: " .. retStr .. ". Unknown alias is: " .. unknownAlias
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    -- add /apply with the ability to use the chid or everyone within LOS and 30 tiles
    starcustomchat.utils.setMessageHandler("/apply", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local splitArgs = splitStr(data, " ")
            local aliasPrio = (splitArgs[1] and tonumber(splitArgs[1])) or "0"
            local chid = self.cursorChar or nil
            local playerAliases = player.getProperty("DPC::aliases") or {}
            playerAliases["0"] = world.entityName(player.id())
            local aliasInfo = {}

            if playerAliases and tonumber(aliasPrio) and playerAliases[tostring(aliasPrio)] then
                aliasInfo = {
                    ["alias"] = tostring(playerAliases[tostring(aliasPrio)]),
                    ["priority"] = tonumber(aliasPrio),
                    ["UUID"] = player.uniqueId()
                }
            else
                return "Missing aliases, command failed."
            end

            if not chid then
                -- do an entity query within 25 and call it good
                local players = world.playerQuery(world.entityPosition(player.id()), 25, {
                    boundMode = "position"
                })

                local pCount = 0
                for _, pl in ipairs(players) do
                    if pl ~= player.id() then
                        world.sendEntityMessage(pl, "showRecog", aliasInfo)
                        pCount = pCount + 1
                    end
                end
                return "Sent alias " .. aliasInfo.alias .. " to " .. pCount .. " players."
            end

            world.sendEntityMessage(chid.entityId, "showRecog", aliasInfo)
            return "The selected character should now recognise you (if running DPC)."
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)

    -- FezzedOne: Added /nametag for both xStarbound and OpenStarbound.
    starcustomchat.utils.setMessageHandler("/nametag", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            if root.assetJson("/player.config:genericScriptContexts").OpenStarbound ~= nil and player.setNametag then
                local newName = splitStr(data, " ")[1]
                if (not newName) or newName == "" then
                    player.setNametag("")
                    status.setStatusProperty("currentName", nil)
                    return "Cleared name tag."
                else
                    player.setNametag(tostring(newName))
                    status.setStatusProperty("currentName", tostring(newName))
                    return "Set name tag to '" .. tostring(newName) .. "'."
                end
            else
                return "^red;Command unavailable on this client."
            end
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/ignoreversion", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            root.setConfiguration("DPC::ignoreVersion", true)
            return "Ignoring version notices until you reconnect."
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/talkvol", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local newVol = splitStr(data, " ")[1]

            if #trim(newVol) < 1 then
                return "Default volume is: " .. (player.getProperty("DPC::defaultVolume") or 0)
            end

            if not tonumber(newVol) or tonumber(newVol) > 4 or tonumber(newVol) < -4 then
                return "Invalid argument provided, enter a number between -4 and 4"
            end
            newVol = tonumber(newVol)

            player.setProperty("DPC::defaultVolume", newVol)
            return "Default volume set to " .. newVol
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/editlangphrase", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local splitArgs = splitStr(data, " ")
            local langCode, phrase, replacement = splitArgs[1] or nil, splitArgs[2] or nil, splitArgs[3] or nil

            local playerSecret = player.getProperty("DPC::playerCheck") or false
            if not langCode then
                return "Bad arguments, must include language code."
            end

            local playerSecret = player.getProperty("DPC::playerCheck") or false
            if not playerSecret then
                playerSecret = sb.makeUuid()
                player.setProperty("DPC::playerCheck", playerSecret)
            end

            local addInfo = {
                player = player.id(),
                uuid = player.uniqueId(),
                playerSecret = playerSecret,
                dCode = langCode,
                phrase = phrase,
                replacement = replacement
            }
            starcustomchat.utils.createStagehandWithData("dpcServerHandler", {
                message = "editLangPhrase",
                data = addInfo
            })
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/emphcolor", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local splitArgs = splitStr(data, " ")
            local emphColor = splitArgs[1] or nil

            if emphColor == nil or #emphColor < 1 then
                emphColor = player.getProperty("DPC::emphColor") or "#d80"
                return "Current emphasis color is ^" .. emphColor .. ";" .. emphColor
            end

            if emphColor == "reset" or tonumber(emphColor) == 0 then
                player.setProperty("DPC::emphColor", nil)
                return "Reset emphasis color."
            end

            emphColor = emphColor:gsub("#", "")

            emphColor = "#" .. emphColor

            player.setProperty("DPC::emphColor", emphColor)
            return "Set emphasis color to ^" .. emphColor .. ";" .. emphColor
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
end

local function normaliseText(str)
    return tostring(str):gsub("%^[^^;]-;", ""):gsub("%p", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "):lower()
end

local function getQuotes(str)
    -- FezzedOne: Need to strip escape codes here to avoid fucking up parsing.
    str = str:gsub("%^[^^;]-;", "")

    local returnStr, quoteBuffer = "", ""

    local isQuote = false
    for c in str:gmatch(".") do
        if c == '"' then
            if isQuote then
                -- close out quote and add to return string
                returnStr = returnStr .. quoteBuffer
                quoteBuffer = ""
                isQuote = false
            else
                -- turn quote collection on
                isQuote = true
                quoteBuffer = quoteBuffer .. " "
            end
        elseif isQuote then
            quoteBuffer = quoteBuffer .. c
        end
    end
    return returnStr
end

-- FezzedOne: Used DeepSeek for this one.
local function quoteMap(str)
    local quotes = getQuotes(str)
    -- Normalize spaces and trim
    quotes = quotes:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "):lower()

    -- Split quotes into individual words
    local words = {}
    for word in quotes:gmatch("%S+") do
        -- Remove punctuation from each word
        word = word:gsub("%p", "")
        if #word > 0 then
            table.insert(words, word)
        end
    end

    local tokens = {}
    local numWords = #words

    -- Generate all 1-5 word n-grams (overlapping)
    for startIdx = 1, numWords do
        local currentToken = ""
        for n = 1, 5 do -- n-gram length (1 to 5 words)
            local endIdx = startIdx + n - 1
            if endIdx > numWords then
                break
            end

            -- Build token by adding next word
            if n == 1 then
                currentToken = words[startIdx]
            else
                currentToken = currentToken .. " " .. words[endIdx]
            end

            tokens[currentToken] = true
        end
    end

    return tokens
end

local function applyRecogToQuotes(str, recogList)
    --[[
    (optimization) if out of a quote, check the rest of the string for quotes. if none exist then finish
    ]]

    if not str:match("\"") then
        return str
    end

    local retStr = ""
    local word = ""
    local inQuote = false
    local index = 1

    while index <= #str do
        local char = str:sub(index, index)

        if char:match("[%s!\"%$%*%+%,%-%./:%;%?%@%[%\\%]#%`~]") then
            -- check recogList here
            if inQuote and recogList[word:lower()] then
                word = "_" .. word .. "_"
            end

            retStr = retStr .. word
            word = ""
            retStr = retStr .. char
        else
            word = word .. char
        end
        if char == "\"" then
            inQuote = not inQuote
        end
        index = index + 1
    end

    if #word > 0 then
        retStr = retStr .. word
    end

    return retStr
end

function dynamicprox:formatOutcomingMessage(data)
    local currentPlayerName = ""

    -- think about running this in local to allow players without the mod to still see messages
    if data.mode == "Prox" then
        data.proxRadius = self.proxRadius
        -- data.time = systemTime() this is where i'd add time if i wanted it
        local position = player.id() and world.entityPosition(player.id())

        -- FezzedOne: Dice roll handling.
        local rawText = data.text
        local newStr = ""
        local cInd = 1
        while cInd <= #rawText do
            local c = rawText:sub(cInd, cInd)
            if c == "\\" then -- Handle escapes.
                newStr = newStr .. "\\" .. rawText:sub(cInd + 1, cInd + 1)
                cInd = cInd + 1
            else
                newStr = newStr .. c
            end
            cInd = cInd + 1
        end

        data.text = newStr

        if position then
            local estRad = data.proxRadius
            local rawText = data.text
            local sum = 0
            local parenSum = 0
            local inOoc = false
            local iCount = 1
            local globalFlag = false
            local hasNoise = false
            local defaultKey = getDefaultLang(true)
            data.defaultLang = defaultKey
            local typoTable = root.getConfiguration("DPC::typos") or {}
            local typoVar = typoTable["typosActive"]
            if typoVar then
                local newText = ""
                local wordBuffer = ""
                for i in (rawText .. " "):gmatch(".") do
                    if i:match("[%s%p]") and i ~= "[" and i ~= "]" then
                        if typoTable[wordBuffer] ~= nil then
                            newText = newText .. typoTable[wordBuffer] .. i

                            wordBuffer = ""
                        else
                            newText = newText .. wordBuffer .. i
                        end
                        wordBuffer = ""
                    else
                        wordBuffer = wordBuffer .. i
                    end
                end
                rawText = newText:sub(1, #newText - 1)
            end
            local debugStr = ""
            while iCount <= #rawText do -- Removed globalFlag check in this while loop. Caused parsing issues!
                if parenSum == 3 then
                    globalFlag = true
                end

                local i = rawText:sub(iCount, iCount)
                local langEnd = rawText:find("]", iCount)
                debugStr = debugStr .. i
                -- if langEnd then langEnd = langEnd - 1 end
                if i == "\\" then -- FezzedOne: Ignore escaped characters.
                    iCount = iCount + 1
                elseif i == "+" then
                    sum = sum + 1
                elseif i == "(" then
                    if rawText:sub(iCount + 1, iCount + 1) == "(" then
                        inOoc = true
                    end
                    parenSum = parenSum + 1
                elseif i == "<" then
                    if rawText:sub(iCount + 1, iCount + 1) == "<" then
                        inOoc = true
                    end
                elseif i == ")" then
                    if rawText:sub(iCount + 1, iCount + 1) == ")" then
                        inOoc = false
                    end
                elseif i == ">" then
                    if rawText:sub(iCount + 1, iCount + 1) == ">" then
                        inOoc = false
                    end
                elseif i == "{" and rawText:find("}", iCount) ~= nil then
                    globalFlag = true
                elseif i == "[" and langEnd ~= nil then -- use this flag to check for default languages. A string without any noise won't have any language support
                    if (not inOoc) and rawText:sub(iCount + 1, iCount + 1) ~= "[" then -- FezzedOne: If `[[` is detected, don't parse it as a language key.
                        local langKey, commKey
                        -- local commKeySubstitute = nil
                        -- local legalCommKey = true
                        if rawText:sub(iCount, langEnd) == "[]" then -- checking for []
                            langKey = defaultKey
                            rawText = rawText:gsub("%[%]", "[" .. defaultKey .. "]")
                        else
                            langKey = rawText:sub(iCount + 1, rawText:find("]") - 1)
                        end
                        if langKey then
                            local upperKey = langKey:upper()
                            -- if sendoverserver is on, this returns a prof value. Otherwise it returns an item. Either way it doesn't get checked later so that's fine
                            local learnedLangs = player.getProperty("DPC::learnedLangs")
                            if learnedLangs and not learnedLangs[upperKey] and upperKey ~= "!!" then
                                rawText = rawText:gsub("%[" .. langKey .. "%]", "[" .. defaultKey .. "]")
                            end
                        end
                    else
                        iCount = iCount + 1
                    end
                else
                    parenSum = 0
                end
                iCount = iCount + 1
            end

            if parenSum == 2 or globalFlag then
                estRad = estRad * 2
            elseif sum > 3 then
                estRad = estRad * 1.5
            else
                estRad = estRad + (estRad * 0.25 + (3 * sum))
            end

            local playerAliases = player.getProperty("DPC::aliases") or {}
            data.fakeName = player.getProperty("DPC::unknownAlias") or nil

            local recogName = nil
            local recogPrio = 100

            local isOSB = root.assetJson("/player.config:genericScriptContexts").OpenStarbound ~= nil

            -- recogList for server processing (uses recogList[word])
            local recogList = {}

            -- FezzedOne: Fixed the default priority 0 alias not getting changed after character swaps on xStarbound, OpenStarbound and StarExtensions.
            -- Shouldn't need to use the stock chat nickname (`data.nickname`) anyway in this alias system.
            playerAliases["0"] = world.entityName(player.id())
            -- check for any aliases here and set the highest priority one as the name
            table.sort(playerAliases)
            local quoteTbl = quoteMap(rawText or "")
            local minPrio = 100
            for prio, alias in pairs(playerAliases) do
                -- FezzedOne: Because this is stored as a JSON object, which requires all keys to be strings.
                local prioNum = tonumber(prio)
                -- FezzedOne: Ignore punctuation, escape codes, and duplicate spaces in alias comparisons. Fixes an issue where «I'm Jonny.» wouldn't proc for the alias «Jonny».
                local normalisedAlias = normaliseText(alias)
                -- FezzedOne: Now correctly returns the *highest*-priority matching alias as per the comment, not the lowest.
                -- reno a lower number is higher priority
                if prioNum and quoteTbl[normalisedAlias] and prioNum < minPrio then
                    recogName = tostring(alias)
                    recogPrio = prioNum
                    minPrio = prioNum
                end

                -- go through each word and insert them individually into the table
                for index, value in ipairs(splitStr(normalisedAlias, "%s")) do
                    recogList[value] = true
                end
            end
            -- data.alias is for the alias
            -- data.aliasPrio is for the priority

            if recogName then
                data.alias = recogName
                data.aliasPrio = recogPrio
            end

            data.playerName = xsb and currentPlayerName or world.entityName(player.id())
            -- FezzedOne: Moved these to ensure full recog support in client-side mode.
            data.playerId = player.id()
            data.playerUid = player.uniqueId()
            data.skipRecog = player.getProperty("DPC::skipRecog") or false
            data.recogGroup = player.getProperty("DPC::recogGroup") or false
            data.estRad = estRad

            -- local playerSecret = player.getProperty("DPC::playerCheck") or false
            -- if not playerSecret then
            --     playerSecret = sb.makeUuid()
            --     player.setProperty("DPC::playerCheck", playerSecret)
            --     player.setProperty("DPC:playerCheck", nil)
            -- end
            -- if data.updatedLangs then
            --     data.playerplayerSecret = playerSecret
            -- end

            local recogs = player.getProperty("DPC::recognizedPlayers") or {}
            for uuid, info in pairs(recogs) do
                if info ~= true and info["savedName"] then
                    for index, value in ipairs(splitStr(normaliseText(info["savedName"]), "%s")) do
                        recogList[value] = true
                    end
                end
            end

            rawText = applyRecogToQuotes(rawText, recogList)

            -- data.recogList = recogList

            data.version = 203
            data.ignoreVersion = root.getConfiguration("DPC::ignoreVersion") or nil

            data.globalFlag = globalFlag

            data.volume = player.getProperty("DPC::defaultVolume") or 0

            -- FezzedOne: xStarbound also supports the stuff needed for the server-side message handler.
            data.isOSB = isOSB
            -- player.setProperty("DPC::"..type.."Font",self.fontLib[font])
            data.actionFont = player.getProperty("DPC::generalFont") or nil
            data.quoteFont = player.getProperty("DPC::quoteFont") or nil
            -- sb.logInfo("quoteFont in client is %s",data.quoteFont)
            data.fontW8 = player.getProperty("DPC::quoteWeight") or nil
            -- sb.logInfo("font weight in client is %s",data.fontW8)
            if rawText:find("{") then
                data.defaultComms = player.getProperty("DPC::activeFreq") or nil
            end
            data.emphColor = player.getProperty("DPC::emphColor") or "#d80"
            data.text = rawText
        end
    end
    return data
end

function dynamicprox:onSendMessage(data)
    local currentPlayerName = ""
    if xsb then -- FezzedOne: Needed to ensure the correct default alias is sent on DPC after swapping characters on xStarbound.
        local _, defaultName = getNames()
        currentPlayerName = defaultName or ""
    end

    -- think about running this in local to allow players without the mod to still see messages
    if data.mode == "Prox" then
        local rawText = data.text
        data.content = data.text
        data.text = ""

        local function sendMessageToPlayers()

            sb.logInfo("checking serverValid, which is %s", self.serverValid)
            if self.serverValid == nil then

                local status, resultOrError = pcall(function(data)
                    sb.logInfo("running pcall")
                    local addInfo = {
                        player = player.id(),
                        uuid = player.uniqueId()
                    }
                    starcustomchat.utils.createStagehandWithData("dpcServerHandler", {
                        message = "checkStatus",
                        data = addInfo
                    })
                end, data)
                if status then
                    sb.logInfo("Server plugin loaded successfully.")
                    self.serverValid = true
                else
                    -- set up the client processor
                    sb.logInfo("Server plugin not found, using client processing.")
                    self.serverValid = false
                end
            end

            -- check for alias stuff here
            data.fakeName = player.getProperty("DPC::unknownAlias") or nil
            data.playerName = world.entityName(player.id())


            if self.serverValid then
                starcustomchat.utils.createStagehandWithData("dpcServerHandler", {
                    message = "sendDynamicMessage",
                    data = data
                })
            else
                --send locally to players
            end
            return true -- this should stop global strings from running (which i want in this case)
            -- later on i may make this a client config setting
        end

        local sendMessagePromise = {
            finished = function()
                local status, errorMsg = pcall(sendMessageToPlayers)
                if status then
                    return errorMsg
                else
                    sb.logWarn(
                        "[DynamicProxChat] Error occurred while sending proximity message: %s\n  Message data: %s",
                        errorMsg, data)
                    return true -- FezzedOne: Fixed log spam whenever an error occurs on sending.
                end
            end,
            succeeded = function()
                return true
            end
        }

        promises:add(sendMessagePromise)
        if root.getConfiguration("DPC::chatBubble") or false then
            player.say("...")
        end
        if data.content:find("\"") then
            player.emote("Blabbering")
        end
    end
end

function dynamicprox:formatIncomingMessage(rawMessage)
    local messageFormatter = function(message)
        if message.mode == "Broadcast" and message.connection == 0 and message.text:find("connected") then
            if root.getConfiguration("DPC::showConnection") then
                if message.text:match("disconnected") then
                    message.text = "Player disconnected."
                else
                    message.text = "Player connected."
                end
            else
                message.text = ""
            end

            return message
        end

        if message.mode == "Prox" then
            message.isDpc = true
        end

        local cleanText = message.text:gsub("%^[^^;]-;", "")

        if cleanText:gsub("%s", "") == "" then
            message.text = ""
            return message
        end

        if message.isDpc then
            message.displayName = message.playerName or message.nickname
        end

        -- this is disabled for now since i'd prefer the nickname to appear if it's just you
        -- FezzedOne: The stock nickname is not changed after character swaps. Fixed that issue by not using the stock nickname.
        -- It's now recommended that the character's main name (set with `/setname` on xStarbound or `/identity set name` on
        -- OpenStarbound or StarExtensions) be the character's «canonical» name. E.g., «Jonathan», «Jonathan F. Thompson» or
        -- «Jonathan 'Hammer' Thompson», instead of «Jonny», «Dr. Thompson» or «'Hammer'».
        -- Tip: With this change, you can now save the stock nickname for your OOC username (or whatever else) in non-Dynamic chat,
        -- since it's now completely disconnected from DPC messages. Wanted to add auto-nick for this reason, but that'd cause issues
        -- with servers running StarryPy3k.
        if message.isDpc and message.playerUid == (message.receiverUid or player.uniqueId()) then
            -- allow higher (negative) priority aliases to appear on the message
            -- take from player config instead of the message
            -- in the future, allow players to use the nickname feature on themselves. right now i dont see why it'd be useful to do but whatever
            -- local aliases = player.getProperty("DPC::aliases") or {}
            local _, defaultName = getNames()
            local useName = world.entityName(player.id())
            -- local minPrio = 0

            -- for prio, alias in pairs(aliases) do
            --     if prio < minPrio then
            --         useName = alias
            --     end
            -- end
            message.displayName = useName
        elseif message.isDpc and message.playerUid ~= (message.receiverUid or player.uniqueId()) and
            not message.skipRecog and
            (not message.recogGroup or message.recogGroup ~= player.getProperty("DPC::recogGroup")) then
            -- FezzedOne: Removed this check to add recog support in client-side modes: and root.getConfiguration("dpcOverServer")
            local recoged = {}
            recoged = player.getProperty("DPC::recognizedPlayers") or {}
            local charRecInfo = recoged[message.playerUid] or nil
            if charRecInfo == true then
                charRecInfo = nil
            end
            local useName = message.fakeName or "^#999;???^reset;"
            local playerNicks = player.getProperty("DPC::playerNicks") or {}

            if charRecInfo and charRecInfo.manName then
                playerNicks[message.playerUid] = charRecInfo.savedName
                charRecInfo = nil
                recoged[message.playerUid] = charRecInfo
                player.setProperty("DPC::recognizedPlayers", recoged)
                player.setProperty("DPC::playerNicks", playerNicks)
            end

            if (message.alias and message.aliasPrio) and (not charRecInfo or (charRecInfo and
                (charRecInfo.manName or (message.aliasPrio <= charRecInfo.aliasPrio) and message.alias ~=
                    charRecInfo.savedName))) then -- if conditions are met
                local normalisedAlias = normaliseText(message.alias)
                local tokens = quoteMap(message.text or "")
                if tokens[normalisedAlias] then -- FezzedOne: Check that the alias isn't garbled first.
                    -- apply new thing or create entry, should work either way
                    charRecInfo = {
                        ["savedName"] = message.alias,
                        ["manName"] = nil,
                        ["aliasPrio"] = message.aliasPrio,
                        ["timestamp"] = message.time
                    }
                    recoged[message.playerUid] = charRecInfo
                    if xsb then
                        world.sendEntityMessage(message.receiverId or player.id(), "dpcSetRecogs", recoged)
                    else
                        player.setProperty("DPC::recognizedPlayers", recoged)
                    end
                end
            end

            if charRecInfo then
                useName = charRecInfo.savedName
            end

            local nickName = nil

            local nickCandidate = playerNicks[message.playerUid]
            if nickCandidate and normaliseText(useName) ~= normaliseText(nickCandidate) then
                nickName = " ^font=M;^#999;(" .. nickCandidate .. "^#999;)^reset;"
            end

            message.displayName = useName .. (nickName or "")
        end

        if message.displayName == "" then
            message.displayName = "^#999;???^reset;"
        end

        -- remove this once a server update looks to be pushed.
        -- message.text = message.text:gsub("_", "") --this needs to be here, otherwise people will put autotune crying baby to shame
        return message
    end
    -- return messageFormatter(rawMessage)

    local messageData = copy(rawMessage)
    local rawText = messageData.text
    local status, messageOrError = pcall(messageFormatter, rawMessage)
    if status then
        return messageOrError
    else
        sb.logWarn("[DynamicProxChat] Error occurred while formatting proximity message: %s\n  Message data: %s",
            messageOrError, messageData)
        rawMessage.text = rawText
        return rawMessage
    end
end

function dynamicprox:onReceiveMessage(message) -- here for logging the message you receive, just in case you wanted to save it or something
    if message.connection ~= 0 and (message.sourceId or message.mode == "Prox" or message.mode == "ProxSecondary") then
        sb.logInfo("Chat: <%s> %s", message.nickname:gsub("%^[^^;]-;", ""), message.text:gsub("%^[^^;]-;", ""))
    end
end

function dynamicprox:onModeChange(mode)
    if mode == "Prox" and not (player.getProperty("DPC::firstLoad") or false) then
        chat.addMessage(
            "^CornFlowerBlue;Dynamic Prox Chat^reset;: Before getting started with this mod, be aware that currently the mod is set up only with server configurations. If the chat mod doesn't work, odds are it isn't mounted on the server. To use the language system, use ^cyan;/learnlang^reset; to manage languages for chat. This notice will only appear once, but its information can be found on the mod page.")
        if self.serverDefault then
            root.setConfiguration("dpcOverServer", true)
        end
        player.setProperty("DPC::firstLoad", true)
    end
    setTextHint(mode)
end
