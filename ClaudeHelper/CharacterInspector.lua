-- ============================================================
-- CharacterInspector.lua  v0.2
-- Character panel: 3D model, current gear, BIS guide, auto-equip
-- WoW Midnight 12.x — multi-class, class auto-detected
-- ============================================================

local addon = ClaudeHelper

-- ── BIS data by class/spec (Midnight Season 1) ───────────────
-- Key: "CLASSFILE_SPECNAME" (e.g. "SHAMAN_Elemental")
-- Slot IDs: 1=Head 2=Neck 3=Shoulder 5=Chest 6=Waist 7=Legs 8=Feet
--           9=Wrist 10=Hands 11=Ring1 12=Ring2 13=Trinket1 14=Trinket2
--           15=Back 16=MainHand 17=OffHand
local BIS_BY_CLASS = {
    SHAMAN_Elemental = {
        [1]  = {name="Locus of the Primal Core",      id=249979, src="Midnight Falls (Tier)"},
        [2]  = {name="Amulet of the Abyssal Hymn",    id=250247, src="Midnight Falls Raid"},
        [3]  = {name="Tempests of the Primal Core",   id=249977, src="Midnight Falls (Tier)"},
        [5]  = {name="Embrace of the Primal Core",    id=249982, src="Midnight Falls (Tier)"},
        [6]  = {name="World Tender's Barkclasp",      id=244611, src="Crafting"},
        [7]  = {name="Greaves of the Divine Guile",   id=251215, src="Nexus Point Xenas"},
        [8]  = {name="World Tender's Rootslippers",   id=244610, src="Crafting"},
        [9]  = {name="Fallen King's Cuffs",           id=249304, src="Fallen-King Salhadaar"},
        [10] = {name="Earthgrips of the Primal Core", id=249980, src="Midnight Falls (Tier)"},
        [11] = {name="Platinum Star Band",            id=193708, src="Algeth'ar Academy"},
        [12] = {name="Sin'dorei Band of Hope",        id=249919, src="Belo'ren"},
        [13] = {name="Gaze of the Alnseer",           id=249343, src="Chimaerus"},
        [14] = {name="Emberwing Feather",             id=250144, src="Windrunner Spire"},
        [15] = {name="Guardian of the Primal Core",   id=249974, src="Catalyst"},
        [16] = {name="Excavating Cudgel",             id=251083, src="Windrunner Spire"},
        [17] = {name="Ward of the Spellbreaker",      id=251105, src="Magister's Terrace"},
    },
    SHAMAN_Enhancement = {
        [1]  = {name="Helm of the Primal Core",       id=249979, src="Midnight Falls (Tier)"},
        [2]  = {name="Amulet of the Abyssal Hymn",    id=250247, src="Midnight Falls Raid"},
        [16] = {name="Excavating Cudgel",             id=251083, src="Windrunner Spire"},
    },
    SHAMAN_Restoration = {
        [2]  = {name="Amulet of the Abyssal Hymn",    id=250247, src="Midnight Falls Raid"},
        [16] = {name="Excavating Cudgel",             id=251083, src="Windrunner Spire"},
    },
    -- Extend with more classes as data becomes available.
    -- Format: CLASSFILE_SpecName = { [slotID]={name,id,src}, ... }
}

-- Resolve BIS table for the logged-in character
local function GetBIS()
    local _, classFile = UnitClass("player")
    local specIdx = GetSpecialization and GetSpecialization() or 0
    local specName = ""
    if specIdx and specIdx > 0 then
        local _, sn = GetSpecializationInfo(specIdx)
        specName = sn or ""
    end
    local key = (classFile or "UNKNOWN") .. "_" .. specName
    return BIS_BY_CLASS[key] or BIS_BY_CLASS["SHAMAN_Elemental"] or {}
end

-- Keep a module-level reference updated on show/refresh
local BIS = GetBIS()

local SLOT_ORDER = {1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17}

