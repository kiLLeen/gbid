local Gbid = CreateFrame("Frame", "Gbid")
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
  SendChatMessage("Bidding has started on " .. itemLink .. ". Type \"!bid " .. itemName .. " " .. tostring(minBid) .. "\" to make a minimum bid.", "RAID")
  -- TODO: Add a player and bid table to allow bids when multiple of the same item drops.
  items[itemLink] = {}
end

function Gbid:remove(item)
  local itemName, itemLink, itemQuality = GetItemInfo(item)
  SendChatMessage("Item " .. itemLink .. " was removed from the gbid.", "RAID")
  items[itemLink] = nil
end

function Gbid:record()
  Gbid:RegisterEvent("CHAT_MSG_LOOT")
  Gbid:RegisterEvent("CHAT_MSG_RAID")
  Gbid:RegisterEvent("CHAT_MSG_RAID_LEADER")
  recording = true
end

function Gbid:norecord()
  Gbid:UnregisterEvent("CHAT_MSG_LOOT")
  Gbid:UnregisterEvent("CHAT_MSG_RAID")
  Gbid:UnregisterEvent("CHAT_MSG_RAID_LEADER")
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
  if(string.find(message, "^!bid ")) then
    local itemChatRef = string.match(message, "^!bid%s+(.*)%s+%d+g?$")
    local bidChatRef = tonumber(string.match(message, "^!bid%s+.*%s+(%d+)g?$"))
    local itemName, itemLink, itemQuality = GetItemInfo(itemChatRef)
    if (itemName and items[itemLink]) then
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

function Gbid:ADDON_LOADED(event, title)
  if (title == "Gbid") then
    items = items or {}
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
    if (recording) then
      print("You ARE currently recording loot data...")
    else
      print("You ARE NOT currently recording loot data.")
    end
  elseif (string.find(message, "^record")) then
    print("Recording loot data...")
    Gbid:record()
  elseif (string.find(message, "^norecord")) then
    print("No longer recording loot data.")
    Gbid:norecord()
  elseif (string.find(message, "^clear")) then
    print("Cleared all loot and bids.")
    Gbid:clear()
  elseif (string.find(message, "^report")) then
    local i = 1
    local total = 0
    for item, bidInfo in pairs(items) do
      local bid = "No bids"
      if (bidInfo.bid) then
        bid = bidInfo.player .. " @ " .. bidInfo.bid .. "g"
        total = total + bidInfo.bid
      end
      SendChatMessage(tostring(i) .. ". " .. item .. ": " .. bid, "RAID")
      i = i + 1
    end
    SendChatMessage("Total gold: " .. total .. "g", "RAID")
  elseif (string.find(message, "^add")) then
    local item = string.match(message, "^add%s+(.*)$")
    Gbid:add(item)
  elseif (string.find(message, "^remove")) then
    local item = string.match(message, "^remove%s+(.*)$")
    Gbid:remove(item)
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
  else
    print("Gbid chatbot - Created by Kleenex on Herod")
    print("General command list")
    print("  status: Reports loot recording and bidding status.")
    print("  record: Records loot.") 
    print("  norecord: Stops recording loot.") 
    print("  clear: Clears data stored on any previously ran gbids.") 
    print("  report: One time report of the current state of the items and bids.") 
    -- TODO: Doesn't work yet
    print("Settings")
    print("  quality {number}: Sets the minimum item quality for gbids (default is 4 which is Epic item quality.) - TODO")
    print("  minBid {number}: Sets the minimum bid for the current and future gbids.")
    print("  minIncrement {number}: Sets the minimum bid increment for the current and future gbids.")
    print("Admin item command list")
    print("  add {item}: Adds an item to the current gbid and announces it.")
    print("  remove {item}: Removes an item from the current gbid and announces it.")
  end
end
