require("/interface/scripted/starcustomchat/plugin.lua")

-- Need this to copy message tables.
local function copy(obj, seen)
    if type(obj) ~= "table" then return obj end
    if seen and seen[obj] then return seen[obj] end
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
    name = "dynamicprox",
})

local DynamicProxPrefix = "^DynamicProx,reset;"
local AuthorIdPrefix = "^author="
local DefaultLangPrefix = ",defLang="
local TagSuffix = ",reset;"
local AnnouncementPrefix = "^clear;!!^reset;"
local randSource = sb.makeRandomSource()
local DEBUG = false
local DEBUG_PREFIX = "[DynamicProx::Debug] "

-- FezzedOne: From FezzedTech.
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
            if not i then return nil end
            if i == 1 then
                rolls = 1
            else
                rolls = tonumber(string.sub(die, 0, (j - 1)))
            end

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

        -- Make sure dice are properly random.
        --changed RNG to sb.makerandomsource to keep other rng features untouched
        randSource:init(math.floor(os.clock() * 100000000000))

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


function dynamicprox:init()
    self:_loadConfig()
    local currentName, _ = getNames()
    -- FezzedOne: Check to ensure this callback EXISTS first, Captain Salt!
    if player.setNametag then
        player.setNametag(currentName or "")
    end
    root.setConfiguration("DPC::cursorChar", nil)
    root.setConfiguration("DPC::ignoreVersion", nil)

    self.unchecked = true
end

function dynamicprox:uninit()
    -- FezzedOne: Ensures the player's name tag on OpenStarbound isn't left invisible or as a custom tag if DPC is uninstalled.
    if player.setNametag then player.setNametag() end
end

function dynamicprox:addCustomCommandPreview(availableCommands, substr)
    if string.find("/newlangitem", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/newlangitem",
            description = "commands.newlangitem.desc",
            data = "/newlangitem",
            color = nil,
        })
    elseif string.find("/learnlang", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/learnlang",
            description = "commands.learnlang.desc",
            data = "/learnlang",
        })
    elseif string.find("/showlangs", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/showlangs",
            description = "commands.showlangs.desc",
            data = "/showlangs",
        })
    elseif string.find("/langlist", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/langlist",
            description = "commands.langlist.desc",
            data = "/langlist",
        })
    elseif string.find("/editlang", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/editlang",
            description = "commands.editlang.desc",
            data = "/editlang",
        })
    elseif string.find("/resetlangs", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/resetlangs",
            description = "commands.resetlangs.desc",
            data = "/resetlangs",
        })
    elseif string.find("/defaultlang", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/defaultlang",
            description = "commands.defaultlang.desc",
            data = "/defaultlang",
        })
    elseif string.find("/addtypo", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/addtypo",
            description = "commands.addtypo.desc",
            data = "/addtypo",
        })
    elseif string.find("/removetypo", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/removetypo",
            description = "commands.removetypo.desc",
            data = "/removetypo",
        })
    elseif string.find("/toggletypos", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/toggletypos",
            description = "commands.toggletypos.desc",
            data = "/toggletypos",
        })
    elseif string.find("/checktypo", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/checktypo",
            description = "commands.checktypo.desc",
            data = "/checktypo",
        })
    elseif string.find("/showtypos", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/showtypos",
            description = "commands.showtypos.desc",
            data = "/showtypos",
        })
    elseif string.find("/togglehints", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/togglehints",
            description = "commands.togglehints.desc",
            data = "/togglehints",
        })
    elseif string.find("/proxlocal", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/proxlocal",
            description = "commands.proxlocal.desc",
            data = "/proxlocal",
        })
    elseif string.find("/sendlocal", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/sendlocal",
            description = "commands.sendlocal.desc",
            data = "/sendlocal",
        })
    elseif string.find("/dynamicsccrp", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/dynamicsccrp",
            description = "commands.dynamicsccrp.desc",
            data = "/dynamicsccrp",
        })
    elseif string.find("/proxooc", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/proxooc",
            description = "commands.proxooc.desc",
            data = "/proxooc",
        })
    elseif string.find("/toggleradio", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/toggleradio",
            description = "commands.toggleradio.desc",
            data = "/toggleradio",
        })
    elseif string.find("/setfreq", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/setfreq",
            description = "commands.setfreq.desc",
            data = "/setfreq",
        })
    elseif string.find("/getfreq", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/getfreq",
            description = "commands.getfreq.desc",
            data = "/getfreq",
        })
    elseif string.find("/dpcserver", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/dpcserver",
            description = "commands.dpcserver.desc",
            data = "/dpcserver",
        })
    elseif string.find("/chatbubble", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/chatbubble",
            description = "commands.chatbubble.desc",
            data = "/chatbubble",
        })
    elseif string.find("/skiprecog", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/skiprecog",
            description = "commands.skiprecog.desc",
            data = "/skiprecog",
        })
    elseif string.find("/resetrecog", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/resetrecog",
            description = "commands.resetrecog.desc",
            data = "/resetrecog",
        })
    elseif string.find("/grouprecog", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/grouprecog",
            description = "commands.grouprecog.desc",
            data = "/grouprecog",
        })
    elseif string.find("/font", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/font",
            description = "commands.font.desc",
            data = "/font",
        })
    elseif string.find("/chid", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/chid",
            description = "commands.chid.desc",
            data = "/chid",
        })
    elseif string.find("/addnick", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/addnick",
            description = "commands.addnick.desc",
            data = "/addnick",
        })
    elseif string.find("/clearnick", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/clearnick",
            description = "commands.clearnick.desc",
            data = "/clearnick",
        })
    elseif string.find("/addalias", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/addalias",
            description = "commands.addalias.desc",
            data = "/addalias",
        })
    elseif string.find("/resetalias", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/resetalias",
            description = "commands.resetalias.desc",
            data = "/resetalias",
        })
    elseif string.find("/showalias", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/showalias",
            description = "commands.showalias.desc",
            data = "/showalias",
        })
    elseif string.find("/apply", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/apply",
            description = "commands.apply.desc",
            data = "/apply",
        })
    elseif string.find("/nametag", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/nametag",
            description = "commands.nametag.desc",
            data = "/nametag",
        })
    elseif string.find("/ignoreversion", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/ignoreversion",
            description = "commands.ignoreversion.desc",
            data = "/ignoreversion",
        })
    elseif xsb and string.find("/nametag", substr, nil, true) then
        table.insert(availableCommands, {
            name = "/setname",
            description = "commands.setname.desc",
            data = "/setname",
        })
    end
end

local function splitStr(inputstr, sep) --replaced this with a less efficient linear search in order to be system agnostic
    if sep == nil then sep = "%s" end
    local arg = ""
    local t = {}
    local qFlag = false
    for c in inputstr:gmatch(".") do
        if c:match(sep) and not qFlag and #arg > 0 then
            arg = trim(arg)
            table.insert(t, arg)
            arg = ""
        elseif c == '"' then --"test word" 1 makes "test word" and " 1"
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
        local langItem = player.getItemWithParameter("defaultLang", true) --checks for an item with the "defaultLang" parameter
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
    local autoCorVal = (root.getConfiguration("DPC::typos") and root.getConfiguration("DPC::typos")["typosActive"] and "on") or
        "off"
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

