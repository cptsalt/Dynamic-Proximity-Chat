require "/interface/scripted/starcustomchat/plugin.lua"

inlineprox = PluginClass:new({
  name = "inlineprox"
})

function inlineprox:init()
  self:_loadConfig()
end

function inlineprox:addCustomCommandPreview(availableCommands, substr)
  if string.find("/newlangitem", substr, nil, true) then
    table.insert(availableCommands, {
      name = "/newlangitem",
      description = "commands.newlangitem.desc",
      data = "/newlangitem",
      color = nil
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
    --this one is broken, not sure why
  elseif string.find("/showtypos", substr, nil, true) then
    table.insert(availableCommands, {
      name = "/showtypos",
      description = "commands.showtypos.desc",
      data = "/showtypos"
    })
  end
end

local function checktypo(toggle)
  local typoTable = player.getProperty("typos", {})
  local typoStatus

  if typoTable["typosActive"] == true then
    if toggle then
      typoTable["typosActive"] = false
      typoStatus = "off"
    else
      typoStatus = "on"
    end
  else
    if toggle then
      typoTable["typosActive"] = true
      typoStatus = "on"
    else
      typoStatus = "off"
    end
  end
  player.setProperty("typos", typoTable)
  return "Typo correction is " .. typoStatus
end

local function splitStr(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

local function getDefaultLang()
  local langItem = player.getItemWithParameter("defaultLang", true) --checks for an item with the "defaultLang" parameter
  local defaultKey
  if langItem == nil then
    defaultKey = "!!"
  else
    defaultKey = langItem['parameters']['langKey'] or "!!"
  end
  return defaultKey
end

--this messagehandler function runs if the chat preview exists
function inlineprox:registerMessageHandlers(shared) --look at this function in irden chat's editchat thing
  starcustomchat.utils.setMessageHandler("/showtypos", function(_, _, data)
    local typoTable = player.getProperty("typos", {})
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
    --add a typo correction to the typos table in player data, or replace it if it already exists
    -- local typo, correction = chat.parseArguments(data)
    local splitArgs = splitStr(data, " ")
    local typo, correction = splitArgs[1], splitArgs[2]

    if typo == nil or correction == nil then
      return "Missing arguments for /addtypo, need {typo, correction}"
    end
    local typoTable = player.getProperty("typos", {})

    typoTable[typo] = correction
    player.setProperty("typos", typoTable)
    return "Typo \"" .. typo .. "\" added as \"" .. correction .. "\"."
  end)
  starcustomchat.utils.setMessageHandler("/removetypo", function(_, _, data)
    --add a typo correction to the typos table in player data, or replace it if it already exists
    -- local typo = chat.parseArguments(data)
    local typo = splitStr(data, " ")[1]
    local typoTable = player.getProperty("typos", false)

    if typo == nil then
      return "Missing arguments for /removetypo, need {typo}"
    end

    if typoTable then
      typoTable[typo] = nil
      player.setProperty("typos", typoTable)
    end
    return "Typo \"" .. typo .. "\" removed."
  end)

  starcustomchat.utils.setMessageHandler("/newlangitem", function(_, _, data)
    local splitArgs = splitStr(data, " ")
    local langName, langKey, langLevel, isDefault, color = (splitArgs[1] or nil), (splitArgs[2] or nil),
        (tonumber(splitArgs[3]) or 10),
        (splitArgs[4] or nil), (splitArgs[5] or nil)

    if langKey == nil or langName == nil then
      return "Missing arguments for /newlangitem, need {name, code, count, automatic, [hex color]}"
    end
    if isDefault == nil then
      isDefault = false
    end

    if color ~= nil then
      if not color:match("#") then
        color = "#" .. color
      end
      if #color > 7 then
        color = color:sub(1, 7)
      end
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
        color = color
      }
    }

    player.giveItem(itemData)
    return "Language " .. langName .. " added, use [" .. langKey .. "] to use it."
  end)
end

function inlineprox:onSendMessage(data)
  --think about running this in local to allow players without the mod to still see messages

  if data.mode == "Prox" then
    -- data.time = systemTime() this is where i'd add time if i wanted it
    data.proxRadius = self.proxRadius
    local function sendMessageToPlayers()
      local position = player.id() and world.entityPosition(player.id())

      if position then
        local estRad = data.proxRadius
        local rawText = data.text
        local sum = 0
        local parenSum = 0
        local iCount = 1
        local globalFlag = false
        local hasNoise = false
        local defaultKey = getDefaultLang()
        data.defaultLang = defaultKey
        local typoTable = player.getProperty("typos", {})
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
        while iCount <= #rawText and not globalFlag do
          if parenSum == 3 then
            globalFlag = true
          end

          local i = rawText:sub(iCount, iCount)
          local langEnd = rawText:find("]", iCount)
          if i == "+" then
            sum = sum + 1
          elseif i == "(" then
            parenSum = parenSum + 1
          elseif i == "{" and rawText:find("}", iCount) ~= nil then
            globalFlag = true
          elseif i == "[" and langEnd ~= nil then        --use this flag to check for default languages. A string without any noise won't have any language support
            local langKey
            if rawText:sub(iCount, langEnd) == "[]" then --checking for []
              langKey = defaultKey
              rawText = rawText:gsub("%[%]", "[" .. defaultKey .. "]")
            else
              langKey = rawText:sub(iCount + 1, langEnd - 1)
            end
            local upperKey = langKey:upper()

            local langItem = player.getItemWithParameter("langKey", upperKey)

            if (langItem == nil and upperKey ~= "!!") then
              rawText = rawText:gsub("%[" .. langKey, "[" .. defaultKey)
            end
          else
            parenSum = 0
          end
          iCount = iCount + 1
        end
        data.content = rawText
        data.text = ""
        if (parenSum == 2 or globalFlag) then
          estRad = estRad * 2
        elseif sum > 3 then
          estRad = estRad * 1.5
        else
          estRad = estRad + (estRad * 0.25 + (3 * sum))
        end

        --estrad should be pretty close to actual radius


        --this is where i'd change players if needed
        local players = world.playerQuery(position, estRad, {
          boundMode =
          "position"
        })
        for _, pl in ipairs(players) do
          world.sendEntityMessage(pl, "scc_add_message", data)
        end


        return true
      end
    end

    local sendMessagePromise = {
      finished = sendMessageToPlayers,
      succeeded = function() return true end
    }

    promises:add(sendMessagePromise)
    player.say("...")
  end
end

function inlineprox:formatIncomingMessage(message)
  --think about running this in local to allow players without the mod to still see messages

  if message.mode == "Prox" then
    message.text = message.content
    message.content = ""


    if message.connection then --i don't know what receivingRestricted does
      local authorEntityId = message.connection * -65536

      if world.entityExists(authorEntityId) then
        local authorPos = world.entityPosition(authorEntityId)
        local playerPos = world.entityPosition(player.id())
        local messageDistance = world.magnitude(playerPos, authorPos)
        -- messageDistance = 30
        local inSight = not world.lineTileCollision(authorPos, playerPos, { "Block", "Dynamic" }) --not doing dynamic, i think that's only for open doors

        -- this is for later, testing to see if i can calculate how many tiles are between a sender and receiver
        -- local testCol = world.lineTileCollisionPoint(authorPos, playerPos, { "Block", "Dynamic" })
        -- sb.logWarn("messageDistance is " .. messageDistance)
        -- if testCol ~= nil then
        --   sb.logInfo("testCol is " .. dump(testCol))
        --   local pos1 = testCol[1][1]
        --   local pos2 = testCol[1][2]
        --   sb.logInfo("pos1 "..pos1.." pos2 "..pos2)
        --   sb.logInfo("distance is " .. world.magnitude(pos1, pos2))
        -- end
        local randSource = sb.makeRandomSource()





        local actionRad = 200             --this is hard-coded for now, i might chagne it later
        local loocRad = actionRad * 2     --2x actions, actions should already be pretty long though

        local noiseRad = 0.25 * actionRad --talking, should be smaller than actions
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
        local maxRad = 0
        local rawText = message.text
        local debugTable = {}                    --this will eventually be smashed together to make filterText
        local textTable = {}                     --this will eventually be smashed together to make filterText
        local validSum = 0                       --number of valid entries in the table
        local cInd = 1                           --lua starts at 1 >:(
        local charBuffer = ""
        local languageCode = message.defaultLang --the !! shouldn't need to be set, but i'll leave it anyway
        local radioMode = false                  --radio flag

        local modeRadTypes = {
          action = function()
            return actionRad
          end,
          quote = function()
            return tVolRad
          end,
          sound = function()
            return sVolRad
          end,
          lOOC = function()
            return loocRad
          end,
          gOOC = function()
            return -1
          end,
        }

        local function rawSub(sInd, eInd)
          return rawText:sub(sInd, eInd)
        end

        --use this to construct the components
        --any component indications (like :+) that remain should stay, use them for coloring if they aren't picked up here and reset after each component
        local function formatInsert(str, radius, type, langKey, isValid, msgQuality, inSight, isRadio)
          if langKey == nil then
            langKey = "!!"
          end


          if msgQuality < 0 then
            msgQuality = 100
          end


          table.insert(textTable, {
            text = str,
            radius = radius,
            type = type,
            langKey = langKey,
            valid = isValid,
            msgQuality = msgQuality,
            hasLOS = inSight,
            isRadio = isRadio,
          })
        end

        local function parseDefault(letter)
          charBuffer = charBuffer .. letter
          cInd = cInd + 1
        end

        local function newMode(nextMode) --if radius is -1, the insert is instance wide
          if (#charBuffer < 1 or charBuffer == '"' or charBuffer == '>' or charBuffer == '<') then
            prevMode = curMode
            curMode = nextMode
            return
          end

          local useRad
          useRad = modeRadTypes[curMode]()
          local isValid = false                                                         --start with false
          if messageDistance <= useRad or useRad == -1 then                             --if in range
            isValid = true                                                              --the message is valid
            if inSight == false and curMode == "action" then                            --if i can't see you and the mode is action
              isValid = false                                                           --the message isn't valid anymore
            elseif inSight == false and (curMode == "quote" or curMode == "sound") then --else, if i can't see you and the mode is quote or sound
              --check for path
              local noPathVol
              if world.findPlatformerPath(authorPos, playerPos, root.monsterMovementSettings("smallflying")) then --if path is found
                noPathVol = volTable[useRad] -
                    1                                                                                             --set the volume to 1 (maybe 2 later on) level lower
              else                                                                                                --if the path isn't found
                noPathVol = volTable[useRad] -
                    4                                                                                             --set the volume to 4 levels lower
              end
              if noPathVol > 4 then
                noPathVol = 4
              elseif noPathVol < -4 then
                noPathVol = -4
                isValid = false
              end
              useRad = soundTable[noPathVol]                  --set the radius to whatever the soundelevel would be
              isValid = isValid and messageDistance <= useRad --set isvalid to the new value if it's still true
            end
          end

          local msgQuality = 0
          if isValid then
            validSum = validSum + 1
            msgQuality = math.min(((useRad / 2) / messageDistance) * 100, 100) --basically, check half the radius and take the percentage of that vs the message distance, cap at 100
            maxRad = math.max(maxRad, useRad)
          end

          if useRad == -1 and maxRad ~= -1 then
            maxRad = -1
          end
          formatInsert(charBuffer, useRad, curMode, languageCode, isValid, msgQuality, inSight, radioMode)
          charBuffer = ""

          prevMode = curMode
          if (curMode ~= nextMode) then
            prevDiffMode = curMode
          end
          curMode = nextMode
        end


        local defaultKey = getDefaultLang()

        local mode_table = {
          ['\"'] = function()
            if curMode == "quote" then
              parseDefault('')
              newMode("action")
            elseif curMode == "action" then
              newMode("quote")
              parseDefault('')
            else
              parseDefault('"')
            end
          end,
          ['<'] = function()                                  --i could combine these two, but i don't want to
            if curMode ~= "sound" and curMode ~= "quote" then --added quotes here so people can do the cool combine vocoder thing <::Pick up that can.::>
              newMode("sound")
            end
            parseDefault('')
          end,
          ['>'] = function()
            parseDefault('')
            if curMode == "sound" then
              newMode(prevDiffMode)
            end
          end,
          [':'] = function()
            local nextChar = rawSub(cInd + 1, cInd + 1)
            if (nextChar == "+" or nextChar == "-" or nextChar == "=") then
              newMode(curMode) --this happens to change volume, but mode isn't actually changing

              local maxAmp = 4 --maximum chars after the colon

              local lStart, lEnd = rawText:find(":%++", cInd)
              local qStart, qEnd = rawText:find(":%-+", cInd)
              local eStart, eEnd = rawText:find(":%=+", cInd)
              local nCStart, nCEnd


              if (qStart == nil) then
                qStart = #rawText
              end
              if (qEnd == nil) then
                qEnd = #rawText
              end
              if (lStart == nil) then
                lStart = #rawText
              end
              if (lEnd == nil) then
                lEnd = #rawText
              end
              if (eStart == nil) then
                eStart = #rawText
              end
              if (eEnd == nil) then
                eEnd = #rawText
              end

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
              if curMode == 'radio' or curMode == 'gOOC' or curMode == 'lOOC' then
                cInd = nCEnd + 1
              elseif curMode == 'action' then
                local nextInd = rawText:find("[\"<]", cInd)


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

              if doVolume ~= 'none' then
                local sum = 0
                local nextStr = rawSub(nCStart + 1, nCEnd)

                if doVolume == "quote" then
                  sum = tVol
                else
                  sum = sVol
                end

                for i in nextStr:gmatch(".") do
                  if i == '+' then
                    sum = sum + 1
                  elseif i == '-' then
                    sum = sum - 1
                  elseif i == '=' then
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
          ['*'] = function() --leave this for the visual alterations later on
            -- i have this commented out so people can keep asterisks in actions if they want
            -- if curMode == 'action' then
            --   cInd = cInd + 1
            -- else
            --   parseDefault("*")
            -- end
            parseDefault("*")
          end,
          ['/'] = function()
            parseDefault("*")
          end,
          ['\\'] = function()
            parseDefault("\\")
          end,
          ['('] = function() --check for number of parentheses
            local nextChar = rawSub(cInd + 1, cInd + 1)
            if nextChar == "(" then
              local oocEnd = 0
              local oocBump = 0
              local oocType
              local oocRad
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
          ['{'] = function() --this should function as a global IC message, but finding the playercount is not possible (or i'm stupid) clientside
            --i'm not doing secure radio because you can edit this file and ignore the password requirement with it
            --if you want to do that, just do it over group chat or something
            --this is where a stagehand serverside would be useful. In the future it might be worth exploring that

            --maybe set up multiple radio ranges with multiple brackets? seems kind of pointless imo
            newMode(curMode)
            radioMode = true
            parseDefault("{")
          end,
          ['}'] = function()
            if rawSub(cInd + 1, cInd + 1) == "\"" and curMode == "quote" then
              parseDefault("}")
              parseDefault("\"")
              newMode("action")
            else
              parseDefault("}")
              newMode(curMode)
            end


            radioMode = false
            -- cInd = cInd + 1
          end,
          ['|'] = function()
            local fStart, fEnd = rawText:find("%d+|", cInd)

            if fStart ~= nil and fEnd ~= nil then
              local timeNum = message.time:gsub("%D", "")
              local mixNum = tonumber(timeNum .. math.abs(authorEntityId))
              randSource:init(mixNum)
              local numMax = rawSub(fStart, fEnd - 1):gsub("%D", "")
              local roll = randSource:randInt(1, tonumber(numMax))
              parseDefault("|" .. roll .. "|")
              cInd = fEnd + 1
            else
              parseDefault("|")
            end
          end,
          ['['] = function()
            local fStart, fEnd = rawText:find("%[%S%S+]", cInd - 1)
            if fStart ~= nil and fEnd ~= nil then
              local newCode = rawSub(fStart + 1, fEnd - 1)

              if languageCode ~= newCode and curMode == "quote" then
                newMode(curMode)
              end
              languageCode = newCode:upper()
              cInd = rawText:find("%S", fEnd + 1) or
                  #rawText                             --set index to the next non whitespace character after the code
            elseif rawSub(cInd, cInd + 1) == '[]' then --this should never happen anymore
              newMode(curMode)
              languageCode = defaultKey
              cInd = cInd + 2
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

        local function trim(s)
          local l = 1
          while string.sub(s, l, l) == ' ' do
            l = l + 1
          end
          local r = #s
          while string.sub(s, r, r) == ' ' do
            r = r - 1
          end
          return string.sub(s, l, r)
        end

        local function degradeMessage(str, quality)
          local returnStr = ""
          local char
          local iCount = 1
          local rMax = (#str - 2) - ((#str - 2) * (quality / 100)) --basically, how many characters can be "-", helps
          local rCount = 0
          while iCount <= #str do
            char = str:sub(iCount, iCount)
            if char == "[" and str:sub(iCount + 3, iCount + 3) == "]" then
              returnStr = returnStr .. str:sub(iCount, iCount + 3)
              iCount = iCount + 4
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
          local returnStr = ""
          for char in word:gmatch(".") do
            char = char:lower()
            returnStr = returnStr .. math.abs(string.byte(char) - 100)
          end
          return returnStr
        end

        local function langWordRep(word, byteLC)
          local vowels = { 'a', 'e', 'i', 'o', 'u', 'y' }
          local consonants = { 'b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'p', 'q', 'r', 's', 't',
            'v', 'w',
            'x', 'z' }
          local pickInd = 0
          local newWord = ""
          randSource:init(tonumber(byteLC .. wordBytes(word)))
          for char in word:gmatch(".") do
            local charLower = char:lower()
            local isLower = char == charLower
            if charLower:match("[aeiouy]") then
              local randNum = randSource:randInt(1, #vowels)
              char = vowels[randNum]
            elseif not char:match("[%p]") then
              local randNum = randSource:randInt(1, #consonants)
              char = consonants[randNum]
            end
            if not isLower then
              char = char:upper()
            end
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
            if i == " " then
              words = words + 1
            end
          end
          words = words + 1
          local rMax = words - (words * (prof / 100))
          local wordBuffer = ""
          local byteLC = wordBytes(langCode)
          local iCount = 1
          local char

          if langColor == nil then
            local hexDigits = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" }
            local randSource = sb.makeRandomSource()
            local hexMin = 1

            --not sure if there's an cleaner way to do this
            randSource:init(byteLC .. wordBytes("Red One"))
            local rNumR = hexDigits[randSource:randInt(hexMin, 16)]
            randSource:init(byteLC .. wordBytes("Green Two"))
            local rNumG = hexDigits[randSource:randInt(hexMin, 16)]
            randSource:init(byteLC .. wordBytes("Blue Three"))
            local rNumB = hexDigits[randSource:randInt(hexMin, 16)]
            randSource:init(byteLC .. wordBytes("Red Four"))
            local rNumR2 = hexDigits[randSource:randInt(hexMin, 16)]
            randSource:init(byteLC .. wordBytes("Green Five"))
            local rNumG2 = hexDigits[randSource:randInt(hexMin, 16)]
            randSource:init(byteLC .. wordBytes("Blue Six"))
            local rNumB2 = hexDigits[randSource:randInt(hexMin, 16)]
            langColor = "#" .. rNumR .. rNumG .. rNumB .. rNumR2 .. rNumG2 .. rNumB2
          end


          while iCount <= #str do
            char = str:sub(iCount, iCount)
            if char == "[" and str:sub(iCount + 3, iCount + 3) == "]" then
              returnStr = returnStr .. char .. str:sub(iCount + 1, iCount + 3)
              iCount = iCount + 3
            elseif char == " " and not wordBuffer:match("%a") and #wordBuffer > 0 then
              returnStr = returnStr .. " " .. wordBuffer
              wordBuffer = ""
            elseif char ~= "'" and char:match("[%s%p]") then
              if #wordBuffer > 0 then
                local byteWord = wordBytes(wordBuffer)
                randSource:init(tonumber(wordBytes(player.uniqueId()) .. byteLC .. byteWord))
                local wordRoll = randSource:randInt(1, 100)
                if wordRoll > prof then
                  wordBuffer = langWordRep(trim(wordBuffer), wordRoll, byteLC)
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

          if returnStr:match("%s", #returnStr) then
            returnStr = returnStr:sub(0, #returnStr - 1)
          end


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
          local colorOn = false
          local charBuffer = ""
          for i in str:gmatch(".") do
            if i == char then
              if colorOn == false then
                charBuffer = charBuffer .. "^" .. color .. ";"
                colorOn = true
              else
                charBuffer = charBuffer .. "^" .. prevColor .. ";"
                colorOn = false
              end
            else
              --put this outside the if statement to make the characters appear as well as colors
              charBuffer = charBuffer .. i
            end
          end
          print("Charbuffer is " .. charBuffer)
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
                if colorCode ~= prevColor then
                  cleanStr = cleanStr .. colorCode
                end
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

        if maxRad ~= -1 and (messageDistance > maxRad and validSum == 0) then
          message.text = ""
        else
          chunkType = nil

          local prevChunk = ""
          local repeatFlag = false
          table.insert(textTable, {
            text = "",
            radius = "0",
            type = "bad",
            langKey = ":(",
            valid = false,
            msgQuality = 0
          })



          for k, v in pairs(textTable) do
            if v['hasLOS'] == false and chunkType == "action" then
              v['valid'] = false
            end
            if v['valid'] then
              hasValids = true
            end
          end
          for k, v in pairs(textTable) do
            if v['radius'] == -1 or v['isRadio'] == true then
              v['valid'] = true
            end


            chunkStr = v['text']
            chunkType = v['type']
            local langKey = v['langKey']
            if v['valid'] == true or (chunkType == "quote" and ((k > 1 and textTable[k - 1]['type'] == "quote") or (k < #textTable and textTable[k + 1]['type'] == "quote"))) then --check if this is surrounded by quotes
              v['valid'] = true                                                                                                                                                    --this should be set to true in here, since everything in this block should show up on the screen
              -- remember, noiserad is a const and radius is for the message

              local colorOverride = chunkStr:find("%^%#") ~=
                  nil                    --don't touch colors if this is true
              local actionColor = "#fff" --white for non sound based chunks
              local msgColor = "#fff"    --white for non sound based chunks
              --disguise unheard stuff
              if chunkType == "sound" then
                if not colorOverride then
                  msgColor = colorTable[volTable[v['radius']]]
                  chunkStr = "^" .. msgColor .. ";" .. chunkStr .. "^" .. actionColor .. ";"
                end
              elseif chunkType == "quote" then
                msgColor = colorTable[volTable[v['radius']]]

                if chunkType == 'quote' and langKey ~= "!!" then
                  local langProf, langColor
                  if langBank[langKey] ~= nil then
                    langProf = langBank[langKey]["prof"]
                    langColor = langBank[langKey]["color"]
                  end
                  if langProf == nil then
                    local newLang = player.getItemWithParameter("langKey", langKey) or nil
                    if newLang then
                      langColor = newLang['parameters']['color']
                      local hasItem = player.hasCountOfItem(newLang, true)

                      if hasItem then
                        langProf = hasItem * 10
                      else
                        langProf = 0
                      end
                      langBank[langKey] = {
                        prof = langProf,
                        color = langColor
                      }
                    else
                      langProf = 0
                    end
                  end

                  if langProf < 100 then
                    --scramble the word
                    chunkStr =
                        langScramble(trim(chunkStr), langProf, langKey, msgColor, langColor)
                  end
                end
                --check message quality
                if v['msgQuality'] < 100 and chunkType == 'quote' then
                  chunkStr = degradeMessage(trim(chunkStr), v['msgQuality'])
                end

                if not colorOverride then
                  chunkStr = "^" .. msgColor .. ";" .. chunkStr .. "^" .. actionColor .. ";"
                end

                --add in languagee indicator
                if langKey ~= prevLang then
                  chunkStr = "^#fff;[" .. langKey .. "]^" .. msgColor .. "; " .. chunkStr
                  prevLang = langKey
                end
              end
              chunkStr = chunkStr:gsub("%^%#fff%;%^%#fff;", "^#fff;")
              chunkStr = chunkStr:gsub("%^" .. msgColor .. ";%^#fff;", "^#fff;")
              chunkStr = chunkStr:gsub("%^" .. msgColor .. ";%^" .. msgColor .. ";", "^" .. msgColor .. ";")


              --recolors certain things for emphasis
              if chunkType ~= "action" then                             --allow asterisks to stay in actions
                chunkStr = colorWithin(chunkStr, "*", "#fe7", msgColor) --yellow
              end
              chunkStr = colorWithin(chunkStr, "\\", "#d80", msgColor)  --orange
            elseif chunkType == "quote" and hasValids and prevType ~= "quote" then
              chunkStr = "They say something."
              v['valid'] = true
              chunkType = "action"
            end

            --after check, this puts formatted chunks in
            if chunkType ~= "quote" and prevType == "quote" then
              local checkCombo = quoteCombo:gsub("%[%w%w%]", "")

              if not checkCombo:match("[%w%d]") then
                if prevStr ~= "They say something." then
                  quoteCombo = "They say something."
                else
                  quoteCombo = ""
                end
                prevStr = quoteCombo
              end

              quoteCombo = '"' .. quoteCombo .. '"'
              tableStr = tableStr .. " " .. quoteCombo
              quoteCombo = ""
            end
            if chunkType ~= "sound" and prevType == "sound" then
              if soundCombo:match("[%w%d]") then
                soundCombo = '<' .. soundCombo .. '>'
                tableStr = tableStr .. " " .. soundCombo
              end
              soundCombo = ""
            end

            if v['valid'] and chunkType == "quote" then
              if quoteCombo:sub(#quoteCombo):match("%p") then
                --this adds the space after a quote
                quoteCombo = quoteCombo .. " " .. chunkStr
              else
                quoteCombo = quoteCombo .. chunkStr
              end
            elseif v['valid'] and chunkType == "sound" then
              if soundCombo:sub(#soundCombo):match("%p") then
                --this adds the space after a quote
                soundCombo = soundCombo .. " " .. chunkStr
              else
                soundCombo = soundCombo .. chunkStr
              end
            elseif v['valid'] then --everything that isn't a sound or a quote goes here
              tableStr = tableStr .. " " .. chunkStr
              prevStr = chunkStr
            end

            prevType = chunkType
          end
          tableStr = cleanDoubleSpaces(tableStr) --removes double spaces, ignores colors
          tableStr = tableStr:gsub(" \"%s", " \"")
          tableStr = tableStr:gsub("}{", "...")  --for multiple radios
          tableStr = trim(tableStr)

          message.text = tableStr
        end
      end
    end

    message.portrait = message.portrait and message.portrait ~= "" and message.portrait or message.connection
  end

  return message
end

-- function inlineprox:onReceiveMessage(message) --i'm not sure why this would be needed, or if it would help at all
--   if message.connection ~= 0 and message.mode == "Prox" then

--   end
-- end
