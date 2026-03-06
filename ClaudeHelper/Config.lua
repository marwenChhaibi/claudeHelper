-- ============================================================
-- Config.lua  v1.0
-- Configuration window: guide source, class detection,
-- talent import, quest auto-acceptance
-- ============================================================

local addon = ClaudeHelper

-- ── Saved variable defaults ───────────────────────────────────
local DEFAULTS = {
    guideSource          = "wowhead",
    autoAcceptMainQuest  = false,
    autoAcceptSideQuest  = false,
    buildVersion         = "Midnight S1 — March 2026",
    lastTalentString     = "",
}

local function InitDB()
    ClaudeHelperDB = ClaudeHelperDB or {}
    for k, v in pairs(DEFAULTS) do
        if ClaudeHelperDB[k] == nil then
            ClaudeHelperDB[k] = v
        end
    end
end

-- Init on ADDON_LOADED
local dbInitFrame = CreateFrame("Frame")
dbInitFrame:RegisterEvent("ADDON_LOADED")
dbInitFrame:SetScript("OnEvent", function(self, _, addonName)
    if addonName == "ClaudeHelper" then
        InitDB()
        self:UnregisterAllEvents()
    end
end)

-- ── Guide sources ─────────────────────────────────────────────
local GUIDES = {
    { key="wowhead",   label="Wowhead",   hint="wowhead.com — search your class + spec guide" },
    { key="icyveins",  label="Icy Veins", hint="icy-veins.com — class guides with talent strings" },
    { key="archon",    label="Archon.gg", hint="archon.gg/wow — statistical top builds" },
    { key="subcreation", label="Subcreation", hint="subcreation.net — aggregated meta data" },
}

local GUIDE_HINT = {}
for _, g in ipairs(GUIDES) do GUIDE_HINT[g.key] = g.hint end

-- Online source URLs per class (shown as reference text in UI)
local CLASS_GUIDE_URLS = {
    SHAMAN = {
        wowhead    = "wowhead.com/guide/classes/shaman/elemental",
        icyveins   = "icy-veins.com/wow/elemental-shaman-guide",
        archon     = "archon.gg/wow/builds/shaman/elemental",
        subcreation= "subcreation.net/shaman-elemental.html",
    },
    WARRIOR = {
        wowhead    = "wowhead.com/guide/classes/warrior/fury",
        icyveins   = "icy-veins.com/wow/fury-warrior-guide",
        archon     = "archon.gg/wow/builds/warrior/fury",
        subcreation= "subcreation.net/warrior-fury.html",
    },
    PALADIN = {
        wowhead    = "wowhead.com/guide/classes/paladin/retribution",
        icyveins   = "icy-veins.com/wow/retribution-paladin-guide",
        archon     = "archon.gg/wow/builds/paladin/retribution",
        subcreation= "subcreation.net/paladin-retribution.html",
    },
    HUNTER = {
        wowhead    = "wowhead.com/guide/classes/hunter/beast-mastery",
        icyveins   = "icy-veins.com/wow/beast-mastery-hunter-guide",
        archon     = "archon.gg/wow/builds/hunter/beast-mastery",
        subcreation= "subcreation.net/hunter-beast-mastery.html",
    },
    ROGUE = {
        wowhead    = "wowhead.com/guide/classes/rogue/outlaw",
        icyveins   = "icy-veins.com/wow/outlaw-rogue-guide",
        archon     = "archon.gg/wow/builds/rogue/outlaw",
        subcreation= "subcreation.net/rogue-outlaw.html",
    },
    PRIEST = {
        wowhead    = "wowhead.com/guide/classes/priest/shadow",
        icyveins   = "icy-veins.com/wow/shadow-priest-guide",
        archon     = "archon.gg/wow/builds/priest/shadow",
        subcreation= "subcreation.net/priest-shadow.html",
    },
    DEATHKNIGHT = {
        wowhead    = "wowhead.com/guide/classes/death-knight/unholy",
        icyveins   = "icy-veins.com/wow/unholy-death-knight-guide",
        archon     = "archon.gg/wow/builds/death-knight/unholy",
        subcreation= "subcreation.net/death-knight-unholy.html",
    },
    DRUID = {
        wowhead    = "wowhead.com/guide/classes/druid/balance",
        icyveins   = "icy-veins.com/wow/balance-druid-guide",
        archon     = "archon.gg/wow/builds/druid/balance",
        subcreation= "subcreation.net/druid-balance.html",
    },
    MAGE = {
        wowhead    = "wowhead.com/guide/classes/mage/fire",
        icyveins   = "icy-veins.com/wow/fire-mage-guide",
        archon     = "archon.gg/wow/builds/mage/fire",
        subcreation= "subcreation.net/mage-fire.html",
    },
    WARLOCK = {
        wowhead    = "wowhead.com/guide/classes/warlock/affliction",
        icyveins   = "icy-veins.com/wow/affliction-warlock-guide",
        archon     = "archon.gg/wow/builds/warlock/affliction",
        subcreation= "subcreation.net/warlock-affliction.html",
    },
    MONK = {
        wowhead    = "wowhead.com/guide/classes/monk/windwalker",
        icyveins   = "icy-veins.com/wow/windwalker-monk-guide",
        archon     = "archon.gg/wow/builds/monk/windwalker",
        subcreation= "subcreation.net/monk-windwalker.html",
    },
    DEMONHUNTER = {
        wowhead    = "wowhead.com/guide/classes/demon-hunter/havoc",
        icyveins   = "icy-veins.com/wow/havoc-demon-hunter-guide",
        archon     = "archon.gg/wow/builds/demon-hunter/havoc",
        subcreation= "subcreation.net/demon-hunter-havoc.html",
    },
    EVOKER = {
        wowhead    = "wowhead.com/guide/classes/evoker/devastation",
        icyveins   = "icy-veins.com/wow/devastation-evoker-guide",
        archon     = "archon.gg/wow/builds/evoker/devastation",
        subcreation= "subcreation.net/evoker-devastation.html",
    },
}