--this messagehandler function runs if the chat preview exists
function dynamicprox:registerMessageHandlers(shared) --look at this function in irden chat's editchat thing
    starcustomchat.utils.setMessageHandler("/proxdebug", function(_, _, data)
        if string.lower(data) == "on" then
            DEBUG = true
            return "^green;ENABLED^reset; debug mode for Dynamic Proximity Chat"
        elseif string.lower(data) == "off" then
            DEBUG = false
            return "^red;DISABLED^reset; debug mode for Dynamic Proximity Chat"
        else
            return "Debug mode for Dynamic Proximity Chat is "
                .. (DEBUG and "^green;ENABLED" or "^red;DISABLED")
                .. "^reset;. To change this setting, pass ^orange;on^reset; or ^orange;off^reset; to this command."
        end
    end)
    starcustomchat.utils.setMessageHandler("/dynamicsccrp", function(_, _, data)
        if string.lower(data) == "on" then
            root.setConfiguration("DynamicProxChat::handleSccrpProx", true)
            return "^green;ENABLED^reset; handling SCCRP Proximity messages as dynamic proximity chat"
        elseif string.lower(data) == "off" then
            root.setConfiguration("DynamicProxChat::handleSccrpProx", false)
            return "^red;DISABLED^reset; handling SCCRP Proximity messages as dynamic proximity chat"
        else
            local enabled = root.getConfiguration("DynamicProxChat::handleSccrpProx") or false
            return "Handling SCCRP Proximity messages as dynamic proximity chat is "
                .. (enabled and "^green;ENABLED" or "^red;DISABLED")
                .. "^reset;. To change this setting, pass ^orange;on^reset; or ^orange;off^reset; to this command."
        end
    end)
    starcustomchat.utils.setMessageHandler("/proxooc", function(_, _, data)
        if string.lower(data) == "on" then
            root.setConfiguration("DynamicProxChat::proximityOoc", true)
            return "^green;ENABLED^reset; handling (( )) as range-limited OOC chat"
        elseif string.lower(data) == "off" then
            root.setConfiguration("DynamicProxChat::proximityOoc", false)
            return "^red;DISABLED^reset; handling (( )) as range-limited OOC chat"
        else
            local enabled = root.getConfiguration("DynamicProxChat::proximityOoc") or false
            return "Handling (( )) as range-limited OOC chat is "
                .. (enabled and "^green;ENABLED" or "^red;DISABLED")
                .. "^reset;. To change this setting, pass ^orange;on^reset; or ^orange;off^reset; to this command."
        end
    end)
    starcustomchat.utils.setMessageHandler("/proxlocal", function(_, _, data)
        if string.lower(data) == "on" then
            root.setConfiguration("DynamicProxChat::localChatIsProx", true)
            return "^green;ENABLED^reset; handling local chat as proximity chat"
        elseif string.lower(data) == "off" then
            root.setConfiguration("DynamicProxChat::localChatIsProx", false)
            return "^red;DISABLED^reset; handling local chat as proximity chat"
        else
            local enabled = root.getConfiguration("DynamicProxChat::localChatIsProx") or false
            return "Handling local chat as proximity chat is "
                .. (enabled and "^green;ENABLED" or "^red;DISABLED")
                .. "^reset;. To change this setting, pass ^orange;on^reset; or ^orange;off^reset; to this command."
        end
    end)
    starcustomchat.utils.setMessageHandler("/sendlocal", function(_, _, data)
        if string.lower(data) == "on" then
            root.setConfiguration("DynamicProxChat::sendProxChatInLocal", true)
            return "^green;ENABLED^reset; sending proximity chat as local chat"
        elseif string.lower(data) == "off" then
            root.setConfiguration("DynamicProxChat::sendProxChatInLocal", false)
            return "^red;DISABLED^reset; sending proximity chat as local chat"
        else
            local enabled = root.getConfiguration("DynamicProxChat::sendProxChatInLocal") or false
            return "Sending proximity chat as local chat is "
                .. (enabled and "^green;ENABLED" or "^red;DISABLED")
                .. "^reset;. To change this setting, pass ^orange;on^reset; or ^orange;off^reset; to this command."
        end
    end)
    starcustomchat.utils.setMessageHandler("/showtypos", function(_, _, data)
        local typoTable = root.getConfiguration("DPC::typos") or {}
        if typoTable == nil then return "You have no corrections or typos saved. Use /addtypo to make one." end

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

        if tyTableLen == 0 then rtStr = "You have no corrections or typos saved. Use /addtypo to make one." end
        return rtStr
    end)
    starcustomchat.utils.setMessageHandler("/checktypo", function(_, _, data) return checktypo(false) end)
    starcustomchat.utils.setMessageHandler("/toggletypos", function(_, _, data) return checktypo(true) end)
    starcustomchat.utils.setMessageHandler("/addtypo", function(_, _, data)
        --add a typo correction to the typos table in player data, or replace it if it already exists
        -- local typo, correction = chat.parseArguments(data)
        local splitArgs = splitStr(data, " ")
        local typo, correction = splitArgs[1], splitArgs[2]

        if typo == nil or correction == nil then return "Missing arguments for /addtypo, need {typo, correction}" end
        local typoTable = root.getConfiguration("DPC::typos") or {}

        typoTable[typo] = correction
        root.setConfiguration("DPC::typos", typoTable)
        return 'Typo "' .. typo .. '" added as "' .. correction .. '".'
    end)
    starcustomchat.utils.setMessageHandler("/removetypo", function(_, _, data)
        --add a typo correction to the typos table in player data, or replace it if it already exists
        -- local typo = chat.parseArguments(data)
        local typo = splitStr(data, " ")[1]
        local typoTable = player.getProperty("typos", false)

        if typo == nil then return "Missing arguments for /removetypo, need {typo}" end

        if typoTable then
            typoTable[typo] = nil
            root.setConfiguration("DPC::typos", typoTable)
            return 'Typo "' .. typo .. '" removed.'
        else
            return "No typos found."
        end
    end)

    starcustomchat.utils.setMessageHandler("/newlangitem", function(_, _, data)
        local sendOverServer = root.getConfiguration("dpcOverServer") or false

        if sendOverServer then
            return "Lang items aren't supported for server processing, use /learnlang instead."
        end
        -- FezzedOne: Whitespace in language names is now supported (only on xStarbound).
        -- Okay, Captain Salt, fair enough. I'll do it only on xSB because oSB and SE convert argument types implicitly.
        local splitArgs = xsb and chat.parseArguments(data) or splitStr(data, " ")
        local langName, langKey, langLevel, isDefault, color =
            (splitArgs[1] or nil),
            (splitArgs[2] or nil),
            (tonumber(splitArgs[3]) or 10),
            (splitArgs[4] or nil),
            (splitArgs[5] or nil)

        if langKey == nil or langName == nil then
            return "Missing arguments for /newlangitem, need {name, code, count, automatic, [hex color]}"
        end
        if isDefault == nil then isDefault = false end

        if color ~= nil then
            if not color:match("#") then color = "#" .. color end
            if #color > 7 then color = color:sub(1, 7) end
        end
        langKey = langKey:upper()
        langKey = langKey:gsub("[%[%]]", "")

        langLevel = math.max(1, math.min(langLevel, 10))
        local itemName = "inferiorbrain"
        local itemDesc = "Allows the user to understand " .. langName .. " [" .. langKey .. "]"
        local shortDesc = "[" .. langKey .. "] " .. langName .. " Aptitude"
        local itemRarity = "Uncommon"
        local itemImage = "inferiorbrain.png"

        if isDefault ~= nil and (isDefault == "true") then
            isDefault = true
            itemRarity = "Rare"
            itemName = "brain"
            itemDesc = "!Default, will automatically apply! " .. itemDesc
            itemImage = "brain.png"
        else
            isDefault = false
        end

        local itemData = {
            name = itemName,
            count = langLevel,
            parameters = {
                inventoryIcon = itemImage,
                description = itemDesc,
                rarity = itemRarity,
                maxStack = 10,
                shortdescription = shortDesc,
                langKey = langKey,
                defaultLang = isDefault,
                color = color,
            },
        }

        player.giveItem(itemData)
        return "Language " .. langName .. " added, use [" .. langKey .. "] to use it."
    end)
    starcustomchat.utils.setMessageHandler("/learnlang", function(_, _, data)
        local sendOverServer = root.getConfiguration("dpcOverServer") or false
        if not sendOverServer then
            return "Lang commands aren't supported for client processing, use /newlangitem instead."
        end

        local splitArgs = splitStr(data, " ")
        local langKey, langLevel, langName, color, preset =
            (splitArgs[1] or nil),
            (tonumber(splitArgs[2]) or 10),
            (splitArgs[3] or nil),
            (splitArgs[4] or nil),
            (splitArgs[5] or nil)


        if not langKey or #langKey < 1 then
            return "Missing arguments for /learnlang, need {code, prof, [name], [hex color], [preset]}"
        end

        langKey = langKey:upper()
        langKey = langKey:gsub("[%[%]]", "")

        local learnedLangs = player.getProperty("DPC::learnedLangs") or {}
        if color == "random" or color == "false" or color == nil then
            local hexDigits =
            { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" }
            -- local randSource = sb.makeRandomSource()
            local hexMin = 4 --make the minimum so people can still see stuff in case of weird random shit where you get lots of low values

            --totally random value here, since it's generating for a server file
            randSource:init()
            color = ""
            while #color < 6 do
                local randNum1 = randSource:randInt(hexMin, #hexDigits)
                local randNum2 = randSource:randInt(hexMin, #hexDigits)
                color = color .. hexDigits[randNum1] .. hexDigits[randNum2]
                table.remove(hexDigits, randNum1) --remove the primary value, since the secondary is not as strong i'm okay with it being re-used
            end
            color = "#" .. color
        else
            if not color:match("#") then color = "#" .. color end
            if #color > 7 then color = color:sub(1, 7) end
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
        starcustomchat.utils.createStagehandWithData("dpcServerHandler",
            { message = "addLang", data = addInfo })
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
        --send a stagehand request to see a list of all languages on the server
        local addInfo = {
            player = player.id(),
            uuid = player.uniqueId()
        }
        starcustomchat.utils.createStagehandWithData("dpcServerHandler",
            { message = "langlist", data = addInfo })
    end)
    starcustomchat.utils.setMessageHandler("/editlang", function(_, _, data)
        --send a stagehand request to see a list of all languages on the server
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
        starcustomchat.utils.createStagehandWithData("dpcServerHandler",
            { message = "editlang", data = addInfo })
    end)
    starcustomchat.utils.setMessageHandler("/resetlangs", function(_, _, data)
        local sendOverServer = root.getConfiguration("dpcOverServer") or false
        if not sendOverServer then
            return "Lang commands aren't supported for client processing, use /newlangitem instead."
        end
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
                playerSecret = playerSecret,
            }
            starcustomchat.utils.createStagehandWithData("dpcServerHandler",
                { message = "resetLangs", data = addInfo })
            setTextHint("Prox")
        else
            return "Missing confirmation: Ensure that \"reset\" is included in this command to confirm the reset."
        end
    end)
    starcustomchat.utils.setMessageHandler("/defaultlang", function(_, _, data)
        local sendOverServer = root.getConfiguration("dpcOverServer") or false
        if not sendOverServer then
            return "Lang commands aren't supported for client processing, use /newlangitem instead."
        end
        local splitArgs = splitStr(data, " ") or nil
        local defaultCode = splitArgs[1] or nil

        if #defaultCode < 1 or not defaultCode then
            local defLang = player.getProperty("DPC::defaultLang") or nil
            if defLang then
                return "Current default language code is [" .. player.getProperty("DPC::defaultLang") .. "]."
            end
            return "You have no default language set."
        end
        --set the default key in the learnedlangs table
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
        starcustomchat.utils.createStagehandWithData("dpcServerHandler",
            { message = "defaultLang", data = addInfo })

        player.setProperty("DPC::defaultLang", defaultCode)
        setTextHint("Prox") --we're gonna assume that the server works
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
            local sendOverServer = root.getConfiguration("dpcOverServer") or false
            local radioState = player.getProperty("DPC::radioState")
            if radioState == nil then
                radioState = true
            end
            player.setProperty("DPC::radioState", not radioState)
            setTextHint("Prox")
            if sendOverServer then
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
                starcustomchat.utils.createStagehandWithData("dpcServerHandler",
                    { message = "toggleradio", data = addInfo })
                return
            else
                return "Your radio is now " .. radioState and "on." or "off."
            end
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/getfreq", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local activeFreq = player.getProperty("DPC::activeFreq") or nil
            if activeFreq then
                local freqAlias = (activeFreq["alias"] and "(" .. activeFreq["alias"] .. ")") or "(no alias)"
                return "Active frequency is: " .. activeFreq["freq"] .. " " .. freqAlias .. "."
            else
                return "No frequency has been set, use /setfreq to make one."
            end
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/setfreq", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local args = splitStr(data, " ")
            local newFreq, freqAlias = args[1] or nil, args[2] or nil
            if not tonumber(newFreq) then
                return "Invalid frequency given, use a number instead."
            end

            --freq is valid, pass it to the player property to override
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

            local sendOverServer = root.getConfiguration("dpcOverServer") or false
            if sendOverServer then
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
                starcustomchat.utils.createStagehandWithData("dpcServerHandler",
                    { message = "setfreq", data = addInfo })
                return
            end

            local freqAlias = (activeFreq["alias"] and "(" .. activeFreq["alias"] .. ")") or "(no alias)"
            return "Active frequency is now: " .. activeFreq["freq"] .. " " .. freqAlias .. "."
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    starcustomchat.utils.setMessageHandler("/dpcserver", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local splitArgs = splitStr(data, " ")
            local clSetting = splitArgs[1]
            local clientForced = splitArgs[2] == "forced"
            local retStr = ""
            if clSetting == "true" or clSetting == "on" or clSetting == "enabled" then
                root.setConfiguration("dpcOverServer", true)
                retStr = "DPC server handling is ^green;enabled^reset;."
            elseif #clSetting >= 1 then
                root.setConfiguration("dpcOverServer", false)
                retStr = "DPC server handling is ^red;disabled^reset;."
            else
                local curConfig = root.getConfiguration("dpcOverServer") or false
                if curConfig then
                    curConfig = "^green;enabled^reset;"
                else
                    curConfig = "^red;disabled^reset;"
                end
                retStr = "DPC server handling is " .. curConfig .. "."
            end

            if clientForced then
                retStr = retStr .. " Client mode forced."
                root.setConfiguration("DPC::forcedClient", true)
            else
                root.setConfiguration("DPC::forcedClient", nil)
            end
            return retStr
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
            if bubbleSetting then retStr = "" end

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
            if skipStatus then retStr = "" end

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
            player.setProperty("DPC::recogGroup", nil)
            return "Your recognized characters and groups have been reset."
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
            --no font support yet
            -- if true then
            --     return "Fonts aren't supported (yet), wait until [next version]"
            -- end
            --1st arg is type, 2nd arg is font
            local splitArgs = splitStr(data, " ")
            local type, font = splitArgs[1] or nil, splitArgs[2] or nil


            if type ~= "general" and type ~= "quote" then
                return "Incorrect type supplied, use \"general\" or \"quote\"."
            end

            if font == "reset" or font == "exo" then
                --apply player property to tell people what font is used for general/quotes
                player.setProperty("DPC::" .. type .. "Font", nil)
                player.setProperty("DPC::" .. type .. "Weight", nil)
                return "Reset " .. type .. " font."
            end

            -- sb.logInfo("font is %s, lib entry is %s", font, self.fontLib[font])

            if self.fontLib and self.fontLib[font] then
                --apply player property to tell people what font is used for general/quotes
                player.setProperty("DPC::" .. type .. "Font", self.fontLib[font]["font"])
                if self.fontLib[font]["weight"] then
                    player.setProperty("DPC::" .. type .. "Weight", self.fontLib[font]["weight"])
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
            root.setConfiguration("DPC::cursorChar", chidTable)
            return "Character selected."
        end, data)
        if status then
            return resultOrError
        else
            sb.logError("Error occurred while running DPC command: %s", resultOrError)
            return "^red;Error occurred while running command, check log"
        end
    end)
    --add a nickanme command that lets you apply a custom name to the selected chid character
    starcustomchat.utils.setMessageHandler("/addnick", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local splitArgs = splitStr(data, " ")
            local newNick = splitArgs[1] or nil
            if not newNick or #tostring(newNick) < 1 then
                return "No nickname provided, try again."
            end

            local chid = root.getConfiguration("DPC::cursorChar") or nil
            if not chid then
                return "No character selected, move your cursor over one and use /chid to select them."
            end
            chid = chid.UUID
            --add the nickname
            --[[
            {
            uuid: {
                savedName: "name",
                manName: "/addnick name", (if populated, prevent alias overwrites for higher priority aliases)
                aliasPrio: int (0 is for real name, can make negative ints)
            },
            }
        ]]
            local recoged = player.getProperty("DPC::recognizedPlayers") or {}
            recoged[chid] = {
                ["savedName"] = tostring(newNick),
                ["manName"] = true,
                ["aliasPrio"] = -10
            }
            player.setProperty("DPC::recognizedPlayers", recoged)
            root.setConfiguration("DPC::cursorChar", nil)

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
            local chid = root.getConfiguration("DPC::cursorChar") or nil
            if not chid then
                return "No character selected, move your cursor over one and use /chid to select them."
            end
            chid = chid.UUID
            local recoged = player.getProperty("DPC::recognizedPlayers") or {}
            if recoged[chid] then
                recoged[chid] = nil
                player.setProperty("DPC::recognizedPlayers", recoged)
                root.setConfiguration("DPC::cursorChar", nil)
                return "Reset nickname for character, selection released."
            else
                return "No nickname for this character exists."
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
            --the different splitting caused problems with negative numbers, reverted
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
            --print out all of the aliases
            local retStr = ""
            local playerAliases = player.getProperty("DPC::aliases") or nil
            if not playerAliases then
                return "No aliases exist, use /addalias to make some."
            end


            for prioNum = -10, 10, 1 do
                local prio = tostring(prioNum)
                local alias = playerAliases[prio]
                if prioNum == 0 then
                    local _, defaultName = getNames()
                    local canonicalName = xsb and defaultName or world.entityName(player.id())
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
    --add /apply with the ability to use the chid or everyone within LOS and 30 tiles
    starcustomchat.utils.setMessageHandler("/apply", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            local aliasPrio = splitStr(data, " ")[1] or "0"
            local chid = root.getConfiguration("DPC::cursorChar") or nil
            if not chid then
                return "No character selected, move your cursor over one and use /chid to select them."
            end
            local playerAliases = player.getProperty("DPC::aliases") or {}
            local aliasInfo = {}

            if playerAliases and tonumber(aliasPrio) and playerAliases[aliasPrio] then
                aliasInfo = {
                    ["alias"] = tostring(playerAliases[aliasPrio]),
                    ["priority"] = tonumber(aliasPrio),
                    ["UUID"] = player.uniqueId()
                }
            end


            -- FezzedOne: This is ASYNCHRONOUS on players owned by other clients and will thus always jump to the `else` for them, showing the failure even if it succeeds.
            --[[
            if world.sendEntityMessage(chid.entityId, "showRecog", aliasInfo):result() then
                return chid.name .. " now recognizes you."
            else
                return "Recognition failed (this is bad it shouldn't happen)."
            end
            ]]

            -- FezzedOne: Use this instead!
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
            if xsb then
                local splitArgs = chat.parseArguments(data)
                local newName = splitArgs[1]
                if (not newName) or newName == "" then
                    player.setName("")
                    status.setStatusProperty("currentName", nil)
                    return "Cleared name tag."
                else
                    player.setName(tostring(newName))
                    status.setStatusProperty("currentName", tostring(newName))
                    return "Set name tag to '" .. tostring(newName) .. "'."
                end
            elseif root.assetJson("/player.config:genericScriptContexts").OpenStarbound ~= nil and player.setNametag then
                local newName = chat.parseArguments(data)
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

    -- FezzedOne: Added /setname for xStarbound.
    starcustomchat.utils.setMessageHandler("/setname", function(_, _, data)
        local status, resultOrError = pcall(function(data)
            if xsb then
                local splitArgs = chat.parseArguments(data)
                local newName = splitArgs[1]
                if not newName then
                    return "Must specify a character name!"
                else
                    status.setStatusProperty("defaultName", tostring(newName))
                    return "Set character name to '" .. tostring(newName) .. "'."
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
                --close out quote and add to return string
                returnStr = returnStr .. quoteBuffer
                quoteBuffer = ""
                isQuote = false
            else
                --turn quote collection on
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
            if endIdx > numWords then break end

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

function dynamicprox:formatOutcomingMessage(data)
    local currentPlayerName = ""
    if xsb then -- FezzedOne: Needed to ensure the correct default alias is sent on DPC after swapping characters on xStarbound.
        local _, defaultName = getNames()
        currentPlayerName = defaultName or ""
    end

    --think about running this in local to allow players without the mod to still see messages
    if data.mode == "Prox" then
        local sendOverServer = root.getConfiguration("dpcOverServer") or false
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
            elseif not sendOverServer and c == "|" then
                local fStart = cInd
                local fEnd = rawText:find("|", cInd + 1)

                if fStart ~= nil and fEnd ~= nil then
                    -- FezzedOne: Replaced dice roller with the more flexible one from FezzedTech.
                    local diceResults = rawText:sub(fStart + 1, fEnd)
                    diceResults = diceResults:gsub("[ ]*", ""):gsub(
                        "(.-)[,|]",
                        function(die) return tostring(rollDice(die) or "n/a") .. ", " end
                    )
                    newStr = newStr .. "|" .. diceResults:sub(1, -3) .. "|"
                    cInd = fEnd
                else
                    newStr = newStr .. "|"
                end
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
            local defaultKey = getDefaultLang(sendOverServer)
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
                if parenSum == 3 then globalFlag = true end

                local i = rawText:sub(iCount, iCount)
                local langEnd = rawText:find("]", iCount)
                debugStr = debugStr .. i
                -- if langEnd then langEnd = langEnd - 1 end
                if i == "\\" then -- FezzedOne: Ignore escaped characters.
                    iCount = iCount + 1
                elseif i == "+" then
                    sum = sum + 1
                elseif i == "(" then
                    if rawText:sub(iCount + 1, iCount + 1) == "(" then inOoc = true end
                    parenSum = parenSum + 1
                elseif i == "<" then
                    if rawText:sub(iCount + 1, iCount + 1) == "<" then inOoc = true end
                elseif i == ")" then
                    if rawText:sub(iCount + 1, iCount + 1) == ")" then inOoc = false end
                elseif i == ">" then
                    if rawText:sub(iCount + 1, iCount + 1) == ">" then inOoc = false end
                elseif i == "{" and rawText:find("}", iCount) ~= nil then
                    globalFlag = true
                elseif i == "[" and langEnd ~= nil then                                --use this flag to check for default languages. A string without any noise won't have any language support
                    if (not inOoc) and rawText:sub(iCount + 1, iCount + 1) ~= "[" then -- FezzedOne: If `[[` is detected, don't parse it as a language key.
                        local langKey, commKey
                        -- local commKeySubstitute = nil
                        -- local legalCommKey = true
                        if rawText:sub(iCount, langEnd) == "[]" then --checking for []
                            langKey = defaultKey
                            rawText = rawText:gsub("%[%]", "[" .. defaultKey .. "]")
                        else
                            langKey = rawText:gsub("[%(%)%.%%%+%-%*%?%[%^%$]", function(s) return "%" .. s end)
                        end
                        if langKey then
                            local upperKey = langKey:upper()
                            --if sendoverserver is on, this returns a prof value. Otherwise it returns an item. Either way it doesn't get checked later so that's fine
                            local langItem = (sendOverServer and player.getProperty("DPC::learnedLangs")) or
                                player.getItemWithParameter("langKey", upperKey)
                            if langItem == nil and upperKey ~= "!!" then
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

            --recogList for server processing (uses recogList[word])
            local recogList = {}

            -- FezzedOne: Fixed the default priority 0 alias not getting changed after character swaps on xStarbound, OpenStarbound and StarExtensions.
            -- Shouldn't need to use the stock chat nickname (`data.nickname`) anyway in this alias system.
            playerAliases["0"] = xsb and currentPlayerName or world.entityName(player.id())
            --check for any aliases here and set the highest priority one as the name
            table.sort(playerAliases)
            local quoteTbl = quoteMap(rawText or "")
            local minPrio = 100
            for prio, alias in pairs(playerAliases) do
                -- FezzedOne: Because this is stored as a JSON object, which requires all keys to be strings.
                local prioNum = tonumber(prio)
                -- FezzedOne: Ignore punctuation, escape codes, and duplicate spaces in alias comparisons. Fixes an issue where «I'm Jonny.» wouldn't proc for the alias «Jonny».
                local normalisedAlias = normaliseText(alias)
                -- FezzedOne: Now correctly returns the *highest*-priority matching alias as per the comment, not the lowest.
                --reno a lower number is higher priority
                if prioNum and quoteTbl[normalisedAlias] and prioNum < minPrio then
                    recogName = tostring(alias)
                    recogPrio = prioNum
                    minPrio = prioNum
                end

                --go through each word and insert them individually into the table
                for index, value in ipairs(splitStr(normalisedAlias, "%s")) do
                    recogList[value] = true
                end
            end
            --data.alias is for the alias
            --data.aliasPrio is for the priority

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

            if sendOverServer then
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

                data.recogList = recogList

                data.version = 172
                data.ignoreVersion = root.getConfiguration("DPC::ignoreVersion") or nil

                data.estRad = estRad
                data.globalFlag = globalFlag
                -- FezzedOne: xStarbound also supports the stuff needed for the server-side message handler.
                data.isOSB = (not not xsb) or isOSB
                -- player.setProperty("DPC::"..type.."Font",self.fontLib[font])
                data.actionFont = player.getProperty("DPC::generalFont") or nil
                data.quoteFont = player.getProperty("DPC::quoteFont") or nil
                data.fontW8 = player.getProperty("DPC::quoteWeight") or nil
                if rawText:find("{") then
                    data.defaultComms = player.getProperty("DPC::activeFreq") or nil
                end
            end
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

    --think about running this in local to allow players without the mod to still see messages
    if data.mode == "Prox" then
        local rawText = data.text
        data.content = data.text
        data.text = ""
        local sendOverServer = root.getConfiguration("dpcOverServer") or false


        local function sendMessageToPlayers()
            local position = player.id() and world.entityPosition(player.id())
            local players = {}
            local estRad = data.estRad

            if not sendOverServer then
                players = world.playerQuery(position, estRad, {
                    boundMode = "position",
                })
            end

            -- FezzedOne: Added a setting that allows proximity chat to be sent as local chat for compatibility with «standard» local chat.
            -- Chat sent this way is prefixed so that it always shows up as proximity chat for those with the mod installed.
            local chatTags = AuthorIdPrefix
                .. tostring(player.id())
                .. DefaultLangPrefix
                .. tostring(data.defaultLang)
                .. TagSuffix

            local globalOocStrings = {}
            if not sendOverServer then
                data.text = data.text:gsub("\\%(%(%(", "(^;(("):gsub("%(%(%((.-)%)%)%)", function(s)
                    table.insert(globalOocStrings, s)
                    return ""
                end)
            end
            local globalStrings = {}
            if not sendOverServer then
                rawText = rawText:gsub("\\{{", "{^;{"):gsub("{{(.-)}}", function(s)
                    table.insert(globalStrings, s)
                    return ""
                end)
            end

            --check for alias stuff here
            data.fakeName = player.getProperty("DPC::unknownAlias") or nil
            data.playerName = xsb and currentPlayerName or world.entityName(player.id())

            local isOSB = root.assetJson("/player.config:genericScriptContexts").OpenStarbound ~= nil

            if sendOverServer then
                starcustomchat.utils.createStagehandWithData("dpcServerHandler",
                    { message = "sendDynamicMessage", data = data })
                return true --this should stop global strings from running (which i want in this case)
                --later on i may make this a client config setting
            elseif root.getConfiguration("DynamicProxChat::sendProxChatInLocal") then
                -- FezzedOne: Added xStarbound/OpenStarbound chat metadata support to `/proxlocal`.
                -- The legacy tags remain for some stock server / legacy connection compatibility.
                chat.send(DynamicProxPrefix .. chatTags .. data.content, "Local", false, data)
            else
                for _, pl in ipairs(players) do
                    if xsb then data.sourceId = world.primaryPlayer() end
                    data.targetId =
                        pl -- FezzedOne: Used to distinguish DPC messages from SCCRP messages *and* for filtering messages as seen by secondaries on xStarbound clients.
                    data.mode = "Proximity"
                    world.sendEntityMessage(pl, "scc_add_message", data)
                end
            end

            if #globalStrings ~= 0 then
                local globalMsg = ""
                for _, str in ipairs(globalStrings) do
                    globalMsg = globalMsg .. str .. " "
                end
                globalMsg:sub(1, -2)
                globalMsg = commKey .. "{{" .. globalMsg .. "}}"
                globalMsg = globalMsg:gsub("[ ]+", " "):gsub("%{ ", "{"):gsub(" %}", "}")
                globalMsg = DynamicProxPrefix .. chatTags .. globalMsg
                -- The third parameter is ignored on StarExtensions, but retains the "..." chat bubble on xStarbound and OpenStarbound.
                chat.send(globalMsg, "Broadcast", false, data)
            end
            if #globalOocStrings ~= 0 then
                local globalOocMsg = ""
                for _, str in ipairs(globalOocStrings) do
                    globalOocMsg = globalOocMsg .. str .. " "
                end
                globalOocMsg:sub(1, -2)
                globalOocMsg = "((" .. globalOocMsg .. "))"
                globalOocMsg = globalOocMsg:gsub("[ ]+", " ")
                globalOocMsg = DynamicProxPrefix .. globalOocMsg
                -- The third parameter is ignored on StarExtensions, but retains the "..." chat bubble on xStarbound and OpenStarbound.
                chat.send(globalOocMsg, "Broadcast", false, data)
            end
            return true
        end

        local sendMessagePromise = {
            finished = function()
                local status, errorMsg = pcall(sendMessageToPlayers)
                if status then
                    return errorMsg
                else
                    sb.logWarn(
                        "[DynamicProxChat] Error occurred while sending proximity message: %s\n  Message data: %s",
                        errorMsg,
                        data
                    )
                    return true -- FezzedOne: Fixed log spam whenever an error occurs on sending.
                end
            end,
            succeeded = function() return true end,
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
        local hasPrefix = message.text:sub(1, #DynamicProxPrefix) == DynamicProxPrefix

        local isGlobalChat = message.mode == "Broadcast"
        -- FezzedOne: Handle SCCRP Proximity messages if 1) SCCRP isn't installed or 2) it's explicitly enabled via a toggle and SCCRP is installed.
        local skipHandling = false
        local isSccrpMessage = message.mode == "Proximity" and not message.targetId
        local showAsProximity = (sccrpInstalled() and isSccrpMessage)
        local showAsLocal = message.mode == "Local"
        -- Fezzedone: Whoops. Forgot to actually handle (or rather, not handle) SCCRP announcement messages.
        if message.text:sub(1, #AnnouncementPrefix) == AnnouncementPrefix then skipHandling = true end
        if not root.getConfiguration("DynamicProxChat::handleSccrpProx") then
            skipHandling = skipHandling or showAsProximity
        end

        if self.serverDefault and message.mode == "Broadcast" and message.connection == 0 and message.text:find("connected") then
            message.text = ""
        end

        -- FezzedOne: This setting allows local chat to be «funneled» into proximity chat and appropriately formatted and filtered automatically.
        if
            hasPrefix
            or (
                root.getConfiguration("DynamicProxChat::localChatIsProx")
                and (message.mode == "Local" or message.isSccrp or isSccrpMessage)
            )
        then
            message.mode = "Proximity"
            if hasPrefix and not message.processed then message.text = message.text:sub(#DynamicProxPrefix + 1, -1) end
            message.contentIsText = true
        end
        if message.mode == "Proximity" and not skipHandling and not message.processed then
            message.isSccrp = isSccrpMessage or nil
            message.contentIsText = isSccrpMessage or message.contentIsText
            -- FezzedOne: These are from my SCCRP PR. Ensures that SCCRP messages from and to xStarbound clients are always correctly handled.
            if message.isSccrp then
                message.sourceId = message.senderId
                message.targetId = message.receiverId
            end
            message.mode = "Prox"
            if not message.contentIsText then message.text = message.content end
            message.content = ""

            if message.connection then
                local hasAuthorPrefix = message.text:sub(1, #AuthorIdPrefix) == AuthorIdPrefix
                local authorEntityId
                local defaultLangStr = nil
                if hasAuthorPrefix and not message.alias then
                    local i = #AuthorIdPrefix + 1
                    local authorIdStr = ""
                    local c = ""
                    while i <= #message.text do
                        c = message.text:sub(i, i)
                        if c == "," then break end
                        authorIdStr = authorIdStr .. c
                        i = i + 1
                    end
                    authorEntityId = math.tointeger(authorIdStr)
                    if message.text:sub(i, i + #DefaultLangPrefix - 1) == DefaultLangPrefix then
                        i = i + #DefaultLangPrefix
                        defaultLangStr = ""
                        while i <= #message.text do
                            c = message.text:sub(i, i)
                            if c == "," then break end
                            defaultLangStr = defaultLangStr .. c
                            i = i + 1
                        end
                        i = i + #TagSuffix
                    else
                        while i <= #message.text do
                            c = message.text:sub(i, i)
                            if c == ";" then
                                i = i + 1
                                break
                            end
                            i = i + 1
                        end
                    end
                    message.text = message.text:sub(i, -1)
                end
                -- FezzedOne: Allows OpenStarbound and StarExtensions clients to correctly display received messages from xStarbound clients.
                local basePlayerId = message.connection * -65536
                authorEntityId = authorEntityId or message.sourceId or basePlayerId
                local authorRendered = world.entityExists(authorEntityId)
                -- FezzedOne: If the author ID has to be guessed from the connection ID and it's *not* the first ID, that means the author is using xStarbound,
                -- so look for the first rendered player belonging to the author's client. Kinda kludgy, but this is what we have to do for xStarbound clients
                -- that don't send the required information because they don't have this mod or SCCRP!
                if not (authorRendered or hasAuthorPrefix or message.sourceId) then
                    for i = (message.connection * -65536 + 1), (message.connection * -65536 + 65535), 1 do
                        if world.entityExists(i) and world.entityType(i) == "player" then
                            authorEntityId = i
                            authorRendered = true
                            break
                        end
                    end
                end
                local receiverEntityId = message.targetId or player.id()
                -- FezzedOne: DPC-side part of fix for SCCRP portraits in dynamically handled messages.
                message.senderId = authorEntityId
                message.sourceId = authorEntityId
                message.receiverId = receiverEntityId
                local ownPlayers = {}
                if xsb then ownPlayers = world.ownPlayers() end
                local isLocalPlayer = function(entityId)
                    if not xsb then return true end
                    for _, plr in ipairs(ownPlayers) do
                        if entityId == plr then return true end
                    end
                    return false
                end

                local handleMessage = function(receiverEntityId, copiedMessage)
                    local uncapRad = isGlobalChat
                    local wasGlobal = isGlobalChat
                    message.global = wasGlobal
                    local message = copiedMessage or message
                    if xsb and not message.isSccrp then           -- FezzedOne: Already handled in SCCRP with my PR.
                        if copiedMessage or message.targetId then -- FezzedOne: Show the receiver's name for disambiguation on xClient.
                            if world.entityExists(receiverEntityId) then
                                local receiverName = world.sendEntityMessage(receiverEntityId, "receiverName"):result() or
                                    "<n/a>"
                                if #ownPlayers ~= 1 then
                                    message.receiverName = receiverName
                                    message.receiverUid = world.entityUniqueId(receiverEntityId)
                                end
                                if receiverEntityId ~= player.id() then message.mode = "ProxSecondary" end
                            end
                        end
                    end
                    do
                        local authorPos, messageDistance, inSight = nil, math.huge, false
                        local playerPos = world.entityPosition(
                            world.entityExists(receiverEntityId) and receiverEntityId or player.id()
                        )
                        if authorRendered then
                            authorPos = world.entityPosition(authorEntityId)
                            messageDistance = world.magnitude(playerPos, authorPos)
                            -- messageDistance = 30
                            inSight = not world.lineTileCollision(authorPos, playerPos, { "Block", "Dynamic" }) --not doing dynamic, i think that's only for open doors
                        end

                        -- FezzedOne: This will be used to determine whether to hide the nick and portrait.
                        message.inSight = inSight
                        message.inEarShot = false

                        local activeFreq = player.getProperty("DPC::activeFreq")

                        -- FezzedOne: Dynamic collision thickness calculation.
                        local collisionA = nil
                        if authorPos and not inSight then
                            collisionA = world.lineTileCollisionPoint(authorPos, playerPos, { "Block", "Dynamic" })
                                or nil
                        end
                        local wallThickness = 0
                        if collisionA then
                            -- FezzedOne: To find wall thickness, run collision checks in opposite directions.
                            local collisionB = world.lineTileCollisionPoint(
                                playerPos,
                                authorPos,
                                { "Block", "Dynamic" }
                            ) or { collisionA[1] }
                            wallThickness = math.floor(world.magnitude(collisionA[1], collisionB[1]))
                        end
                        if DEBUG then
                            sb.logInfo(
                                DEBUG_PREFIX .. "Wall thickness is %s %s.",
                                tostring(wallThickness),
                                wallThickness == 1 and "tile" or "tiles"
                            )
                        end

                        local actionRad = self.proxActionRadius -- FezzedOne: Un-hardcoded the action radius.
                        local loocRad = self
                            .proxOocRadius                      -- actionRad * 2 -- FezzedOne: Un-hardcoded the local OOC radius.
                        local noiseRad = self.proxTalkRadius    -- FezzedOne: Un-hardcoded the talking radius.

                        --originally i made this a function, but tracking the values is difficult and it's easier to manually set them since there are only 9
                        local soundTable = {
                            [-4] = noiseRad / 10,
                            [-3] = noiseRad / 5,
                            [-2] = noiseRad / 4,
                            [-1] = noiseRad / 2,
                            [0] = noiseRad, --based on the default range of talking being 50, this should be good
                            [1] = noiseRad * 1.5,
                            [2] = noiseRad * 2,
                            [3] = noiseRad * 3,
                            [4] = noiseRad * 5,
                        }

                        --i dont like this but it'll have to do
                        local volTable = {
                            [noiseRad / 10] = -4,
                            [noiseRad / 5] = -3,
                            [noiseRad / 4] = -2,
                            [noiseRad / 2] = -1,
                            [noiseRad] = 0, --based on the default range of talking being 50, this should be good
                            [noiseRad * 1.5] = 1,
                            [noiseRad * 2] = 2,
                            [noiseRad * 3] = 3,
                            [noiseRad * 5] = 4,
                        }

                        local tVol, sVol = 0, 0
                        local tVolRad = noiseRad
                        local sVolRad = noiseRad
                        --iterate through message and get components here
                        local curMode = "action"
                        local prevMode = "action"
                        local prevDiffMode = "action"
                        local maxRad = 0      -- Remove the maximum radius restriction from global messages.
                        local rawText = message.text
                        local debugTable = {} --this will eventually be smashed together to make filterText
                        local textTable = {}  --this will eventually be smashed together to make filterText
                        local validSum = 0    --number of valid entries in the table
                        local cInd = 1        --lua starts at 1 >:(
                        local charBuffer = ""
                        local noScramble = false
                        local languageCode = defaultLangStr or
                            message.defaultLang --the !! shouldn't need to be set, but i'll leave it anyway
                        local radioMode = false --radio flag
                        local commCode = "0"    -- FezzedOne: Comm code.

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
                            isValid,
                            msgQuality,
                            inSight,
                            isRadio,
                            commCode,
                            noScramble
                        )
                            if langKey == nil then langKey = "!!" end

                            if msgQuality < 0 then msgQuality = 100 end

                            table.insert(textTable, {
                                text = str,
                                radius = radius,
                                type = type,
                                langKey = langKey,
                                valid = isValid,
                                msgQuality = msgQuality,
                                hasLOS = inSight,
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
                            if #charBuffer < 1 or charBuffer == '"' or charBuffer == ">" or charBuffer == "<" then
                                prevMode = curMode
                                curMode = nextMode
                                if curMode ~= nextMode then prevDiffMode = curMode end
                                return
                            end

                            local useRad
                            useRad = modeRadTypes[curMode]()
                            local isValid = false                                                           --start with false
                            if messageDistance <= useRad or useRad == -1 then                               --if in range
                                isValid = true                                                              --the message is valid
                                if inSight == false and curMode == "action" then                            --if i can't see you and the mode is action
                                    isValid = false                                                         --the message isn't valid anymore
                                elseif inSight == false and (curMode == "quote" or curMode == "sound") then --else, if i can't see you and the mode is quote or sound
                                    --check for path
                                    local noPathVol
                                    if authorPos then
                                        if
                                            world.findPlatformerPath(
                                                authorPos,
                                                playerPos,
                                                root.monsterMovementSettings("smallflying")
                                            )
                                        then      --if path is found
                                            noPathVol = volTable[useRad] -
                                                2 --set the volume to 1 (maybe 2 later on) level lower
                                        else      --if the path isn't found
                                            if wallThickness <= 4 then
                                                noPathVol = volTable[useRad] - (wallThickness <= 1 and 2 or 3)
                                            else
                                                noPathVol = volTable[useRad] - 4 --set the volume to 4 levels lower
                                            end
                                        end
                                    else
                                        noPathVol = -4
                                    end
                                    if noPathVol > 4 then
                                        noPathVol = 4
                                    elseif noPathVol < -4 then
                                        noPathVol = -4
                                        isValid = false
                                    end
                                    useRad = soundTable
                                        [noPathVol] --set the radius to whatever the soundelevel would be
                                    isValid = isValid and
                                        messageDistance <=
                                        useRad --set isvalid to the new value if it's still true
                                end
                            end

                            local msgQuality = 0
                            if isValid then
                                validSum = validSum + 1
                                msgQuality = math.min(((useRad / 2) / messageDistance) * 100, 100) --basically, check half the radius and take the percentage of that vs the message distance, cap at 100
                                maxRad = math.max(maxRad, useRad)
                            end

                            if useRad == -1 and maxRad ~= -1 then maxRad = -1 end
                            formatInsert(
                                charBuffer,
                                useRad,
                                curMode,
                                languageCode,
                                isValid,
                                msgQuality,
                                inSight,
                                radioMode,
                                commCode,
                                noScramble
                            )
                            charBuffer = ""

                            prevMode = curMode
                            if curMode ~= nextMode then prevDiffMode = curMode end
                            curMode = nextMode
                        end

                        local defaultKey = getDefaultLang()

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
                                parseDefault("")
                                if curMode == "quote" then
                                    newMode(curMode)
                                    noScramble = false
                                elseif curMode == "sound" then
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
                                                sum = 0
                                                if doVolume == "quote" then
                                                    tVolRad = noiseRad
                                                else
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
                            end,
                            ["/"] = function() parseDefault("/") end,
                            ["`"] = function() parseDefault("`") end,
                            ["\\"] = function() -- Allow escaping any specially parsed character with `\`. Also allow escaping `\` itself.
                                local nextChar = rawSub(cInd + 1, cInd + 1)
                                -- Since backtick and asterisk parsing are handled later, keep the escaping backslash for these special cases.
                                if nextChar == "*" or nextChar == "`" then charBuffer = charBuffer .. "\\" end
                                local prevChar = cInd ~= 1 and rawSub(cInd - 1, cInd - 1) or ""
                                if prevChar ~= "\\" then parseDefault(nextChar) end
                                cInd = cInd + 1
                            end,
                            ["("] = function() --check for number of parentheses
                                local nextChar = rawSub(cInd + 1, cInd + 1)
                                if nextChar == "(" then
                                    local oocEnd = 0
                                    local oocBump = 0
                                    local oocType
                                    local oocRad
                                    if not root.getConfiguration("DynamicProxChat::proximityOoc") then
                                        uncapRad = true
                                    end
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
                                radioMode = true
                                uncapRad = true
                                parseDefault("{")
                            end,
                            ["}"] = function()
                                if rawSub(cInd + 1, cInd + 1) == '"' and curMode == "quote" then
                                    parseDefault("}")
                                    parseDefault('"')
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
                            -- ["|"] = function()
                            --     local fStart = cInd
                            --     local fEnd = rawText:find("|", cInd + 1)
                            --
                            --     if fStart ~= nil and fEnd ~= nil then
                            --         -- local timeNum = tostring(math.floor(os.time()))
                            --         -- local mixNum = tonumber(timeNum .. math.abs(authorEntityId))
                            --         -- randSource:init(mixNum)
                            --         -- local numMax = rawSub(fStart, fEnd - 1):gsub("%D", "")
                            --         -- local roll = randSource:randInt(1, tonumber(numMax) or 20)
                            --         -- FezzedOne: Replaced dice roller with the more flexible one from FezzedTech.
                            --         local diceResults = rawSub(fStart + 1, fEnd):gsub("[ ]*", ""):gsub(
                            --             "(.-)[,|]",
                            --             function(die) return tostring(rollDice(die) or "n/a") .. ", " end
                            --         )
                            --         parseDefault("|" .. diceResults:sub(1, -3) .. "|")
                            --         cInd = fEnd + 1
                            --     else
                            --         parseDefault("|")
                            --     end
                            -- end,
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

                        local function degradeMessage(str, quality)
                            local returnStr = ""
                            local char
                            local iCount = 1
                            local rMax = (#str - 2) -
                                ((#str - 2) * (quality / 100)) --basically, how many characters can be "-", helps
                            local rCount = 0
                            while iCount <= #str do
                                char = str:sub(iCount, iCount)
                                if char == "\\" then
                                    returnStr = returnStr .. str:sub(iCount + 1, iCount + 1)
                                    iCount = iCount + 2
                                    -- FezzedOne: Got rid of hardcoded assumption that language codes are two characters long.
                                elseif char == "[" and str:find("]", iCount) ~= nil then
                                    local closingBracket = str:find("]", iCount)
                                    returnStr = returnStr .. str:sub(iCount, closingBracket)
                                    iCount = closingBracket + 1
                                elseif char == "^" and str:find(";", iCount) ~= nil then
                                    local nextSemi = str:find(";", iCount)
                                    returnStr = returnStr .. str:sub(iCount, nextSemi)
                                    iCount = nextSemi + 1
                                else
                                    randSource:init()

                                    local letterRoll = randSource:randInt(1, 100)
                                    if letterRoll > quality and char:match("[%p%s]") == nil then
                                        char = "-"
                                        rCount = rCount + 1
                                    end
                                    returnStr = returnStr .. char
                                    iCount = iCount + 1
                                end
                            end
                            return returnStr
                        end

                        local function wordBytes(word)
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

                        local function langWordRep(word, proficiency, byteLC)
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
                            randSource:init(math.tointeger(byteLC + wordBytes(word)))
                            for char in word:gmatch(".") do
                                local charLower = char:lower()
                                local isLower = char == charLower
                                local vowelPattern = mergePattern(vowels)
                                local compFail = randSource:randInt(0, 150)
                                    > (proficiency - (wordLength ^ 2 + 10) / (math.max(1, proficiency - 50) / 5))
                                if proficiency < 5 or compFail then -- FezzedOne: Added a chance that a word will be partially comprehensible.
                                    if charLower:match(vowelPattern) then
                                        local randNum = randSource:randInt(1, #vowels)
                                        char = vowels[randNum]
                                    elseif not char:match("[%p]") then -- Don't mess with punctuation.
                                        local randNum = randSource:randInt(1, #consonants)
                                        char = consonants[randNum]
                                    end
                                end
                                if not isLower then char = char:upper() end
                                newWord = newWord .. char
                            end
                            return newWord
                        end

                        local function langScramble(str, prof, langCode, msgColor, langColor)
                            local returnStr = ""
                            str = str .. " "
                            str = str:gsub("  ", " ")
                            local rCount = 0
                            local words = 0
                            for i in str:gmatch(".") do
                                if i == " " then words = words + 1 end
                            end
                            words = words + 1
                            local rMax = words - (words * (prof / 100))
                            local wordBuffer = ""
                            local byteLC = wordBytes(langCode)
                            local iCount = 1
                            local char
                            local effProf = 64 * math.log(prof / 3 + 1, 10)
                            -- local effProf = 64 * math.log(prof / 5, 5) - 20 --attempt at tweaking value, low proficiency seems to bottom out too much
                            if DEBUG then sb.logInfo(DEBUG_PREFIX .. "effProf is " .. effProf) end
                            local uniqueIdBytes = wordBytes(
                                (xsb and isLocalPlayer(receiverEntityId)) and world.entityUniqueId(receiverEntityId)
                                or player.uniqueId()
                            )

                            if langColor == nil then
                                local hexDigits =
                                { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" }
                                -- local randSource = sb.makeRandomSource()
                                local hexMin = 3

                                --not sure if there's an cleaner way to do this
                                randSource:init(math.tointeger(byteLC + wordBytes("Red One")))
                                local rNumR = hexDigits[randSource:randInt(hexMin, 16)]
                                randSource:init(math.tointeger(byteLC + wordBytes("Green Two")))
                                local rNumG = hexDigits[randSource:randInt(hexMin, 16)]
                                randSource:init(math.tointeger(byteLC + wordBytes("Blue Three")))
                                local rNumB = hexDigits[randSource:randInt(hexMin, 16)]
                                randSource:init(math.tointeger(byteLC + wordBytes("Red Four")))
                                local rNumR2 = hexDigits[randSource:randInt(hexMin, 16)]
                                randSource:init(math.tointeger(byteLC + wordBytes("Green Five")))
                                local rNumG2 = hexDigits[randSource:randInt(hexMin, 16)]
                                randSource:init(math.tointeger(byteLC + wordBytes("Blue Six")))
                                local rNumB2 = hexDigits[randSource:randInt(hexMin, 16)]
                                langColor = "#" .. rNumR .. rNumG .. rNumB .. rNumR2 .. rNumG2 .. rNumB2
                                if DEBUG then
                                    sb.logInfo(DEBUG_PREFIX .. "langColor for " .. langCode .. " is " .. langColor)
                                end
                            end

                            while iCount <= #str do
                                char = str:sub(iCount, iCount)
                                -- FezzedOne: Got rid of hardcoded assumption that language keys are two characters long.
                                if char == "[" and str:find(iCount, "]") ~= nil then
                                    local closingBracket = str:find("]", iCount)
                                    returnStr = returnStr .. char .. str:sub(iCount + 1, closingBracket)
                                    iCount = closingBracket + 1
                                elseif char == " " and not wordBuffer:match("%a") and #wordBuffer > 0 then
                                    returnStr = returnStr .. " " .. wordBuffer
                                    wordBuffer = ""
                                elseif char ~= "'" and char:match("[%s%p]") then
                                    if #wordBuffer > 0 then
                                        local wordLength = #wordBuffer
                                        local byteWord = wordBytes(wordBuffer)
                                        randSource:init(math.tointeger(uniqueIdBytes + byteLC + byteWord))
                                        local wordRoll = randSource:randInt(1, 100)
                                        if
                                            effProf < 5
                                            or (wordRoll + (wordLength ^ 2 / (math.max(1, effProf - 50) / 5)) - 10)
                                            > effProf
                                        then
                                            wordBuffer = langWordRep(trim(wordBuffer), effProf, byteLC)
                                            wordBuffer = "^" .. langColor .. ";" .. wordBuffer .. "^" .. msgColor .. ";"
                                            rCount = rCount + 1
                                        end
                                    end
                                    returnStr = returnStr .. wordBuffer .. char
                                    wordBuffer = ""
                                else
                                    wordBuffer = wordBuffer .. char
                                end
                                iCount = iCount + 1
                            end

                            if returnStr:match("%s", #returnStr) then returnStr = returnStr:sub(0, #returnStr - 1) end

                            randSource:init()
                            return returnStr
                        end

                        local colorTable = { --transparency is an options here, but it makes things hard to read
                            [-4] = "#555",
                            [-3] = "#777",
                            [-2] = "#999",
                            [-1] = "#bbb",
                            [0] = "#ddd",
                            [1] = "#fff",
                            [2] = "#daa",
                            [3] = "#d66",
                            [4] = "#d00",
                        }

                        local function colorWithin(str, char, color, prevColor)
                            -- FezzedOne: Annoying that this function also has to handle escape syntax properly.
                            -- sb.logInfo(DEBUG_PREFIX .. "Colouring chunk '" .. tostring(str) .. "'")
                            local colorOn = false
                            local escaped = false
                            local charBuffer = ""
                            for i in str:gmatch(".") do
                                if i == "\\" then
                                    if escaped then -- Have to handle printing escaped backslashes a *second* time.
                                        escaped = false
                                        charBuffer = charBuffer .. i
                                    else
                                        escaped = true
                                    end
                                elseif i == char then
                                    if escaped then
                                        escaped = false
                                        charBuffer = charBuffer .. i
                                    else
                                        if colorOn == false then
                                            charBuffer = charBuffer .. "^" .. color .. ";"
                                            colorOn = true
                                        else
                                            charBuffer = charBuffer .. "^" .. prevColor .. ";"
                                            colorOn = false
                                        end
                                    end
                                else
                                    -- Don't eat backslashes unnecessarily.
                                    if escaped then charBuffer = charBuffer .. "\\" end
                                    escaped = false
                                    charBuffer = charBuffer .. i
                                end
                            end
                            -- sb.logInfo(DEBUG_PREFIX .. "Char buffer: '" .. charBuffer .. "'")
                            return charBuffer
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
                        local quoteOpen = false
                        local soundOpen = false
                        local hasValids = false
                        local chunkStr
                        local chunkType
                        local langBank = {}               --populate with languages in inventory when you find them
                        local prevLang = getDefaultLang() --either the player's default language, or !!
                        local prevCommCode = "0"
                        local prevRadio = false

                        if not (uncapRad or maxRad == -1) and (messageDistance > maxRad and validSum == 0) then
                            message.text = ""
                        else
                            chunkType = nil

                            local prevChunk = ""
                            local repeatFlag = false
                            table.insert(
                                textTable,
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

                            local numChunks = #textTable

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
                            local receiverIsLocal = isLocalPlayer(receiverEntityId)
                            for k, v in ipairs(textTable) do
                                local lastChunk = k == numChunks

                                if
                                    v["radius"] == -1
                                    or (v["type"] == "pOOC" and wasGlobal)
                                    or (v["type"] == "lOOC" and uncapRad)
                                    or v["type"] == "gOOC"
                                then
                                    v["valid"] = true
                                end

                                local rawStr = v["text"]
                                -- FezzedOne: Strip out radio brackets. We'll re-add them later.
                                v["text"] = rawStr:gsub("^{{", ""):gsub("^{", ""):gsub("}}$", ""):gsub("}$", "")

                                if v["isRadio"] and (activeFreq["freq"] == v["commCode"] or v["commCode"] == 0) then
                                    v["valid"] = true
                                else
                                    v["isRadio"] = false
                                end

                                chunkStr = v["text"]
                                chunkType = v["type"]
                                if chunkType == "quote" and v["valid"] then message.inEarShot = true end
                                local langKey = v["langKey"]
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
                                        nil                    --don't touch colors if this is true
                                    local actionColor = "#fff" --white for non sound based chunks
                                    local msgColor = "#fff"    --white for non sound based chunks
                                    --disguise unheard stuff
                                    if chunkType == "sound" then
                                        if not colorOverride then
                                            msgColor = colorTable[volTable[v["radius"]]]
                                            chunkStr = "^" .. msgColor .. ";" .. chunkStr .. "^" .. actionColor .. ";"
                                        end
                                    elseif chunkType == "quote" then
                                        msgColor = colorTable[volTable[v["radius"]]]

                                        if chunkType == "quote" and langKey ~= "!!" then
                                            local langProf, langColor
                                            if langBank[langKey] ~= nil then
                                                langProf = langBank[langKey]["prof"]
                                                langColor = langBank[langKey]["color"]
                                            end
                                            if langProf == nil then
                                                local newLang
                                                if xsb and receiverIsLocal then
                                                    newLang = world
                                                        .sendEntityMessage(receiverEntityId, "hasLangKey", langKey)
                                                        :result() or nil
                                                else
                                                    newLang = player.getItemWithParameter("langKey", langKey) or nil
                                                end
                                                if newLang then
                                                    langColor = newLang["parameters"]["color"]
                                                    local hasItem
                                                    if xsb and receiverIsLocal then
                                                        hasItem = world
                                                            .sendEntityMessage(receiverEntityId, "langKeyCount", newLang)
                                                            :result()
                                                    else
                                                        hasItem = player.hasCountOfItem(newLang, true)
                                                    end

                                                    if hasItem then
                                                        langProf = hasItem * 10
                                                    else
                                                        langProf = 0
                                                    end
                                                    langBank[langKey] = {
                                                        prof = langProf,
                                                        color = langColor,
                                                    }
                                                else
                                                    langProf = 0
                                                end
                                            end

                                            if (not v["noScramble"]) and langProf < 100 then
                                                --scramble the word
                                                chunkStr =
                                                    langScramble(trim(chunkStr), langProf, langKey, msgColor, langColor)
                                            end
                                        end
                                        --check message quality
                                        if v["msgQuality"] < 100 and not v["isRadio"] and chunkType == "quote" then
                                            chunkStr = degradeMessage(trim(chunkStr), v["msgQuality"])
                                        end

                                        if not colorOverride then
                                            chunkStr = "^" .. msgColor .. ";" .. chunkStr .. "^" .. actionColor .. ";"
                                        end

                                        --add in language indicator
                                        if langKey ~= prevLang then
                                            chunkStr = "^#fff;[" .. langKey .. "]^" .. msgColor .. "; " .. chunkStr
                                            prevLang = langKey
                                        end
                                    end
                                    chunkStr = chunkStr:gsub("%^%#fff%;%^%#fff;", "^#fff;")
                                    chunkStr = chunkStr:gsub("%^" .. msgColor .. ";%^#fff;", "^#fff;")
                                    chunkStr = chunkStr:gsub(
                                        "%^" .. msgColor .. ";%^" .. msgColor .. ";",
                                        "^" .. msgColor .. ";"
                                    )

                                    --recolors certain things for emphasis
                                    -- Remove emphasis colouring from OOC chunks.
                                    if
                                        chunkType ~= "action"
                                        and chunkType ~= "gOOC"
                                        and chunkType ~= "lOOC"
                                        and chunkType ~= "pOOC"
                                    then                                                        --allow asterisks to stay in actions
                                        chunkStr = colorWithin(chunkStr, "*", "#fe7", msgColor) --yellow
                                    end
                                    -- FezzedOne: This now uses backticks. Also removed emphasis colouring from OOC chunks.
                                    if chunkType ~= "gOOC" and chunkType ~= "lOOC" and chunkType ~= "pOOC" then
                                        chunkStr = colorWithin(chunkStr, "`", "#d80", msgColor) --orange
                                    end
                                elseif chunkType == "quote" and hasValids and prevType ~= "quote" then
                                    chunkStr = "Says something."
                                    v["valid"] = true
                                    chunkType = "action"
                                end

                                -- FezzedOne: Add comm codes to chunks.
                                if v["isRadio"] and v["valid"] then
                                    local msgColor = "#fff"
                                    local commKey = v["commCode"]
                                    if commKey == activeFreq["freq"] or commKey == "0" then
                                        chunkStr = "^"
                                            .. (activeFreq["alias"] and "#88f" or "#44f")
                                            .. ";{" ..
                                            (activeFreq["alias"] or activeFreq["freq"]) ..
                                            "}^" .. msgColor .. "; " .. chunkStr
                                    end
                                end
                                if v["valid"] and chunkStr ~= "" then
                                    if prevRadio and not v["isRadio"] then
                                        chunkStr = (wasGlobal and "}}" or "}") .. chunkStr
                                    elseif v["isRadio"] and not prevRadio then
                                        chunkStr = (wasGlobal and "{{" or "{") .. chunkStr
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
                                        if quoteCombo:sub(1, 2) == "}}" then
                                            quoteCombo = quoteCombo:sub(3, -1)
                                            endRadio = true
                                        end
                                        if quoteCombo:sub(1, 1) == "}" then
                                            quoteCombo = quoteCombo:sub(2, -1)
                                            endRadio = true
                                        end
                                        if quoteCombo:sub(1, 2) == "{{" then
                                            quoteCombo = quoteCombo:sub(3, -1)
                                            beginRadio = true
                                        end
                                        if quoteCombo:sub(1, 1) == "{" then
                                            quoteCombo = quoteCombo:sub(2, -1)
                                            beginRadio = true
                                        end
                                        local isEmpty = #(quoteCombo:gsub("%^[^^;]-;", ""):gsub("%s", "")) == 0
                                        quoteCombo = (endRadio and (wasGlobal and "}} " or "} ") or "")
                                            .. (beginRadio and (wasGlobal and "{{" or "{") or "")
                                            .. (isEmpty and "" or '"')
                                            .. quoteCombo
                                            .. (isEmpty and "" or '"')
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
                                        soundCombo = (endRadio and (wasGlobal and "}} " or "} ") or "")
                                            .. (beginRadio and (wasGlobal and "{{" or "{") or "")
                                            .. (isEmpty and "" or "<")
                                            .. soundCombo
                                            .. (isEmpty and "" or ">")
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
                                    tableStr = tableStr .. " " .. chunkStr
                                    prevStr = chunkStr
                                end

                                if lastChunk and prevRadio then tableStr = tableStr .. (wasGlobal and "}}" or "}") end

                                prevType = chunkType
                            end
                            tableStr = cleanDoubleSpaces(tableStr)     --removes double spaces, ignores colors
                            tableStr = tableStr:gsub(' "%s', ' "')
                            tableStr = tableStr:gsub("}}%s*{{", "...") --for multiple radios
                            tableStr = tableStr:gsub("}%s*{", "...")   --for multiple radios
                            tableStr = trim(tableStr)

                            message.text = tableStr
                        end
                    end

                    if message.inSight then
                        message.portrait = message.portrait and message.portrait ~= "" and message.portrait
                            or message.connection
                    else -- FezzedOne: Remove the portrait from the message if the receiver can't see the sender.
                        -- Use a dummy negative connection ID so that a portrait is never "grabbed" by SCC.
                        message.connection = -message.connection
                        message.portrait = message.connection
                        -- Don't need to process the sender ID anymore after this, so we can remove it so that a portrait is no longer displayed.
                        message.senderId = nil
                    end
                    if copiedMessage then
                        message.processed = true
                        world.sendEntityMessage(receiverEntityId, "scc_add_message", message)
                    end
                end

                message.isDpc = true
                -- FezzedOne: If both SCCRP and Dynamic Proximity Chat are installed, always show SCCRP Proximity messages as such, even if handled by DPC.
                if message.isSccrp then message.mode = "Proximity" end
                -- FezzedOne: Show Local and Broadcast messages as such, even if formatted by DPC.
                if showAsLocal then message.mode = "Local" end
                if isGlobalChat then message.mode = "Broadcast" end

                if xsb and message.contentIsText then
                    if message.isSccrp then
                        handleMessage(receiverEntityId)
                    else
                        for _, pId in ipairs(ownPlayers) do
                            handleMessage(pId, copy(message))
                        end
                        message.text = ""
                    end
                elseif message.contentIsText then
                    if message.isSccrp then
                        handleMessage(receiverEntityId)
                    else
                        handleMessage(receiverEntityId, copy(message))
                        message.text = ""
                    end
                else
                    handleMessage(receiverEntityId)
                end
            end
        end

        local ownPlayers = {}
        if xsb then ownPlayers = world.ownPlayers() end
        local isLocalPlayer = function(entityId)
            if not xsb then return true end
            for _, plr in ipairs(ownPlayers) do
                if entityId == plr then return true end
            end
            return false
        end


        if message.mode == "Prox" then message.isDpc = true end

        if message.isDpc then message.nickname = message.playerName or message.nickname end

        --this is disabled for now since i'd prefer the nickname to appear if it's just you
        -- FezzedOne: The stock nickname is not changed after character swaps. Fixed that issue by not using the stock nickname.
        -- It's now recommended that the character's main name (set with `/setname` on xStarbound or `/identity set name` on
        -- OpenStarbound or StarExtensions) be the character's «canonical» name. E.g., «Jonathan», «Jonathan F. Thompson» or
        -- «Jonathan 'Hammer' Thompson», instead of «Jonny», «Dr. Thompson» or «'Hammer'».
        -- Tip: With this change, you can now save the stock nickname for your OOC username (or whatever else) in non-Dynamic chat,
        -- since it's now completely disconnected from DPC messages. Wanted to add auto-nick for this reason, but that'd cause issues
        -- with servers running StarryPy3k.
        if message.isDpc and message.playerUid == (message.receiverUid or player.uniqueId()) then
            --allow higher (negative) priority aliases to appear on the message
            --take from player config instead of the message
            --in the future, allow players to use the nickname feature on themselves. right now i dont see why it'd be useful to do but whatever
            -- local aliases = player.getProperty("DPC::aliases") or {}
            local _, defaultName = getNames()
            local useName = xsb and (defaultName or "") or world.entityName(player.id())
            -- local minPrio = 0

            -- for prio, alias in pairs(aliases) do
            --     if prio < minPrio then
            --         useName = alias
            --     end
            -- end
            message.nickname = useName
        elseif message.isDpc and message.playerUid ~= (message.receiverUid or player.uniqueId()) and not message.skipRecog and (not message.recogGroup or message.recogGroup ~= player.getProperty("DPC::recogGroup")) then
            -- FezzedOne: Removed this check to add recog support in client-side modes: and root.getConfiguration("dpcOverServer")
            local recoged = {}
            if xsb then
                if isLocalPlayer(message.receiverId or player.id()) then
                    recoged = world.sendEntityMessage(message.receiverId or player.id(), "dpcGetRecogs"):result() or {}
                end
            else
                recoged = player.getProperty("DPC::recognizedPlayers") or {}
            end

            --sending player will check for aliases or a name (and priority) in the message and attach a param if it exists
            --this will just apply it if it exists and is higher priority
            --if the entry doesn't exist and the message has no value filled in then apply the ???
            --[[
            table should be:
            {
            uuid: {
                savedName: "name",
                manName: "/addnick name", (if populated, prevent alias overwrites for higher priority aliases)
                aliasPrio: int (0 is for real name, can make negative ints)
            },
            uuid:{etc}
            }
            ]]
            local charRecInfo = recoged[message.playerUid] or nil
            if charRecInfo == true then
                charRecInfo = nil
            end
            local useName = message.fakeName or "^#999;???^reset;"

            if (message.alias and message.aliasPrio) and
                ((not charRecInfo) or (charRecInfo and (not charRecInfo.manName) and message.aliasPrio < charRecInfo.aliasPrio)) then --if conditions are met
                local normalisedAlias = normaliseText(message.alias)
                local tokens = quoteMap(message.text or "")
                if tokens[normalisedAlias] then -- FezzedOne: Check that the alias isn't garbled first.
                    --apply new thing or create entry, should work either way
                    charRecInfo = {
                        ["savedName"] = message.alias,
                        ["manName"] = false,
                        ["aliasPrio"] = message.aliasPrio
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

            message.nickname = useName

            -- FezzedOne's note: Messages sent with `/proxlocal` enabled will *not* automatically «proc» recog or handle recog groups
            -- or skips on a player unless all three of the sending client, receiving client *and* server are running the same
            -- mod (i.e., either xStarbound or OpenStarbound) *and* are not connected in legacy mode, due to the alias and
            -- character name being sent in chat metadata in this case. Players should consider using `/addnick` or disabling
            -- `/proxlocal` on stock servers.
        end

        if message.nickname == "" then message.nickname = "^#999;???^reset;" end

        if xsb then
            message.nickname = message.receiverName and
                ((message.nickname or "^#999;???^reset;") .. " -> " .. message.receiverName)
                or message.nickname
        end

        if showAsProximity then message.mode = "Proximity" end
        if showAsLocal then message.mode = "Local" end
        if (isGlobalChat or message.global) and message.mode ~= "ProxSecondary" then message.mode = "Broadcast" end
        -- setTextHint(message.mode)
        return message
    end
    -- return messageFormatter(rawMessage)

    local messageData = copy(rawMessage)
    local rawText = messageData.text
    local status, messageOrError = pcall(messageFormatter, rawMessage)
    if status then
        return messageOrError
    else
        sb.logWarn(
            "[DynamicProxChat] Error occurred while formatting proximity message: %s\n  Message data: %s",
            messageOrError,
            messageData
        )
        rawMessage.text = rawText
        return rawMessage
    end
end

function dynamicprox:onReceiveMessage(message) --here for logging the message you receive, just in case you wanted to save it or something
    if message.connection ~= 0 and (message.sourceId or message.mode == "Prox" or message.mode == "ProxSecondary") then
        sb.logInfo("Chat: <%s> %s", message.nickname:gsub("%^[^^;]-;", ""), message.text:gsub("%^[^^;]-;", ""))
    end
end

function dynamicprox:onModeChange(mode)
    if mode == "Prox" and not (player.getProperty("DPC::firstLoad") or false) then
        chat.addMessage(
            "^CornFlowerBlue;Dynamic Prox Chat^reset;: Before getting started with this mod, first check to see if you're using it with a server or as an individual client, then use \"^cyan;/dpcserver^reset; ^green;on^reset;/^red;off^reset;\" to enable or disable server handling for message processing. To use the language system, use ^cyan;/learnlang^reset; or ^cyan;/newlangitem^reset; to manage languages for chat. This notice will only appear once, but its information can be found on the mod page.")
        if self.serverDefault then
            root.setConfiguration("dpcOverServer", true)
        end
        player.setProperty("DPC::firstLoad", true)
    elseif mode == "Prox" and self.serverDefault and not root.getConfiguration("dpcOverServer") and not root.getConfiguration("DPC::forcedClient") then
        sb.logInfo("Setting dpcOverServer to true")
        chat.addMessage(
            "^CornFlowerBlue;Dynamic Prox Chat^reset;: You have a mod installed that has ^green;enabled^reset; server handling for messages. If you want to keep server handling disabled, use \"^cyan;/dpcserver off forced^reset;\" to force the mod to ignore this configuration.")
        root.setConfiguration("dpcOverServer", true)
        -- root.setConfiguration("scc_autohide_ignore_server_messages",true)
    end
    setTextHint(mode)
end