local SLOT_LABEL = {
    [1]="Head",    [2]="Neck",    [3]="Shoulder", [5]="Chest",
    [6]="Waist",   [7]="Legs",    [8]="Feet",     [9]="Wrist",
    [10]="Hands",  [11]="Ring 1", [12]="Ring 2",  [13]="Trinkt 1",
    [14]="Trinkt 2",[15]="Back",  [16]="Main Hand",[17]="Off Hand",
}

-- equipLoc string → possible inventory slot IDs
local EQUIP_LOC_MAP = {
    INVTYPE_HEAD=           {1},
    INVTYPE_NECK=           {2},
    INVTYPE_SHOULDER=       {3},
    INVTYPE_CLOAK=          {15},
    INVTYPE_CHEST=          {5},  INVTYPE_ROBE={5},
    INVTYPE_WRIST=          {9},
    INVTYPE_HAND=           {10},
    INVTYPE_WAIST=          {6},
    INVTYPE_LEGS=           {7},
    INVTYPE_FEET=           {8},
    INVTYPE_FINGER=         {11, 12},
    INVTYPE_TRINKET=        {13, 14},
    INVTYPE_WEAPON=         {16, 17},
    INVTYPE_WEAPONMAINHAND= {16},
    INVTYPE_WEAPONOFFHAND=  {17},
    INVTYPE_SHIELD=         {17},
    INVTYPE_2HWEAPON=       {16},
}

-- ── Item helpers ─────────────────────────────────────────────

local function GetIlvl(link)
    if not link then return 0 end
    local ok, ilvl = pcall(GetDetailedItemLevelInfo, link)
    if ok and ilvl and ilvl > 0 then return ilvl end
    local ok2, _, _, ilvl2 = pcall(GetItemInfo, link)
    return (ok2 and ilvl2) or 0
end

local function GetEquippedIlvl(slotID)
    return GetIlvl(GetInventoryItemLink("player", slotID))
end

local function GetEquippedItemID(slotID)
    return GetInventoryItemID("player", slotID)
end

-- Get item info fields via pcall (data may not be cached yet)
local function SafeGetItemInfo(item)
    local ok, name, link, quality, ilvl, _, _, _, _, equipLoc, tex =
        pcall(GetItemInfo, item)
    if not ok then return nil end
    return name, link, quality, ilvl, equipLoc, tex
end

-- Find best upgrade in bags for slotID.
-- Returns: bag, slot, ilvl  (nil if nothing better)
local function BestBagItem(slotID)
    -- For paired slots, target the weaker one
    local targetSlot = slotID
    local curIlvl    = GetEquippedIlvl(slotID)
    if slotID == 11 or slotID == 12 then
        local il11 = GetEquippedIlvl(11)
        local il12 = GetEquippedIlvl(12)
        if il11 <= il12 then targetSlot = 11; curIlvl = il11
        else               targetSlot = 12; curIlvl = il12 end
    elseif slotID == 13 or slotID == 14 then
        local il13 = GetEquippedIlvl(13)
        local il14 = GetEquippedIlvl(14)
        if il13 <= il14 then targetSlot = 13; curIlvl = il13
        else               targetSlot = 14; curIlvl = il14 end
    end

    local bestBag, bestSlot, bestIlvl = nil, nil, curIlvl
    for bag = 0, 4 do
        local n = 0
        if C_Container and C_Container.GetContainerNumSlots then
            n = C_Container.GetContainerNumSlots(bag) or 0
        end
        for s = 1, n do
            local info = C_Container and C_Container.GetContainerItemInfo(bag, s)
            local link = info and info.hyperlink
            if link then
                local _, _, _, ilvl, equipLoc = SafeGetItemInfo(link)
                local slots = EQUIP_LOC_MAP[equipLoc or ""]
                if slots then
                    for _, sid in ipairs(slots) do
                        if sid == targetSlot
                        or (targetSlot == 11 and sid == 12)
                        or (targetSlot == 12 and sid == 11)
                        or (targetSlot == 13 and sid == 14)
                        or (targetSlot == 14 and sid == 13) then
                            local il = ilvl or 0
                            if il > bestIlvl then
                                bestIlvl = il
                                bestBag  = bag
                                bestSlot = s
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    return bestBag, bestSlot, bestIlvl
end

