-- ============================================================
-- ClaudeHelper.lua  v0.4
-- Core: error logger, slash commands
-- Active modules: CharacterInspector
-- ============================================================

ClaudeHelper = {}
local addon = ClaudeHelper

-- ── Error capture ─────────────────────────────────────────────
local errorLog  = {}
local MAX_ERRORS = 100

local function CaptureError(msg)
    local entry = string.format("|cffffff00%s|r  %s", date("%H:%M:%S"), tostring(msg))
    table.insert(errorLog, 1, entry)
    if #errorLog > MAX_ERRORS then table.remove(errorLog) end
    if addon.RefreshErrorLog then addon:RefreshErrorLog() end
end

local _origErr = geterrorhandler()
seterrorhandler(function(msg)
    CaptureError(msg)
    if _origErr then pcall(_origErr, msg) end
end)

-- ── Utility ───────────────────────────────────────────────────
function addon:SpellIcon(spellID)
    if not spellID then return 134400 end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    return (ok and info and info.iconID) or 134400
end

function addon:SpellName(spellID)
    if not spellID then return "?" end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    return (ok and info and info.name) or ("Spell "..spellID)
end

-- ── Error log window ──────────────────────────────────────────
local errFrame = CreateFrame("Frame","ClaudeHelperErrFrame",UIParent,"BackdropTemplate")
errFrame:SetSize(540, 320)
errFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
errFrame:SetMovable(true)
errFrame:EnableMouse(true)
errFrame:RegisterForDrag("LeftButton")
errFrame:SetScript("OnDragStart", errFrame.StartMoving)
errFrame:SetScript("OnDragStop",  errFrame.StopMovingOrSizing)
errFrame:SetBackdrop({
    bgFile="Interface/Tooltips/UI-Tooltip-Background",
    edgeFile="Interface/Tooltips/UI-Tooltip-Border",
    tile=true, tileSize=16, edgeSize=16,
    insets={left=4,right=4,top=4,bottom=4},
})
errFrame:SetBackdropColor(0, 0, 0, 0.92)
errFrame:SetBackdropBorderColor(1, 0.3, 0.3, 1)
errFrame:Hide()

local errTitle = errFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
errTitle:SetPoint("TOP",0,-8)
errTitle:SetText("|cffff4444Claude Helper — Error Log|r")

local msgFrame = CreateFrame("ScrollingMessageFrame","ClaudeHelperErrMsg",errFrame)
msgFrame:SetPoint("TOPLEFT", 8, -26)
msgFrame:SetPoint("BOTTOMRIGHT", -8, 38)
msgFrame:SetMaxLines(MAX_ERRORS)
msgFrame:SetFontObject("GameFontNormalSmall")
msgFrame:SetFading(false)
msgFrame:SetJustifyH("LEFT")
msgFrame:EnableMouseWheel(true)
msgFrame:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
end)

function addon:RefreshErrorLog()
    msgFrame:Clear()
    for i = #errorLog, 1, -1 do
        msgFrame:AddMessage(errorLog[i])
    end
    msgFrame:ScrollToBottom()
end

local clearBtn = CreateFrame("Button",nil,errFrame,"UIPanelButtonTemplate")
clearBtn:SetSize(80,24); clearBtn:SetPoint("BOTTOMLEFT",8,6)
clearBtn:SetText("Clear")
clearBtn:SetScript("OnClick", function() wipe(errorLog); msgFrame:Clear() end)

local closeErrBtn = CreateFrame("Button",nil,errFrame,"UIPanelButtonTemplate")
closeErrBtn:SetSize(80,24); closeErrBtn:SetPoint("BOTTOMRIGHT",-8,6)
closeErrBtn:SetText("Close")
closeErrBtn:SetScript("OnClick", function() errFrame:Hide() end)

-- ── Slash commands ────────────────────────────────────────────
SLASH_CLAUDEHELPER1 = "/ch"
SLASH_CLAUDEHELPER2 = "/claudehelper"
SlashCmdList["CLAUDEHELPER"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "" or msg == "char" then
        if addon.charInspFrame then
            if addon.charInspFrame:IsShown() then addon.charInspFrame:Hide()
            else addon.charInspFrame:Show() end
        else
            print("|cff00aaffClaudeHelper|r: Character Inspector not loaded.")
        end

    elseif msg == "config" or msg == "cfg" then
        if addon.cfgFrame then
            if addon.cfgFrame:IsShown() then addon.cfgFrame:Hide()
            else addon.cfgFrame:Show() end
        else
            print("|cff00aaffClaudeHelper|r: Config window not loaded.")
        end

    elseif msg == "errors" then
        addon:RefreshErrorLog()
        if errFrame:IsShown() then errFrame:Hide() else errFrame:Show() end

    elseif msg == "reset" then
        if addon.charInspFrame then
            addon.charInspFrame:ClearAllPoints()
            addon.charInspFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        if addon.cfgFrame then
            addon.cfgFrame:ClearAllPoints()
            addon.cfgFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        print("|cff00aaffClaudeHelper|r: windows repositioned.")

    else
        print("|cff00aaffClaudeHelper|r commands:")
        print("  /ch          – toggle character inspector")
        print("  /ch char     – toggle character inspector")
        print("  /ch config   – toggle configuration window")
        print("  /ch errors   – show error log")
        print("  /ch reset    – reposition windows to center")
    end
end

print("|cff00aaffClaudeHelper|r loaded  ·  Press |cffffff00C|r to open character inspector  ·  /ch config for settings")