-- ── Helper: detect current class + spec ──────────────────────
local function GetClassSpec()
    local _, classFile = UnitClass("player")
    local specIdx = GetSpecialization and GetSpecialization() or 0
    local specName = ""
    if specIdx and specIdx > 0 then
        local _, sName = GetSpecializationInfo(specIdx)
        specName = sName or ""
    end
    return classFile or "UNKNOWN", specName
end

local function GetClassColor(classFile)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then
        return string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
    end
    return "|cffffffff"
end

-- ── Talent import ─────────────────────────────────────────────
local function ApplyTalentString(str)
    str = str and str:match("^%s*(.-)%s*$") or ""
    if str == "" then
        print("|cff00aaffClaudeHelper|r: |cffff4444No talent string entered.|r")
        return
    end
    -- Try C_ClassTalents import (Dragonflight+)
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local configID = C_ClassTalents.GetActiveConfigID()
        if configID then
            local ok, err = pcall(C_Traits.ImportTraitConfig, configID, str)
            if ok then
                print("|cff00aaffClaudeHelper|r: |cff00ff00Talent build imported! Click Apply in the Talent UI to confirm.|r")
                ClaudeHelperDB.lastTalentString = str
                return
            else
                print("|cff00aaffClaudeHelper|r: |cffff4444Import error: " .. tostring(err) .. "|r")
            end
        end
    end
    -- Fallback: try PlayerTalentFrame import via default UI
    if PlayerTalentFrame and PlayerTalentFrame.ImportButton then
        print("|cff00aaffClaudeHelper|r: Open the Talent frame (N) and paste the string there.")
    else
        print("|cff00aaffClaudeHelper|r: |cffff4444Talent import API not available. Open the Talent frame and paste manually.|r")
    end
end

-- ── Config window ─────────────────────────────────────────────
local CFG_W, CFG_H = 520, 500
local P = 10  -- padding

local cfgFrame = CreateFrame("Frame","ClaudeHelperCfgFrame",UIParent,"BackdropTemplate")
cfgFrame:SetSize(CFG_W, CFG_H)
cfgFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
cfgFrame:SetMovable(true)
cfgFrame:EnableMouse(true)
cfgFrame:RegisterForDrag("LeftButton")
cfgFrame:SetScript("OnDragStart", cfgFrame.StartMoving)
cfgFrame:SetScript("OnDragStop",  cfgFrame.StopMovingOrSizing)
cfgFrame:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile=true, tileSize=16, edgeSize=16,
    insets={left=4,right=4,top=4,bottom=4},
})
cfgFrame:SetBackdropColor(0.05, 0.05, 0.10, 0.97)
cfgFrame:SetBackdropBorderColor(0.4, 0.6, 1.0, 1)
cfgFrame:SetFrameStrata("DIALOG")
cfgFrame:Hide()