local function EquipFromBag(bag, slot)
    if InCombatLockdown() then
        print("|cff00aaffClaudeHelper|r |cffff4444Cannot equip items in combat.|r")
        return false
    end
    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(bag, slot)
    elseif UseContainerItem then
        UseContainerItem(bag, slot)
    end
    return true
end

-- ── Main frame ───────────────────────────────────────────────
local CI_W, CI_H  = 760, 560
local MDL_W       = 210   -- left model panel width
local PAD         = 8
local ROW_H       = 30
local ICON_SZ     = 26
local BIS_ICON_SZ = 22

local charInspFrame = CreateFrame("Frame","ClaudeHelperCharInspFrame",UIParent,"BackdropTemplate")
charInspFrame:SetSize(CI_W, CI_H)
charInspFrame:SetMovable(true)
charInspFrame:EnableMouse(true)
charInspFrame:RegisterForDrag("LeftButton")
charInspFrame:SetScript("OnDragStart", charInspFrame.StartMoving)
charInspFrame:SetScript("OnDragStop",  charInspFrame.StopMovingOrSizing)
charInspFrame:SetBackdrop({
    bgFile="Interface/Tooltips/UI-Tooltip-Background",
    edgeFile="Interface/Tooltips/UI-Tooltip-Border",
    tile=true, tileSize=16, edgeSize=16,
    insets={left=4,right=4,top=4,bottom=4},
})
charInspFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
charInspFrame:SetBackdropBorderColor(0.5, 0.5, 0.7, 1)
charInspFrame:Hide()

-- Title
local ciTitle = charInspFrame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
ciTitle:SetPoint("TOP",0,-10)
ciTitle:SetText("|cff00aaffClaude Helper|r  —  Character Inspector")

-- Subtitle (updated dynamically on show)
local ciSub = charInspFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
ciSub:SetPoint("TOP",0,-28)
ciSub:SetText("|cffffff00Detecting class…  ·  Midnight Season 1|r")

function addon:UpdateInspectorSubtitle()
    local _, classFile = UnitClass("player")
    local className    = UnitClass("player") or "?"
    local specIdx  = GetSpecialization and GetSpecialization() or 0
    local specName = ""
    if specIdx and specIdx > 0 then
        local _, sn = GetSpecializationInfo(specIdx)
        specName = sn or ""
    end
    local src = (ClaudeHelperDB and ClaudeHelperDB.guideSource) or "wowhead"
    local srcLabel = ({ wowhead="Wowhead", icyveins="Icy Veins",
                        archon="Archon.gg", subcreation="Subcreation" })[src] or src
    ciSub:SetText(string.format("|cffffff00%s %s  ·  Midnight S1  ·  via %s|r",
        specName, className, srcLabel))
end

-- Divider
local ciDiv = charInspFrame:CreateTexture(nil,"ARTWORK")
ciDiv:SetSize(CI_W-20, 1); ciDiv:SetPoint("TOP",0,-42); ciDiv:SetColorTexture(0.4,0.4,0.5,0.8)

-- ── 3D PlayerModel ───────────────────────────────────────────
local modelBG = CreateFrame("Frame",nil,charInspFrame,"BackdropTemplate")
modelBG:SetSize(MDL_W, CI_H - 90)
modelBG:SetPoint("TOPLEFT", PAD, -48)
modelBG:SetBackdrop({
    bgFile="Interface/Tooltips/UI-Tooltip-Background",
    edgeFile="Interface/Tooltips/UI-Tooltip-Border",
    tile=true, tileSize=8, edgeSize=8,
    insets={left=2,right=2,top=2,bottom=2},
})
modelBG:SetBackdropColor(0,0,0,0.6)
modelBG:SetBackdropBorderColor(0.3,0.3,0.4,1)

local model = CreateFrame("PlayerModel", nil, modelBG)
model:SetPoint("TOPLEFT",4,-4); model:SetPoint("BOTTOMRIGHT",-4,4)
model:SetUnit("player")
model:SetFacing(math.pi * 1.1)  -- face slightly to the right

