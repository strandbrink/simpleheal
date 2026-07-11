----------------------------------------------
-- SimpleHeal - Minimalist Healing Frames
----------------------------------------------

local ADDON_NAME = "SimpleHeal"

local DEFAULTS = {
    spells = {
        LEFT_CLICK        = "Flash of Light",
        RIGHT_CLICK       = "Holy Light",
        SHIFT_LEFT        = "Holy Shock",
        SHIFT_RIGHT       = "Cleanse",
        SCROLL_UP         = "Flash of Light",
        SCROLL_DOWN       = "Holy Light",
        SHIFT_SCROLL_UP   = "Blessing of Wisdom",
        SHIFT_SCROLL_DOWN = "Blessing of Kings",
    },
    buffs = { "", "", "", "" },
    locked   = false,
    frameW   = 90,
    frameH   = 32,
    position = nil,
    specTree = 0,  -- 0 = always show, 1/2/3 = only show for that talent tree
    clickTarget = false,  -- target unit on click
}

-- Click bindings: free combination of modifier + mouse button/wheel (Cell/HealBot style)
-- Buttons 1-5 = mouse buttons, 6 = wheel up, 7 = wheel down
local MOD_OPTIONS = { "", "shift", "ctrl", "alt" }
local MOD_LABELS  = { [""] = "None", shift = "Shift", ctrl = "Ctrl", alt = "Alt" }
local BTN_LABELS  = { "Left", "Right", "Middle", "Btn 4", "Btn 5", "Wheel Up", "Wheel Dn" }
local MAX_CLICK_BINDINGS = 20

-- Old fixed keys -> {modifier, button} (for presets, migration and legacy import)
local LEGACY_KEY_MAP = {
    { "LEFT_CLICK",        "",      1 },
    { "RIGHT_CLICK",       "",      2 },
    { "SHIFT_LEFT",        "shift", 1 },
    { "SHIFT_RIGHT",       "shift", 2 },
    { "CTRL_LEFT",         "ctrl",  1 },
    { "CTRL_RIGHT",        "ctrl",  2 },
    { "ALT_LEFT",          "alt",   1 },
    { "ALT_RIGHT",         "alt",   2 },
    { "SCROLL_UP",         "",      6 },
    { "SCROLL_DOWN",       "",      7 },
    { "SHIFT_SCROLL_UP",   "shift", 6 },
    { "SHIFT_SCROLL_DOWN", "shift", 7 },
}