-- Title
local cfgTitle = cfgFrame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
cfgTitle:SetPoint("TOP", 0, -P)
cfgTitle:SetText("|cff00aaffClaude Helper|r  —  Configuration")

-- Divider
local function MakeDivider(parent, yOff)
    local d = parent:CreateTexture(nil,"ARTWORK")
    d:SetHeight(1)
    d:SetPoint("TOPLEFT",  P, yOff)
    d:SetPoint("TOPRIGHT", -P, yOff)
    d:SetColorTexture(0.4, 0.5, 0.8, 0.5)
    return d
end

-- Section label
local function MakeSectionLabel(parent, text, yOff)
    local f = parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    f:SetPoint("TOPLEFT", P, yOff)
    f:SetTextColor(0.6, 0.8, 1.0)
    f:SetText(text)
    return f
end

-- ── § 1 — Character ──────────────────────────────────────────
MakeDivider(cfgFrame, -30)
MakeSectionLabel(cfgFrame, "Character", -34)

-- Class icon + name (populated on show)
local classIconTex = cfgFrame:CreateTexture(nil,"OVERLAY")
classIconTex:SetSize(28,28)
classIconTex:SetPoint("TOPLEFT", P, -52)

local classLabel = cfgFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
classLabel:SetPoint("LEFT", classIconTex, "RIGHT", 6, 0)
classLabel:SetText("Detecting...")

local specLabel = cfgFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
specLabel:SetPoint("TOPLEFT", P, -86)
specLabel:SetTextColor(0.85, 0.85, 0.85)

local buildVerLabel = cfgFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
buildVerLabel:SetPoint("TOPLEFT", P, -102)
buildVerLabel:SetTextColor(0.6, 0.9, 0.6)

-- ── § 2 — Guide Source ────────────────────────────────────────
MakeDivider(cfgFrame, -118)
MakeSectionLabel(cfgFrame, "Guide Source", -122)

local guideHintLabel = cfgFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
guideHintLabel:SetPoint("TOPLEFT", P, -160)
guideHintLabel:SetPoint("TOPRIGHT", -P, -160)
guideHintLabel:SetJustifyH("LEFT")
guideHintLabel:SetTextColor(0.7,0.7,0.5)

local guideUrlLabel = cfgFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
guideUrlLabel:SetPoint("TOPLEFT", P, -174)
guideUrlLabel:SetPoint("TOPRIGHT", -P, -174)
guideUrlLabel:SetJustifyH("LEFT")
guideUrlLabel:SetTextColor(0.5, 0.8, 1.0)

local guideBtns = {}
local function RefreshGuideButtons()
    local src = ClaudeHelperDB and ClaudeHelperDB.guideSource or "wowhead"
    local classFile = GetClassSpec()
    local urls = CLASS_GUIDE_URLS[classFile] or {}
    for _, btn in ipairs(guideBtns) do
        if btn.guideKey == src then
            btn:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)
            btn:SetBackdropColor(0.1, 0.25, 0.1, 1)
        else
            btn:SetBackdropBorderColor(0.3, 0.3, 0.5, 1)
            btn:SetBackdropColor(0.08, 0.08, 0.12, 1)
        end
    end
    guideHintLabel:SetText(GUIDE_HINT[src] or "")
    guideUrlLabel:SetText((urls[src] and ("  " .. urls[src])) or "")
end

for i, g in ipairs(GUIDES) do
    local bx = P + (i-1) * 122
    local btn = CreateFrame("Frame", nil, cfgFrame, "BackdropTemplate")
    btn:SetSize(118, 26)
    btn:SetPoint("TOPLEFT", bx, -140)
    btn:SetBackdrop({
        bgFile="Interface/Tooltips/UI-Tooltip-Background",
        edgeFile="Interface/Tooltips/UI-Tooltip-Border",
        tile=true, tileSize=8, edgeSize=6,
        insets={left=2,right=2,top=2,bottom=2},
    })
    btn:SetBackdropColor(0.08,0.08,0.12,1)
    btn:SetBackdropBorderColor(0.3,0.3,0.5,1)
    btn:EnableMouse(true)
    btn.guideKey = g.key

    local lbl = btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lbl:SetAllPoints()
    lbl:SetJustifyH("CENTER")
    lbl:SetText(g.label)

    btn:SetScript("OnMouseDown", function(self)
        ClaudeHelperDB = ClaudeHelperDB or {}
        ClaudeHelperDB.guideSource = self.guideKey
        RefreshGuideButtons()
        -- Update inspector subtitle if visible
        if addon.UpdateInspectorSubtitle then addon:UpdateInspectorSubtitle() end
    end)
    btn:SetScript("OnEnter", function(self)
        local src = self.guideKey
        local classFile = GetClassSpec()
        local urls = CLASS_GUIDE_URLS[classFile] or {}
        guideHintLabel:SetText(GUIDE_HINT[src] or "")
        guideUrlLabel:SetText((urls[src] and ("  " .. urls[src])) or "")
    end)
    btn:SetScript("OnLeave", function() RefreshGuideButtons() end)

    guideBtns[i] = btn