-- Rotate on left-drag
local ciDragging = false
local ciLastX    = 0
model:EnableMouse(true)
model:SetScript("OnMouseDown", function(self, btn)
    if btn == "LeftButton" then ciDragging=true; ciLastX=select(1,GetCursorPosition()) end
end)
model:SetScript("OnMouseUp",   function() ciDragging=false end)
model:SetScript("OnUpdate",    function(self)
    if ciDragging then
        local x = select(1, GetCursorPosition())
        self:SetFacing(self:GetFacing() + (x - ciLastX) * 0.01)
        ciLastX = x
    end
end)
-- Zoom on scroll
model:SetScript("OnMouseWheel", function(self, d)
    local s = self:GetModelScale()
    self:SetModelScale(math.max(0.3, math.min(2.5, s + d * 0.1)))
end)

local modelHint = charInspFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
modelHint:SetPoint("BOTTOMLEFT", modelBG, "BOTTOMLEFT", 4, 4)
modelHint:SetTextColor(0.5,0.5,0.5); modelHint:SetText("Drag: rotate  ·  Scroll: zoom")

-- ── Gear list area ───────────────────────────────────────────
local listX    = MDL_W + PAD*2 + 4
local listW    = CI_W - listX - PAD
local listTopY = -48

-- Column headers
local function MakeHeader(text, xOff, yOff, w, color)
    local h = charInspFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    h:SetPoint("TOPLEFT", listX + xOff, yOff)
    h:SetWidth(w); h:SetJustifyH("LEFT")
    h:SetText(color and (color..text.."|r") or text)
    h:SetTextColor(0.7,0.7,0.8)
    return h
end
MakeHeader("Slot",    0,  listTopY,     52, nil)
MakeHeader("Equipped (ilvl)",52, listTopY, 230, nil)
MakeHeader("BIS Item  (Source)", 310, listTopY, 260, nil)

local hdrDiv = charInspFrame:CreateTexture(nil,"ARTWORK")
hdrDiv:SetHeight(1); hdrDiv:SetColorTexture(0.3,0.3,0.4,0.7)
hdrDiv:SetPoint("TOPLEFT",  listX,          listTopY - 14)
hdrDiv:SetPoint("TOPRIGHT", charInspFrame, "TOPRIGHT", -PAD, listTopY - 14)

-- ── Build 16 gear rows ────────────────────────────────────────
local rows = {}

