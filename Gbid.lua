local Gbid = CreateFrame("Frame", "Gbid")
Gbid:RegisterEvent("CHAT_MSG_RAID")
Gbid:RegisterEvent("CHAT_MSG_RAID_LEADER")

Gbid:RegisterEvent("ADDON_LOADED")
Gbid:RegisterEvent("GROUP_JOINED")
local recording = false

function Gbid:GROUP_JOINED(event)
  print("Use \"/gbid clear\" to purge previously saved gbid data.")
  print("Use \"/gbid record\" to record new loot for a gbid.")
  print("For more options run \"/gbid\" or \"/gbid help\"")
end

function Gbid:add(item)
  local itemName, itemLink, itemQuality = GetItemInfo(item)
  items[itemLink] = items[itemLink] or {}
  table.insert(items[itemLink], { biddable = immediate })

  if (immediate and itemQuality >= minQuality) then
    SendChatMessage("Bidding has started on " .. itemLink .. ". Type \"" .. prefix .. " " .. itemName .. " " .. tostring(minBid) .. "\" to make a minimum bid.", "RAID")
  end
end

function Gbid:handleStart(item, index)
  index = index or 1
  if (not item or item == "") then
    for item, bidInfos in pairs(items) do
      for index, bidInfo in pairs(bidInfos) do
        Gbid:start(item, index)
      end
    end
  elseif (items[item][index]) then
    Gbid:start(item, index)
  else
    print("Item does not exist in the bid list.")
  end
end

function Gbid:start(item, index)
  index = index or 1
  local itemName, itemLink, itemQuality = GetItemInfo(item)
  if (items[itemLink]) then
    if (not items[itemLink][index].biddable) then
      items[itemLink][index].biddable = true
      SendChatMessage("Bidding has started on " .. Gbid:displayItemWithIndex(itemLink, index) .. ". Type \"" .. prefix .. " " .. Gbid:displayItemWithIndex(itemLink, index) .. " " .. tostring(minBid) .. "\" to make a minimum bid.", "RAID")
    else
      print("The bid for " .. Gbid:displayItemWithIndex(item, index) .. " is already in progress. You can stop it with \"/gbid stop " .. Gbid:displayItemWithIndex(item, index) .. "\".")
    end
  else
    print("Could not start the bid for " .. item .. " because it was not found. You can try to \"/gbid add " .. item .. "\".")
  end
end

function Gbid:handleStop(item, index)
  index = index or 1
  if (not item or item == "") then
    for item, bidInfos in pairs(items) do
      for index, bidInfo in pairs(bidInfos) do
        Gbid:stop(item, index)
      end
    end
  elseif (items[item] and items[item][index]) then
    Gbid:stop(item, index)
  else
    print("Item does not exist in the bid list.")
  end
end

function Gbid:stop(item, index)
  index = index or 1
  local itemName, itemLink, itemQuality = GetItemInfo(item)
  if (items[itemLink]) then
    if (items[itemLink][index].biddable) then
      items[itemLink][index].biddable = false
      SendChatMessage("Bidding has stopped on " .. Gbid:displayItemWithIndex(itemLink, index) .. ".", "RAID")
    else
      print("The bid for " .. Gbid:displayItemWithIndex(item, index) .. " has already stopped. You can start it with \"/gbid start " .. Gbid:displayItemWithIndex(item, index) .. "\".")
    end
  else
    print("Could not stop the bid for " .. item .. " because it was not found. You can try to \"/gbid add " .. item .. "\".")
  end
end