end

-- ── § 3 — Talent Import ───────────────────────────────────────
MakeDivider(cfgFrame, -196)
MakeSectionLabel(cfgFrame, "Talent Import", -200)

local talentNote = cfgFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
talentNote:SetPoint("TOPLEFT", P, -218)
talentNote:SetPoint("TOPRIGHT", -P, -218)
talentNote:SetJustifyH("LEFT")
talentNote:SetTextColor(0.7,0.7,0.6)
talentNote:SetText("Paste a talent loadout string from your guide source, then click Import.")

-- EditBox for talent string
local talentBox = CreateFrame("EditBox", "ClaudeHelperTalentBox", cfgFrame, "InputBoxTemplate")
talentBox:SetSize(CFG_W - P*2 - 90, 26)
talentBox:SetPoint("TOPLEFT", P + 4, -236)
talentBox:SetAutoFocus(false)
talentBox:SetMaxLetters(2048)
talentBox:SetFontObject("GameFontNormalSmall")
talentBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
talentBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

-- Restore last saved string on show
cfgFrame:SetScript("OnShow", function()
    InitDB()
    if ClaudeHelperDB.lastTalentString and ClaudeHelperDB.lastTalentString ~= "" then
        talentBox:SetText(ClaudeHelperDB.lastTalentString)
    end

    -- Update class labels
    local classFile, specName = GetClassSpec()
    local classColor = GetClassColor(classFile)
    local className  = UnitClass("player") or classFile

    -- Class icon
    local iconPath = string.format("Interface/Icons/ClassIcon_%s", classFile)
    classIconTex:SetTexture(iconPath)
    classLabel:SetText(classColor .. className .. "|r")
    specLabel:SetText("|cffffff88Spec:|r  " .. specName)
    buildVerLabel:SetText("|cffffff88Build version:|r  " .. (ClaudeHelperDB.buildVersion or DEFAULTS.buildVersion))

    -- Quest checkboxes
    if chkMain then chkMain:SetChecked(ClaudeHelperDB.autoAcceptMainQuest) end
    if chkSide then chkSide:SetChecked(ClaudeHelperDB.autoAcceptSideQuest) end

    RefreshGuideButtons()
end)

local importBtn = CreateFrame("Button", nil, cfgFrame, "UIPanelButtonTemplate")
importBtn:SetSize(82, 26)
importBtn:SetPoint("LEFT", talentBox, "RIGHT", 6, 0)
importBtn:SetText("Import")
importBtn:SetScript("OnClick", function()
    ApplyTalentString(talentBox:GetText())
end)

-- Online source info row
local talentSrcLabel = cfgFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
talentSrcLabel:SetPoint("TOPLEFT", P, -268)
talentSrcLabel:SetPoint("TOPRIGHT", -P, -268)
talentSrcLabel:SetJustifyH("LEFT")
talentSrcLabel:SetTextColor(0.5,0.8,1.0)
talentSrcLabel:SetText("Sources: see Guide Source section above — copy the loadout export string from the site.")

-- ── § 4 — Quest Automation ───────────────────────────────────
MakeDivider(cfgFrame, -284)
MakeSectionLabel(cfgFrame, "Quest Automation", -288)

local questNote = cfgFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
questNote:SetPoint("TOPLEFT", P, -306)
questNote:SetPoint("TOPRIGHT", -P, -306)
questNote:SetJustifyH("LEFT")
questNote:SetTextColor(0.7,0.7,0.6)
questNote:SetText("Automatically accept quests when the quest dialog opens.")