for i, slotID in ipairs(SLOT_ORDER) do
    local yOff = listTopY - 18 - (i-1)*ROW_H
    local r    = {}
    r.slotID   = slotID

    -- Row background (alternating)
    if i % 2 == 0 then
        local bg = charInspFrame:CreateTexture(nil,"BACKGROUND")
        bg:SetHeight(ROW_H - 2)
        bg:SetPoint("TOPLEFT",  listX - 2, yOff)
        bg:SetPoint("TOPRIGHT", charInspFrame, "TOPRIGHT", -PAD+2, yOff)
        bg:SetColorTexture(1,1,1, 0.03)
    end

    -- Slot label
    local lbl = charInspFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", listX, yOff - 2)
    lbl:SetWidth(52); lbl:SetJustifyH("LEFT")
    lbl:SetText(SLOT_LABEL[slotID] or "?")
    lbl:SetTextColor(0.75, 0.75, 0.85)

    -- Equipped icon
    local eIconF = CreateFrame("Frame", nil, charInspFrame, "BackdropTemplate")
    eIconF:SetSize(ICON_SZ, ICON_SZ)
    eIconF:SetPoint("TOPLEFT", listX + 52, yOff - 1)
    eIconF:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background",
        edgeFile="Interface/Tooltips/UI-Tooltip-Border",
        tile=true,tileSize=8,edgeSize=6,insets={left=1,right=1,top=1,bottom=1}})
    eIconF:SetBackdropColor(0.1,0.1,0.1,1)
    eIconF:SetBackdropBorderColor(0.3,0.3,0.3,1)
    local eTex = eIconF:CreateTexture(nil,"ARTWORK")
    eTex:SetPoint("TOPLEFT",2,-2); eTex:SetPoint("BOTTOMRIGHT",-2,2)
    eTex:SetTexCoord(0.07,0.93,0.07,0.93)
    r.eIcon    = eTex
    r.eIconF   = eIconF

    -- Equipped tooltip
    eIconF:EnableMouse(true)
    eIconF.slotID = slotID
    eIconF:SetScript("OnEnter", function(self)
        local link = GetInventoryItemLink("player", self.slotID)
        if link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end
    end)
    eIconF:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Equipped item name + ilvl
    local eName = charInspFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    eName:SetPoint("LEFT", eIconF, "RIGHT", 4, 0)
    eName:SetWidth(155); eName:SetJustifyH("LEFT")
    r.eName = eName

    -- Match indicator (✓ or →)
    local match = charInspFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    match:SetPoint("LEFT", eName, "RIGHT", 4, 0)
    match:SetWidth(18); match:SetJustifyH("CENTER")
    r.match = match

    -- BIS icon
    local bIconF = CreateFrame("Frame", nil, charInspFrame, "BackdropTemplate")
    bIconF:SetSize(BIS_ICON_SZ, BIS_ICON_SZ)
    bIconF:SetPoint("TOPLEFT", listX + 316, yOff - 2)
    bIconF:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background",
        edgeFile="Interface/Tooltips/UI-Tooltip-Border",
        tile=true,tileSize=8,edgeSize=6,insets={left=1,right=1,top=1,bottom=1}})
    bIconF:SetBackdropColor(0.1,0.1,0.1,1)
    bIconF:SetBackdropBorderColor(0.2,0.2,0.2,1)
    local bTex = bIconF:CreateTexture(nil,"ARTWORK")
    bTex:SetPoint("TOPLEFT",2,-2); bTex:SetPoint("BOTTOMRIGHT",-2,2)
    bTex:SetTexCoord(0.07,0.93,0.07,0.93)
    r.bIcon    = bTex
    r.bIconF   = bIconF

    -- BIS tooltip
    bIconF:EnableMouse(true)
    bIconF.bisID = BIS[slotID] and BIS[slotID].id
    bIconF:SetScript("OnEnter", function(self)
        if self.bisID then
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            local ok = pcall(GameTooltip.SetItemByID, GameTooltip, self.bisID)
            if not ok then GameTooltip:SetText("Item "..self.bisID) end
            GameTooltip:Show()
        end
    end)
    bIconF:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- BIS name + source
    local bName = charInspFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    bName:SetPoint("LEFT", bIconF, "RIGHT", 4, 0)
    bName:SetWidth(170); bName:SetJustifyH("LEFT")
    r.bName = bName

    -- Per-slot Equip button
    local eBtn = CreateFrame("Button",nil,charInspFrame,"UIPanelButtonTemplate")
    eBtn:SetSize(52, 18)
    eBtn:SetPoint("RIGHT", charInspFrame, "TOPRIGHT", -PAD, yOff - 6)
    eBtn:SetText("Equip ↑")
    eBtn:Hide()
    r.equipBtn = eBtn
    eBtn.slotID = slotID
    eBtn:SetScript("OnClick", function(self)
        local bag, slot = BestBagItem(self.slotID)
        if bag then
            EquipFromBag(bag, slot)
            C_Timer.After(0.5, function() addon:RefreshInspector() end)
        end
    end)

    rows[i] = r
end

-- ── Bottom buttons ────────────────────────────────────────────
local autoBtn = CreateFrame("Button",nil,charInspFrame,"UIPanelButtonTemplate")
autoBtn:SetSize(170, 26)
autoBtn:SetPoint("BOTTOMLEFT", PAD, PAD)
autoBtn:SetText("Auto-equip All Upgrades ↑")
autoBtn:SetScript("OnClick", function()
    if InCombatLockdown() then
        print("|cff00aaffClaudeHelper|r |cffff4444Cannot equip items in combat.|r")
        return
    end
    local count = 0
    for _, slotID in ipairs(SLOT_ORDER) do
        local bag, slot = BestBagItem(slotID)
        if bag then
            EquipFromBag(bag, slot)
            count = count + 1
        end
    end
    if count > 0 then
        print(string.format("|cff00aaffClaudeHelper|r: |cff00ff00Equipped %d upgrade%s.|r",
            count, count==1 and "" or "s"))
        C_Timer.After(0.6, function() addon:RefreshInspector() end)
    else
        print("|cff00aaffClaudeHelper|r: No upgrades found in bags.")
    end
end)