-- Returns "Shift + Left, Ctrl + Right" listing every modifier+button combo used twice, or nil
local function FindDuplicateBinding(bindings)
    local seen, dups, added = {}, {}, {}
    for _, b in ipairs(bindings or {}) do
        if b.spell and b.spell ~= "" then
            local key = (b.mod or "") .. ":" .. (b.btn or 0)
            if seen[key] and not added[key] then
                added[key] = true
                dups[#dups + 1] = (MOD_LABELS[b.mod] or "?") .. " + " .. (BTN_LABELS[b.btn] or "?")
            end
            seen[key] = true
        end
    end
    if #dups > 0 then
        return table.concat(dups, ", ")
    end
    return nil
end

-- Build a click-binding list from a table of legacy spell keys
local function BindingsFromLegacySpells(spells)
    local out = {}
    for _, m in ipairs(LEGACY_KEY_MAP) do
        local sp = spells and spells[m[1]]
        if sp and sp ~= "" then
            out[#out + 1] = { mod = m[2], btn = m[3], spell = sp }
        end
    end
    return out
end

-- Buff indicator colors (one per slot)
local BUFF_COLORS = {
    { 0.80, 0.33, 0.80 },  -- purple
    { 0.33, 0.55, 1.00 },  -- blue
    { 1.00, 0.65, 0.10 },  -- orange
    { 0.33, 0.85, 0.33 },  -- green
}

----------------------------------------------
-- Class/Spec presets
----------------------------------------------
local PRESETS = {
    {
        name  = "Resto Druid",
        spells = {
            LEFT_CLICK        = "Lifebloom",
            RIGHT_CLICK       = "Rejuvenation",
            SHIFT_LEFT        = "Regrowth",
            SHIFT_RIGHT       = "Remove Curse",
            SCROLL_UP         = "Healing Touch",
            SCROLL_DOWN       = "Swiftmend",
            SHIFT_SCROLL_UP   = "Mark of the Wild",
            SHIFT_SCROLL_DOWN = "Abolish Poison",
        },
        buffs = {
            "Mark of the Wild, Gift of the Wild",
            "Thorns",
            "Power Word: Fortitude, Prayer of Fortitude",
            "Arcane Intellect, Arcane Brilliance",
        },
    },
    {
        name  = "Holy Paladin",
        spells = {
            LEFT_CLICK        = "Flash of Light",
            RIGHT_CLICK       = "Holy Light",
            SHIFT_LEFT        = "Holy Shock",
            SHIFT_RIGHT       = "Cleanse",
            SCROLL_UP         = "Flash of Light",
            SCROLL_DOWN       = "Holy Light",
            SHIFT_SCROLL_UP   = "Blessing of Wisdom",
            SHIFT_SCROLL_DOWN = "Blessing of Kings",
        },
        buffs = {
            "Blessing of Kings, Greater Blessing of Kings",
            "Blessing of Wisdom, Greater Blessing of Wisdom",
            "Power Word: Fortitude, Prayer of Fortitude",
            "Mark of the Wild, Gift of the Wild",
        },
    },
    {
        name  = "Holy Priest",
        spells = {
            LEFT_CLICK        = "Flash Heal",
            RIGHT_CLICK       = "Greater Heal",
            SHIFT_LEFT        = "Renew",
            SHIFT_RIGHT       = "Dispel Magic",
            SCROLL_UP         = "Prayer of Mending",
            SCROLL_DOWN       = "Prayer of Healing",
            SHIFT_SCROLL_UP   = "Power Word: Shield",
            SHIFT_SCROLL_DOWN = "Abolish Disease",
        },
        buffs = {
            "Power Word: Fortitude, Prayer of Fortitude",
            "Divine Spirit, Prayer of Divine Spirit",
            "Shadow Protection, Prayer of Shadow Protection",
            "Mark of the Wild, Gift of the Wild",
        },
    },
    {
        name  = "Disc Priest",
        spells = {
            LEFT_CLICK        = "Flash Heal",
            RIGHT_CLICK       = "Greater Heal",
            SHIFT_LEFT        = "Power Word: Shield",
            SHIFT_RIGHT       = "Dispel Magic",
            SCROLL_UP         = "Renew",
            SCROLL_DOWN       = "Prayer of Healing",
            SHIFT_SCROLL_UP   = "Prayer of Mending",
            SHIFT_SCROLL_DOWN = "Abolish Disease",
        },
        buffs = {
            "Power Word: Fortitude, Prayer of Fortitude",
            "Divine Spirit, Prayer of Divine Spirit",
            "Shadow Protection, Prayer of Shadow Protection",
            "Mark of the Wild, Gift of the Wild",
        },
    },
    {
        name  = "Resto Shaman",
        spells = {
            LEFT_CLICK        = "Lesser Healing Wave",
            RIGHT_CLICK       = "Healing Wave",
            SHIFT_LEFT        = "Chain Heal",
            SHIFT_RIGHT       = "Cure Disease",
            SCROLL_UP         = "Earth Shield",
            SCROLL_DOWN       = "Chain Heal",
            SHIFT_SCROLL_UP   = "Cure Poison",
            SHIFT_SCROLL_DOWN = "Water Shield",
        },
        buffs = {
            "Earth Shield",
            "Power Word: Fortitude, Prayer of Fortitude",
            "Mark of the Wild, Gift of the Wild",
            "Arcane Intellect, Arcane Brilliance",
        },
    },
}

local GAP         = 2  -- default; Layout reads db.spacing
local OOR_ALPHA   = 0.4
local UPDATE_HZ   = 0.3
local BUFF_SIZE   = 7
local BUFF_GAP    = 1

local db
local allFrames   = {}
local container
local configPanel
local elapsed     = 0
local pendingApply = false
local canCastBuff  = {}  -- [slot] = true/false, cached on login/spec change
local buffParseCache = {}
local knownSpellCache = {}  -- [name] = true/false, wiped on SPELLS_CHANGED
local scratchBuffs = {}     -- reusable per-Refresh buff name set
local rangeSpellName        -- spell used for range fading, set by ApplyBindings
local lastClickedFrame      -- last frame the player cast from (for the GCD sweep)
local mouseOverFrame = false -- suppress tooltips while hovering a unit frame

-- Map player class to a default preset
local CLASS_PRESET = {
    DRUID   = "Resto Druid",
    PALADIN = "Holy Paladin",
    PRIEST  = "Holy Priest",
    SHAMAN  = "Resto Shaman",
}

-- Dispellable debuff types per class (TBC)
local CLASS_DISPELS = {
    DRUID   = { Poison = true, Curse = true },
    PALADIN = { Magic = true, Poison = true, Disease = true },
    PRIEST  = { Magic = true, Disease = true },
    SHAMAN  = { Poison = true, Disease = true },
    MAGE    = { Curse = true },
}
local canDispel = {}

local DEBUFF_TYPE_COLORS = {
    Poison  = { 0.0, 0.6, 0.0 },
    Curse   = { 0.6, 0.0, 0.6 },
    Magic   = { 0.2, 0.6, 1.0 },
    Disease = { 0.6, 0.4, 0.0 },
}

local RAID_ICON_COORDS = {
    [1] = { 0,    0.25, 0,    0.25 },
    [2] = { 0.25, 0.5,  0,    0.25 },
    [3] = { 0.5,  0.75, 0,    0.25 },
    [4] = { 0.75, 1,    0,    0.25 },
    [5] = { 0,    0.25, 0.25, 0.5  },
    [6] = { 0.25, 0.5,  0.25, 0.5  },
    [7] = { 0.5,  0.75, 0.25, 0.5  },
    [8] = { 0.75, 1,    0.25, 0.5  },
}

----------------------------------------------
-- Bar Textures
----------------------------------------------
local BAR_TEXTURES = {
    { name = "Minimalist",  texture = "Interface\\AddOns\\SimpleHeal\\Textures\\Minimalist" },
    { name = "Default",     texture = "Interface\\TargetingFrame\\UI-StatusBar" },
    { name = "Flat",        texture = nil },
    { name = "Blizzard",    texture = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { name = "Smooth",      texture = "Interface\\AddOns\\SimpleHeal\\Textures\\Smooth" },
}

local function GetBarTexture()
    local idx = db and db.barTexture or 1
    local entry = BAR_TEXTURES[idx]
    return entry and entry.texture or nil
end

local FONT_PATH = "Fonts\\FRIZQT__.TTF"

local function ApplyFontSize()
    local size = db and db.fontSize or 10
    for _, f in pairs(allFrames) do
        if f.name then f.name:SetFont(FONT_PATH, size, "OUTLINE") end
        if f.deficit then f.deficit:SetFont(FONT_PATH, size, "OUTLINE") end
        if f.statusText then f.statusText:SetFont(FONT_PATH, size, "OUTLINE") end
    end
end

-- One-line (name left, health right) or two-line (name top, health bottom) text layout
local function ApplyTextLayout()
    local twoLine = db and db.twoLineText
    for _, f in pairs(allFrames) do
        if f.name and f.deficit then
            f.shownRole = nil  -- force role-icon re-anchor on next refresh
            f.name:ClearAllPoints()
            f.deficit:ClearAllPoints()
            if twoLine then
                f.name:SetPoint("TOP", 0, -3)
                f.name:SetJustifyH("CENTER")
                f.deficit:SetPoint("CENTER", 0, -4)
                f.deficit:SetJustifyH("CENTER")
            else
                f.name:SetPoint("LEFT", 4, 0)
                f.name:SetJustifyH("LEFT")
                f.deficit:SetPoint("RIGHT", -4, 0)
                f.deficit:SetJustifyH("RIGHT")
            end
        end
    end
end

-- Resize HoT icons and buff indicators on all frames
local function ApplyIconSize()
    local hotSize = db and db.iconSize or 10
    local buffSize = math.max(5, math.floor(hotSize * 0.7))
    local timerSize = math.max(6, math.floor(hotSize * 0.7))
    local stackSize = math.max(6, math.floor(hotSize * 0.8))
    for _, f in pairs(allFrames) do
        if f.buffInd then
            for slot = 1, 4 do
                local ind = f.buffInd[slot]
                ind:SetSize(buffSize, buffSize)
                ind:ClearAllPoints()
                ind:SetPoint("TOPRIGHT", f, "TOPRIGHT",
                    -(BUFF_GAP + (4 - slot) * (buffSize + BUFF_GAP)),
                    -BUFF_GAP)
            end
        end
        if f.hots then
            for h, hot in ipairs(f.hots) do
                hot:SetSize(hotSize, hotSize)
                hot:ClearAllPoints()
                hot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", (h - 1) * (hotSize + 1) + 1, 1)
                hot.timer:SetFont(FONT_PATH, timerSize, "OUTLINE")
                hot.stacks:SetFont(FONT_PATH, stackSize, "OUTLINE")
            end
        end
    end
end

local function ApplyBarTexture()
    local tex = GetBarTexture()
    for _, f in pairs(allFrames) do
        if tex then
            f.hp:SetStatusBarTexture(tex)
            f.incHeal:SetTexture(tex)
            f.mana:SetStatusBarTexture(tex)
        else
            f.hp:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            f.incHeal:SetTexture("Interface\\Buttons\\WHITE8X8")
            f.mana:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        end
    end
end

----------------------------------------------
-- Helpers
----------------------------------------------
-- Cached "does the player know this spell" lookup
local function KnownSpell(name)
    local v = knownSpellCache[name]
    if v == nil then
        v = GetSpellInfo(name) and true or false
        knownSpellCache[name] = v
    end
    return v
end

-- List of spell names in the player's spellbook (for autocomplete)
local spellbookNames = {}
local function RebuildSpellbookNames()
    wipe(spellbookNames)
    local seen = {}
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, num = GetSpellTabInfo(tab)
        for i = offset + 1, offset + num do
            local name
            if GetSpellBookItemName then
                name = GetSpellBookItemName(i, "spell")
            elseif GetSpellName then
                name = GetSpellName(i, "spell")
            end
            if name and not seen[name] then
                seen[name] = true
                spellbookNames[#spellbookNames + 1] = name
            end
        end
    end
    table.sort(spellbookNames)
end

-- Check if the player knows any of the comma-separated spell names
local function KnowsAnySpell(buffStr)
    if not buffStr or buffStr == "" then return false end
    for name in buffStr:gmatch("[^,]+") do
        local trimmed = name:match("^%s*(.-)%s*$")
        if GetSpellInfo(trimmed) then return true end
    end
    return false
end

-- Rebuild which buff slots the player can actually cast
local function UpdateCanCastBuffs()
    if not db then return end
    wipe(buffParseCache)
    wipe(knownSpellCache)
    for slot = 1, 4 do
        canCastBuff[slot] = KnowsAnySpell(db.buffs[slot])
    end
end

-- Returns the talent tree index (1/2/3) with the most points
local function GetPrimaryTree()
    local best, bestPts = 1, 0
    for tab = 1, GetNumTalentTabs() do
        local vals = { GetTalentTabInfo(tab) }
        for i = 3, #vals do
            local n = tonumber(vals[i])
            if n and n >= 0 and n <= 71 then
                if n > bestPts then
                    best = tab
                    bestPts = n
                end
                break
            end
        end
    end
    return best
end

-- Fallback tree names per class
local CLASS_TREE_NAMES = {
    DRUID   = { "Balance", "Feral", "Restoration" },
    PALADIN = { "Holy", "Protection", "Retribution" },
    PRIEST  = { "Discipline", "Holy", "Shadow" },
    SHAMAN  = { "Elemental", "Enhancement", "Restoration" },
    WARRIOR = { "Arms", "Fury", "Protection" },
    MAGE    = { "Arcane", "Fire", "Frost" },
    WARLOCK = { "Affliction", "Demonology", "Destruction" },
    HUNTER  = { "Beast Mastery", "Marksmanship", "Survival" },
    ROGUE   = { "Assassination", "Combat", "Subtlety" },
}

-- Returns { [1]="TreeName", [2]="TreeName", [3]="TreeName" }
local function GetTreeNames()
    local names = {}
    local _, cls = UnitClass("player")
    local fallback = cls and CLASS_TREE_NAMES[cls]
    for tab = 1, GetNumTalentTabs() do
        local name = GetTalentTabInfo(tab)
        if not name or tonumber(name) then
            name = fallback and fallback[tab] or ("Tree " .. tab)
        end
        names[tab] = name
    end
    return names
end

-- Show/hide Blizzard raid frames
local partyFramesHooked = false
local function SetBlizzardFrames(show)
    if InCombatLockdown() then return end
    if CompactRaidFrameContainer then
        if show then CompactRaidFrameContainer:Show() else CompactRaidFrameContainer:Hide() end
    end
    if CompactRaidFrameManager then
        if show then CompactRaidFrameManager:Show() else CompactRaidFrameManager:Hide() end
    end
    if CompactPartyFrame then
        if show then CompactPartyFrame:Show() else CompactPartyFrame:Hide() end
    end
    -- Classic party frames (they re-show themselves on roster events, so hook once)
    if not partyFramesHooked then
        partyFramesHooked = true
        for i = 1, 4 do
            local pf = _G["PartyMemberFrame" .. i]
            if pf then
                pf:HookScript("OnShow", function(self)
                    if db and db.hideBlizzFrames and not InCombatLockdown() then self:Hide() end
                end)
            end
        end
    end
    for i = 1, 4 do
        local pf = _G["PartyMemberFrame" .. i]
        if pf then
            if show then
                if UnitExists("party" .. i) then pf:Show() end
            else
                pf:Hide()
            end
        end
    end
end

-- Show or hide the addon based on spec setting
local pendingSpecUpdate = false
local function UpdateSpecVisibility()
    if not db or not container then return end
    if InCombatLockdown() then
        pendingSpecUpdate = true
        return
    end

    -- Group-only check
    local inGroup = IsInRaid() or IsInGroup() or GetNumGroupMembers() > 0
    if db.groupOnly and not inGroup then
        container:Hide()
        if db.hideBlizzFrames then SetBlizzardFrames(true) end
        return
    end

    if db.specTree == 0 then
        container:Show()
        if db.hideBlizzFrames then SetBlizzardFrames(false) end
        return
    end
    if GetPrimaryTree() == db.specTree then
        container:Show()
        if db.hideBlizzFrames then SetBlizzardFrames(false) end
    else
        container:Hide()
        SetBlizzardFrames(true)
    end
end

-- Role detection for grouping
local HEALER_CLASSES = { PRIEST = true, SHAMAN = true, PALADIN = true, DRUID = true }
local TANK_CLASSES   = { WARRIOR = true }

local function GetUnitRole(unit)
    -- Only trust explicit tank/healer assignments. Battlegrounds auto-assign
    -- everyone "DAMAGER", which would hide role icons for healers - fall back
    -- to the class guess in that case, same as when no role is assigned.
    if UnitGroupRolesAssigned then
        local role = UnitGroupRolesAssigned(unit)
        if role == "TANK" or role == "HEALER" then return role end
    end
    local _, cls = UnitClass(unit)
    if not cls then return "DAMAGER" end
    if TANK_CLASSES[cls] then return "TANK" end
    if HEALER_CLASSES[cls] then return "HEALER" end
    return "DAMAGER"
end

local function ClassColor(unit)
    if not UnitExists(unit) then return 0.5, 0.5, 0.5 end
    local _, cls = UnitClass(unit)
    if cls and RAID_CLASS_COLORS[cls] then
        local c = RAID_CLASS_COLORS[cls]
        return c.r, c.g, c.b
    end
    return 0.5, 0.5, 0.5
end

local function ParseBuffStr(buffStr)
    if buffParseCache[buffStr] then return buffParseCache[buffStr] end
    local wanted = {}
    for name in buffStr:gmatch("[^,]+") do
        wanted[name:match("^%s*(.-)%s*$")] = true
    end
    buffParseCache[buffStr] = wanted
    return wanted
end

-- Check if unit has any of the comma-separated buff names
local function HasBuff(unit, buffStr)
    if not buffStr or buffStr == "" then return true end
    local wanted = ParseBuffStr(buffStr)
    for i = 1, 40 do
        local name = UnitBuff(unit, i)
        if not name then break end
        if wanted[name] then return true end
    end
    return false
end

-- Smooth health bar animation
local animFrames = {}
local animator = CreateFrame("Frame")
animator:Hide()
animator:SetScript("OnUpdate", function(_, dt)
    local k = math.min(1, dt * 12)
    for f in pairs(animFrames) do
        local cur = f.hp:GetValue()
        local target = f.hpTarget or cur
        local diff = target - cur
        local _, maxV = f.hp:GetMinMaxValues()
        if math.abs(diff) <= (maxV * 0.005 + 1) then
            f.hp:SetValue(target)
            animFrames[f] = nil
        else
            f.hp:SetValue(cur + diff * k)
        end
    end
    if not next(animFrames) then animator:Hide() end
end)

local function SetHealthSmooth(f, value)
    f.hpTarget = value
    if db and db.smoothBars == false then
        f.hp:SetValue(value)
        animFrames[f] = nil
        return
    end
    local cur = f.hp:GetValue()
    local _, maxV = f.hp:GetMinMaxValues()
    if math.abs(value - cur) <= (maxV * 0.005 + 1) then
        f.hp:SetValue(value)
        animFrames[f] = nil
    else
        animFrames[f] = true
        animator:Show()
    end
end

local function Refresh(f)
    local unit = f.unit
    local locked = InCombatLockdown()
    if not UnitExists(unit) then
        if not locked then f:Hide() end
        return
    end
    if not locked then f:Show() end

    local hp    = UnitHealth(unit)
    local hpMax = UnitHealthMax(unit)

    f.hp:SetMinMaxValues(0, hpMax)
    SetHealthSmooth(f, hp)

    local name = UnitName(unit) or ""
    local maxLen = math.floor((db.frameW or 90) / 7)
    if #name > maxLen then name = name:sub(1, maxLen) .. ".." end
    f.name:SetText(name)

    -- Role icon (only re-anchor when the role actually changes)
    local role = (db.roleIcons ~= false) and GetUnitRole(unit) or "NONE"
    if role ~= f.shownRole then
        f.shownRole = role
        local twoLine = db.twoLineText
        if role == "TANK" or role == "HEALER" then
            if role == "TANK" then
                f.roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64)
            else
                f.roleIcon:SetTexCoord(20/64, 39/64, 1/64, 20/64)
            end
            f.roleIcon:Show()
            if not twoLine then
                f.name:ClearAllPoints()
                f.name:SetPoint("LEFT", 15, 0)
            end
        else
            f.roleIcon:Hide()
            if not twoLine then
                f.name:ClearAllPoints()
                f.name:SetPoint("LEFT", 4, 0)
            end
        end
    end

    local isDead    = UnitIsDeadOrGhost(unit)
    local isOffline = not UnitIsConnected(unit)
    local cr, cg, cb = ClassColor(unit)
    local darkMode = (db.colorMode or 1) == 2

    if darkMode and not isDead and not isOffline then
        f.name:SetTextColor(cr, cg, cb)
    else
        f.name:SetTextColor(1, 1, 1)
    end

    -- Target highlight
    if UnitIsUnit(unit, "target") then
        f.targetBorder:Show()
    else
        f.targetBorder:Hide()
    end

    -- Low HP warning
    if db.lowHpFlash ~= false and not isDead and not isOffline
        and hpMax > 0 and (hp / hpMax) < 0.3 then
        if not f.lowHpBorder:IsShown() then f.lowHpBorder:Show() end
    else
        if f.lowHpBorder:IsShown() then f.lowHpBorder:Hide() end
    end

    -- Rez indicator
    local hasRez = false
    if isDead and UnitHasIncomingResurrection then
        hasRez = UnitHasIncomingResurrection(unit)
    end
    if hasRez then
        f.rezIcon:Show()
    else
        f.rezIcon:Hide()
    end

    -- AFK check
    local isAFK = UnitIsAFK and UnitIsAFK(unit)

    if isDead and UnitIsFeignDeath and UnitIsFeignDeath(unit) then
        -- Hunter feigning death - not actually dead, don't waste a rez
        f.hp:SetStatusBarColor(cr * 0.5, cg * 0.5, cb * 0.5)
        f.deficit:SetText("FD")
        f.deficit:SetTextColor(1, 0.85, 0.2)
        f.statusText:Hide()
        f.deadIcon:Hide()
        f.rezIcon:Hide()
    elseif isDead then
        f.hp:SetStatusBarColor(0.3, 0.3, 0.3)
        f.hp:SetValue(0)
        f.hpTarget = 0
        animFrames[f] = nil
        if hasRez then
            f.deficit:SetText("")
            f.statusText:SetText("REZ")
            f.statusText:SetTextColor(0.2, 1.0, 0.2)
            f.statusText:Show()
            f.deadIcon:Hide()
        else
            f.deficit:SetText("DEAD")
            f.deficit:SetTextColor(1, 0.2, 0.2)
            f.statusText:Hide()
            f.deadIcon:Show()
        end
    elseif isOffline then
        f.hp:SetStatusBarColor(0.2, 0.2, 0.2)
        f.hp:SetValue(0)
        f.hpTarget = 0
        animFrames[f] = nil
        f.deficit:SetText("OFFLINE")
        f.deficit:SetTextColor(0.5, 0.5, 0.5)
        f.statusText:Hide()
        f.deadIcon:Hide()
    elseif isAFK then
        if darkMode then
            f.hp:SetStatusBarColor(0.15, 0.15, 0.15)
        else
            f.hp:SetStatusBarColor(cr * 0.5, cg * 0.5, cb * 0.5)
        end
        f.deficit:SetText("")
        f.statusText:SetText("AFK")
        f.statusText:SetTextColor(0.8, 0.8, 0.0)
        f.statusText:Show()
        f.deadIcon:Hide()
    else
        if darkMode then
            f.hp:SetStatusBarColor(0.25, 0.25, 0.25)
        else
            f.hp:SetStatusBarColor(cr, cg, cb)
        end
        local hpMode = db.hpTextMode or 1
        local diff = hp - hpMax
        if diff < 0 then
            local pct = hpMax > 0 and math.floor(hp / hpMax * 100 + 0.5) or 0
            if hpMode == 2 then
                f.deficit:SetText(pct .. "%")
            elseif hpMode == 3 then
                f.deficit:SetText(diff .. "  " .. pct .. "%")
            else
                f.deficit:SetText(diff)
            end
            f.deficit:SetTextColor(1, 1, 1)
        else
            f.deficit:SetText("")
        end
        f.statusText:Hide()
        f.deadIcon:Hide()
    end

    -- Range check
    local baseAlpha = db.frameAlpha or 1
    local inRange = true
    if db.rangeFade ~= false and not UnitIsUnit(unit, "player") then
        if not UnitIsVisible(unit) then
            -- Different layer/phase or too far away to even see
            inRange = false
        elseif rangeSpellName then
            local r = IsSpellInRange(rangeSpellName, unit)
            if r == 0 then
                inRange = false
            elseif r == nil then
                -- Spell check unavailable (dead target etc) - fall back to API range
                inRange = UnitInRange(unit) and true or false
            end
        else
            inRange = UnitInRange(unit) and true or false
        end
    end
    if inRange then
        f:SetAlpha(baseAlpha)
    else
        f:SetAlpha(OOR_ALPHA * baseAlpha)
    end

    -- Incoming heals
    if not isDead and not isOffline and UnitGetIncomingHeals then
        local inc = UnitGetIncomingHeals(unit) or 0
        if inc > 0 and hpMax > 0 then
            local barW = f.hp:GetWidth()
            local curFrac = hp / hpMax
            local incFrac = inc / hpMax
            local cappedFrac = math.min(incFrac, 1 - curFrac)
            if cappedFrac > 0.01 then
                f.incHeal:SetVertexColor(cr, cg, cb)
                f.incHeal:SetPoint("LEFT", f.hp, "LEFT", curFrac * barW, 0)
                f.incHeal:SetWidth(cappedFrac * barW)
                f.incHeal:Show()
            else
                f.incHeal:Hide()
            end
        else
            f.incHeal:Hide()
        end
    else
        f.incHeal:Hide()
    end

    -- Debuff highlight (only debuffs the player can dispel)
    local debuffColor = nil
    local debuffTex = nil
    local debuffCount = nil
    local debuffExp = nil
    if not isDead and not isOffline then
        for i = 1, 40 do
            local dName, dIcon, dStacks, dType, _, dExpTime = UnitDebuff(unit, i)
            if not dName then break end
            if dType and canDispel[dType] and DEBUFF_TYPE_COLORS[dType] then
                debuffColor = DEBUFF_TYPE_COLORS[dType]
                debuffTex = dIcon
                debuffCount = dStacks
                debuffExp = dExpTime
                break
            end
        end
    end
    if debuffColor then
        -- Stacks + remaining time next to the debuff icon
        if debuffCount and debuffCount > 1 then
            f.debuffStack:SetText(debuffCount)
            f.debuffStack:Show()
        else
            f.debuffStack:Hide()
        end
        if debuffExp and debuffExp > 0 then
            local remaining = debuffExp - GetTime()
            f.debuffTimer:SetText(remaining > 0 and math.floor(remaining + 0.5) or "")
            f.debuffTimer:Show()
        else
            f.debuffTimer:Hide()
        end
        local dc = debuffColor
        f.debuffBorder.top:SetColorTexture(dc[1], dc[2], dc[3], 1)
        f.debuffBorder.bot:SetColorTexture(dc[1], dc[2], dc[3], 1)
        f.debuffBorder.left:SetColorTexture(dc[1], dc[2], dc[3], 1)
        f.debuffBorder.right:SetColorTexture(dc[1], dc[2], dc[3], 1)
        f.debuffBorder:Show()
        if debuffTex then
            f.debuffIcon:SetTexture(debuffTex)
            f.debuffIcon:Show()
        end
    else
        f.debuffBorder:Hide()
        f.debuffIcon:Hide()
        f.debuffStack:Hide()
        f.debuffTimer:Hide()
    end

    -- Mana bar
    if db.showMana ~= false and not isDead and not isOffline then
        local pType = UnitPowerType(unit)
        local power = UnitPower(unit)
        local powerMax = UnitPowerMax(unit)
        if powerMax > 0 then
            f.mana:SetMinMaxValues(0, powerMax)
            f.mana:SetValue(power)
            if pType == 0 then
                f.mana:SetStatusBarColor(0.0, 0.4, 1.0)
            elseif pType == 1 then
                f.mana:SetStatusBarColor(1.0, 0.0, 0.0)
            elseif pType == 3 then
                f.mana:SetStatusBarColor(1.0, 1.0, 0.0)
            else
                f.mana:SetStatusBarColor(0.0, 0.4, 1.0)
            end
            f.mana:Show()
        else
            f.mana:Hide()
        end
    else
        f.mana:Hide()
    end

    -- Aggro indicator
    local showAggro = false
    if db.showAggro ~= false and not isDead and not isOffline and UnitThreatSituation then
        local status = UnitThreatSituation(unit)
        if status and status >= 2 then
            showAggro = true
        end
    end
    if showAggro then
        f.aggroBorder:Show()
    else
        f.aggroBorder:Hide()
    end

    -- Out-of-combat indicator
    if db.showOOC ~= false and not isDead and not isOffline and not UnitAffectingCombat(unit) and (IsInRaid() or IsInGroup()) then
        f.oocIcon:Show()
    else
        f.oocIcon:Hide()
    end

    -- Raid marker
    local raidIdx = GetRaidTargetIndex(unit)
    if raidIdx then
        local c = RAID_ICON_COORDS[raidIdx]
        if c then
            f.raidIcon:SetTexCoord(c[1], c[2], c[3], c[4])
            f.raidIcon:Show()
        else
            f.raidIcon:Hide()
        end
    else
        f.raidIcon:Hide()
    end

    -- Single buff pass: collect buff names + HoT tracking in one loop
    wipe(scratchBuffs)
    local hotIdx = 0
    if not isDead and not isOffline then
        for i = 1, 40 do
            local bName, bIcon, bCount, _, bDur, bExp = UnitBuff(unit, i)
            if not bName then break end
            scratchBuffs[bName] = (bExp and bExp > 0) and bExp or true
            if db.showHots ~= false and bDur and bDur > 0 and bExp and KnownSpell(bName) then
                hotIdx = hotIdx + 1
                if hotIdx <= 6 then
                    local hot = f.hots[hotIdx]
                    hot.icon:SetTexture(bIcon)
                    if bDur <= 60 then
                        local remaining = bExp - GetTime()
                        hot.timer:SetText(remaining > 0 and math.floor(remaining) or "")
                    else
                        hot.timer:SetText("")
                    end
                    if bCount and bCount > 1 then
                        hot.stacks:SetText(bCount)
                    else
                        hot.stacks:SetText("")
                    end
                    hot:Show()
                end
            end
        end
    end
    for h = hotIdx + 1, 6 do
        f.hots[h]:Hide()
    end

    -- Buff indicators: gray = missing, orange = expires in under 2 minutes
    local now = GetTime()
    for slot = 1, 4 do
        local ind = f.buffInd[slot]
        local trackable = canCastBuff[slot] or (db.trackAllBuffs and db.buffs[slot] and db.buffs[slot] ~= "")
        if not trackable or isDead or isOffline then
            ind:Hide()
        else
            local bestExp = nil  -- true = permanent buff found, number = latest expiration
            for name in pairs(ParseBuffStr(db.buffs[slot])) do
                local v = scratchBuffs[name]
                if v == true then
                    bestExp = true
                    break
                elseif v and (bestExp == nil or (bestExp ~= true and v > bestExp)) then
                    bestExp = v
                end
            end
            if bestExp == nil then
                ind:SetVertexColor(0.6, 0.6, 0.6)
                ind:SetAlpha(0.75)
                ind:Show()
            elseif bestExp ~= true and db.buffExpireWarn ~= false and (bestExp - now) < 120 then
                ind:SetVertexColor(1, 0.65, 0.1)
                ind:SetAlpha(1)
                ind:Show()
            else
                ind:Hide()
            end
        end
    end

    -- Missing Thorns text for tanks
    if f.thornsText then
        if GetUnitRole(unit) == "TANK" and KnownSpell("Thorns")
            and not scratchBuffs["Thorns"] and not isDead and not isOffline then
            f.thornsText:Show()
        else
            f.thornsText:Hide()
        end
    end
end

----------------------------------------------
-- Apply spell bindings to all frames
----------------------------------------------
local function ApplyBindings()
    if InCombatLockdown() then
        pendingApply = true
        print("|cff00ff00SimpleHeal:|r Spells will update after combat.")
        return
    end

    -- Warn if two bindings use the same modifier+button (only the first one wins)
    local dup = FindDuplicateBinding(db.bindings)
    if dup then
        print("|cff00ff00SimpleHeal:|r |cffff5555Warning:|r two bindings use " .. dup .. " - only the first one will cast!")
    end

    -- Cache the spell used for range checks.
    -- Priority: explicit range spell setting > plain left-click spell >
    -- any plain spell > spell extracted from a macro binding.
    local function IsPlainSpell(sp)
        if not sp or sp == "" then return false end
        local lower = sp:lower()
        return lower ~= "target" and lower ~= "menu" and sp:sub(1, 1) ~= "/"
    end
    local function SpellFromMacro(text)
        if not text or text:sub(1, 1) ~= "/" then return nil end
        for castArgs in text:gmatch("/cast%s+([^\n;]+)") do
            local name = castArgs:gsub("%[.-%]", ""):match("^%s*(.-)%s*$")
            if name ~= "" and GetSpellInfo(name:match("^(.-)%s*%(") or name) then
                return name
            end
        end
        return nil
    end

    rangeSpellName = nil
    if db.rangeSpell and db.rangeSpell ~= "" then
        rangeSpellName = db.rangeSpell
    end
    if not rangeSpellName then
        for _, b in ipairs(db.bindings or {}) do
            if IsPlainSpell(b.spell) and b.mod == "" and b.btn == 1 then
                rangeSpellName = b.spell
                break
            end
        end
    end
    if not rangeSpellName then
        for _, b in ipairs(db.bindings or {}) do
            if IsPlainSpell(b.spell) then rangeSpellName = b.spell break end
        end
    end
    if not rangeSpellName then
        for _, b in ipairs(db.bindings or {}) do
            local sp = SpellFromMacro(b.spell)
            if sp then rangeSpellName = sp break end
        end
    end

    for _, f in pairs(allFrames) do
        local u = f.unit

        -- Clear all click attributes (every modifier x button combo, incl. wheel)
        for _, mod in ipairs(MOD_OPTIONS) do
            local prefix = mod == "" and "" or (mod .. "-")
            for btn = 1, 5 do
                f:SetAttribute(prefix .. "type" .. btn, nil)
                f:SetAttribute(prefix .. "spell" .. btn, nil)
                f:SetAttribute(prefix .. "macrotext" .. btn, nil)
            end
            f.scrollUp:SetAttribute(prefix .. "type", nil)
            f.scrollUp:SetAttribute(prefix .. "macrotext", nil)
            f.scrollDown:SetAttribute(prefix .. "type", nil)
            f.scrollDown:SetAttribute(prefix .. "macrotext", nil)
        end

        -- Apply the configured click bindings.
        -- On duplicates the FIRST binding wins - later rows never overwrite an earlier spell.
        -- Special values: "target" = target the unit, "menu" = unit menu,
        -- text starting with "/" = macro (@unit is replaced with the clicked unit).
        for _, b in ipairs(db.bindings or {}) do
            if b.spell and b.spell ~= "" and b.btn then
                local prefix = b.mod == "" and "" or (b.mod .. "-")

                -- Wheel bindings live on the hidden scroll buttons (no button suffix)
                local target, typeAttr, macroAttr
                if b.btn == 6 or b.btn == 7 then
                    target = b.btn == 6 and f.scrollUp or f.scrollDown
                    typeAttr = prefix .. "type"
                    macroAttr = prefix .. "macrotext"
                else
                    target = f
                    typeAttr = prefix .. "type" .. b.btn
                    macroAttr = prefix .. "macrotext" .. b.btn
                end

                if not target:GetAttribute(typeAttr) then
                    local lower = b.spell:lower()
                    if lower == "target" then
                        target:SetAttribute(typeAttr, "target")
                    elseif lower == "menu" then
                        target:SetAttribute(typeAttr, "togglemenu")
                    elseif b.spell:sub(1, 1) == "/" then
                        target:SetAttribute(typeAttr, "macro")
                        target:SetAttribute(macroAttr, (b.spell:gsub("@unit", "@" .. u)))
                    elseif db.clickTarget then
                        target:SetAttribute(typeAttr, "macro")
                        target:SetAttribute(macroAttr,
                            "/target " .. u .. "\n/cast [@" .. u .. "] " .. b.spell)
                    else
                        -- Hard [@unit] macro: if the unit is invalid/out of range the cast
                        -- fails instead of falling back to self-cast
                        target:SetAttribute(typeAttr, "macro")
                        target:SetAttribute(macroAttr, "/cast [@" .. u .. "] " .. b.spell)
                    end
                end
            end
        end

        -- Defaults for unbound base clicks
        if not f:GetAttribute("type2") then
            f:SetAttribute("type2", "togglemenu")
        end
        if db.clickTarget and not f:GetAttribute("type1") then
            f:SetAttribute("type1", "target")
        end

        -- Hover-cast keys (Clique-style): keys bound only while the mouse is
        -- over the frame, casting on the hovered unit
        local enterScript = ""
        for i = 1, 5 do
            local hk = db.hoverKeys and db.hoverKeys[i]
            f:SetAttribute("type-hover" .. i, nil)
            f:SetAttribute("macrotext-hover" .. i, nil)
            if hk and hk.key and hk.key ~= "" and hk.spell and hk.spell ~= "" then
                f:SetAttribute("type-hover" .. i, "macro")
                local mt
                if hk.spell:sub(1, 1) == "/" then
                    mt = (hk.spell:gsub("@unit", "@" .. u))
                else
                    mt = "/cast [@" .. u .. "] " .. hk.spell
                end
                f:SetAttribute("macrotext-hover" .. i, mt)
                enterScript = enterScript
                    .. ("self:SetBindingClick(true, %q, self, %q)\n")
                        :format(hk.key:upper(), "hover" .. i)
            end
        end
        if enterScript ~= "" then
            f:SetAttribute("_onenter", enterScript)
            f:SetAttribute("_onleave", "self:ClearBindings()")
        else
            f:SetAttribute("_onenter", nil)
            f:SetAttribute("_onleave", nil)
        end

    end
end

----------------------------------------------
-- Profile switching (usable outside the config panel)
----------------------------------------------
local function ApplyProfileData(name)
    if not db or name == db.activeProfile then return false end
    local prof = name ~= "Default" and db.profiles and db.profiles[name] or nil
    if name ~= "Default" and not prof then return false end

    -- Save current setup into the active profile first
    local cur = db.activeProfile or "Default"
    if cur ~= "Default" then
        db.profiles[cur] = { spells = {}, buffs = {}, bindings = {} }
        for k, v in pairs(db.spells) do db.profiles[cur].spells[k] = v end
        for i = 1, 4 do db.profiles[cur].buffs[i] = db.buffs[i] or "" end
        for _, b in ipairs(db.bindings or {}) do
            table.insert(db.profiles[cur].bindings, { mod = b.mod, btn = b.btn, spell = b.spell })
        end
    end

    if prof then
        for k, v in pairs(prof.spells) do db.spells[k] = v end
        for i = 1, 4 do db.buffs[i] = prof.buffs[i] or "" end
        if prof.bindings then
            db.bindings = {}
            for _, b in ipairs(prof.bindings) do
                table.insert(db.bindings, { mod = b.mod, btn = b.btn, spell = b.spell })
            end
        else
            db.bindings = BindingsFromLegacySpells(prof.spells)
        end
    end
    db.activeProfile = name
    ApplyBindings()
    UpdateCanCastBuffs()
    Layout()
    return true
end

-- Auto-switch profile based on group type (arena > raid > party)
local function AutoSwitchProfile()
    if not db or InCombatLockdown() then return end
    local target
    local _, instType = GetInstanceInfo()
    if instType == "arena" then
        target = db.autoProfileArena
    elseif IsInRaid() then
        target = db.autoProfileRaid
    elseif IsInGroup() then
        target = db.autoProfileParty
    end
    if target and target ~= "" and target ~= "None" and target ~= db.activeProfile then
        if ApplyProfileData(target) then
            print("|cff00ff00SimpleHeal:|r Auto-switched to profile: " .. target)
            if configPanel then
                UIDropDownMenu_SetText(configPanel.profDrop, target)
                if configPanel.RefreshBindingRows then configPanel.RefreshBindingRows() end
            end
        end
    end
end

----------------------------------------------
-- Unit frame creation
----------------------------------------------
local function MakeFrame(unit, parent)
    local fn = "SimpleHeal_" .. unit

    local f = CreateFrame("Button", fn, parent, "SecureUnitButtonTemplate,SecureHandlerEnterLeaveTemplate")
    f:SetSize(db.frameW, db.frameH)
    f.unit = unit
    f:SetAttribute("unit", unit)
    f:RegisterForClicks("AnyUp")

    -- Background
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    -- Health bar
    local hp = CreateFrame("StatusBar", nil, f)
    hp:SetPoint("TOPLEFT", 1, -1)
    hp:SetPoint("BOTTOMRIGHT", -1, 1)
    local barTex = GetBarTexture() or "Interface\\Buttons\\WHITE8X8"
    hp:SetStatusBarTexture(barTex)
    hp:SetMinMaxValues(0, 1)
    hp:SetValue(1)
    f.hp = hp

    local hpBg = hp:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0.1, 0.1, 0.1, 1)

    -- Mouseover highlight (auto-shown by Button on hover)
    local mouseHl = f:CreateTexture(nil, "HIGHLIGHT")
    mouseHl:SetPoint("TOPLEFT", 1, -1)
    mouseHl:SetPoint("BOTTOMRIGHT", -1, 1)
    mouseHl:SetColorTexture(1, 1, 1, 0.18)

    -- Target border (white frame around current target)
    local targetBorder = CreateFrame("Frame", nil, f)
    targetBorder:SetPoint("TOPLEFT", -2, 2)
    targetBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    targetBorder:SetFrameLevel(f:GetFrameLevel() + 3)
    targetBorder:Hide()
    f.targetBorder = targetBorder

    local TB_W = 2
    local tbTop = targetBorder:CreateTexture(nil, "OVERLAY")
    tbTop:SetPoint("TOPLEFT"); tbTop:SetPoint("TOPRIGHT")
    tbTop:SetHeight(TB_W)
    tbTop:SetColorTexture(1, 1, 1, 0.9)
    local tbBot = targetBorder:CreateTexture(nil, "OVERLAY")
    tbBot:SetPoint("BOTTOMLEFT"); tbBot:SetPoint("BOTTOMRIGHT")
    tbBot:SetHeight(TB_W)
    tbBot:SetColorTexture(1, 1, 1, 0.9)
    local tbLeft = targetBorder:CreateTexture(nil, "OVERLAY")
    tbLeft:SetPoint("TOPLEFT"); tbLeft:SetPoint("BOTTOMLEFT")
    tbLeft:SetWidth(TB_W)
    tbLeft:SetColorTexture(1, 1, 1, 0.9)
    local tbRight = targetBorder:CreateTexture(nil, "OVERLAY")
    tbRight:SetPoint("TOPRIGHT"); tbRight:SetPoint("BOTTOMRIGHT")
    tbRight:SetWidth(TB_W)
    tbRight:SetColorTexture(1, 1, 1, 0.9)

    -- Low HP warning border (pulsing red, shown under 30% health)
    local lowHp = CreateFrame("Frame", nil, f)
    lowHp:SetPoint("TOPLEFT", -2, 2)
    lowHp:SetPoint("BOTTOMRIGHT", 2, -2)
    lowHp:SetFrameLevel(f:GetFrameLevel() + 4)
    lowHp:Hide()
    f.lowHpBorder = lowHp

    local LHP_W = 2
    for _, edge in ipairs({
        { "TOPLEFT", "TOPRIGHT", nil, LHP_W },
        { "BOTTOMLEFT", "BOTTOMRIGHT", nil, LHP_W },
        { "TOPLEFT", "BOTTOMLEFT", LHP_W, nil },
        { "TOPRIGHT", "BOTTOMRIGHT", LHP_W, nil },
    }) do
        local t = lowHp:CreateTexture(nil, "OVERLAY")
        t:SetPoint(edge[1]); t:SetPoint(edge[2])
        if edge[3] then t:SetWidth(edge[3]) else t:SetHeight(edge[4]) end
        t:SetColorTexture(1, 0.1, 0.1, 1)
    end

    local pulse = lowHp:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.15)
    fade:SetDuration(0.4)
    lowHp:SetScript("OnShow", function() pulse:Play() end)
    lowHp:SetScript("OnHide", function() pulse:Stop() end)

    -- Incoming heal bar (lighter overlay on health bar)
    local incHeal = hp:CreateTexture(nil, "ARTWORK", nil, 1)
    incHeal:SetPoint("TOP")
    incHeal:SetPoint("BOTTOM")
    incHeal:SetTexture(barTex)
    incHeal:SetAlpha(0.35)
    incHeal:Hide()
    f.incHeal = incHeal

    -- Debuff border (colored frame border for dispellable debuffs)
    local debuffBorder = CreateFrame("Frame", nil, f)
    debuffBorder:SetPoint("TOPLEFT", -1, 1)
    debuffBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    debuffBorder:SetFrameLevel(f:GetFrameLevel() + 2)
    debuffBorder:Hide()
    f.debuffBorder = debuffBorder

    local DEBUFF_BORDER_W = 2
    local dTop = debuffBorder:CreateTexture(nil, "OVERLAY")
    dTop:SetPoint("TOPLEFT"); dTop:SetPoint("TOPRIGHT")
    dTop:SetHeight(DEBUFF_BORDER_W)
    debuffBorder.top = dTop

    local dBot = debuffBorder:CreateTexture(nil, "OVERLAY")
    dBot:SetPoint("BOTTOMLEFT"); dBot:SetPoint("BOTTOMRIGHT")
    dBot:SetHeight(DEBUFF_BORDER_W)
    debuffBorder.bot = dBot

    local dLeft = debuffBorder:CreateTexture(nil, "OVERLAY")
    dLeft:SetPoint("TOPLEFT"); dLeft:SetPoint("BOTTOMLEFT")
    dLeft:SetWidth(DEBUFF_BORDER_W)
    debuffBorder.left = dLeft

    local dRight = debuffBorder:CreateTexture(nil, "OVERLAY")
    dRight:SetPoint("TOPRIGHT"); dRight:SetPoint("BOTTOMRIGHT")
    dRight:SetWidth(DEBUFF_BORDER_W)
    debuffBorder.right = dRight

    -- Debuff icon (shows the actual debuff)
    local debuffIcon = debuffBorder:CreateTexture(nil, "OVERLAY")
    debuffIcon:SetSize(12, 12)
    debuffIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    debuffIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    debuffIcon:Hide()
    f.debuffIcon = debuffIcon

    -- Debuff stack count (bottom-right corner of the icon)
    local debuffStack = debuffBorder:CreateFontString(nil, "OVERLAY")
    debuffStack:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    debuffStack:SetPoint("BOTTOMRIGHT", debuffIcon, "BOTTOMRIGHT", 2, -1)
    debuffStack:SetTextColor(1, 1, 1)
    debuffStack:Hide()
    f.debuffStack = debuffStack

    -- Debuff time remaining (right of the icon)
    local debuffTimer = debuffBorder:CreateFontString(nil, "OVERLAY")
    debuffTimer:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    debuffTimer:SetPoint("LEFT", debuffIcon, "RIGHT", 1, 0)
    debuffTimer:SetTextColor(1, 0.8, 0.3)
    debuffTimer:Hide()
    f.debuffTimer = debuffTimer

    -- Mana bar (thin bar at bottom of health bar)
    local mana = CreateFrame("StatusBar", nil, f)
    mana:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", 0, 0)
    mana:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", 0, 0)
    mana:SetHeight(3)
    mana:SetStatusBarTexture(barTex)
    mana:SetStatusBarColor(0.0, 0.4, 1.0)
    mana:SetMinMaxValues(0, 1)
    mana:SetValue(1)
    mana:SetFrameLevel(hp:GetFrameLevel() + 1)
    local manaBg = mana:CreateTexture(nil, "BACKGROUND")
    manaBg:SetAllPoints()
    manaBg:SetColorTexture(0, 0, 0, 0.5)
    f.mana = mana

    -- Aggro indicator (red glow on top edge)
    local aggroBorder = f:CreateTexture(nil, "OVERLAY")
    aggroBorder:SetPoint("TOPLEFT", -1, 1)
    aggroBorder:SetPoint("TOPRIGHT", 1, 1)
    aggroBorder:SetHeight(2)
    aggroBorder:SetColorTexture(1, 0, 0, 0.9)
    aggroBorder:Hide()
    f.aggroBorder = aggroBorder

    -- Out-of-combat icon (small green dot)
    local oocIcon = f:CreateTexture(nil, "OVERLAY")
    oocIcon:SetSize(8, 8)
    oocIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    oocIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    oocIcon:Hide()
    f.oocIcon = oocIcon

    -- GCD sweep (small cooldown swirl, bottom-right above the ooc dot)
    local gcd = CreateFrame("Cooldown", nil, hp, "CooldownFrameTemplate")
    gcd:SetSize(12, 12)
    gcd:SetPoint("BOTTOMRIGHT", -2, 6)
    gcd:SetDrawEdge(false)
    if gcd.SetHideCountdownNumbers then gcd:SetHideCountdownNumbers(true) end
    f.gcd = gcd

    -- Raid marker icon (top-left)
    local raidIcon = f:CreateTexture(nil, "OVERLAY")
    raidIcon:SetSize(10, 10)
    raidIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    raidIcon:Hide()
    f.raidIcon = raidIcon

    -- Ready check icon (center-right)
    local readyIcon = f:CreateTexture(nil, "OVERLAY")
    readyIcon:SetSize(12, 12)
    readyIcon:SetPoint("RIGHT", f, "RIGHT", -3, 0)
    readyIcon:Hide()
    f.readyIcon = readyIcon

    -- Role icon (tank/healer, left of name)
    local roleIcon = hp:CreateTexture(nil, "OVERLAY")
    roleIcon:SetSize(10, 10)
    roleIcon:SetPoint("LEFT", 3, 0)
    roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    roleIcon:Hide()
    f.roleIcon = roleIcon

    -- Name
    local nameFs = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFs:SetPoint("LEFT", 4, 0)
    nameFs:SetJustifyH("LEFT")
    nameFs:SetTextColor(1, 1, 1)
    f.name = nameFs

    -- Deficit
    local defFs = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    defFs:SetPoint("RIGHT", -4, 0)
    defFs:SetJustifyH("RIGHT")
    f.deficit = defFs

    -- Status text (AFK / rez)
    local statusFs = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusFs:SetPoint("CENTER", 0, 0)
    statusFs:SetTextColor(0.8, 0.8, 0.0)
    statusFs:Hide()
    f.statusText = statusFs

    -- Rez icon
    local rezIcon = f:CreateTexture(nil, "OVERLAY")
    rezIcon:SetSize(14, 14)
    rezIcon:SetPoint("CENTER", f, "CENTER", 0, 0)
    rezIcon:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
    rezIcon:Hide()
    f.rezIcon = rezIcon

    -- Dead skull icon (next to DEAD text)
    local deadIcon = f:CreateTexture(nil, "OVERLAY")
    deadIcon:SetSize(12, 12)
    deadIcon:SetPoint("RIGHT", defFs, "LEFT", -2, 0)
    deadIcon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    deadIcon:Hide()
    f.deadIcon = deadIcon

    -- Buff indicators (top-right corner, grayed-out clock icon)
    f.buffInd = {}
    for slot = 1, 4 do
        local ind = f:CreateTexture(nil, "OVERLAY")
        ind:SetSize(BUFF_SIZE, BUFF_SIZE)
        ind:SetPoint("TOPRIGHT", f, "TOPRIGHT",
            -(BUFF_GAP + (4 - slot) * (BUFF_SIZE + BUFF_GAP)),
            -BUFF_GAP)
        ind:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
        ind:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ind:SetDesaturated(true)
        ind:SetVertexColor(0.6, 0.6, 0.6)
        ind:SetAlpha(0.75)
        ind:Hide()
        f.buffInd[slot] = ind
    end

    -- Buff/HoT indicators (bottom-left, icon + cooldown sweep + timer for short HoTs)
    local HOT_SIZE = 10
    local HOT_MAX = 6
    f.hots = {}
    for h = 1, HOT_MAX do
        local hot = CreateFrame("Frame", nil, f)
        hot:SetSize(HOT_SIZE, HOT_SIZE)
        hot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", (h - 1) * (HOT_SIZE + 1) + 1, 1)
        hot:SetFrameLevel(f:GetFrameLevel() + 3)

        local icon = hot:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        hot.icon = icon

        local border = hot:CreateTexture(nil, "BACKGROUND")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0, 0, 0, 0.8)

        local timer = hot:CreateFontString(nil, "OVERLAY")
        timer:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
        timer:SetPoint("CENTER", 0, 0)
        timer:SetTextColor(1, 1, 1)
        hot.timer = timer

        local stacks = hot:CreateFontString(nil, "OVERLAY")
        stacks:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        stacks:SetPoint("BOTTOMRIGHT", 2, -1)
        stacks:SetTextColor(0.3, 1, 0.3)
        hot.stacks = stacks

        hot:Hide()
        f.hots[h] = hot
    end

    -- Missing Thorns text for tanks
    local thornsText = hp:CreateFontString(nil, "OVERLAY")
    thornsText:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
    thornsText:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", -2, 2)
    thornsText:SetText("no thorns")
    thornsText:SetTextColor(0.4, 0.8, 0.4)
    thornsText:Hide()
    f.thornsText = thornsText

    -- Highlight
    local hl = f:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.12)

    -- Tooltip
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetUnit(self.unit)
        for slot = 1, 4 do
            if canCastBuff[slot] and not HasBuff(self.unit, db.buffs[slot]) then
                local c = BUFF_COLORS[slot]
                local first = db.buffs[slot]:match("^%s*([^,]+)")
                GameTooltip:AddLine("Missing: " .. first, c[1], c[2], c[3])
            end
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Scroll buttons
    local su = CreateFrame("Button", fn .. "SU", f, "SecureActionButtonTemplate")
    su:SetSize(1, 1)
    su:SetAlpha(0)
    su:EnableMouse(false)
    su:RegisterForClicks("AnyUp", "AnyDown")
    su:SetAttribute("unit", unit)
    f.scrollUp = su

    local sd = CreateFrame("Button", fn .. "SD", f, "SecureActionButtonTemplate")
    sd:SetSize(1, 1)
    sd:SetAlpha(0)
    sd:EnableMouse(false)
    sd:RegisterForClicks("AnyUp", "AnyDown")
    sd:SetAttribute("unit", unit)
    f.scrollDown = sd

    -- Track the last frame the player cast from (GCD sweep shows only there)
    f:SetScript("PostClick", function(self) lastClickedFrame = self end)
    su:SetScript("PostClick", function() lastClickedFrame = f end)
    sd:SetScript("PostClick", function() lastClickedFrame = f end)

    -- Suppress tooltips (incl. from tooltip addons) while hovering the frame
    f:HookScript("OnEnter", function()
        mouseOverFrame = true
        if db.hideTooltip ~= false and GameTooltip:IsShown() then
            GameTooltip:Hide()
        end
    end)
    f:HookScript("OnLeave", function()
        mouseOverFrame = false
    end)

    SecureHandlerWrapScript(f, "OnEnter", f, [[
        local n = self:GetName()
        self:SetBindingClick(true, "MOUSEWHEELUP",         n .. "SU", "LeftButton")
        self:SetBindingClick(true, "SHIFT-MOUSEWHEELUP",   n .. "SU", "LeftButton")
        self:SetBindingClick(true, "MOUSEWHEELDOWN",       n .. "SD", "LeftButton")
        self:SetBindingClick(true, "SHIFT-MOUSEWHEELDOWN", n .. "SD", "LeftButton")
    ]])
    SecureHandlerWrapScript(f, "OnLeave", f, [[
        self:ClearBindings()
    ]])

    return f