-- Checkbox helper
local function MakeCheckbox(parent, label, x, y, key)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24,24)
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb.Text:SetFontObject("GameFontNormalSmall")
    cb.Text:SetTextColor(0.9,0.9,0.9)
    cb:SetScript("OnClick", function(self)
        ClaudeHelperDB = ClaudeHelperDB or {}
        ClaudeHelperDB[key] = self:GetChecked()
    end)
    return cb
end

local chkMain = MakeCheckbox(cfgFrame, "Auto-accept Main Campaign quests",  P, -324, "autoAcceptMainQuest")
local chkSide = MakeCheckbox(cfgFrame, "Auto-accept Side quests",           P, -350, "autoAcceptSideQuest")

-- Extra note about campaign detection
local questNote2 = cfgFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
questNote2:SetPoint("TOPLEFT", P, -376)
questNote2:SetPoint("TOPRIGHT", -P, -376)
questNote2:SetJustifyH("LEFT")
questNote2:SetTextColor(0.55,0.55,0.55)
questNote2:SetText("Campaign quests are detected via C_CampaignInfo. Side quests = all non-campaign quests.")

-- ── § 5 — Build Version / Update ─────────────────────────────
MakeDivider(cfgFrame, -394)
MakeSectionLabel(cfgFrame, "Build Version", -398)

local verText = cfgFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
verText:SetPoint("TOPLEFT", P, -418)
verText:SetTextColor(0.7,0.9,0.7)
verText:SetText("Current: Midnight S1 — March 2026  |  To update, get a new talent string from your guide source.")

-- ── Bottom buttons ────────────────────────────────────────────
local saveBtn = CreateFrame("Button",nil,cfgFrame,"UIPanelButtonTemplate")
saveBtn:SetSize(80,26)
saveBtn:SetPoint("BOTTOMLEFT", P, P)
saveBtn:SetText("Save")
saveBtn:SetScript("OnClick", function()
    ClaudeHelperDB = ClaudeHelperDB or {}
    -- talent string already saved on import
    print("|cff00aaffClaudeHelper|r: |cff00ff00Configuration saved.|r")
    cfgFrame:Hide()
end)

local closeCfgBtn = CreateFrame("Button",nil,cfgFrame,"UIPanelButtonTemplate")
closeCfgBtn:SetSize(80,26)
closeCfgBtn:SetPoint("BOTTOMRIGHT", -P, P)
closeCfgBtn:SetText("Close")
closeCfgBtn:SetScript("OnClick", function() cfgFrame:Hide() end)

-- ── Quest auto-accept hook ─────────────────────────────────────
local questHookFrame = CreateFrame("Frame")
questHookFrame:RegisterEvent("QUEST_DETAIL")
questHookFrame:SetScript("OnEvent", function(self, event)
    if event ~= "QUEST_DETAIL" then return end
    local db = ClaudeHelperDB
    if not db then return end
    if not db.autoAcceptMainQuest and not db.autoAcceptSideQuest then return end

    local questID = GetQuestID and GetQuestID() or 0
    local isCampaign = false

    -- Detect campaign quest
    if C_CampaignInfo then
        -- Check if quest belongs to any active campaign
        local campaigns = C_CampaignInfo.GetAvailableCampaigns and C_CampaignInfo.GetAvailableCampaigns() or {}
        for _, cID in ipairs(campaigns) do
            local quests = C_CampaignInfo.GetCampaignChapterInfo and C_CampaignInfo.GetCampaignChapterInfo(cID)
            -- Fallback: use C_QuestLog tag detection
        end
    end
    -- More reliable: check quest tag info
    if C_QuestLog and C_QuestLog.GetQuestTagInfo then
        local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
        if tagInfo and tagInfo.tagID then
            -- tagID 271 = Campaign, 14 = Calling
            isCampaign = (tagInfo.tagID == 271 or tagInfo.tagID == 14)
        end
    end
    -- Additional check via C_QuestLog.IsQuestCampaign if available
    if C_QuestLog and C_QuestLog.IsQuestCampaign then
        isCampaign = isCampaign or C_QuestLog.IsQuestCampaign(questID)
    end

    if isCampaign and db.autoAcceptMainQuest then
        AcceptQuest()
    elseif not isCampaign and db.autoAcceptSideQuest then
        AcceptQuest()
    end
end)

-- ── Expose ────────────────────────────────────────────────────
addon.cfgFrame = cfgFrame