function Gbid:remove(item, index)
  index = index or 1
  local itemName, itemLink, itemQuality = GetItemInfo(item)
  SendChatMessage("Item " .. Gbid:displayItemWithIndex(itemLink, index) .. " was removed from the gbid.", "RAID")
  items[itemLink][index] = nil
  if (#items[itemLink] == 0) then items[itemLink] = nil end
end

function Gbid:record()
  Gbid:RegisterEvent("CHAT_MSG_LOOT")
  recording = true
end

function Gbid:norecord()
  Gbid:UnregisterEvent("CHAT_MSG_LOOT")
  recording = false
end

function Gbid:clear()
  items = {}
end

function Gbid:CHAT_MSG_LOOT(event, message, player, lang)
  if(string.find(message, "receive loot")) then
    Gbid:add(message)
  end
end

function Gbid:CHAT_MSG_RAID(event, message, player, lang)
  Gbid:bidding(message, player, lang)
end

function Gbid:CHAT_MSG_RAID_LEADER(event, message, player, lang)
  Gbid:bidding(message, player, lang)
end

function Gbid:bidding(message, player, lang)
  local item, index, bid = string.match(message, "^" .. prefix .. "%s+([^#]+)#?(%d*)%s+(%d+)g?$")
  index = ((index and tonumber(index)) or 1)
  bid = ((bid and tonumber(bid)) or nil)
  if(item and index and bid) then
    local itemName, itemLink, itemQuality = GetItemInfo(item)
    if (itemName and items[itemLink] and items[itemLink][index] and items[itemLink][index].biddable) then
      if (not items[itemLink][index].bid and bid < minBid) then
        SendChatMessage(tostring(bid) .. "g is below the minimum bid of " .. tostring(minBid) .. ". There are currently no bidders on " .. Gbid:displayItemWithIndex(itemLink, index) .. ".", "RAID")
      elseif (items[itemLink][index].bid and bid <= items[itemLink][index].bid) then    
        SendChatMessage(tostring(bid) .. "g is at or below the current bid. Highest bidder is still " .. items[itemLink][index].player .. " for " .. Gbid:displayItemWithIndex(itemLink, index) .. " @ " .. tostring(items[itemLink][index].bid) .. "g", "RAID")
      elseif (items[itemLink][index].bid and bid < (items[itemLink][index].bid + minIncrement)) then    
        SendChatMessage(tostring(bid) .. "g is below the minimum increment of " .. tostring(minIncrement) .. ". Highest bidder is still " .. items[itemLink][index].player .. " for " .. Gbid:displayItemWithIndex(itemLink, index) .. " @ " .. tostring(items[itemLink][index].bid) .. "g", "RAID")
      elseif (not items[itemLink][index].bid or bid > items[itemLink][index].bid) then
        items[itemLink][index].player = string.match(player, "([^-]+)-.*")
        items[itemLink][index].bid = bid
        SendChatMessage("Highest bidder is " .. items[itemLink][index].player .. " for " .. Gbid:displayItemWithIndex(itemLink, index) .. " @ " .. bid .. "g", "RAID")
      end
    end
  end
end

function Gbid:display(message, broadcast)
  if (broadcast) then
    SendChatMessage(message, "RAID")
  else
    print(message)
  end
end

function Gbid:displayItemWithIndex(item, index)
  return item .. (((index > 1) and "#" .. index) or "")
end

function Gbid:handleReport(broadcast)
  local i = 1
  local total = 0
  Gbid:display("----------------------------", broadcast)
  for item, bidInfos in pairs(items) do
    for index, bidInfo in pairs(bidInfos) do
      local bid = "No bids"
      if (bidInfo.bid) then
        bid = bidInfo.player .. " @ " .. bidInfo.bid .. "g"
        total = total + bidInfo.bid
      end
      Gbid:display(tostring(i) .. ". " .. Gbid:displayItemWithIndex(item, index) .. " (bidding " .. (((not not bidInfo.biddable) and "enabled") or "disabled") .. "): " .. bid, broadcast)
      i = i + 1
    end
  end
  Gbid:display("----------------------------", broadcast)
  Gbid:display("Average gold per item: " .. string.format("%.2f", total / (i-1)) .. "g", broadcast)
  Gbid:display("Total gold: " .. total .. "g", broadcast)
end

function Gbid:ADDON_LOADED(event, title)
  if (title == "Gbid") then
    items = items or {}
    prefix = prefix or "!bid"
    immediate = (immediate ~= nil and immediate) or true
    minQuality = minQuality or 4
    minBid = minBid or 100
    minIncrement = minIncrement or 20
    Gbid:UnregisterEvent("ADDON_LOADED")
  end
end

Gbid:SetScript("OnEvent", function(self, event, ...)
  return Gbid[event](self, event, ...)
end)

SLASH_GBID1 = "/gbid"
SlashCmdList["GBID"] = function (message, editbox)
  if (string.find(message, "^status")) then
    print("Item quality threshold is at " .. tostring(minQuality) .. ".")
    print("You ARE" .. ((recording and "") or " NOT") .. " currently recording loot data...")
  elseif (string.find(message, "^record")) then
    Gbid:record()
    print("Recording loot data...")
  elseif (string.find(message, "^norecord")) then
    Gbid:norecord()
    print("No longer recording loot data.")
  elseif (string.find(message, "^start")) then
    local item, index = string.match(message, "^start%s+([^#]+)#?(%d*)$")
    Gbid:handleStart(item, tonumber(index))
  elseif (string.find(message, "^stop")) then
    local item, index = string.match(message, "^stop%s+([^#]+)#?(%d*)$")
    Gbid:handleStop(item, tonumber(index))
  elseif (string.find(message, "^clear")) then
    Gbid:clear()
    print("Cleared all loot and bids.")
  elseif (string.find(message, "^report")) then
    local broadcast = string.match(message, "^report%s+(.*)$")
    Gbid:handleReport(not not broadcast)
  elseif (string.find(message, "^add")) then
    local item = string.match(message, "^add%s+(.*)$")
    Gbid:add(item)
  elseif (string.find(message, "^remove")) then
    local item, index = string.match(message, "^remove%s+([^#]+)#?(%d*)$")
    Gbid:remove(item, tonumber(index))
  elseif (string.find(message, "^prefix")) then
    prefix = string.match(message, "^prefix%s+(%S+)$") or "!bid"
    print("Bidding prefix set to \"" .. prefix .. "\"")
  elseif (string.find(message, "^quality")) then
    local number = tonumber(string.match(message, "^quality%s+(%d)$"))
    if (not number or number < 0 or number > 4) then
      print("Minimum item quality can be in the range 0-4. 0 being grey items and 4 being epic items.")
    else
      minQuality = number
      print("Minimum item quality set to " .. number .. ".")
    end
  elseif (string.find(message, "^minBid")) then
    local num = string.match(message, "^minBid%s+(%d+)$")
    if (num) then
      minBid = num
    else
      print ("Incorrect format. Here is an example: /gbid minBid 10")
    end
  elseif (string.find(message, "^minIncrement")) then
    local num = string.match(message, "^minIncrement%s+(%d+)$")
    if (num) then
      minIncrement = num
    else
      print ("Incorrect format. Here is an example: /gbid minIncrement 10")
    end
  elseif (string.find(message, "^immediate")) then
    immediate = true
    print("Bidding will start when loot drops.")
  elseif (string.find(message, "^noimmediate")) then
    immediate = false
    print("Bidding will now be manually configured.")
  else
    print("|cffff00ffGbid chatbot|r - |cff00ff00by Kleenex-Herod|r")
    print(" ")
    print("|cffff0000General commands|r")
    print("  |cff00ffffstatus|r|r: Reports status of loot recording.")
    print("  |cff00ffffrecord|r: Records loot.") 
    print("  |cff00ffffnorecord|r: Stops recording loot.") 
    print("  |cff00ffffstart {item}|r: This starts the bidding on an item. If no item is given, bidding starts for all items.")
    print("  |cff00ffffstop {item}|r: This stops the bidding on an item. If no item is given, bidding stops for all items.")
    print("  |cff00ffffclear|r: Clears data stored on any previously ran gbids. (Be careful!)") 
    print("  |cff00ffffreport [raid]|r: Displays all items recorded. If there are any arguments (eg. \"/gbid report raid\") this will report the list in raid.") 
    print(" ")
    print("|cffff0000Item commands|r")
    print("  |cff00ffffadd {item}|r: Adds an item to the current gbid.")
    print("  |cff00ffffremove {item}|r: Removes an item from the current gbid and announces its removal.")
    print(" ")
    print("|cffff0000Settings|r")
    print("  |cff00ffffprefix {string}|r: (Currently|r: \"" .. prefix .. "\") Bidding prefix. Cannot be blank.")
    print("  |cff00ffffquality {number}|r: (Currently|r: " .. tostring(minQuality) .. ") Sets the minimum item quality for gbids (default is 4 which is Epic item quality.)")
    print("  |cff00ffffminBid {number}|r: (Currently|r: " .. tostring(minBid) .. ") Sets the minimum bid for the current and future gbids.")
    print("  |cff00ffffminIncrement {number}|r: (Currently|r: " .. tostring(minIncrement) .. ") Sets the minimum bid increment for the current and future gbids.")
    print("  |cff00ffffimmediate|r: (Currently|r: " .. (immediate and "" or "no") .. "immediate) Immediate mode. Allow bidding as soon as loot drops.")
    print("  |cff00ffffnoimmediate|r: (Currently|r: " .. (immediate and "" or "no") .. "immediate) Manually configure when loot is biddable.")
  end
end
