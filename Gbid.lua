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
  if (immediate and itemQuality >= minQuality) then
    SendChatMessage("Bidding has started on " .. itemLink .. ". Type \"" .. prefix .. " " .. itemName .. " " .. tostring(minBid) .. "\" to make a minimum bid.", "RAID")
  end
  -- TODO: Add a player and bid table to allow bids when multiple of the same item drops.
  items[itemLink] = { biddable = immediate }
end

function Gbid:handleStart(item)
  if (not item or item == "") then
    for item, _ in pairs(items) do Gbid:start(item) end
  elseif (items[item]) then
    Gbid:start(item)
  else
    print("Item does not exist in the bid list.")
  end
end

function Gbid:start(item)
  local itemName, itemLink, itemQuality = GetItemInfo(item)
  if (items[itemLink]) then
    if (not items[itemLink].biddable) then
      items[itemLink].biddable = true
      SendChatMessage("Bidding has started on " .. itemLink .. ". Type \"" .. prefix .. " " .. itemName .. " " .. tostring(minBid) .. "\" to make a minimum bid.", "RAID")
    else
      print("The bid for " .. item .. " is already in progress. You can stop it with \"/gbid stop " .. item .. "\".")
    end
  else
    print("Could not start the bid for " .. item .. " because it was not found. You can try to \"/gbid add " .. item .. "\".")
  end
end

function Gbid:handleStop(item)
  if (not item or item == "") then
    for item, _ in pairs(items) do Gbid:stop(item) end
  elseif (items[item]) then
    Gbid:stop(item)
  else
    print("Item does not exist in the bid list.")
  end
end

function Gbid:stop(item)
  local itemName, itemLink, itemQuality = GetItemInfo(item)
  if (items[itemLink]) then
    if (items[itemLink].biddable) then
      items[itemLink].biddable = false
      SendChatMessage("Bidding has stopped on " .. itemLink .. ".", "RAID")
    else
      print("The bid for " .. item .. " is already stopped. You can start it with \"/gbid start " .. item .. "\".")
    end
  else
    print("Could not stop the bid for " .. item .. " because it was not found. You can try to \"/gbid add " .. item .. "\".")
  end
end

function Gbid:remove(item)
  local itemName, itemLink, itemQuality = GetItemInfo(item)
  SendChatMessage("Item " .. itemLink .. " was removed from the gbid.", "RAID")
  items[itemLink] = nil
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
  local itemChatRef = string.match(message, "^" .. prefix .. "%s+(.*)%s+%d+g?$")
  local bidChatRef = tonumber(string.match(message, "^" .. prefix .. ".*%s+(%d+)g?$"))
  if(itemChatRef and bidChatRef) then
    local itemName, itemLink, itemQuality = GetItemInfo(itemChatRef)
    if (itemName and items[itemLink] and items[itemLink].biddable) then
      if (not items[itemLink].bid and bidChatRef < minBid) then
        SendChatMessage(tostring(bidChatRef) .. "g is below the minimum bid of " .. tostring(minBid) .. ". There are currently no bidders on " .. itemLink .. ".", "RAID")
      elseif (items[itemLink].bid and bidChatRef <= items[itemLink].bid) then    
        SendChatMessage(tostring(bidChatRef) .. "g is at or below the current bid. Highest bidder is still " .. items[itemLink].player .. " for " .. itemLink .. " @ " .. tostring(items[itemLink].bid) .. "g", "RAID")
      elseif (items[itemLink].bid and bidChatRef < (items[itemLink].bid + minIncrement)) then    
        SendChatMessage(tostring(bidChatRef) .. "g is below the minimum increment of " .. tostring(minIncrement) .. ". Highest bidder is still " .. items[itemLink].player .. " for " .. itemLink .. " @ " .. tostring(items[itemLink].bid) .. "g", "RAID")
      elseif (not items[itemLink].bid or bidChatRef > items[itemLink].bid) then
        items[itemLink].player = string.match(player, "([^-]+)-.*")
        items[itemLink].bid = bidChatRef
        SendChatMessage("Highest bidder is " .. items[itemLink].player .. " for " .. itemLink .. " @ " .. bidChatRef .. "g", "RAID")
      end
    end
  end
end

function Gbid:handleReport()
  local i = 1
  local total = 0
  SendChatMessage("----------------------------", "RAID")
  for item, bidInfo in pairs(items) do
    local bid = "No bids"
    if (bidInfo.bid) then
      bid = bidInfo.player .. " @ " .. bidInfo.bid .. "g"
      total = total + bidInfo.bid
    end
    SendChatMessage(tostring(i) .. ". " .. item .. ": " .. bid, "RAID")
    i = i + 1
  end
  SendChatMessage("----------------------------", "RAID")
  SendChatMessage("Average gold per item: " .. string.format("%.2f", total / (i-1)) .. "g", "RAID")
  SendChatMessage("Total gold: " .. total .. "g", "RAID")
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
    print("Recording loot data...")
    Gbid:record()
  elseif (string.find(message, "^norecord")) then
    print("No longer recording loot data.")
    Gbid:norecord()
  elseif (string.find(message, "^start")) then
    local item = string.match(message, "^start%s+(.*)$")
    Gbid:handleStart(item)
  elseif (string.find(message, "^stop")) then
    local item = string.match(message, "^stop%s+(.*)$")
    Gbid:handleStop(item)
  elseif (string.find(message, "^clear")) then
    print("Cleared all loot and bids.")
    Gbid:clear()
  elseif (string.find(message, "^report")) then
    Gbid:handleReport()
  elseif (string.find(message, "^add")) then
    local item = string.match(message, "^add%s+(.*)$")
    Gbid:add(item)
  elseif (string.find(message, "^remove")) then
    local item = string.match(message, "^remove%s+(.*)$")
    Gbid:remove(item)
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
    print("Gbid chatbot - Created by Kleenex on Herod")
    print(" ")
    print("General commands")
    print("  status: Reports status of loot recording.")
    print("  record: Records loot.") 
    print("  norecord: Stops recording loot.") 
    print("  start {item}: This starts the bidding on an item. If no item is given, bidding starts for all items.")
    print("  stop {item}: This stops the bidding on an item. If no item is given, bidding stops for all items.")
    print("  clear: Clears data stored on any previously ran gbids. (Be careful!)") 
    print("  report: One time report of the current state of the items and bids.") 
    print(" ")
    print("Item commands")
    print("  add {item}: Adds an item to the current gbid.")
    print("  remove {item}: Removes an item from the current gbid and announces its removal.")
    print(" ")
    print("Settings")
    print("  prefix {string}: (Currently: \"" .. prefix .. "\") Bidding prefix. Cannot be blank.")
    print("  quality {number}: (Currently: " .. tostring(minQuality) .. ") Sets the minimum item quality for gbids (default is 4 which is Epic item quality.)")
    print("  minBid {number}: (Currently: " .. tostring(minBid) .. ") Sets the minimum bid for the current and future gbids.")
    print("  minIncrement {number}: (Currently: " .. tostring(minIncrement) .. ") Sets the minimum bid increment for the current and future gbids.")
    print("  immediate: (Currently: " .. (immediate and "" or "no") .. "immediate) Immediate mode. Allow bidding as soon as loot drops.")
    print("  noimmediate: (Currently: " .. (immediate and "" or "no") .. "immediate) Manually configure when loot is biddable.")
  end
end