local refreshBtn = CreateFrame("Button",nil,charInspFrame,"UIPanelButtonTemplate")
refreshBtn:SetSize(80, 26)
refreshBtn:SetPoint("BOTTOMRIGHT", charInspFrame, "BOTTOMRIGHT", -PAD*2-80, PAD)
refreshBtn:SetText("Refresh")
refreshBtn:SetScript("OnClick", function() addon:RefreshInspector() end)

local closeBtn = CreateFrame("Button",nil,charInspFrame,"UIPanelButtonTemplate")
closeBtn:SetSize(80, 26)
closeBtn:SetPoint("BOTTOMRIGHT", charInspFrame, "BOTTOMRIGHT", -PAD, PAD)
closeBtn:SetText("Close")
closeBtn:SetScript("OnClick", function() charInspFrame:Hide() end)

-- Progress label (shows upgrade count in bottom bar)
local upgradeLabel = charInspFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
upgradeLabel:SetPoint("LEFT", autoBtn, "RIGHT", 10, 0)
upgradeLabel:SetTextColor(1, 0.85, 0.2)

-- ── Preload BIS item data to avoid empty icon squares ────────
-- Called once per BIS table (on first show / spec change).
-- Uses C_Timer.After(0) so callbacks never re-enter RefreshInspector
-- synchronously, preventing stack-overflow crashes.
local bisPreloadKey = ""  -- tracks which BIS table is already registered

local function PreloadBISItems(bisTable, tableKey)
    if tableKey == bisPreloadKey then return end  -- already registered for this spec
    bisPreloadKey = tableKey

    -- Item mixin may not exist in all environments; guard defensively
    if not Item or not Item.CreateFromItemID then return end

    for _, bisData in pairs(bisTable) do
        if bisData.id then
            local ok, item = pcall(Item.CreateFromItemID, Item, bisData.id)
            if ok and item and item.ContinueOnItemLoad then
                item:ContinueOnItemLoad(function()
                    -- Defer one frame so we never call RefreshInspector
                    -- from inside an item-load callback (avoids recursion)
                    C_Timer.After(0, function()
                        if charInspFrame:IsShown() then
                            addon:RefreshInspector()
                        end
                    end)
                end)
            end
        end
    end
end