end

----------------------------------------------
-- Static popup for profile name input
----------------------------------------------
StaticPopupDialogs["SIMPLEHEAL_SAVE_PROFILE"] = {
    text = "Save profile as:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        local eb = self.editBox or self.EditBox
        local name = eb:GetText()
        if not name or name == "" or name == "Default" then
            print("|cff00ff00SimpleHeal:|r Invalid profile name.")
            return
        end
        if not db.profiles then db.profiles = {} end
        db.profiles[name] = { spells = {}, buffs = {} }
        for k, v in pairs(db.spells) do db.profiles[name].spells[k] = v end
        for i = 1, 4 do db.profiles[name].buffs[i] = db.buffs[i] or "" end
        db.activeProfile = name
        if configPanel then UIDropDownMenu_SetText(configPanel.profDrop, name) end
        print("|cff00ff00SimpleHeal:|r Saved profile: " .. name)
    end,
    OnShow = function(self)
        local eb = self.editBox or self.EditBox
        eb:SetText(db.activeProfile or "")
        eb:HighlightText()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

----------------------------------------------
-- Config panel
----------------------------------------------
local Layout, SavePosition, ToggleTestMode, LayoutTestFrames
local testModeActive = false
local function CreateConfigPanel()
    local panelW  = 340
    local rowH    = 28
    local padX    = 12
    local panelH  = 660

    local p = CreateFrame("Frame", "SimpleHealConfig", UIParent, "BackdropTemplate")
    p:SetSize(panelW, panelH)
    p:SetPoint("CENTER")
    p:SetMovable(true)
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:SetFrameStrata("DIALOG")
    p:Hide()

    p:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, p)
    titleBar:SetPoint("TOPLEFT", 0, 12)
    titleBar:SetPoint("TOPRIGHT", 0, 12)
    titleBar:SetHeight(36)
    titleBar:EnableMouse(true)
    titleBar:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then p:StartMoving() end
    end)
    titleBar:SetScript("OnMouseUp", function() p:StopMovingOrSizing() end)

    local titleBg = p:CreateTexture(nil, "OVERLAY")
    titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBg:SetPoint("TOP", 0, 12)
    titleBg:SetSize(240, 48)

    local titleText = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", 0, 2)
    titleText:SetText("SimpleHeal Settings")

    local closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetFrameLevel(p:GetFrameLevel() + 10)

    tinsert(UISpecialFrames, "SimpleHealConfig")

    ------------------------------------------------
    -- Tab system (Blizzard-style tabs along the bottom edge)
    ------------------------------------------------
    local tabContentTop = -32
    local tabFrames = {}
    for t = 1, 3 do
        local tf = CreateFrame("Frame", nil, p)
        tf:SetPoint("TOPLEFT", 0, tabContentTop)
        tf:SetPoint("BOTTOMRIGHT", 0, 42)
        if t > 1 then tf:Hide() end
        tabFrames[t] = tf
    end
    local tab1Frame, tab2Frame, tab3Frame = tabFrames[1], tabFrames[2], tabFrames[3]

    local TAB_NAMES = { "Spells", "Display", "Advanced" }
    local tabButtons = {}
    local usingBlizzTabs = pcall(function()
        for t = 1, 3 do
            tabButtons[t] = CreateFrame("Button", "SimpleHealConfigTab" .. t, p, "CharacterFrameTabButtonTemplate")
        end
    end)

    local SetActiveTab
    if usingBlizzTabs then
        for t = 1, 3 do
            tabButtons[t]:SetID(t)
            tabButtons[t]:SetText(TAB_NAMES[t])
            if t == 1 then
                tabButtons[t]:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 12, 4)
            else
                tabButtons[t]:SetPoint("LEFT", tabButtons[t - 1], "RIGHT", -14, 0)
            end
        end
        PanelTemplates_SetNumTabs(p, 3)

        SetActiveTab = function(n)
            PanelTemplates_SetTab(p, n)
            for t = 1, 3 do
                if t == n then tabFrames[t]:Show() else tabFrames[t]:Hide() end
            end
        end
    else
        -- Fallback: simple flat tabs at the top
        local tabW = math.floor((panelW - padX * 2) / 3) - 4
        for t = 1, 3 do
            local btn = CreateFrame("Button", nil, p)
            btn:SetSize(tabW, 22)
            btn:SetPoint("TOPLEFT", padX + (t - 1) * (tabW + 4), -28)
            local btnBg = btn:CreateTexture(nil, "BACKGROUND")
            btnBg:SetAllPoints()
            btn.bg = btnBg
            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btnText:SetPoint("CENTER")
            btnText:SetText(TAB_NAMES[t])
            btn.label = btnText
            tabButtons[t] = btn
        end
        for t = 1, 3 do
            tabFrames[t]:SetPoint("TOPLEFT", 0, -56)
        end

        SetActiveTab = function(n)
            for t = 1, 3 do
                if t == n then
                    tabFrames[t]:Show()
                    tabButtons[t].bg:SetColorTexture(0.2, 0.4, 0.2, 0.9)
                    tabButtons[t].label:SetTextColor(1, 1, 1)
                else
                    tabFrames[t]:Hide()
                    tabButtons[t].bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
                    tabButtons[t].label:SetTextColor(0.6, 0.6, 0.6)
                end
            end
        end
    end

    for t = 1, 3 do
        tabButtons[t]:SetScript("OnClick", function() SetActiveTab(t) end)
    end
    SetActiveTab(1)

    local function AddTooltip(widget, title, text)
        widget:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(title, 1, 0.82, 0)
            GameTooltip:AddLine(text, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    ------------------------------------------------
    -- TAB 1: Spells & Profiles
    ------------------------------------------------
    local t1 = tab1Frame

    -- Preset dropdown
    local presetLabel = t1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    presetLabel:SetPoint("TOPLEFT", padX, -8)
    presetLabel:SetText("Preset:")

    local presetDrop = CreateFrame("Frame", "SimpleHealPresetDrop", t1, "UIDropDownMenuTemplate")
    presetDrop:SetPoint("LEFT", presetLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(presetDrop, 180)
    UIDropDownMenu_SetText(presetDrop, "-- Choose class/spec --")
    p.presetDrop = presetDrop

    local function FillFromPreset(preset)
        p.takeSnapshot()
        db.bindings = BindingsFromLegacySpells(preset.spells)
        for slot = 1, 4 do
            local b = preset.buffs and preset.buffs[slot] or ""
            p.buffBoxes[slot]:SetText(b)
            db.buffs[slot] = b
        end
        UIDropDownMenu_SetText(presetDrop, preset.name)
        p.RefreshBindingRows()
        ApplyBindings()
        UpdateCanCastBuffs()
        print("|cff00ff00SimpleHeal:|r " .. preset.name .. " preset applied! (Undo button reverts)")
    end

    UIDropDownMenu_Initialize(presetDrop, function(self, level)
        for _, preset in ipairs(PRESETS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = preset.name
            info.func = function()
                FillFromPreset(preset)
                CloseDropDownMenus()
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    AddTooltip(presetDrop, "Class Preset",
        "Pick your class and spec - all spell bindings and buff tracking are applied instantly. Use the Undo button to revert.")

    -- Profile row
    local profLabel = t1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    profLabel:SetPoint("TOPLEFT", padX, -36)
    profLabel:SetText("Profile:")

    local profDrop = CreateFrame("Frame", "SimpleHealProfDrop", t1, "UIDropDownMenuTemplate")
    profDrop:SetPoint("LEFT", profLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(profDrop, 110)
    UIDropDownMenu_SetText(profDrop, db.activeProfile or "Default")
    p.profDrop = profDrop
    AddTooltip(profDrop, "Profiles",
        "Save different spell setups and switch between them - e.g. one for raids and one for PvP.")

    local function SwitchProfile(name)
        if name == db.activeProfile then return end
        p.saveCurrentToProfile()
        local prof = name ~= "Default" and db.profiles[name] or nil
        if prof then
            for k, v in pairs(prof.spells) do db.spells[k] = v end
            for i2 = 1, 4 do db.buffs[i2] = prof.buffs[i2] or "" end
            if prof.bindings then
                db.bindings = {}
                for _, b in ipairs(prof.bindings) do
                    db.bindings[#db.bindings + 1] = { mod = b.mod, btn = b.btn, spell = b.spell }
                end
            else
                db.bindings = BindingsFromLegacySpells(prof.spells)
            end
        end
        db.activeProfile = name
        UIDropDownMenu_SetText(profDrop, name)
        p.RefreshBindingRows()
        for s = 1, 4 do
            p.buffBoxes[s]:SetText(db.buffs[s] or "")
        end
        ApplyBindings()
        UpdateCanCastBuffs()
        Layout()
        print("|cff00ff00SimpleHeal:|r Loaded profile: " .. name)
    end

    UIDropDownMenu_Initialize(profDrop, function(self, level)
        if not db.profiles then db.profiles = {} end
        local names = {}
        for name in pairs(db.profiles) do names[#names + 1] = name end
        table.sort(names)
        table.insert(names, 1, "Default")
        for _, name in ipairs(names) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.func = function()
                SwitchProfile(name)
                CloseDropDownMenus()
            end
            info.checked = (name == (db.activeProfile or "Default"))
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local profSaveBtn = CreateFrame("Button", nil, t1, "UIPanelButtonTemplate")
    profSaveBtn:SetSize(70, 20)
    profSaveBtn:SetPoint("TOPLEFT", padX + 44, -64)
    profSaveBtn:SetText("Save As")
    profSaveBtn:SetScript("OnClick", function()
        StaticPopup_Show("SIMPLEHEAL_SAVE_PROFILE")
    end)

    local profDelBtn = CreateFrame("Button", nil, t1, "UIPanelButtonTemplate")
    profDelBtn:SetSize(50, 20)
    profDelBtn:SetPoint("LEFT", profSaveBtn, "RIGHT", 4, 0)
    profDelBtn:SetText("Del")
    profDelBtn:SetScript("OnClick", function()
        local name = db.activeProfile or "Default"
        if name == "Default" then
            print("|cff00ff00SimpleHeal:|r Cannot delete Default profile.")
            return
        end
        if db.profiles then db.profiles[name] = nil end
        db.activeProfile = "Default"
        UIDropDownMenu_SetText(profDrop, "Default")
        print("|cff00ff00SimpleHeal:|r Deleted profile: " .. name)
    end)

    local profUndoBtn = CreateFrame("Button", nil, t1, "UIPanelButtonTemplate")
    profUndoBtn:SetSize(50, 20)
    profUndoBtn:SetPoint("LEFT", profDelBtn, "RIGHT", 4, 0)
    profUndoBtn:SetText("Undo")
    p.profUndoBtn = profUndoBtn

    p.saveCurrentToProfile = function()
        local name = db.activeProfile or "Default"
        if name == "Default" then return end
        if not db.profiles then db.profiles = {} end
        db.profiles[name] = { spells = {}, buffs = {}, bindings = {} }
        for k, v in pairs(db.spells) do db.profiles[name].spells[k] = v end
        for i2 = 1, 4 do db.profiles[name].buffs[i2] = db.buffs[i2] or "" end
        for _, b in ipairs(db.bindings or {}) do
            table.insert(db.profiles[name].bindings, { mod = b.mod, btn = b.btn, spell = b.spell })
        end
    end

    p.undoSnapshot = nil
    p.takeSnapshot = function()
        p.undoSnapshot = { spells = {}, buffs = {}, bindings = {} }
        for k, v in pairs(db.spells) do p.undoSnapshot.spells[k] = v end
        for i2 = 1, 4 do p.undoSnapshot.buffs[i2] = db.buffs[i2] or "" end
        for _, b in ipairs(db.bindings or {}) do
            table.insert(p.undoSnapshot.bindings, { mod = b.mod, btn = b.btn, spell = b.spell })
        end
    end

    profUndoBtn:SetScript("OnClick", function()
        if not p.undoSnapshot then
            print("|cff00ff00SimpleHeal:|r Nothing to undo.")
            return
        end
        for k, v in pairs(p.undoSnapshot.spells) do db.spells[k] = v end
        for i2 = 1, 4 do db.buffs[i2] = p.undoSnapshot.buffs[i2] or "" end
        db.bindings = {}
        for _, b in ipairs(p.undoSnapshot.bindings or {}) do
            table.insert(db.bindings, { mod = b.mod, btn = b.btn, spell = b.spell })
        end
        p.RefreshBindingRows()
        for s = 1, 4 do
            p.buffBoxes[s]:SetText(db.buffs[s] or "")
        end
        ApplyBindings()
        UpdateCanCastBuffs()
        p.undoSnapshot = nil
        print("|cff00ff00SimpleHeal:|r Reverted to previous spells.")
    end)

    -- Spell bindings
    local spellHeader = t1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellHeader:SetPoint("TOPLEFT", padX, -92)
    spellHeader:SetText("Spell Bindings")
    spellHeader:SetTextColor(1, 0.82, 0)

    local spellHint = t1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    spellHint:SetPoint("LEFT", spellHeader, "RIGHT", 6, 0)
    spellHint:SetText("(spell, macro \"/...\", target, menu)")

    -- Live validation: green if in spellbook, red if not.
    -- Macros ("/..."), "target" and "menu" are shown in blue.
    local function AttachValidation(eb)
        eb:HookScript("OnTextChanged", function(self)
            local text = self:GetText()
            if not text or text == "" then
                self:SetTextColor(1, 1, 1)
                return
            end
            local lower = text:lower()
            if lower == "target" or lower == "menu" or text:sub(1, 1) == "/" then
                self:SetTextColor(0.5, 0.8, 1)
                return
            end
            local base = text:match("^(.-)%s*%(") or text
            if KnownSpell(base:match("^%s*(.-)%s*$")) then
                self:SetTextColor(0.5, 1, 0.5)
            else
                self:SetTextColor(1, 0.45, 0.45)
            end
        end)
    end

    -- Autocomplete from spellbook (chat-style: fills and highlights the rest)
    local function AttachAutocomplete(eb, tokenized)
        eb:SetScript("OnChar", function(self)
            local text = self:GetText()
            if self:GetCursorPosition() ~= #text then return end
            local prefix, token = "", text
            if tokenized then
                prefix, token = text:match("^(.-)([^,]*)$")
            end
            local search = token:match("^%s*(.-)$")
            local pad = token:sub(1, #token - #search)
            if #search < 2 then return end
            local lower = search:lower()
            for _, name in ipairs(spellbookNames) do
                if name:lower():sub(1, #search) == lower and #name > #search then
                    self:SetText(prefix .. pad .. name)
                    self:HighlightText(#text, -1)
                    self:SetCursorPosition(#text)
                    break
                end
            end
        end)
    end

    ------------------------------------------------
    -- Click bindings: dynamic rows [modifier][button][spell][x]
    ------------------------------------------------
    local bindTop = 106
    local bindRowH = 24
    p.bindingRows = {}

    local function ApplyRowToDB(i)
        if p.UpdateDupWarning then p.UpdateDupWarning() end
        if InCombatLockdown() then
            pendingApply = true
        else
            ApplyBindings()
        end
    end

    -- Scrollable binding list (10 rows visible, up to MAX_CLICK_BINDINGS total)
    local VISIBLE_BIND_ROWS = 10
    local bindScroll = CreateFrame("ScrollFrame", "SimpleHealBindScroll", t1, "UIPanelScrollFrameTemplate")
    bindScroll:SetPoint("TOPLEFT", padX, -bindTop)
    bindScroll:SetSize(panelW - padX * 2 - 20, VISIBLE_BIND_ROWS * bindRowH)

    local bindChild = CreateFrame("Frame", nil, bindScroll)
    bindChild:SetSize(panelW - padX * 2 - 20, MAX_CLICK_BINDINGS * bindRowH)
    bindScroll:SetScrollChild(bindChild)
    bindChild:SetPoint("TOPLEFT", 0, 0)

    for i = 1, MAX_CLICK_BINDINGS do
        local row = CreateFrame("Frame", nil, bindChild)
        row:SetSize(panelW - padX * 2 - 20, 22)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * bindRowH)

        local modBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        modBtn:SetSize(48, 20)
        modBtn:SetPoint("LEFT", 0, 0)
        modBtn:SetScript("OnClick", function()
            local b = db.bindings[i]
            if not b then return end
            local idx = 1
            for j, m in ipairs(MOD_OPTIONS) do
                if m == b.mod then idx = j break end
            end
            b.mod = MOD_OPTIONS[(idx % #MOD_OPTIONS) + 1]
            modBtn:SetText(MOD_LABELS[b.mod])
            ApplyRowToDB(i)
        end)
        AddTooltip(modBtn, "Modifier", "Click to cycle: None / Shift / Ctrl / Alt")

        local btnBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnBtn:SetSize(56, 20)
        btnBtn:SetPoint("LEFT", modBtn, "RIGHT", 2, 0)
        btnBtn:SetScript("OnClick", function()
            local b = db.bindings[i]
            if not b then return end
            b.btn = (b.btn % 7) + 1
            btnBtn:SetText(BTN_LABELS[b.btn])
            ApplyRowToDB(i)
        end)
        AddTooltip(btnBtn, "Mouse button", "Click to cycle: Left / Right / Middle / Button 4 / Button 5 / Wheel Up / Wheel Down")

        local eb = CreateFrame("EditBox", "SimpleHealBindEB" .. i, row, "InputBoxTemplate")
        eb:SetSize(140, 20)
        eb:SetPoint("LEFT", btnBtn, "RIGHT", 8, 0)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(255)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        eb:HookScript("OnEditFocusLost", function(self)
            local b = db.bindings[i]
            if b then
                b.spell = self:GetText() or ""
                ApplyRowToDB(i)
            end
        end)
        AttachValidation(eb)
        AttachAutocomplete(eb, false)

        local delBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
        delBtn:SetSize(22, 22)
        delBtn:SetPoint("LEFT", eb, "RIGHT", 0, 0)
        delBtn:SetScript("OnClick", function()
            table.remove(db.bindings, i)
            p.RefreshBindingRows()
            if not InCombatLockdown() then ApplyBindings() end
        end)

        row.modBtn, row.btnBtn, row.eb = modBtn, btnBtn, eb
        row:Hide()
        p.bindingRows[i] = row
    end

    local addBindBtn = CreateFrame("Button", nil, t1, "UIPanelButtonTemplate")
    addBindBtn:SetSize(140, 20)
    addBindBtn:SetText("+ Add binding")
    addBindBtn:SetPoint("TOPLEFT", padX, -bindTop - VISIBLE_BIND_ROWS * bindRowH - 4)
    addBindBtn:SetScript("OnClick", function()
        if #db.bindings >= MAX_CLICK_BINDINGS then
            print("|cff00ff00SimpleHeal:|r Max " .. MAX_CLICK_BINDINGS .. " bindings.")
            return
        end
        db.bindings[#db.bindings + 1] = { mod = "", btn = 1, spell = "" }
        p.RefreshBindingRows()
        -- Scroll to the new row
        bindScroll:SetVerticalScroll(math.max(0, #db.bindings * bindRowH - VISIBLE_BIND_ROWS * bindRowH))
    end)

    local dupWarning = t1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dupWarning:SetPoint("LEFT", addBindBtn, "RIGHT", 8, 0)
    dupWarning:SetPoint("RIGHT", t1, "RIGHT", -padX, 0)
    dupWarning:SetJustifyH("LEFT")
    dupWarning:SetTextColor(1, 0.35, 0.35)
    dupWarning:Hide()

    p.UpdateDupWarning = function()
        local dup = FindDuplicateBinding(db.bindings)
        if dup then
            dupWarning:SetText("Duplicate: " .. dup .. "!")
            dupWarning:Show()
        else
            dupWarning:Hide()
        end
    end

    p.RefreshBindingRows = function()
        if not db.bindings then db.bindings = {} end
        for i = 1, MAX_CLICK_BINDINGS do
            local row = p.bindingRows[i]
            local b = db.bindings[i]
            if b then
                row.modBtn:SetText(MOD_LABELS[b.mod] or "None")
                row.btnBtn:SetText(BTN_LABELS[b.btn] or "Left")
                row.eb:SetText(b.spell or "")
                row:Show()
            else
                row:Hide()
            end
        end
        addBindBtn:SetText(("+ Add binding (%d/%d)"):format(#db.bindings, MAX_CLICK_BINDINGS))
        if #db.bindings >= MAX_CLICK_BINDINGS then
            addBindBtn:Disable()
        else
            addBindBtn:Enable()
        end
        p.UpdateDupWarning()
    end
    p.RefreshBindingRows()

    -- Buff tracking
    local buffTop = bindTop + VISIBLE_BIND_ROWS * bindRowH + 44
    local buffHeader = t1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buffHeader:SetPoint("TOPLEFT", padX, -buffTop + 14)
    buffHeader:SetText("Missing Buff Alerts")
    buffHeader:SetTextColor(1, 0.82, 0)

    local buffHint = t1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    buffHint:SetPoint("TOPLEFT", buffHeader, "TOPRIGHT", 6, 0)
    buffHint:SetText("(comma = OR)")

    p.buffBoxes = {}
    for slot = 1, 4 do
        local y = -buffTop - (slot - 1) * rowH
        local colorSwatch = t1:CreateTexture(nil, "OVERLAY")
        colorSwatch:SetSize(12, 12)
        colorSwatch:SetPoint("TOPLEFT", padX + 4, y + 1)
        local c = BUFF_COLORS[slot]
        colorSwatch:SetColorTexture(c[1], c[2], c[3], 1)
        local label = t1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", colorSwatch, "RIGHT", 4, 0)
        label:SetText("Buff " .. slot .. ":")
        local eb = CreateFrame("EditBox", "SimpleHealBuff" .. slot, t1, "InputBoxTemplate")
        eb:SetSize(190, 20)
        eb:SetPoint("TOPLEFT", padX + 88, y + 2)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(255)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        eb:HookScript("OnEditFocusLost", function(self)
            db.buffs[slot] = self:GetText() or ""
            UpdateCanCastBuffs()
        end)
        AttachAutocomplete(eb, true)

        -- Spell icon preview (first name in the list)
        local iconPrev = t1:CreateTexture(nil, "OVERLAY")
        iconPrev:SetSize(18, 18)
        iconPrev:SetPoint("LEFT", eb, "RIGHT", 6, 0)
        iconPrev:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconPrev:Hide()
        eb:HookScript("OnTextChanged", function(self)
            local text = self:GetText() or ""
            local first = text:match("^([^,]+)")
            local icon = first and select(3, GetSpellInfo(first:match("^%s*(.-)%s*$")))
            if icon then
                iconPrev:SetTexture(icon)
                iconPrev:Show()
            else
                iconPrev:Hide()
            end
        end)

        p.buffBoxes[slot] = eb
    end

    ------------------------------------------------
    -- TAB 2: Display
    ------------------------------------------------
    local t2 = tab2Frame
    ------------------------------------------------
    -- TAB 3: Advanced
    ------------------------------------------------
    local t3 = tab3Frame

    -- Spec filter dropdown (Advanced)
    local specLabel = t3:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    specLabel:SetPoint("TOPLEFT", padX, -8)
    specLabel:SetText("Show only for:")

    p.selectedSpecTree = 0

    local specDrop = CreateFrame("Frame", "SimpleHealSpecDrop", t3, "UIDropDownMenuTemplate")
    specDrop:SetPoint("LEFT", specLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(specDrop, 140)
    UIDropDownMenu_SetText(specDrop, "Always Show")
    p.specDrop = specDrop
    AddTooltip(specDrop, "Show only for",
        "Only show SimpleHeal in the chosen talent tree. In your off-spec the Blizzard frames come back automatically.")

    UIDropDownMenu_Initialize(specDrop, function(self, level)
        local function AddItem(text, tree)
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.func = function()
                p.selectedSpecTree = tree
                UIDropDownMenu_SetText(specDrop, text)
                db.specTree = tree
                UpdateSpecVisibility()
                CloseDropDownMenus()
            end
            info.checked = (p.selectedSpecTree == tree)
            UIDropDownMenu_AddButton(info, level)
        end
        AddItem("Always Show", 0)
        local names = GetTreeNames()
        for t = 1, 3 do
            if names[t] then AddItem(names[t], t) end
        end
    end)

    -- Sliders
    local sliderTop = -10

    local function MakeSlider(name, minV, maxV, step, x, y, width)
        local s = CreateFrame("Slider", "SimpleHeal" .. name .. "Slider", t2, "OptionsSliderTemplate")
        s:SetSize(width, 14)
        s:SetPoint("TOPLEFT", x, y)
        s:SetMinMaxValues(minV, maxV)
        s:SetValueStep(step)
        s:SetObeyStepOnDrag(true)
        s.Text = s.Text or _G[s:GetName() .. "Text"]
        s.Low = s.Low or _G[s:GetName() .. "Low"]
        s.High = s.High or _G[s:GetName() .. "High"]
        if s.Low then s.Low:SetText("") end
        if s.High then s.High:SetText("") end
        return s
    end

    local sizeHeader = t2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeHeader:SetPoint("TOPLEFT", padX, sliderTop + 6)
    sizeHeader:SetText("Frame Size & Opacity")
    sizeHeader:SetTextColor(1, 0.82, 0)

    local wSlider = MakeSlider("Width", 50, 200, 5, padX + 10, sliderTop - 18, 130)
    wSlider:SetValue(db.frameW)
    if wSlider.Text then wSlider.Text:SetText("Width: " .. db.frameW) end
    wSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        if self.Text then self.Text:SetText("Width: " .. val) end
        if not InCombatLockdown() then
            db.frameW = val
            for _, f in pairs(allFrames) do f:SetSize(val, db.frameH) end
            Layout()
        end
    end)
    p.wSlider = wSlider

    local hSlider = MakeSlider("Height", 16, 80, 2, padX + 172, sliderTop - 18, 130)
    hSlider:SetValue(db.frameH)
    if hSlider.Text then hSlider.Text:SetText("Height: " .. db.frameH) end
    hSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        if self.Text then self.Text:SetText("Height: " .. val) end
        if not InCombatLockdown() then
            db.frameH = val
            for _, f in pairs(allFrames) do f:SetSize(db.frameW, val) end
            Layout()
        end
    end)
    p.hSlider = hSlider

    local aSlider = MakeSlider("Alpha", 20, 100, 5, padX + 10, sliderTop - 62, 130)
    local alphaVal = math.floor((db.frameAlpha or 1) * 100)
    aSlider:SetValue(alphaVal)
    if aSlider.Text then aSlider.Text:SetText("Opacity: " .. alphaVal .. "%") end
    aSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        if self.Text then self.Text:SetText("Opacity: " .. val .. "%") end
        db.frameAlpha = val / 100
        for _, f in pairs(allFrames) do
            if f:IsShown() then f:SetAlpha(db.frameAlpha) end
        end
        if testModeActive and not InCombatLockdown() then Layout() end
    end)
    p.aSlider = aSlider

    local fSlider = MakeSlider("Font", 7, 16, 1, padX + 172, sliderTop - 62, 130)
    fSlider:SetValue(db.fontSize or 10)
    if fSlider.Text then fSlider.Text:SetText("Font size: " .. (db.fontSize or 10)) end
    fSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        if self.Text then self.Text:SetText("Font size: " .. val) end
        db.fontSize = val
        ApplyFontSize()
        if not InCombatLockdown() then Layout() end
    end)
    p.fSlider = fSlider

    local iSlider = MakeSlider("Icon", 6, 20, 1, padX + 10, sliderTop - 106, 130)
    iSlider:SetValue(db.iconSize or 10)
    if iSlider.Text then iSlider.Text:SetText("Icon size: " .. (db.iconSize or 10)) end
    iSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        if self.Text then self.Text:SetText("Icon size: " .. val) end
        db.iconSize = val
        ApplyIconSize()
        if testModeActive and not InCombatLockdown() then Layout() end
    end)
    p.iSlider = iSlider
    AddTooltip(iSlider, "Icon size",
        "Size of the HoT icons (bottom-left) and missing-buff indicators (top-right) on each frame.")

    local sSlider = MakeSlider("Spacing", 0, 10, 1, padX + 172, sliderTop - 106, 130)
    sSlider:SetValue(db.spacing or 2)
    if sSlider.Text then sSlider.Text:SetText("Spacing: " .. (db.spacing or 2)) end
    sSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        if self.Text then self.Text:SetText("Spacing: " .. val) end
        db.spacing = val
        if not InCombatLockdown() then Layout() end
    end)
    p.sSlider = sSlider
    AddTooltip(sSlider, "Spacing", "Gap between frames in pixels.")

    -- Appearance
    local texHeader = t2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    texHeader:SetPoint("TOPLEFT", padX, sliderTop - 148)
    texHeader:SetText("Appearance")
    texHeader:SetTextColor(1, 0.82, 0)

    local texLabel = t2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    texLabel:SetPoint("TOPLEFT", padX, sliderTop - 170)
    texLabel:SetText("Bar Texture")

    local texDrop = CreateFrame("Frame", "SimpleHealBarTextureDrop", t2, "UIDropDownMenuTemplate")
    texDrop:SetPoint("LEFT", texLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(texDrop, 130)
    local curTexIdx = db.barTexture or 1
    UIDropDownMenu_SetText(texDrop, BAR_TEXTURES[curTexIdx] and BAR_TEXTURES[curTexIdx].name or "Minimalist")
    UIDropDownMenu_Initialize(texDrop, function(self, level)
        for i, entry in ipairs(BAR_TEXTURES) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.name
            info.func = function()
                db.barTexture = i
                UIDropDownMenu_SetText(texDrop, entry.name)
                CloseDropDownMenus()
                ApplyBarTexture()
                if not InCombatLockdown() then Layout() end
            end
            info.checked = (i == (db.barTexture or 1))
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Layout mode dropdown
    local LAYOUT_MODES = { "Columns (by role)", "Rows (by role)", "Grid (groups as rows)", "Grid (groups as columns)" }
    local layoutLabel = t2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    layoutLabel:SetPoint("TOPLEFT", padX, sliderTop - 200)
    layoutLabel:SetText("Layout")

    local layoutDrop = CreateFrame("Frame", "SimpleHealLayoutDrop", t2, "UIDropDownMenuTemplate")
    layoutDrop:SetPoint("LEFT", layoutLabel, "RIGHT", 18, -2)
    UIDropDownMenu_SetWidth(layoutDrop, 130)
    UIDropDownMenu_SetText(layoutDrop, LAYOUT_MODES[db.layoutMode or 1])
    UIDropDownMenu_Initialize(layoutDrop, function(self, level)
        for i, name in ipairs(LAYOUT_MODES) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.func = function()
                db.layoutMode = i
                UIDropDownMenu_SetText(layoutDrop, name)
                CloseDropDownMenus()
                if not InCombatLockdown() then Layout() end
            end
            info.checked = (i == (db.layoutMode or 1))
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Color mode dropdown
    local COLOR_MODES = { "Class-colored bars", "Dark bars, colored names" }
    local colorLabel = t2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colorLabel:SetPoint("TOPLEFT", padX, sliderTop - 230)
    colorLabel:SetText("Colors")

    local colorDrop = CreateFrame("Frame", "SimpleHealColorDrop", t2, "UIDropDownMenuTemplate")
    colorDrop:SetPoint("LEFT", colorLabel, "RIGHT", 14, -2)
    UIDropDownMenu_SetWidth(colorDrop, 150)
    UIDropDownMenu_SetText(colorDrop, COLOR_MODES[db.colorMode or 1])
    UIDropDownMenu_Initialize(colorDrop, function(self, level)
        for i, name in ipairs(COLOR_MODES) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.func = function()
                db.colorMode = i
                UIDropDownMenu_SetText(colorDrop, name)
                CloseDropDownMenus()
                if not InCombatLockdown() then Layout() end
            end
            info.checked = (i == (db.colorMode or 1))
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Health text dropdown
    local HEALTH_MODES = { "Missing health (-1234)", "Percent (87%)", "Both" }
    local healthLabel = t2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    healthLabel:SetPoint("TOPLEFT", padX, sliderTop - 260)
    healthLabel:SetText("Health text")

    local healthDrop = CreateFrame("Frame", "SimpleHealHealthDrop", t2, "UIDropDownMenuTemplate")
    healthDrop:SetPoint("LEFT", healthLabel, "RIGHT", -6, -2)
    UIDropDownMenu_SetWidth(healthDrop, 150)
    UIDropDownMenu_SetText(healthDrop, HEALTH_MODES[db.hpTextMode or 1])
    p.healthDrop = healthDrop
    p.HEALTH_MODES = HEALTH_MODES
    UIDropDownMenu_Initialize(healthDrop, function(self, level)
        for i, name in ipairs(HEALTH_MODES) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.func = function()
                db.hpTextMode = i
                UIDropDownMenu_SetText(healthDrop, name)
                CloseDropDownMenus()
                for _, f in pairs(allFrames) do
                    if f:IsShown() then Refresh(f) end
                end
                if not InCombatLockdown() then Layout() end
            end
            info.checked = (i == (db.hpTextMode or 1))
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Display checkboxes
    local cbTop = sliderTop - 296

    local function MakeCheckbox(parent, label, x, y)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", x, y)
        local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        text:SetText(label)
        cb.label = text
        return cb
    end

    local elemHeader = t2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    elemHeader:SetPoint("TOPLEFT", padX, cbTop + 14)
    elemHeader:SetText("Elements")
    elemHeader:SetTextColor(1, 0.82, 0)

    local styleHeader = t2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    styleHeader:SetPoint("TOPLEFT", padX + 170, cbTop + 14)
    styleHeader:SetText("Style")
    styleHeader:SetTextColor(1, 0.82, 0)

    local cbLock = MakeCheckbox(t2, "Lock position", padX + 170, cbTop - 4)
    cbLock:SetChecked(db.locked)
    cbLock:SetScript("OnClick", function(self)
        db.locked = self:GetChecked() and true or false
        if db.locked then container.handle:Hide() else container.handle:Show() end
    end)
    p.cbLock = cbLock
    AddTooltip(cbLock, "Lock position", "Locks the frames so they cannot be moved by dragging.")

    local cbTwoLine = MakeCheckbox(t2, "Two-line text", padX + 170, cbTop - 26)
    cbTwoLine:SetChecked(db.twoLineText or false)
    cbTwoLine:SetScript("OnClick", function(self)
        db.twoLineText = self:GetChecked() and true or false
        ApplyTextLayout()
        for _, f in pairs(allFrames) do
            if f:IsShown() then Refresh(f) end
        end
        if not InCombatLockdown() then Layout() end
    end)
    p.cbTwoLine = cbTwoLine
    AddTooltip(cbTwoLine, "Two-line text", "Name on the first line and missing health on the second - good for square frames.")

    local cbShowPets = MakeCheckbox(t2, "Show pets", padX + 170, cbTop - 70)
    cbShowPets:SetChecked(db.showPets ~= false)
    cbShowPets:SetScript("OnClick", function(self)
        db.showPets = self:GetChecked() and true or false
        if not InCombatLockdown() then Layout() end
    end)
    p.cbShowPets = cbShowPets
    AddTooltip(cbShowPets, "Show pets", "Shows hunter/warlock pets as small frames below their owner.")

    local cbTitle = MakeCheckbox(t2, "Show title", padX + 170, cbTop - 114)
    cbTitle:SetChecked(db.showTitle ~= false)
    cbTitle:SetScript("OnClick", function(self)
        db.showTitle = self:GetChecked() and true or false
        if container and container.handleText then
            if db.showTitle then container.handleText:Show() else container.handleText:Hide() end
        end
    end)
    p.cbTitle = cbTitle
    AddTooltip(cbTitle, "Show title", "Shows the SimpleHeal label on the drag handle above the frames.")

    local cbRoleIcons = MakeCheckbox(t2, "Role icons", padX, cbTop - 92)
    cbRoleIcons:SetChecked(db.roleIcons ~= false)
    cbRoleIcons:SetScript("OnClick", function(self)
        db.roleIcons = self:GetChecked() and true or false
        for _, f in pairs(allFrames) do
            if f:IsShown() then Refresh(f) end
        end
        if not InCombatLockdown() then Layout() end
    end)
    p.cbRoleIcons = cbRoleIcons
    AddTooltip(cbRoleIcons, "Role icons", "Shows a small tank/healer icon next to the name on each frame.")

    local function RefreshAll()
        for _, f in pairs(allFrames) do
            if f:IsShown() then Refresh(f) end
        end
    end

    local cbMana = MakeCheckbox(t2, "Mana bar", padX, cbTop - 4)
    cbMana:SetChecked(db.showMana ~= false)
    cbMana:SetScript("OnClick", function(self)
        db.showMana = self:GetChecked() and true or false
        RefreshAll()
    end)
    p.cbMana = cbMana
    AddTooltip(cbMana, "Mana bar", "Shows the thin mana/rage/energy bar at the bottom of each frame.")

    local cbHots = MakeCheckbox(t2, "HoT icons", padX, cbTop - 26)
    cbHots:SetChecked(db.showHots ~= false)
    cbHots:SetScript("OnClick", function(self)
        db.showHots = self:GetChecked() and true or false
        RefreshAll()
        if testModeActive and not InCombatLockdown() then Layout() end
    end)
    p.cbHots = cbHots
    AddTooltip(cbHots, "HoT icons", "Shows your own HoTs/buffs with timers in the bottom-left corner of each frame.")

    local cbSmooth = MakeCheckbox(t2, "Smooth bars", padX + 170, cbTop - 48)
    cbSmooth:SetChecked(db.smoothBars ~= false)
    cbSmooth:SetScript("OnClick", function(self)
        db.smoothBars = self:GetChecked() and true or false
    end)
    p.cbSmooth = cbSmooth
    AddTooltip(cbSmooth, "Smooth bars", "Animates health bar changes instead of jumping instantly.")

    local cbOOC = MakeCheckbox(t2, "OOC indicator", padX, cbTop - 48)
    cbOOC:SetChecked(db.showOOC ~= false)
    cbOOC:SetScript("OnClick", function(self)
        db.showOOC = self:GetChecked() and true or false
        RefreshAll()
    end)
    p.cbOOC = cbOOC
    AddTooltip(cbOOC, "Out-of-combat indicator", "Shows a green dot on players that are out of combat.")

    local cbAggro = MakeCheckbox(t2, "Aggro border", padX, cbTop - 70)
    cbAggro:SetChecked(db.showAggro ~= false)
    cbAggro:SetScript("OnClick", function(self)
        db.showAggro = self:GetChecked() and true or false
        RefreshAll()
    end)
    p.cbAggro = cbAggro
    AddTooltip(cbAggro, "Aggro border", "Shows a red line at the top of frames when a player has threat.")

    local cbPetsSep = MakeCheckbox(t2, "Pets in own group", padX + 170, cbTop - 92)
    cbPetsSep:SetChecked(db.petsSeparate or false)
    cbPetsSep:SetScript("OnClick", function(self)
        db.petsSeparate = self:GetChecked() and true or false
        if not InCombatLockdown() then Layout() end
    end)
    p.cbPetsSep = cbPetsSep
    AddTooltip(cbPetsSep, "Pets in own group",
        "Places all pets in their own column (right of DPS) or row instead of below their owners.")

    local cbRoleLabels = MakeCheckbox(t2, "Role labels", padX, cbTop - 114)
    cbRoleLabels:SetChecked(db.showRoleLabels ~= false)
    cbRoleLabels:SetScript("OnClick", function(self)
        db.showRoleLabels = self:GetChecked() and true or false
        if not InCombatLockdown() then Layout() end
    end)
    p.cbRoleLabels = cbRoleLabels
    AddTooltip(cbRoleLabels, "Role labels", "Shows the TANKS / HEALERS / DPS headers above each group.")

    local cbLowHp = MakeCheckbox(t2, "Low HP warning", padX, cbTop - 158)
    cbLowHp:SetChecked(db.lowHpFlash ~= false)
    cbLowHp:SetScript("OnClick", function(self)
        db.lowHpFlash = self:GetChecked() and true or false
        RefreshAll()
    end)
    p.cbLowHp = cbLowHp
    AddTooltip(cbLowHp, "Low HP warning", "Pulsing red border on players below 30% health.")

    local cbGCD = MakeCheckbox(t2, "GCD indicator", padX, cbTop - 136)
    cbGCD:SetChecked(db.showGCD ~= false)
    cbGCD:SetScript("OnClick", function(self)
        db.showGCD = self:GetChecked() and true or false
    end)
    p.cbGCD = cbGCD
    AddTooltip(cbGCD, "GCD indicator", "Small cooldown swirl in the corner of each frame while your global cooldown is running.")

    ------------------------------------------------
    -- TAB 3: Advanced - behavior options
    ------------------------------------------------
    local advTop = -46

    local advHeader = t3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    advHeader:SetPoint("TOPLEFT", padX, advTop + 14)
    advHeader:SetText("Behavior")
    advHeader:SetTextColor(1, 0.82, 0)

    local cbTarget = MakeCheckbox(t3, "Click-to-target + cast", padX, advTop - 4)
    cbTarget:SetChecked(db.clickTarget)
    cbTarget:SetScript("OnClick", function(self)
        db.clickTarget = self:GetChecked() and true or false
        if not InCombatLockdown() then ApplyBindings() end
    end)
    p.cbTarget = cbTarget
    AddTooltip(cbTarget, "Click-to-target + cast", "Clicking a frame also targets the player before casting.")

    local cbHideBlizz = MakeCheckbox(t3, "Hide Blizzard raid/party frames", padX, advTop - 26)
    cbHideBlizz:SetChecked(db.hideBlizzFrames or false)
    cbHideBlizz:SetScript("OnClick", function(self)
        db.hideBlizzFrames = self:GetChecked() and true or false
        if not InCombatLockdown() then SetBlizzardFrames(not db.hideBlizzFrames) end
    end)
    p.cbHideBlizz = cbHideBlizz
    AddTooltip(cbHideBlizz, "Hide Blizzard raid/party frames", "Hides the built-in raid AND party frames so only SimpleHeal is shown.")

    local cbGroupOnly = MakeCheckbox(t3, "Only show in group/raid", padX, advTop - 48)
    cbGroupOnly:SetChecked(db.groupOnly or false)
    cbGroupOnly:SetScript("OnClick", function(self)
        db.groupOnly = self:GetChecked() and true or false
        UpdateSpecVisibility()
    end)
    p.cbGroupOnly = cbGroupOnly
    AddTooltip(cbGroupOnly, "Only show in group/raid", "Hides SimpleHeal when you are solo.")

    local cbTrackAll = MakeCheckbox(t3, "Track buffs from any class", padX, advTop - 70)
    cbTrackAll:SetChecked(db.trackAllBuffs or false)
    cbTrackAll:SetScript("OnClick", function(self)
        db.trackAllBuffs = self:GetChecked() and true or false
    end)
    p.cbTrackAll = cbTrackAll
    AddTooltip(cbTrackAll, "Track buffs from any class",
        "Show missing-buff indicators even for buffs you cannot cast yourself (e.g. track Fortitude as a druid).")

    local cbExpireWarn = MakeCheckbox(t3, "Warn when buff is about to expire", padX, advTop - 92)
    cbExpireWarn:SetChecked(db.buffExpireWarn ~= false)
    cbExpireWarn:SetScript("OnClick", function(self)
        db.buffExpireWarn = self:GetChecked() and true or false
    end)
    p.cbExpireWarn = cbExpireWarn
    AddTooltip(cbExpireWarn, "Buff expire warning",
        "The buff indicator turns orange when a tracked buff has less than 2 minutes left.")

    local cbRangeFade = MakeCheckbox(t3, "Fade out-of-range players", padX, advTop - 114)
    cbRangeFade:SetChecked(db.rangeFade ~= false)
    cbRangeFade:SetScript("OnClick", function(self)
        db.rangeFade = self:GetChecked() and true or false
        for _, f in pairs(allFrames) do
            if f:IsShown() then Refresh(f) end
        end
    end)
    p.cbRangeFade = cbRangeFade
    AddTooltip(cbRangeFade, "Range fade",
        "Fades frames of players that are out of range of your left-click heal.")

    -- Explicit range-check spell (needed when left click is a macro or "target")
    local rangeLabel = t3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rangeLabel:SetPoint("TOPLEFT", padX + 168, advTop - 119)
    rangeLabel:SetText("Spell:")

    local rangeEb = CreateFrame("EditBox", "SimpleHealRangeSpell", t3, "InputBoxTemplate")
    rangeEb:SetSize(110, 20)
    rangeEb:SetPoint("LEFT", rangeLabel, "RIGHT", 8, 0)
    rangeEb:SetAutoFocus(false)
    rangeEb:SetMaxLetters(60)
    rangeEb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    rangeEb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    rangeEb:HookScript("OnEditFocusLost", function(self)
        db.rangeSpell = self:GetText() or ""
        if InCombatLockdown() then
            pendingApply = true
        else
            ApplyBindings()
        end
    end)
    AttachValidation(rangeEb)
    AttachAutocomplete(rangeEb, false)
    p.rangeEb = rangeEb
    AddTooltip(rangeEb, "Range check spell",
        "Spell used to measure range for the fade. Leave empty to auto-detect from your bindings (macros are parsed too).")

    local cbHideTooltip = MakeCheckbox(t3, "Hide tooltips over frames", padX + 170, advTop - 4)
    cbHideTooltip:SetChecked(db.hideTooltip ~= false)
    cbHideTooltip:SetScript("OnClick", function(self)
        db.hideTooltip = self:GetChecked() and true or false
    end)
    p.cbHideTooltip = cbHideTooltip
    AddTooltip(cbHideTooltip, "Hide tooltips over frames",
        "Suppresses unit tooltips (including from tooltip addons) while your mouse is over a SimpleHeal frame, so they never cover the frames.")

    local cbMinimap = MakeCheckbox(t3, "Minimap button", padX, advTop - 136)
    cbMinimap:SetChecked(db.showMinimap ~= false)
    cbMinimap:SetScript("OnClick", function(self)
        db.showMinimap = self:GetChecked() and true or false
        local btn = _G.SimpleHealMinimapBtn
        if btn then
            if db.showMinimap then btn:Show() else btn:Hide() end
        end
    end)
    p.cbMinimap = cbMinimap
    AddTooltip(cbMinimap, "Minimap button", "Shows the SimpleHeal button around the minimap.")

    -- Auto-profile per group type
    local autoHeader = t3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoHeader:SetPoint("TOPLEFT", padX, advTop - 170)
    autoHeader:SetText("Auto Profile")
    autoHeader:SetTextColor(1, 0.82, 0)

    local function MakeAutoProfDrop(label, y, dbKey)
        local lbl = t3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", padX, y)
        lbl:SetText(label)
        local drop = CreateFrame("Frame", "SimpleHealAuto" .. dbKey, t3, "UIDropDownMenuTemplate")
        drop:SetPoint("LEFT", lbl, "RIGHT", -4, -2)
        UIDropDownMenu_SetWidth(drop, 110)
        UIDropDownMenu_SetText(drop, db[dbKey] or "None")
        UIDropDownMenu_Initialize(drop, function(self, level)
            local names = { "None", "Default" }
            for name in pairs(db.profiles or {}) do names[#names + 1] = name end
            for _, name in ipairs(names) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.func = function()
                    db[dbKey] = name ~= "None" and name or nil
                    UIDropDownMenu_SetText(drop, name)
                    CloseDropDownMenus()
                    AutoSwitchProfile()
                end
                info.checked = ((db[dbKey] or "None") == name)
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        return drop
    end

    p.autoPartyDrop = MakeAutoProfDrop("In party:", advTop - 192, "autoProfileParty")
    p.autoRaidDrop  = MakeAutoProfDrop("In raid:",  advTop - 224, "autoProfileRaid")
    p.autoArenaDrop = MakeAutoProfDrop("In arena:", advTop - 256, "autoProfileArena")
    AddTooltip(p.autoPartyDrop, "Auto profile", "Automatically switch to this profile when you join a party.")
    AddTooltip(p.autoRaidDrop, "Auto profile", "Automatically switch to this profile when you join a raid.")
    AddTooltip(p.autoArenaDrop, "Auto profile", "Automatically switch to this profile when you enter an arena (takes priority over party/raid).")

    ------------------------------------------------
    -- Hover-cast keys (Clique-style)
    ------------------------------------------------
    local hoverHeader = t3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hoverHeader:SetPoint("TOPLEFT", padX, advTop - 296)
    hoverHeader:SetText("Hover-Cast Keys")
    hoverHeader:SetTextColor(1, 0.82, 0)

    local hoverHint = t3:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hoverHint:SetPoint("LEFT", hoverHeader, "RIGHT", 6, 0)
    hoverHint:SetText("(key + spell, e.g. F1 / SHIFT-Q)")

    p.hoverRows = {}
    local hoverTop = -advTop + 312
    for i = 1, 5 do
        local y = -hoverTop - (i - 1) * 24

        local keyEb = CreateFrame("EditBox", "SimpleHealHoverKey" .. i, t3, "InputBoxTemplate")
        keyEb:SetSize(70, 20)
        keyEb:SetPoint("TOPLEFT", padX + 8, y)
        keyEb:SetAutoFocus(false)
        keyEb:SetMaxLetters(20)
        keyEb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        keyEb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

        local spellEb = CreateFrame("EditBox", "SimpleHealHoverSpell" .. i, t3, "InputBoxTemplate")
        spellEb:SetSize(190, 20)
        spellEb:SetPoint("LEFT", keyEb, "RIGHT", 8, 0)
        spellEb:SetAutoFocus(false)
        spellEb:SetMaxLetters(255)
        spellEb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        spellEb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        AttachValidation(spellEb)
        AttachAutocomplete(spellEb, false)

        local function CommitHoverRow()
            if not db.hoverKeys then db.hoverKeys = {} end
            db.hoverKeys[i] = {
                key = (keyEb:GetText() or ""):gsub("%s+", ""):upper(),
                spell = spellEb:GetText() or "",
            }
            keyEb:SetText(db.hoverKeys[i].key)
            if InCombatLockdown() then
                pendingApply = true
            else
                ApplyBindings()
            end
        end
        keyEb:HookScript("OnEditFocusLost", CommitHoverRow)
        spellEb:HookScript("OnEditFocusLost", CommitHoverRow)

        p.hoverRows[i] = { keyEb = keyEb, spellEb = spellEb }
    end

    -- Show 3 rows by default; "+ 2 more" reveals the last two
    local hoverMoreBtn = CreateFrame("Button", nil, t3, "UIPanelButtonTemplate")
    hoverMoreBtn:SetSize(70, 18)
    hoverMoreBtn:SetPoint("TOPLEFT", padX + 8, -hoverTop - 3 * 24)
    hoverMoreBtn:SetText("+ 2 more")

    p.UpdateHoverRowVisibility = function()
        local expanded = p.hoverExpanded
        for i = 4, 5 do
            local hk = db.hoverKeys and db.hoverKeys[i]
            if hk and ((hk.key or "") ~= "" or (hk.spell or "") ~= "") then
                expanded = true
            end
        end
        for i = 4, 5 do
            local r = p.hoverRows[i]
            if expanded then
                r.keyEb:Show(); r.spellEb:Show()
            else
                r.keyEb:Hide(); r.spellEb:Hide()
            end
        end
        if expanded then hoverMoreBtn:Hide() else hoverMoreBtn:Show() end
    end

    hoverMoreBtn:SetScript("OnClick", function()
        p.hoverExpanded = true
        p.UpdateHoverRowVisibility()
    end)
    p.UpdateHoverRowVisibility()

    -- Import/Export (Advanced)
    local ieHeader = t3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ieHeader:SetPoint("BOTTOMLEFT", t3, "BOTTOMLEFT", padX, 30)
    ieHeader:SetText("Import / Export Spells")
    ieHeader:SetTextColor(1, 0.82, 0)

    local ieBox = CreateFrame("EditBox", nil, t3, "BackdropTemplate")
    ieBox:SetSize(panelW - padX * 2 - 110, 20)
    ieBox:SetPoint("BOTTOMLEFT", t3, "BOTTOMLEFT", padX, 8)
    ieBox:SetFontObject(GameFontHighlightSmall)
    ieBox:SetAutoFocus(false)
    ieBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ieBox:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    ieBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.ieBox = ieBox

    local exportBtn = CreateFrame("Button", nil, t3, "UIPanelButtonTemplate")
    exportBtn:SetSize(50, 20)
    exportBtn:SetPoint("LEFT", ieBox, "RIGHT", 4, 0)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        local parts = { "SH2" }
        for _, b in ipairs(db.bindings or {}) do
            parts[#parts + 1] = "b:" .. b.mod .. ":" .. b.btn .. ":" .. (b.spell or "")
        end
        for i = 1, 4 do
            parts[#parts + 1] = "a:" .. i .. ":" .. (db.buffs[i] or "")
        end
        ieBox:SetText(table.concat(parts, ";"))
        ieBox:HighlightText()
        ieBox:SetFocus()
    end)

    local importBtn = CreateFrame("Button", nil, t3, "UIPanelButtonTemplate")
    importBtn:SetSize(50, 20)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 2, 0)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local str = ieBox:GetText()
        if not str or str == "" then return end

        if str:sub(1, 4) == "SH2;" or str == "SH2" then
            -- New format: SH2;b:mod:btn:spell;s:KEY:spell;a:slot:buffs
            local newBindings = {}
            local legacyScroll = {}
            for seg in str:gmatch("[^;]+") do
                local kind, rest = seg:match("^(%a):(.*)$")
                if kind == "b" then
                    local mod, btn, spell = rest:match("^([a-z]*):(%d+):(.*)$")
                    if btn then
                        newBindings[#newBindings + 1] =
                            { mod = mod or "", btn = tonumber(btn), spell = spell or "" }
                    end
                elseif kind == "s" then
                    -- Old exports had separate scroll spells - convert to wheel bindings
                    local key, spell = rest:match("^([%u_]+):(.*)$")
                    if key then legacyScroll[key] = spell or "" end
                elseif kind == "a" then
                    local slot, buffs = rest:match("^(%d):(.*)$")
                    if slot then db.buffs[tonumber(slot)] = buffs or "" end
                end
            end
            for _, b in ipairs(BindingsFromLegacySpells(legacyScroll)) do
                if #newBindings < MAX_CLICK_BINDINGS then
                    newBindings[#newBindings + 1] = b
                end
            end
            db.bindings = newBindings
        else
            -- Legacy pipe format
            local parts = {}
            for part in (str .. "|"):gmatch("([^|]*)|") do
                parts[#parts + 1] = part
            end
            if #parts < 12 then
                print("|cff00ff00SimpleHeal:|r Invalid import string.")
                return
            end
            local OLD_ORDER
            local numSpells
            if #parts >= 16 then
                numSpells = 12
                OLD_ORDER = { "LEFT_CLICK", "RIGHT_CLICK", "SHIFT_LEFT", "SHIFT_RIGHT",
                    "CTRL_LEFT", "CTRL_RIGHT", "ALT_LEFT", "ALT_RIGHT",
                    "SCROLL_UP", "SCROLL_DOWN", "SHIFT_SCROLL_UP", "SHIFT_SCROLL_DOWN" }
            else
                numSpells = 8
                OLD_ORDER = { "LEFT_CLICK", "RIGHT_CLICK", "SHIFT_LEFT", "SHIFT_RIGHT",
                    "SCROLL_UP", "SCROLL_DOWN", "SHIFT_SCROLL_UP", "SHIFT_SCROLL_DOWN" }
            end
            local legacySpells = {}
            for i, key in ipairs(OLD_ORDER) do
                legacySpells[key] = parts[i] or ""
            end
            db.bindings = BindingsFromLegacySpells(legacySpells)
            for s = 1, 4 do
                db.buffs[s] = parts[numSpells + s] or ""
            end
        end

        p.RefreshBindingRows()
        for s = 1, 4 do
            p.buffBoxes[s]:SetText(db.buffs[s] or "")
        end
        ApplyBindings()
        UpdateCanCastBuffs()
        ieBox:SetText("")
        ieBox:ClearFocus()
        print("|cff00ff00SimpleHeal:|r Imported and applied!")
    end)

    ------------------------------------------------
    -- Save / Reset (bottom of panel, always visible)
    ------------------------------------------------
    local saveBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    saveBtn:SetSize(80, 24)
    saveBtn:SetPoint("BOTTOMLEFT", padX + 20, 14)
    saveBtn:SetText("Close")
    saveBtn:SetScript("OnClick", function()
        -- Everything already applies instantly - just commit any field
        -- that still has focus, then close
        for i, row in ipairs(p.bindingRows) do
            local b = db.bindings[i]
            if b and row:IsShown() then
                b.spell = row.eb:GetText() or ""
            end
        end
        for slot = 1, 4 do
            local text = p.buffBoxes[slot]:GetText()
            db.buffs[slot] = (text and text ~= "") and text or ""
        end

        p.saveCurrentToProfile()
        if not InCombatLockdown() then ApplyBindings() end
        UpdateCanCastBuffs()
        SavePosition()
        CloseDropDownMenus()
        p:Hide()

        -- Warn about spell names not found in the spellbook
        local unknown = {}
        local function CheckSpell(sp)
            if sp and sp ~= "" then
                local lower = sp:lower()
                if lower == "target" or lower == "menu" or sp:sub(1, 1) == "/" then return end
                local base = sp:match("^(.-)%s*%(") or sp  -- strip "(Rank X)"
                if not GetSpellInfo(base) then
                    unknown[#unknown + 1] = sp
                end
            end
        end
        for _, b in ipairs(db.bindings or {}) do CheckSpell(b.spell) end
        if #unknown > 0 then
            print("|cff00ff00SimpleHeal:|r |cffff5555Warning:|r these spells are not in your spellbook (typo or not learned yet): " .. table.concat(unknown, ", "))
        end
    end)

    local testBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    testBtn:SetSize(70, 24)
    testBtn:SetPoint("BOTTOM", 0, 14)
    testBtn:SetText("Test")
    testBtn:SetScript("OnClick", function() ToggleTestMode() end)
    AddTooltip(testBtn, "Test frames",
        "Shows 15 fake players so you can preview layout, size, texture and font without being in a group. Click again to exit.")

    local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetBtn:SetSize(100, 24)
    resetBtn:SetPoint("BOTTOMRIGHT", -padX - 10, 14)
    resetBtn:SetText("Reset spells")
    resetBtn:SetScript("OnClick", function()
        db.bindings = BindingsFromLegacySpells(DEFAULTS.spells)
        p.RefreshBindingRows()
        for slot = 1, 4 do
            p.buffBoxes[slot]:SetText("")
            db.buffs[slot] = ""
        end
        if not InCombatLockdown() then ApplyBindings() end
        UpdateCanCastBuffs()
        UIDropDownMenu_SetText(presetDrop, "-- Choose class/spec --")
    end)
    AddTooltip(resetBtn, "Reset spells",
        "Resets spell bindings and buff tracking to defaults. Layout and display settings are kept.")

    configPanel = p
end

local function ShowConfig()
    if not configPanel then CreateConfigPanel() end
    configPanel.RefreshBindingRows()
    for slot = 1, 4 do
        configPanel.buffBoxes[slot]:SetText(db.buffs[slot] or "")
    end
    -- Rebuild spellbook list for autocomplete
    RebuildSpellbookNames()
    -- Restore spec selection
    configPanel.selectedSpecTree = db.specTree or 0
    if (db.specTree or 0) == 0 then
        UIDropDownMenu_SetText(configPanel.specDrop, "Always Show")
    else
        local names = GetTreeNames()
        UIDropDownMenu_SetText(configPanel.specDrop, names[db.specTree] or ("Tree " .. db.specTree))
    end
    -- Restore size sliders
    configPanel.wSlider:SetValue(db.frameW)
    configPanel.hSlider:SetValue(db.frameH)
    configPanel.aSlider:SetValue(math.floor((db.frameAlpha or 1) * 100))
    configPanel.fSlider:SetValue(db.fontSize or 10)
    configPanel.iSlider:SetValue(db.iconSize or 10)
    configPanel.cbShowPets:SetChecked(db.showPets ~= false)
    UIDropDownMenu_SetText(configPanel.healthDrop, configPanel.HEALTH_MODES[db.hpTextMode or 1])
    configPanel.cbTitle:SetChecked(db.showTitle ~= false)
    configPanel.cbRoleIcons:SetChecked(db.roleIcons ~= false)
    configPanel.cbTwoLine:SetChecked(db.twoLineText or false)
    configPanel.cbTrackAll:SetChecked(db.trackAllBuffs or false)
    configPanel.cbExpireWarn:SetChecked(db.buffExpireWarn ~= false)
    configPanel.cbMana:SetChecked(db.showMana ~= false)
    configPanel.cbHots:SetChecked(db.showHots ~= false)
    configPanel.cbSmooth:SetChecked(db.smoothBars ~= false)
    configPanel.cbOOC:SetChecked(db.showOOC ~= false)
    configPanel.cbAggro:SetChecked(db.showAggro ~= false)
    configPanel.cbRoleLabels:SetChecked(db.showRoleLabels ~= false)
    configPanel.cbRangeFade:SetChecked(db.rangeFade ~= false)
    configPanel.cbMinimap:SetChecked(db.showMinimap ~= false)
    configPanel.cbPetsSep:SetChecked(db.petsSeparate or false)
    configPanel.cbLowHp:SetChecked(db.lowHpFlash ~= false)
    configPanel.cbGCD:SetChecked(db.showGCD ~= false)
    configPanel.rangeEb:SetText(db.rangeSpell or "")
    configPanel.cbHideTooltip:SetChecked(db.hideTooltip ~= false)
    configPanel.sSlider:SetValue(db.spacing or 2)
    for i = 1, 5 do
        local hk = db.hoverKeys and db.hoverKeys[i]
        configPanel.hoverRows[i].keyEb:SetText(hk and hk.key or "")
        configPanel.hoverRows[i].spellEb:SetText(hk and hk.spell or "")
    end
    configPanel.UpdateHoverRowVisibility()
    UIDropDownMenu_SetText(configPanel.autoPartyDrop, db.autoProfileParty or "None")
    UIDropDownMenu_SetText(configPanel.autoRaidDrop, db.autoProfileRaid or "None")
    UIDropDownMenu_SetText(configPanel.autoArenaDrop, db.autoProfileArena or "None")
    -- Restore checkboxes
    configPanel.cbLock:SetChecked(db.locked)
    configPanel.cbTarget:SetChecked(db.clickTarget)
    configPanel.cbHideBlizz:SetChecked(db.hideBlizzFrames or false)
    configPanel.cbGroupOnly:SetChecked(db.groupOnly or false)
    UIDropDownMenu_SetText(configPanel.profDrop, db.activeProfile or "Default")
    configPanel:Show()
end

----------------------------------------------
-- Container & drag handle
----------------------------------------------
local function CreateContainer()
    container = CreateFrame("Frame", "SimpleHealContainer", UIParent)
    container:SetPoint("CENTER", UIParent, "CENTER", -300, 0)
    container:SetSize(100, 300)
    container:SetMovable(true)
    container:SetClampedToScreen(true)

    local handle = CreateFrame("Frame", nil, container)
    handle:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 0)
    handle:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 0, 0)
    handle:SetHeight(14)
    handle:EnableMouse(true)
    container.handle = handle

    local hBg = handle:CreateTexture(nil, "BACKGROUND")
    hBg:SetAllPoints()
    hBg:SetColorTexture(0.15, 0.55, 0.15, 0.85)

    local hText = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hText:SetPoint("CENTER")
    hText:SetText("SimpleHeal")
    hText:SetTextColor(1, 1, 1)
    container.handleText = hText
    if db and db.showTitle == false then hText:Hide() end

    handle:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" and not db.locked then container:StartMoving() end
    end)
    handle:SetScript("OnMouseUp", function(_, btn)
        container:StopMovingOrSizing()
        if btn == "RightButton" then ShowConfig() end
    end)

    -- Role group labels
    container.roleLabels = {}
    local ROLE_LABEL_INFO = {
        { key = "TANK",    text = "TANKS",   r = 0.5, g = 0.5, b = 1.0 },
        { key = "HEALER",  text = "HEALERS", r = 0.2, g = 1.0, b = 0.2 },
        { key = "DAMAGER", text = "DPS",     r = 1.0, g = 0.3, b = 0.3 },
        { key = "PETS",    text = "PETS",    r = 0.7, g = 0.7, b = 0.7 },
    }
    for _, info in ipairs(ROLE_LABEL_INFO) do
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetTextColor(info.r, info.g, info.b)
        lbl:SetText(info.text)
        lbl:Hide()
        container.roleLabels[info.key] = lbl
    end
end

----------------------------------------------
-- Layout
----------------------------------------------
local LABEL_HEIGHT = 12
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }

Layout = function()
    if InCombatLockdown() then return end
    if testModeActive then
        LayoutTestFrames()
        return
    end
    for _, f in pairs(allFrames) do
        f:ClearAllPoints()
        f:Hide()
    end
    for _, lbl in pairs(container.roleLabels) do lbl:Hide() end

    local fw = db.frameW
    local fh = db.frameH
    local GAP = db.spacing or GAP

    for _, f in pairs(allFrames) do
        f:SetSize(fw, fh)
    end

    -- Collect units and their roles
    local roleGroups = { TANK = {}, HEALER = {}, DAMAGER = {} }

    local inRaid = IsInRaid and IsInRaid() or (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
    local totalMembers = GetNumGroupMembers and GetNumGroupMembers() or 0

    if inRaid and totalMembers > 0 then
        for i = 1, 40 do
            local name = GetRaidRosterInfo(i)
            if name then
                local unit = "raid" .. i
                local f = allFrames[unit]
                if f then
                    local role = GetUnitRole(unit)
                    roleGroups[role][#roleGroups[role] + 1] = f
                end
            end
        end
    else
        local numParty = 0
        if GetNumSubgroupMembers then
            numParty = GetNumSubgroupMembers()
        elseif GetNumPartyMembers then
            numParty = GetNumPartyMembers()
        elseif totalMembers > 1 then
            numParty = totalMembers - 1
        end

        local pf = allFrames["player"]
        if pf then
            local role = GetUnitRole("player")
            roleGroups[role][#roleGroups[role] + 1] = pf
        end
        for i = 1, numParty do
            local f = allFrames["party" .. i]
            if f then
                local role = GetUnitRole("party" .. i)
                roleGroups[role][#roleGroups[role] + 1] = f
            end
        end
    end

    local MAX_PER_COL = 5
    local petH = math.floor(fh * 0.6)
    local showPets = db.showPets ~= false
    local mode = db.layoutMode or 1  -- 1 = columns, 2 = rows, 3 = grid

    -- Returns pet frame for a unit's owner frame, or nil
    local function GetPetFrame(f)
        if not showPets then return nil end
        local petUnit = f.unit == "player" and "pet"
            or f.unit:match("^party(%d)$") and ("partypet" .. f.unit:match("^party(%d)$"))
            or f.unit:match("^raid(%d+)$") and ("raidpet" .. f.unit:match("^raid(%d+)$"))
        if petUnit then
            local petKey = petUnit == "pet" and "playerpet" or petUnit
            local pf = allFrames[petKey]
            if pf and UnitExists(petUnit) then return pf end
        end
        return nil
    end

    local showLabels = db.showRoleLabels ~= false
    local labelH = showLabels and LABEL_HEIGHT or 0
    local separatePets = showPets and db.petsSeparate

    -- Collect all pets (used when pets get their own column/row)
    local function CollectPets()
        local pets = {}
        for _, roleKey in ipairs(ROLE_ORDER) do
            for _, f in ipairs(roleGroups[roleKey]) do
                local pf = GetPetFrame(f)
                if pf then pets[#pets + 1] = pf end
            end
        end
        return pets
    end

    if mode == 1 then
        -- Columns: TANK | HEALER | DPS (splits at MAX_PER_COL)
        local col = 0
        local maxY = 0

        local function LayoutColumn(members, label, startCol, height)
            local c = startCol
            if showLabels then
                local lbl = container.roleLabels[label]
                lbl:SetPoint("TOPLEFT", container, "TOPLEFT", c * (fw + GAP), 0)
                lbl:Show()
            end

            local y = labelH
            local count = 0
            for _, f in ipairs(members) do
                if count >= MAX_PER_COL then
                    if y > maxY then maxY = y end
                    c = c + 1
                    y = labelH
                    count = 0
                end
                f:SetSize(fw, height or fh)
                f:SetPoint("TOPLEFT", container, "TOPLEFT", c * (fw + GAP), -y)
                f:Show()
                y = y + (height or fh) + GAP
                count = count + 1

                if not separatePets then
                    local pf = GetPetFrame(f)
                    if pf then
                        pf:SetSize(fw, petH)
                        pf:SetPoint("TOPLEFT", container, "TOPLEFT", c * (fw + GAP), -y)
                        pf:Show()
                        y = y + petH + GAP
                    end
                end
            end
            if y > maxY then maxY = y end
            return c + 1
        end

        for _, roleKey in ipairs(ROLE_ORDER) do
            local members = roleGroups[roleKey]
            if #members > 0 then
                col = LayoutColumn(members, roleKey, col)
            end
        end

        -- Pets in their own column to the right of DPS
        if separatePets then
            local pets = CollectPets()
            if #pets > 0 then
                col = LayoutColumn(pets, "PETS", col, petH)
            end
        end

        if col == 0 then col = 1 end
        if maxY == 0 then maxY = fh + LABEL_HEIGHT end
        container:SetSize(col * (fw + GAP) - GAP, maxY - GAP)

    elseif mode == 2 then
        -- Rows: one horizontal row per role (wraps at 8 per row)
        local MAX_PER_ROW = 8
        local y = 0
        local maxCols = 1

        for _, roleKey in ipairs(ROLE_ORDER) do
            local members = roleGroups[roleKey]
            if #members > 0 then
                if showLabels then
                    local lbl = container.roleLabels[roleKey]
                    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
                    lbl:Show()
                end
                y = y + labelH

                local x = 0
                local count = 0
                local rowHasPet = false
                for _, f in ipairs(members) do
                    if count >= MAX_PER_ROW then
                        y = y + fh + GAP + (rowHasPet and (petH + GAP) or 0)
                        x = 0
                        count = 0
                        rowHasPet = false
                    end
                    f:SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)
                    f:Show()

                    if not separatePets then
                        local pf = GetPetFrame(f)
                        if pf then
                            pf:SetSize(fw, petH)
                            pf:SetPoint("TOPLEFT", container, "TOPLEFT", x, -(y + fh + GAP))
                            pf:Show()
                            rowHasPet = true
                        end
                    end

                    x = x + fw + GAP
                    count = count + 1
                    if count > maxCols then maxCols = count end
                end
                y = y + fh + GAP + (rowHasPet and (petH + GAP) or 0)
            end
        end

        -- Pets in their own row at the bottom
        if separatePets then
            local pets = CollectPets()
            if #pets > 0 then
                if showLabels then
                    local lbl = container.roleLabels.PETS
                    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
                    lbl:Show()
                end
                y = y + labelH
                local x = 0
                local count = 0
                for _, pf in ipairs(pets) do
                    if count >= MAX_PER_ROW then
                        y = y + petH + GAP
                        x = 0
                        count = 0
                    end
                    pf:SetSize(fw, petH)
                    pf:SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)
                    pf:Show()
                    x = x + fw + GAP
                    count = count + 1
                    if count > maxCols then maxCols = count end
                end
                y = y + petH + GAP
            end
        end

        if y == 0 then y = fh + LABEL_HEIGHT end
        container:SetSize(maxCols * (fw + GAP) - GAP, y - GAP)

    else
        -- Grid: players grouped by raid subgroup, in stable raid-roster order
        -- (no re-sorting mid-fight). Mode 3 = groups as rows, mode 4 = groups as columns.
        local vertical = (mode == 4)
        local groups = {}
        local groupOrder = {}

        if inRaid and totalMembers > 0 then
            for i = 1, 40 do
                local rName, _, subgroup = GetRaidRosterInfo(i)
                if rName then
                    local f = allFrames["raid" .. i]
                    if f then
                        subgroup = subgroup or 1
                        if not groups[subgroup] then
                            groups[subgroup] = {}
                            groupOrder[#groupOrder + 1] = subgroup
                        end
                        table.insert(groups[subgroup], f)
                    end
                end
            end
            table.sort(groupOrder)
        else
            groups[1] = {}
            groupOrder[1] = 1
            if allFrames["player"] then table.insert(groups[1], allFrames["player"]) end
            for i = 1, 4 do
                local f = allFrames["party" .. i]
                if f and UnitExists("party" .. i) then
                    table.insert(groups[1], f)
                end
            end
        end

        local maxLen = 1
        for _, g in ipairs(groupOrder) do
            if #groups[g] > maxLen then maxLen = #groups[g] end
        end

        local line = 0  -- row index (mode 3) or column index (mode 4)
        for _, g in ipairs(groupOrder) do
            local pos = 0
            for _, f in ipairs(groups[g]) do
                local gx, gy
                if vertical then
                    gx = line * (fw + GAP)
                    gy = pos * (fh + GAP)
                else
                    gx = pos * (fw + GAP)
                    gy = line * (fh + GAP)
                end
                f:SetPoint("TOPLEFT", container, "TOPLEFT", gx, -gy)
                f:Show()
                pos = pos + 1
            end
            line = line + 1
        end

        -- Pets in their own row/column after the groups
        if showPets then
            local pets = CollectPets()
            if #pets > 0 then
                local pos = 0
                for _, pf in ipairs(pets) do
                    pf:SetSize(fw, petH)
                    local gx, gy
                    if vertical then
                        gx = line * (fw + GAP)
                        gy = pos * (petH + GAP)
                    else
                        gx = pos * (fw + GAP)
                        gy = line * (fh + GAP)
                    end
                    pf:SetPoint("TOPLEFT", container, "TOPLEFT", gx, -gy)
                    pf:Show()
                    pos = pos + 1
                end
                line = line + 1
            end
        end

        local lines = math.max(line, 1)
        if vertical then
            container:SetSize(lines * (fw + GAP) - GAP, maxLen * (fh + GAP) - GAP)
        else
            container:SetSize(maxLen * (fw + GAP) - GAP, lines * (fh + GAP) - GAP)
        end
    end
end

----------------------------------------------
-- Test mode (/sh test) - fake frames for layout/styling
----------------------------------------------
local testFrames = {}
local TEST_MAX_HP = 8000

local TEST_UNITS = {
    -- Tanks
    { name = "Shieldman",   class = "WARRIOR", role = "TANK",    hp = 0.40, hots = 2 },
    { name = "Bearford",    class = "DRUID",   role = "TANK",    hp = 0.65, hots = 2 },
    { name = "Palatank",    class = "PALADIN", role = "TANK",    hp = 0.85, hots = 1 },
    -- Healers
    { name = "Lightwell",   class = "PRIEST",  role = "HEALER",  hp = 1.00 },
    { name = "Chainheal",   class = "SHAMAN",  role = "HEALER",  hp = 0.92 },
    { name = "Treeform",    class = "DRUID",   role = "HEALER",  hp = 0.77 },
    { name = "Sealtwist",   class = "PALADIN", role = "HEALER",  hp = 0.50 },
    -- DPS
    { name = "Fireballs",   class = "MAGE",    role = "DAMAGER", hp = 0.55, hots = 1 },
    { name = "Backstabby",  class = "ROGUE",   role = "DAMAGER", hp = 0.30 },
    { name = "Dotmaster",   class = "WARLOCK", role = "DAMAGER", hp = 0.88, pet = "Impling" },
    { name = "Petlover",    class = "HUNTER",  role = "DAMAGER", hp = 0.70, pet = "Wolfie" },
    { name = "Windfury",    class = "SHAMAN",  role = "DAMAGER", hp = 0.45 },
    { name = "Moonfire",    class = "DRUID",   role = "DAMAGER", hp = 0.99 },
    { name = "Shadowmind",  class = "PRIEST",  role = "DAMAGER", hp = 0.60 },
    { name = "Arcaneblast", class = "MAGE",    role = "DAMAGER", hp = 0.25 },
}

local TEST_HOT_ICONS = {
    "Interface\\Icons\\Spell_Nature_Rejuvenation",
    "Interface\\Icons\\Spell_Nature_ResistNature",
}
local testPets = {}  -- [ownerIndex] = pet frame

local function UpdateTestDeficit(f)
    local hp = f.testHP
    local diff = math.floor(hp - TEST_MAX_HP)
    if diff < 0 then
        local pct = math.floor(hp / TEST_MAX_HP * 100 + 0.5)
        local hpMode = db.hpTextMode or 1
        if hpMode == 2 then
            f.deficit:SetText(pct .. "%")
        elseif hpMode == 3 then
            f.deficit:SetText(diff .. "  " .. pct .. "%")
        else
            f.deficit:SetText(diff)
        end
        f.deficit:SetTextColor(1, 1, 1)
    else
        f.deficit:SetText("")
    end
end

local function CreateTestFrames()
    if #testFrames > 0 then return end
    local barTex = GetBarTexture() or "Interface\\Buttons\\WHITE8X8"
    for i, tu in ipairs(TEST_UNITS) do
        local f = CreateFrame("Frame", nil, container)
        f:SetSize(db.frameW, db.frameH)

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

        local hp = CreateFrame("StatusBar", nil, f)
        hp:SetPoint("TOPLEFT", 1, -1)
        hp:SetPoint("BOTTOMRIGHT", -1, 1)
        hp:SetStatusBarTexture(barTex)
        hp:SetMinMaxValues(0, TEST_MAX_HP)
        hp:SetValue(tu.hp * TEST_MAX_HP)
        f.hp = hp
        f.testHP = tu.hp * TEST_MAX_HP

        local hpBg = hp:CreateTexture(nil, "BACKGROUND")
        hpBg:SetAllPoints()
        hpBg:SetColorTexture(0.1, 0.1, 0.1, 1)

        -- Role icon (tank/healer)
        local roleIcon = hp:CreateTexture(nil, "OVERLAY")
        roleIcon:SetSize(10, 10)
        roleIcon:SetPoint("LEFT", 3, 0)
        roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        if tu.role == "TANK" then
            roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64)
        elseif tu.role == "HEALER" then
            roleIcon:SetTexCoord(20/64, 39/64, 1/64, 20/64)
        else
            roleIcon:Hide()
        end
        f.roleIcon = roleIcon

        local nameFs = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFs:SetTextColor(1, 1, 1)
        nameFs:SetText(tu.name)
        f.name = nameFs

        local defFs = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.deficit = defFs
        f.testIndex = i

        -- Fake HoT icons with ticking timers
        if tu.hots then
            f.hots = {}
            for h = 1, tu.hots do
                local hot = CreateFrame("Frame", nil, f)
                hot:SetFrameLevel(f:GetFrameLevel() + 3)
                local icon = hot:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints()
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                icon:SetTexture(TEST_HOT_ICONS[h] or TEST_HOT_ICONS[1])
                local border = hot:CreateTexture(nil, "BACKGROUND")
                border:SetPoint("TOPLEFT", -1, 1)
                border:SetPoint("BOTTOMRIGHT", 1, -1)
                border:SetColorTexture(0, 0, 0, 0.8)
                local timer = hot:CreateFontString(nil, "OVERLAY")
                timer:SetFont(FONT_PATH, 7, "OUTLINE")
                timer:SetPoint("CENTER", 0, 0)
                timer:SetTextColor(1, 1, 1)
                hot.timer = timer
                hot.remaining = math.random(6, 18)
                f.hots[h] = hot
            end
        end

        f:Hide()
        testFrames[i] = f

        -- Fake pet frame
        if tu.pet then
            local pf = CreateFrame("Frame", nil, container)
            local pbg = pf:CreateTexture(nil, "BACKGROUND")
            pbg:SetAllPoints()
            pbg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
            local php = CreateFrame("StatusBar", nil, pf)
            php:SetPoint("TOPLEFT", 1, -1)
            php:SetPoint("BOTTOMRIGHT", -1, 1)
            php:SetStatusBarTexture(barTex)
            php:SetMinMaxValues(0, TEST_MAX_HP)
            php:SetValue(TEST_MAX_HP * 0.8)
            php:SetStatusBarColor(0.4, 0.7, 0.4)
            pf.hp = php
            local phpBg = php:CreateTexture(nil, "BACKGROUND")
            phpBg:SetAllPoints()
            phpBg:SetColorTexture(0.1, 0.1, 0.1, 1)
            local pName = php:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            pName:SetPoint("LEFT", 4, 0)
            pName:SetTextColor(0.8, 0.8, 0.8)
            pName:SetText(tu.pet)
            pf.name = pName
            pf.testHP = TEST_MAX_HP * 0.8
            pf:Hide()
            testPets[i] = pf
        end
    end
end

-- Simulated damage and healing while test mode is active
local testSim = CreateFrame("Frame")
testSim:Hide()
local testSimElapsed = 0
testSim:SetScript("OnUpdate", function(_, dt)
    testSimElapsed = testSimElapsed + dt
    if testSimElapsed < 0.6 then return end
    testSimElapsed = 0
    for i, f in ipairs(testFrames) do
        local r = math.random()
        if r < 0.40 then
            f.testHP = math.max(TEST_MAX_HP * 0.05, f.testHP - math.random(400, 1800))
        elseif r < 0.80 then
            f.testHP = math.min(TEST_MAX_HP, f.testHP + math.random(600, 2200))
        end
        SetHealthSmooth(f, f.testHP)
        UpdateTestDeficit(f)

        -- Tick fake HoT timers
        if f.hots then
            for _, hot in ipairs(f.hots) do
                hot.remaining = hot.remaining - 0.6
                if hot.remaining <= 0 then hot.remaining = math.random(8, 18) end
                hot.timer:SetText(math.floor(hot.remaining))
            end
        end
    end

    -- Pets take a little damage too
    for _, pf in pairs(testPets) do
        if pf:IsShown() then
            local r = math.random()
            if r < 0.30 then
                pf.testHP = math.max(TEST_MAX_HP * 0.2, pf.testHP - math.random(300, 900))
            elseif r < 0.70 then
                pf.testHP = math.min(TEST_MAX_HP, pf.testHP + math.random(400, 1200))
            end
            SetHealthSmooth(pf, pf.testHP)
        end
    end
end)

LayoutTestFrames = function()
    local fw, fh = db.frameW, db.frameH
    local GAP = db.spacing or GAP
    local petH = math.floor(fh * 0.6)
    local size = db.fontSize or 10
    local barTex = GetBarTexture() or "Interface\\Buttons\\WHITE8X8"
    local mode = db.layoutMode or 1
    local darkMode = (db.colorMode or 1) == 2
    local twoLine = db.twoLineText
    local showLabels = db.showRoleLabels ~= false and mode <= 2
    local labelH = showLabels and LABEL_HEIGHT or 0
    local roleIconsOn = db.roleIcons ~= false
    local showPets = db.showPets ~= false
    local separatePets = showPets and db.petsSeparate
    local inlinePets = showPets and not db.petsSeparate and mode <= 2
    local hotSize = db.iconSize or 10

    -- Style all frames
    for i, f in ipairs(testFrames) do
        local tu = TEST_UNITS[i]
        f:SetSize(fw, fh)
        f.hp:SetStatusBarTexture(barTex)
        local cc = RAID_CLASS_COLORS[tu.class]
        if darkMode then
            f.hp:SetStatusBarColor(0.25, 0.25, 0.25)
            f.name:SetTextColor(cc.r, cc.g, cc.b)
        else
            f.hp:SetStatusBarColor(cc.r, cc.g, cc.b)
            f.name:SetTextColor(1, 1, 1)
        end
        f.name:SetFont(FONT_PATH, size, "OUTLINE")
        f.deficit:SetFont(FONT_PATH, size, "OUTLINE")

        local showRole = roleIconsOn and (tu.role == "TANK" or tu.role == "HEALER")
        if showRole then f.roleIcon:Show() else f.roleIcon:Hide() end

        f.name:ClearAllPoints()
        f.deficit:ClearAllPoints()
        if twoLine then
            f.name:SetPoint("TOP", 0, -3)
            f.deficit:SetPoint("CENTER", 0, -4)
        else
            f.name:SetPoint("LEFT", showRole and 15 or 4, 0)
            f.deficit:SetPoint("RIGHT", -4, 0)
        end

        -- HoT icons
        if f.hots then
            for h, hot in ipairs(f.hots) do
                hot:SetSize(hotSize, hotSize)
                hot:ClearAllPoints()
                hot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", (h - 1) * (hotSize + 1) + 1, 1)
                hot.timer:SetFont(FONT_PATH, math.max(6, math.floor(hotSize * 0.7)), "OUTLINE")
                hot.timer:SetText(math.floor(hot.remaining))
                if db.showHots ~= false then hot:Show() else hot:Hide() end
            end
        end

        UpdateTestDeficit(f)
        f:SetAlpha(db.frameAlpha or 1)
        f:ClearAllPoints()
    end

    -- Style + reset pets
    for i, pf in pairs(testPets) do
        pf:SetSize(fw, petH)
        pf.hp:SetStatusBarTexture(barTex)
        pf.name:SetFont(FONT_PATH, size, "OUTLINE")
        pf:SetAlpha(db.frameAlpha or 1)
        pf:ClearAllPoints()
        pf:Hide()
    end

    local function PlacePetUnder(f, x, y)
        if not inlinePets then return 0 end
        local pet = testPets[f.testIndex]
        if not pet then return 0 end
        pet:SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)
        pet:Show()
        return petH + GAP
    end

    local function CollectTestPets()
        local pets = {}
        for i, tu in ipairs(TEST_UNITS) do
            if testPets[i] then pets[#pets + 1] = testPets[i] end
        end
        return pets
    end

    -- Group by role
    local roleGroups = { TANK = {}, HEALER = {}, DAMAGER = {} }
    for i, f in ipairs(testFrames) do
        local role = TEST_UNITS[i].role
        roleGroups[role][#roleGroups[role] + 1] = f
    end

    for _, lbl in pairs(container.roleLabels) do lbl:Hide() end

    if mode == 1 then
        -- Columns by role
        local MAX_PER_COL = 5
        local col = 0
        local maxY = 0
        for _, roleKey in ipairs(ROLE_ORDER) do
            local members = roleGroups[roleKey]
            if #members > 0 then
                if showLabels then
                    local lbl = container.roleLabels[roleKey]
                    lbl:ClearAllPoints()
                    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", col * (fw + GAP), 0)
                    lbl:Show()
                end
                local y = labelH
                local count = 0
                for _, f in ipairs(members) do
                    if count >= MAX_PER_COL then
                        if y > maxY then maxY = y end
                        col = col + 1
                        y = labelH
                        count = 0
                    end
                    f:SetPoint("TOPLEFT", container, "TOPLEFT", col * (fw + GAP), -y)
                    f:Show()
                    y = y + fh + GAP
                    y = y + PlacePetUnder(f, col * (fw + GAP), y)
                    count = count + 1
                end
                if y > maxY then maxY = y end
                col = col + 1
            end
        end

        -- Pets in their own column
        if separatePets then
            local pets = CollectTestPets()
            if #pets > 0 then
                if showLabels then
                    local lbl = container.roleLabels.PETS
                    lbl:ClearAllPoints()
                    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", col * (fw + GAP), 0)
                    lbl:Show()
                end
                local y = labelH
                for _, pf in ipairs(pets) do
                    pf:SetPoint("TOPLEFT", container, "TOPLEFT", col * (fw + GAP), -y)
                    pf:Show()
                    y = y + petH + GAP
                end
                if y > maxY then maxY = y end
                col = col + 1
            end
        end

        container:SetSize(math.max(col, 1) * (fw + GAP) - GAP, math.max(maxY, fh) - GAP)

    elseif mode == 2 then
        -- Rows by role
        local MAX_PER_ROW = 8
        local y = 0
        local maxCols = 1
        for _, roleKey in ipairs(ROLE_ORDER) do
            local members = roleGroups[roleKey]
            if #members > 0 then
                if showLabels then
                    local lbl = container.roleLabels[roleKey]
                    lbl:ClearAllPoints()
                    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
                    lbl:Show()
                end
                y = y + labelH
                local x = 0
                local count = 0
                local rowHasPet = false
                for _, f in ipairs(members) do
                    if count >= MAX_PER_ROW then
                        y = y + fh + GAP + (rowHasPet and (petH + GAP) or 0)
                        x = 0
                        count = 0
                        rowHasPet = false
                    end
                    f:SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)
                    f:Show()
                    if PlacePetUnder(f, x, y + fh + GAP) > 0 then rowHasPet = true end
                    x = x + fw + GAP
                    count = count + 1
                    if count > maxCols then maxCols = count end
                end
                y = y + fh + GAP + (rowHasPet and (petH + GAP) or 0)
            end
        end

        -- Pets in their own row
        if separatePets then
            local pets = CollectTestPets()
            if #pets > 0 then
                if showLabels then
                    local lbl = container.roleLabels.PETS
                    lbl:ClearAllPoints()
                    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
                    lbl:Show()
                end
                y = y + labelH
                local x = 0
                for _, pf in ipairs(pets) do
                    pf:SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)
                    pf:Show()
                    x = x + fw + GAP
                end
                y = y + petH + GAP
            end
        end

        container:SetSize(maxCols * (fw + GAP) - GAP, math.max(y - GAP, fh))

    else
        -- Grid: 3 fake subgroups of 5, as rows (mode 3) or columns (mode 4)
        local vertical = (mode == 4)
        local PER_GROUP = 5
        local line = 0
        local pos = 0
        for i, f in ipairs(testFrames) do
            if pos >= PER_GROUP then
                line = line + 1
                pos = 0
            end
            local gx, gy
            if vertical then
                gx = line * (fw + GAP)
                gy = pos * (fh + GAP)
            else
                gx = pos * (fw + GAP)
                gy = line * (fh + GAP)
            end
            f:SetPoint("TOPLEFT", container, "TOPLEFT", gx, -gy)
            f:Show()
            pos = pos + 1
        end
        line = line + 1

        if showPets then
            local pets = CollectTestPets()
            if #pets > 0 then
                local ppos = 0
                for _, pf in ipairs(pets) do
                    local gx, gy
                    if vertical then
                        gx = line * (fw + GAP)
                        gy = ppos * (petH + GAP)
                    else
                        gx = ppos * (fw + GAP)
                        gy = line * (fh + GAP)
                    end
                    pf:SetPoint("TOPLEFT", container, "TOPLEFT", gx, -gy)
                    pf:Show()
                    ppos = ppos + 1
                end
                line = line + 1
            end
        end

        if vertical then
            container:SetSize(line * (fw + GAP) - GAP, PER_GROUP * (fh + GAP) - GAP)
        else
            container:SetSize(PER_GROUP * (fw + GAP) - GAP, line * (fh + GAP) - GAP)
        end
    end
end

ToggleTestMode = function()
    if InCombatLockdown() then
        print("|cff00ff00SimpleHeal:|r Cannot toggle test mode in combat.")
        return
    end
    testModeActive = not testModeActive
    if testModeActive then
        CreateTestFrames()
        for _, f in pairs(allFrames) do
            f:ClearAllPoints()
            f:Hide()
        end
        for _, lbl in pairs(container.roleLabels) do lbl:Hide() end
        LayoutTestFrames()
        testSim:Show()
        print("|cff00ff00SimpleHeal:|r Test mode ON (simulating damage/heals) - /sh test to exit")
    else
        testSim:Hide()
        for _, f in ipairs(testFrames) do
            f:Hide()
            animFrames[f] = nil
        end
        for _, pf in pairs(testPets) do
            pf:Hide()
            animFrames[pf] = nil
        end
        for _, lbl in pairs(container.roleLabels) do lbl:Hide() end
        Layout()
        print("|cff00ff00SimpleHeal:|r Test mode OFF")
    end
end

----------------------------------------------
-- Save/restore position
----------------------------------------------
SavePosition = function()
    if not container then return end
    local point, _, relPoint, x, y = container:GetPoint()
    db.position = { point, relPoint, x, y }
end

local function RestorePosition()
    if db.position then
        container:ClearAllPoints()
        container:SetPoint(db.position[1], UIParent, db.position[2], db.position[3], db.position[4])
    end
end

----------------------------------------------
-- Minimap button
----------------------------------------------
local function CreateMinimapButton()
    local btn = CreateFrame("Button", "SimpleHealMinimapBtn", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(10)
    btn:Show()
    btn:SetMovable(true)
    btn:SetClampedToScreen(true)

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexture("Interface\\Icons\\Spell_Holy_FlashHeal")

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local function UpdatePosition(angle)
        local rad = math.rad(angle)
        local x = math.cos(rad) * 80
        local y = math.sin(rad) * 80
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    local angle = db.minimapAngle or 220
    UpdatePosition(angle)

    if db.showMinimap == false then btn:Hide() end

    local dragging = false
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function()
        dragging = true
    end)
    btn:SetScript("OnDragStop", function()
        dragging = false
    end)
    btn:SetScript("OnUpdate", function()
        if not dragging then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        angle = math.deg(math.atan2(cy - my, cx - mx))
        db.minimapAngle = angle
        btn:ClearAllPoints()
        UpdatePosition(angle)
    end)

    btn:SetScript("OnClick", function()
        ShowConfig()
    end)
    btn:RegisterForClicks("AnyUp")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("SimpleHeal")
        GameTooltip:AddLine("|cffffffffClick:|r Open settings", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

----------------------------------------------
-- Initialization
----------------------------------------------
-- Deep copy for settings tables
local function CopyDeep(src)
    local dst = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDeep(v)
        else
            dst[k] = v
        end
    end
    return dst
end

local function Init()
    if not SimpleHealDB then SimpleHealDB = {} end
    if not SimpleHealDB.chars then SimpleHealDB.chars = {} end

    -- Stash old account-wide settings in _legacy so EVERY character can inherit
    -- them (not just the first one to log in)
    if SimpleHealDB.spells then
        SimpleHealDB._legacy = SimpleHealDB._legacy or {}
        local keys = {}
        for k in pairs(SimpleHealDB) do
            if k ~= "chars" and k ~= "_legacy" then keys[#keys + 1] = k end
        end
        for _, k in ipairs(keys) do
            SimpleHealDB._legacy[k] = SimpleHealDB[k]
            SimpleHealDB[k] = nil
        end
    end

    -- Per-character settings
    local charKey = UnitName("player") .. "-" .. (GetRealmName() or "Realm")
    local cdb = SimpleHealDB.chars[charKey]
    if not cdb then
        if SimpleHealDB._legacy then
            -- New character on this account: inherit the pre-1.4 shared settings
            cdb = CopyDeep(SimpleHealDB._legacy)
            print("|cff00ff00SimpleHeal:|r Settings are now saved per character - your previous setup was inherited.")
        else
            cdb = {}
        end
        SimpleHealDB.chars[charKey] = cdb
    end

    if not cdb.spells then cdb.spells = {} end
    for k, v in pairs(DEFAULTS.spells) do
        if cdb.spells[k] == nil then
            cdb.spells[k] = v
        end
    end
    if not cdb.buffs then cdb.buffs = {} end
    for i = 1, 4 do
        if cdb.buffs[i] == nil then
            cdb.buffs[i] = DEFAULTS.buffs[i]
        end
    end
    if cdb.locked   == nil then cdb.locked   = DEFAULTS.locked end
    if cdb.frameW   == nil then cdb.frameW   = DEFAULTS.frameW end
    if cdb.frameH   == nil then cdb.frameH   = DEFAULTS.frameH end
    if cdb.specTree     == nil then cdb.specTree     = DEFAULTS.specTree end
    if cdb.minimapAngle == nil then cdb.minimapAngle = 220 end
    if cdb.clickTarget == nil then cdb.clickTarget = DEFAULTS.clickTarget end
    if cdb.hideBlizzFrames == nil then cdb.hideBlizzFrames = false end
    if cdb.groupOnly == nil then cdb.groupOnly = false end
    if cdb.frameAlpha == nil then cdb.frameAlpha = 1 end
    if cdb.barTexture == nil then cdb.barTexture = 1 end
    if cdb.layoutMode == nil then cdb.layoutMode = 1 end
    if cdb.showPets == nil then cdb.showPets = true end
    if cdb.fontSize == nil then cdb.fontSize = 10 end
    if cdb.colorMode == nil then cdb.colorMode = 1 end
    if cdb.hpPercent == nil then cdb.hpPercent = false end
    if cdb.showTitle == nil then cdb.showTitle = true end
    if cdb.iconSize == nil then cdb.iconSize = 10 end
    if cdb.roleIcons == nil then cdb.roleIcons = true end
    if cdb.twoLineText == nil then cdb.twoLineText = false end
    if cdb.trackAllBuffs == nil then cdb.trackAllBuffs = false end
    if cdb.buffExpireWarn == nil then cdb.buffExpireWarn = true end
    if cdb.showMana == nil then cdb.showMana = true end
    if cdb.showHots == nil then cdb.showHots = true end
    if cdb.showOOC == nil then cdb.showOOC = true end
    if cdb.smoothBars == nil then cdb.smoothBars = true end
    if cdb.rangeFade == nil then cdb.rangeFade = true end
    if cdb.showAggro == nil then cdb.showAggro = true end
    if cdb.showRoleLabels == nil then cdb.showRoleLabels = true end
    if cdb.showMinimap == nil then cdb.showMinimap = true end
    if cdb.petsSeparate == nil then cdb.petsSeparate = false end
    if cdb.hpTextMode == nil then
        cdb.hpTextMode = cdb.hpPercent and 2 or 1  -- migrate old checkbox
    end
    if cdb.spacing == nil then cdb.spacing = 2 end
    if cdb.lowHpFlash == nil then cdb.lowHpFlash = true end
    if cdb.showGCD == nil then cdb.showGCD = true end
    if not cdb.hoverKeys then cdb.hoverKeys = {} end
    if cdb.rangeSpell == nil then cdb.rangeSpell = "" end
    if cdb.hideTooltip == nil then cdb.hideTooltip = true end
    if not cdb.profiles then cdb.profiles = {} end
    if not cdb.activeProfile then cdb.activeProfile = "Default" end
    db = cdb

    -- Auto-apply class preset on first use + welcome message
    if not db.presetApplied then
        local _, cls = UnitClass("player")
        local presetName = cls and CLASS_PRESET[cls]
        if presetName then
            for _, p in ipairs(PRESETS) do
                if p.name == presetName then
                    for k, v in pairs(p.spells) do db.spells[k] = v end
                    for i = 1, 4 do db.buffs[i] = p.buffs[i] or "" end
                    break
                end
            end
        end
        db.presetApplied = true

        print("|cff00ff00SimpleHeal|r - Welcome! You are ready to heal:")
        if presetName then
            print("  |cffffd100" .. presetName .. "|r preset is active - click frames to heal")
        end
        print("  |cffffd100/sh|r - settings (spells, layout, size)")
        print("  |cffffd100/sh test|r - preview with 15 fake players")
        print("  Drag the handle above the frames to move them")
    end

    -- Migrate old fixed click keys to the flexible binding list
    if not db.bindings then
        db.bindings = BindingsFromLegacySpells(db.spells)
        if #db.bindings == 0 then
            db.bindings = { { mod = "", btn = 1, spell = "" } }
        end
        db.scrollMigrated = true  -- legacy map now includes scroll keys
    end

    -- One-time: move the old fixed scroll-wheel spells into the binding list
    if not db.scrollMigrated then
        db.scrollMigrated = true
        local SCROLL_MAP = {
            { "SCROLL_UP", "", 6 }, { "SCROLL_DOWN", "", 7 },
            { "SHIFT_SCROLL_UP", "shift", 6 }, { "SHIFT_SCROLL_DOWN", "shift", 7 },
        }
        for _, m in ipairs(SCROLL_MAP) do
            local sp = db.spells and db.spells[m[1]]
            if sp and sp ~= "" and #db.bindings < MAX_CLICK_BINDINGS then
                table.insert(db.bindings, { mod = m[2], btn = m[3], spell = sp })
            end
        end
    end

    local _, playerClass = UnitClass("player")
    canDispel = CLASS_DISPELS[playerClass] or {}

    CreateContainer()

    allFrames["player"] = MakeFrame("player", container)
    allFrames["playerpet"] = MakeFrame("pet", container)
    for i = 1, 4 do
        allFrames["party" .. i] = MakeFrame("party" .. i, container)
        allFrames["partypet" .. i] = MakeFrame("partypet" .. i, container)
    end
    for i = 1, 40 do
        allFrames["raid" .. i] = MakeFrame("raid" .. i, container)
        allFrames["raidpet" .. i] = MakeFrame("raidpet" .. i, container)
    end

    ApplyBindings()
    UpdateCanCastBuffs()
    ApplyFontSize()
    ApplyIconSize()
    ApplyTextLayout()
    RestorePosition()
    Layout()
    UpdateSpecVisibility()
    CreateMinimapButton()

    if db.locked then
        container.handle:Hide()
    end
end

----------------------------------------------
-- Tooltip suppression while hovering unit frames
----------------------------------------------
GameTooltip:HookScript("OnShow", function(self)
    if mouseOverFrame and db and db.hideTooltip ~= false then
        self:Hide()
    end
end)

----------------------------------------------
-- Events
----------------------------------------------
local ev = CreateFrame("Frame")
local function SafeReg(e) pcall(function() ev:RegisterEvent(e) end) end
SafeReg("ADDON_LOADED")
SafeReg("PLAYER_ENTERING_WORLD")
SafeReg("PLAYER_LOGOUT")
SafeReg("GROUP_ROSTER_UPDATE")
SafeReg("PARTY_MEMBERS_CHANGED")
SafeReg("RAID_ROSTER_UPDATE")
SafeReg("UNIT_HEALTH")
SafeReg("UNIT_MAXHEALTH")
SafeReg("UNIT_CONNECTION")
SafeReg("UNIT_NAME_UPDATE")
SafeReg("UNIT_AURA")
SafeReg("PLAYER_REGEN_ENABLED")
SafeReg("SPELLS_CHANGED")
SafeReg("CHARACTER_POINTS_CHANGED")
SafeReg("PLAYER_TALENT_UPDATE")
SafeReg("ACTIVE_TALENT_GROUP_CHANGED")
SafeReg("PLAYER_TARGET_CHANGED")
SafeReg("SPELL_UPDATE_COOLDOWN")
SafeReg("READY_CHECK")
SafeReg("READY_CHECK_CONFIRM")
SafeReg("READY_CHECK_FINISHED")

-- Unit events only need to refresh the affected unit's frame
local UNIT_EVENTS = {
    UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true,
    UNIT_CONNECTION = true,
    UNIT_NAME_UPDATE = true,
    UNIT_AURA = true,
}

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        Init()
        print("|cff00ff00SimpleHeal|r loaded - |cff88ff88/sh|r for settings")
        return
    end

    if not db then return end

    if event == "PLAYER_LOGOUT" then
        SavePosition()
        return
    end

    -- GCD sweep on the frame the player last cast from
    if event == "SPELL_UPDATE_COOLDOWN" then
        if db.showGCD ~= false and rangeSpellName
            and lastClickedFrame and lastClickedFrame:IsShown() then
            local start, dur = GetSpellCooldown(rangeSpellName)
            if start and dur and dur > 0 and dur <= 1.6 then
                lastClickedFrame.gcd:SetCooldown(start, dur)
            end
        end
        return
    end

    -- Fast path: unit event -> refresh only that unit's frame
    if UNIT_EVENTS[event] then
        if arg1 then
            local f = allFrames[arg1] or (arg1 == "pet" and allFrames["playerpet"])
            if f and f:IsShown() then Refresh(f) end
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then
            pendingApply = false
            ApplyBindings()
            print("|cff00ff00SimpleHeal:|r Spell bindings updated.")
        end
        if pendingSpecUpdate then
            pendingSpecUpdate = false
            UpdateSpecVisibility()
        end
        Layout()
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" then
        UpdateCanCastBuffs()
        UpdateSpecVisibility()
    end

    if event == "CHARACTER_POINTS_CHANGED"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        UpdateCanCastBuffs()
        UpdateSpecVisibility()
    end

    if event == "PLAYER_ENTERING_WORLD"
        or event == "GROUP_ROSTER_UPDATE"
        or event == "PARTY_MEMBERS_CHANGED"
        or event == "RAID_ROSTER_UPDATE" then
        AutoSwitchProfile()
        Layout()
        -- Blizzard frames re-show themselves on roster changes
        if db.hideBlizzFrames then
            SetBlizzardFrames(false)
        end
    end

    -- Ready check
    if event == "READY_CHECK" then
        for _, f in pairs(allFrames) do
            if UnitExists(f.unit) then
                f.readyIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
                f.readyIcon:Show()
            end
        end
    elseif event == "READY_CHECK_CONFIRM" then
        for _, f in pairs(allFrames) do
            if UnitExists(f.unit) then
                local ready = GetReadyCheckStatus(f.unit)
                if ready == "ready" then
                    f.readyIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                elseif ready == "notready" then
                    f.readyIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
                end
                f.readyIcon:Show()
            end
        end
    elseif event == "READY_CHECK_FINISHED" then
        C_Timer.After(3, function()
            for _, f in pairs(allFrames) do
                f.readyIcon:Hide()
            end
        end)
    end

    for _, f in pairs(allFrames) do
        if f:IsShown() then Refresh(f) end
    end
end)

ev:SetScript("OnUpdate", function(_, dt)
    if not db then return end
    elapsed = elapsed + dt
    if elapsed < UPDATE_HZ then return end
    elapsed = 0
    for _, f in pairs(allFrames) do
        if f:IsShown() then Refresh(f) end
    end
end)

----------------------------------------------
-- Slash commands
----------------------------------------------
SLASH_SIMPLEHEAL1 = "/simpleheal"
SLASH_SIMPLEHEAL2 = "/sh"
SlashCmdList["SIMPLEHEAL"] = function(msg)
    if not db then return end
    msg = (msg or ""):lower():trim()

    if msg == "lock" then
        db.locked = not db.locked
        if db.locked then
            container.handle:Hide()
            SavePosition()
            print("|cff00ff00SimpleHeal:|r Locked")
        else
            container.handle:Show()
            print("|cff00ff00SimpleHeal:|r Unlocked")
        end
    elseif msg == "reset" then
        container:ClearAllPoints()
        container:SetPoint("CENTER", UIParent, "CENTER", -300, 0)
        db.position = nil
        print("|cff00ff00SimpleHeal:|r Position reset")
    elseif msg == "blizzard" or msg == "blizz" then
        local shown = (CompactRaidFrameContainer and CompactRaidFrameContainer:IsShown())
            or (CompactPartyFrame and CompactPartyFrame:IsShown())
        SetBlizzardFrames(not shown)
        if not shown then
            print("|cff00ff00SimpleHeal:|r Blizzard raid frames shown")
        else
            print("|cff00ff00SimpleHeal:|r Blizzard raid frames hidden")
        end
    elseif msg == "target" then
        db.clickTarget = not db.clickTarget
        if db.clickTarget then
            print("|cff00ff00SimpleHeal:|r Click-to-target ON (click targets unit)")
        else
            print("|cff00ff00SimpleHeal:|r Click-to-target OFF (click casts spells)")
        end
        ApplyBindings()
    elseif msg == "test" then
        ToggleTestMode()
    elseif msg:match("^copy%s+%S") then
        local target = msg:match("^copy%s+(%S+)")
        local found
        for key in pairs(SimpleHealDB.chars or {}) do
            local nm = key:match("^(.-)%-")
            if nm and nm:lower() == target:lower() then found = key break end
        end
        if not found then
            print("|cff00ff00SimpleHeal:|r No saved settings found for '" .. target .. "'. Characters with settings:")
            for key in pairs(SimpleHealDB.chars or {}) do print("  " .. key) end
            return
        end
        local src = SimpleHealDB.chars[found]
        for k in pairs(db) do db[k] = nil end
        for k, v in pairs(src) do
            if type(v) == "table" then
                local copy = {}
                local function deep(s, d)
                    for k2, v2 in pairs(s) do
                        if type(v2) == "table" then d[k2] = {}; deep(v2, d[k2]) else d[k2] = v2 end
                    end
                end
                deep(v, copy)
                db[k] = copy
            else
                db[k] = v
            end
        end
        print("|cff00ff00SimpleHeal:|r Copied settings from " .. found .. ". Type /reload to apply.")
    elseif msg == "bind" then
        print("|cff00ff00SimpleHeal:|r Active bindings:")
        for i, b in ipairs(db.bindings or {}) do
            print(("  %d: [%s + %s] = '%s'"):format(i, MOD_LABELS[b.mod] or "?", BTN_LABELS[b.btn] or "?", b.spell or ""))
        end
        local f = allFrames["player"]
        if f then
            print("|cff00ff00SimpleHeal:|r Player frame attributes:")
            for _, mod in ipairs(MOD_OPTIONS) do
                local prefix = mod == "" and "" or (mod .. "-")
                for btn = 1, 5 do
                    local t = f:GetAttribute(prefix .. "type" .. btn)
                    if t then
                        local sp = f:GetAttribute(prefix .. "spell" .. btn) or f:GetAttribute(prefix .. "macrotext" .. btn) or ""
                        print(("  %stype%d = %s (%s)"):format(prefix, btn, t, tostring(sp):gsub("\n", " / ")))
                    end
                end
            end
        end
    elseif msg == "config" or msg == "settings" or msg == "" then
        ShowConfig()
    else
        print("|cff00ff00SimpleHeal:|r /sh - open settings")
        print("  /sh lock - toggle lock")
        print("  /sh target - toggle click-to-target")
        print("  /sh blizz - toggle Blizzard raid frames")
        print("  /sh test - toggle test frames (layout preview)")
        print("  /sh copy <name> - copy settings from another character")
        print("  /sh reset - reset position")
    end
end