-- ── Refresh logic ─────────────────────────────────────────────
function addon:RefreshInspector()
    -- Re-resolve BIS for current spec (may have changed)
    local _, classFile = UnitClass("player")
    local specIdx = GetSpecialization and GetSpecialization() or 0
    local specName = ""
    if specIdx and specIdx > 0 then
        local ok, _, sn = pcall(GetSpecializationInfo, specIdx)
        if ok then specName = sn or "" end
    end
    local bisKey = (classFile or "UNKNOWN") .. "_" .. specName
    BIS = GetBIS()

    -- Preload any un-cached BIS items (no-op if already done for this spec)
    PreloadBISItems(BIS, bisKey)

    -- Update subtitle with current class/spec/guide
    addon:UpdateInspectorSubtitle()

    -- Refresh 3D model
    model:SetUnit("player")

    local upgradeCount = 0

    for _, r in ipairs(rows) do
        local slotID    = r.slotID
        local bis       = BIS[slotID]

        -- ── Equipped slot ─────────────────────────────────────
        local link       = GetInventoryItemLink("player", slotID)
        local tex        = GetInventoryItemTexture("player", slotID)
        local equippedID = GetInventoryItemID("player", slotID)
        local ilvl       = GetIlvl(link)

        if tex then
            -- Item equipped — show icon box
            r.eIconF:Show()
            r.eIcon:SetTexture(tex)
            r.eIconF:SetBackdropBorderColor(0.3,0.3,0.3,1)
        else
            -- Nothing equipped — hide the square, keep label
            r.eIconF:Hide()
        end

        if link then
            local name = SafeGetItemInfo(link) or "..."
            if #name > 22 then name = name:sub(1,20)..".." end
            local col
            if bis and equippedID == bis.id then
                col = "|cff00ff00"
            elseif bis then
                col = "|cffff8888"
            else
                col = "|cffffff00"
            end
            r.eName:SetText(string.format("%s%s|r  |cffaaaaaa%d|r", col, name, ilvl))
        else
            r.eName:SetText("|cff555555— empty —|r")
        end

        -- ── BIS slot ──────────────────────────────────────────
        if bis then
            local bisName, _, _, _, _, bisTex = SafeGetItemInfo(bis.id)

            if bisTex then
                r.bIconF:Show()
                r.bIcon:SetTexture(bisTex)
            else
                -- Texture not yet cached — hide box, name will show
                r.bIconF:Hide()
            end

            local bisLabel = (bisName or bis.name)
            if #bisLabel > 20 then bisLabel = bisLabel:sub(1,18)..".." end

            if equippedID == bis.id then
                r.match:SetText("|cff00ff00✓|r")
                r.bName:SetText("|cff00ff00"..bisLabel.."|r")
                if bisTex then r.bIconF:SetBackdropBorderColor(0.1, 0.7, 0.1, 1) end
            else
                r.match:SetText("|cffffcc00→|r")
                r.bName:SetText(string.format("|cffffff88%s|r  |cff888888%s|r", bisLabel, bis.src))
                if bisTex then r.bIconF:SetBackdropBorderColor(0.4, 0.3, 0.1, 1) end
            end
        else
            -- No BIS data for this slot — hide both BIS elements
            r.bIconF:Hide()
            r.match:SetText("")
            r.bName:SetText("|cff444444—|r")
        end

        -- ── Bag upgrade button ────────────────────────────────
        local bag, slot = BestBagItem(slotID)
        if bag then
            r.equipBtn:Show()
            upgradeCount = upgradeCount + 1
        else
            r.equipBtn:Hide()
        end
    end

    if upgradeCount > 0 then
        upgradeLabel:SetText(string.format("|cff00ff00%d upgrade%s in bag!|r",
            upgradeCount, upgradeCount==1 and "" or "s"))
    else
        upgradeLabel:SetText("|cff00ff00All slots optimal|r")
    end
end

-- ── Events ───────────────────────────────────────────────────
local ciEventFrame = CreateFrame("Frame")
ciEventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ciEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
ciEventFrame:SetScript("OnEvent", function()
    if charInspFrame:IsShown() then
        C_Timer.After(0.3, function() addon:RefreshInspector() end)
    end
end)

charInspFrame:SetScript("OnShow", function()
    -- Re-resolve BIS before refresh (spec may have changed since last open)
    BIS = GetBIS()
    -- Update BIS tooltip IDs for all rows
    for _, r in ipairs(rows) do
        if r.bIconF then
            r.bIconF.bisID = BIS[r.slotID] and BIS[r.slotID].id
        end
    end
    addon:RefreshInspector()
end)

-- ── Hook onto the default Character panel (C key) ────────────
-- Opens/closes alongside the default frame
local function HookCharacterFrame()
    if CharacterFrame then
        CharacterFrame:HookScript("OnShow", function()
            -- Anchor to the right of the default character panel
            charInspFrame:ClearAllPoints()
            charInspFrame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 4, 0)
            charInspFrame:Show()
        end)
        CharacterFrame:HookScript("OnHide", function()
            charInspFrame:Hide()
        end)
    end
end

-- Hook after ADDON_LOADED so CharacterFrame exists
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hookFrame:SetScript("OnEvent", function(self)
    HookCharacterFrame()
    self:UnregisterAllEvents()
end)

-- ── Expose ───────────────────────────────────────────────────
addon.charInspFrame = charInspFrame
