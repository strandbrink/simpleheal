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

local BINDINGS = {
    { key = "LEFT_CLICK",        label = "Left Click" },
    { key = "RIGHT_CLICK",       label = "Right Click" },
    { key = "SHIFT_LEFT",        label = "Shift + Left" },
    { key = "SHIFT_RIGHT",       label = "Shift + Right" },
    { key = "SCROLL_UP",         label = "Scroll Up" },
    { key = "SCROLL_DOWN",       label = "Scroll Down" },
    { key = "SHIFT_SCROLL_UP",   label = "Shift + Scroll Up" },
    { key = "SHIFT_SCROLL_DOWN", label = "Shift + Scroll Dn" },
}

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

local GAP         = 2
local OOR_ALPHA   = 0.4
local UPDATE_HZ   = 0.1
local BUFF_SIZE   = 7
local BUFF_GAP    = 1

local db
local allFrames   = {}
local container
local configPanel
local elapsed     = 0
local pendingApply = false
local canCastBuff  = {}  -- [slot] = true/false, cached on login/spec change

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

----------------------------------------------
-- Helpers
----------------------------------------------
local function Spell(key)
    local s = db.spells[key]
    if s and s ~= "" then return s end
    return nil
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
local function SetBlizzardFrames(show)
    if CompactRaidFrameContainer then
        if show then CompactRaidFrameContainer:Show() else CompactRaidFrameContainer:Hide() end
    end
    if CompactRaidFrameManager then
        if show then CompactRaidFrameManager:Show() else CompactRaidFrameManager:Hide() end
    end
    if CompactPartyFrame then
        if show then CompactPartyFrame:Show() else CompactPartyFrame:Hide() end
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
    if UnitGroupRolesAssigned then
        local role = UnitGroupRolesAssigned(unit)
        if role == "TANK" or role == "HEALER" or role == "DAMAGER" then return role end
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

-- Check if unit has any of the comma-separated buff names
local function HasBuff(unit, buffStr)
    if not buffStr or buffStr == "" then return true end

    -- Build lookup of wanted names
    local wanted = {}
    for name in buffStr:gmatch("[^,]+") do
        wanted[name:match("^%s*(.-)%s*$")] = true
    end

    for i = 1, 40 do
        local name = UnitBuff(unit, i)
        if not name then break end
        if wanted[name] then return true end
    end
    return false
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
    f.hp:SetValue(hp)

    local name = UnitName(unit) or ""
    if #name > 12 then name = name:sub(1, 12) end
    f.name:SetText(name)

    local isDead    = UnitIsDeadOrGhost(unit)
    local isOffline = not UnitIsConnected(unit)

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

    if isDead then
        f.hp:SetStatusBarColor(0.3, 0.3, 0.3)
        f.hp:SetValue(0)
        if hasRez then
            f.deficit:SetText("")
            f.statusText:SetText("REZ")
            f.statusText:SetTextColor(0.2, 1.0, 0.2)
            f.statusText:Show()
        else
            f.deficit:SetText("DEAD")
            f.deficit:SetTextColor(1, 0.2, 0.2)
            f.statusText:Hide()
        end
    elseif isOffline then
        f.hp:SetStatusBarColor(0.2, 0.2, 0.2)
        f.hp:SetValue(0)
        f.deficit:SetText("OFFLINE")
        f.deficit:SetTextColor(0.5, 0.5, 0.5)
        f.statusText:Hide()
    elseif isAFK then
        local r, g, b = ClassColor(unit)
        f.hp:SetStatusBarColor(r * 0.5, g * 0.5, b * 0.5)
        f.deficit:SetText("")
        f.statusText:SetText("AFK")
        f.statusText:SetTextColor(0.8, 0.8, 0.0)
        f.statusText:Show()
    else
        local r, g, b = ClassColor(unit)
        f.hp:SetStatusBarColor(r, g, b)
        local diff = hp - hpMax
        if diff < 0 then
            f.deficit:SetText(diff)
            f.deficit:SetTextColor(1, 1, 1)
        else
            f.deficit:SetText("")
        end
        f.statusText:Hide()
    end

    -- Range check
    local rangeSpell = Spell("LEFT_CLICK")
    if rangeSpell and IsSpellInRange(rangeSpell, unit) == 0 then
        f:SetAlpha(OOR_ALPHA)
    else
        f:SetAlpha(1)
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
                local r, g, b = ClassColor(unit)
                f.incHeal:SetVertexColor(r, g, b)
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
    local DEBUFF_TYPE_COLORS = {
        Poison  = { 0.0, 0.6, 0.0 },
        Curse   = { 0.6, 0.0, 0.6 },
        Magic   = { 0.2, 0.6, 1.0 },
        Disease = { 0.6, 0.4, 0.0 },
    }
    local debuffColor = nil
    local debuffTex = nil
    if not isDead and not isOffline then
        for i = 1, 40 do
            local dName, dIcon, _, dType = UnitDebuff(unit, i)
            if not dName then break end
            if dType and canDispel[dType] and DEBUFF_TYPE_COLORS[dType] then
                debuffColor = DEBUFF_TYPE_COLORS[dType]
                debuffTex = dIcon
                break
            end
        end
    end
    if debuffColor then
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
    end

    -- Mana bar
    if not isDead and not isOffline then
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
    if not isDead and not isOffline and UnitThreatSituation then
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

    -- Raid marker
    local raidIdx = GetRaidTargetIndex(unit)
    if raidIdx then
        local ICON_COORDS = {
            [1] = { 0,    0.25, 0,    0.25 },
            [2] = { 0.25, 0.5,  0,    0.25 },
            [3] = { 0.5,  0.75, 0,    0.25 },
            [4] = { 0.75, 1,    0,    0.25 },
            [5] = { 0,    0.25, 0.25, 0.5  },
            [6] = { 0.25, 0.5,  0.25, 0.5  },
            [7] = { 0.5,  0.75, 0.25, 0.5  },
            [8] = { 0.75, 1,    0.25, 0.5  },
        }
        local c = ICON_COORDS[raidIdx]
        if c then
            f.raidIcon:SetTexCoord(c[1], c[2], c[3], c[4])
            f.raidIcon:Show()
        else
            f.raidIcon:Hide()
        end
    else
        f.raidIcon:Hide()
    end

    -- Buff indicators (only for buffs the player can cast)
    for slot = 1, 4 do
        local ind = f.buffInd[slot]
        if not canCastBuff[slot] or isDead or isOffline then
            ind:Hide()
        elseif HasBuff(unit, db.buffs[slot]) then
            ind:Hide()
        else
            ind:Show()
        end
    end

    -- Buff/HoT tracking (player-cast buffs with a duration)
    local hotIdx = 0
    if not isDead and not isOffline then
        for i = 1, 40 do
            local bName, bIcon, bCount, _, bDur, bExp = UnitBuff(unit, i)
            if not bName then break end
            if bDur and bDur > 0 and bExp and GetSpellInfo(bName) then
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

    -- Missing Thorns text for tanks
    if f.thornsText then
        local isTank = GetUnitRole(unit) == "TANK"
        local knowsThorns = GetSpellInfo("Thorns") ~= nil
        local hasThorns = HasBuff(unit, "Thorns")
        if isTank and knowsThorns and not hasThorns and not isDead and not isOffline then
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

    for _, f in pairs(allFrames) do
        local u = f.unit

        local function SetBinding(typeAttr, spellAttr, macroAttr, key)
            local sp = Spell(key)
            if sp then
                if db.clickTarget then
                    f:SetAttribute(typeAttr, "macro")
                    f:SetAttribute(macroAttr, "/target " .. u .. "\n/cast [@" .. u .. "] " .. sp)
                    f:SetAttribute(spellAttr, nil)
                else
                    f:SetAttribute(typeAttr, "spell")
                    f:SetAttribute(spellAttr, sp)
                    f:SetAttribute(macroAttr, nil)
                end
            else
                if db.clickTarget and typeAttr == "type1" then
                    f:SetAttribute(typeAttr, "target")
                else
                    f:SetAttribute(typeAttr, nil)
                end
                f:SetAttribute(spellAttr, nil)
                f:SetAttribute(macroAttr, nil)
            end
        end

        SetBinding("type1", "spell1", "macrotext1", "LEFT_CLICK")
        if db.clickTarget then
            local rc = Spell("RIGHT_CLICK")
            if rc then
                f:SetAttribute("type2", "macro")
                f:SetAttribute("macrotext2", "/target " .. u .. "\n/cast [@" .. u .. "] " .. rc)
                f:SetAttribute("spell2", nil)
            else
                f:SetAttribute("type2", "togglemenu")
                f:SetAttribute("macrotext2", nil)
                f:SetAttribute("spell2", nil)
            end
        else
            SetBinding("type2", "spell2", "macrotext2", "RIGHT_CLICK")
        end
        SetBinding("shift-type1", "shift-spell1", "shift-macrotext1", "SHIFT_LEFT")
        SetBinding("shift-type2", "shift-spell2", "shift-macrotext2", "SHIFT_RIGHT")

        local function SetScrollBinding(btn, attr_type, attr_spell, key)
            local sp = Spell(key)
            if sp then
                btn:SetAttribute(attr_type, "spell")
                btn:SetAttribute(attr_spell, sp)
            else
                btn:SetAttribute(attr_type, nil)
                btn:SetAttribute(attr_spell, nil)
            end
        end

        SetScrollBinding(f.scrollUp, "type", "spell", "SCROLL_UP")
        SetScrollBinding(f.scrollUp, "shift-type", "shift-spell", "SHIFT_SCROLL_UP")
        SetScrollBinding(f.scrollDown, "type", "spell", "SCROLL_DOWN")
        SetScrollBinding(f.scrollDown, "shift-type", "shift-spell", "SHIFT_SCROLL_DOWN")
    end
end

----------------------------------------------
-- Unit frame creation
----------------------------------------------
local function MakeFrame(unit, parent)
    local fn = "SimpleHeal_" .. unit

    local f = CreateFrame("Button", fn, parent, "SecureUnitButtonTemplate")
    f:SetSize(db.frameW, db.frameH)
    f.unit = unit
    f:SetAttribute("unit", unit)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Background
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    -- Health bar
    local hp = CreateFrame("StatusBar", nil, f)
    hp:SetPoint("TOPLEFT", 1, -1)
    hp:SetPoint("BOTTOMRIGHT", -1, 1)
    hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hp:SetMinMaxValues(0, 1)
    hp:SetValue(1)
    f.hp = hp

    local hpBg = hp:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0.1, 0.1, 0.1, 1)

    -- Incoming heal bar (lighter overlay on health bar)
    local incHeal = hp:CreateTexture(nil, "ARTWORK", nil, 1)
    incHeal:SetPoint("TOP")
    incHeal:SetPoint("BOTTOM")
    incHeal:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
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

    -- Mana bar (thin bar at bottom of health bar)
    local mana = CreateFrame("StatusBar", nil, f)
    mana:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", 0, 0)
    mana:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", 0, 0)
    mana:SetHeight(3)
    mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
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
        local name = self.editBox:GetText()
        if not name or name == "" or name == "Default" then
            print("|cff00ff00SimpleHeal:|r Invalid profile name.")
            return
        end
        if not db.profiles then db.profiles = {} end
        db.profiles[name] = { spells = {}, buffs = {} }
        for k, v in pairs(db.spells) do db.profiles[name].spells[k] = v end
        for i = 1, 4 do db.profiles[name].buffs[i] = db.buffs[i] or "" end
        db.activeProfile = name
        if configPanel then configPanel.profBtnText:SetText(name) end
        print("|cff00ff00SimpleHeal:|r Saved profile: " .. name)
    end,
    OnShow = function(self)
        self.editBox:SetText(db.activeProfile or "")
        self.editBox:HighlightText()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

----------------------------------------------
-- Config panel
----------------------------------------------
local Layout, SavePosition
local function CreateConfigPanel()
    local panelW  = 340
    local rowH    = 28
    local padX    = 12
    local padTop  = 122    -- after preset + spec + profile rows
    local spellRows = #BINDINGS * rowH
    local buffTop = padTop + spellRows + 24
    local buffRows = 4 * rowH
    local panelH  = buffTop + buffRows + 216

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
    -- Preset dropdown
    ------------------------------------------------
    local presetLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    presetLabel:SetPoint("TOPLEFT", padX, -32)
    presetLabel:SetText("Preset:")

    local presetBtn = CreateFrame("Button", "SimpleHealPresetBtn", p)
    presetBtn:SetSize(200, 22)
    presetBtn:SetPoint("LEFT", presetLabel, "RIGHT", 8, 0)

    local presetBtnBg = presetBtn:CreateTexture(nil, "BACKGROUND")
    presetBtnBg:SetAllPoints()
    presetBtnBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    local presetBtnText = presetBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    presetBtnText:SetPoint("LEFT", 6, 0)
    presetBtnText:SetText("-- Choose class/spec --")
    presetBtnText:SetJustifyH("LEFT")
    presetBtn.text = presetBtnText

    local presetArrow = presetBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    presetArrow:SetPoint("RIGHT", -6, 0)
    presetArrow:SetText("v")

    local dropdown = CreateFrame("Frame", "SimpleHealPresetDropdown", presetBtn, "BackdropTemplate")
    dropdown:SetPoint("TOPLEFT", presetBtn, "BOTTOMLEFT", 0, -2)
    dropdown:SetSize(200, #PRESETS * 20 + 6)
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:Hide()

    dropdown:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    local function FillFromPreset(preset)
        for _, binding in ipairs(BINDINGS) do
            p.editBoxes[binding.key]:SetText(preset.spells[binding.key] or "")
        end
        for slot = 1, 4 do
            p.buffBoxes[slot]:SetText(preset.buffs and preset.buffs[slot] or "")
        end
        presetBtnText:SetText(preset.name)
        dropdown:Hide()
    end

    for i, preset in ipairs(PRESETS) do
        local item = CreateFrame("Button", nil, dropdown)
        item:SetSize(194, 20)
        item:SetPoint("TOPLEFT", 3, -3 - (i - 1) * 20)

        local itemHl = item:CreateTexture(nil, "HIGHLIGHT")
        itemHl:SetAllPoints()
        itemHl:SetColorTexture(0.3, 0.6, 0.3, 0.4)

        local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        itemText:SetPoint("LEFT", 6, 0)
        itemText:SetText(preset.name)

        item:SetScript("OnClick", function() FillFromPreset(preset) end)
    end

    presetBtn:SetScript("OnClick", function()
        if dropdown:IsShown() then dropdown:Hide() else dropdown:Show() end
    end)

    ------------------------------------------------
    -- Spec filter dropdown
    ------------------------------------------------
    local specLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    specLabel:SetPoint("TOPLEFT", padX, -58)
    specLabel:SetText("Show only for:")

    local specBtn = CreateFrame("Button", "SimpleHealSpecBtn", p)
    specBtn:SetSize(170, 22)
    specBtn:SetPoint("LEFT", specLabel, "RIGHT", 8, 0)

    local specBtnBg = specBtn:CreateTexture(nil, "BACKGROUND")
    specBtnBg:SetAllPoints()
    specBtnBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    local specBtnText = specBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    specBtnText:SetPoint("LEFT", 6, 0)
    specBtnText:SetJustifyH("LEFT")
    p.specBtnText = specBtnText

    local specArrow = specBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    specArrow:SetPoint("RIGHT", -6, 0)
    specArrow:SetText("v")

    local specDrop = CreateFrame("Frame", "SimpleHealSpecDropdown", specBtn, "BackdropTemplate")
    specDrop:SetPoint("TOPLEFT", specBtn, "BOTTOMLEFT", 0, -2)
    specDrop:SetSize(170, 4 * 20 + 6)
    specDrop:SetFrameStrata("TOOLTIP")
    specDrop:Hide()

    specDrop:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    p.selectedSpecTree = 0

    -- "Always Show" option
    local alwaysItem = CreateFrame("Button", nil, specDrop)
    alwaysItem:SetSize(164, 20)
    alwaysItem:SetPoint("TOPLEFT", 3, -3)
    local alwaysHl = alwaysItem:CreateTexture(nil, "HIGHLIGHT")
    alwaysHl:SetAllPoints()
    alwaysHl:SetColorTexture(0.3, 0.6, 0.3, 0.4)
    local alwaysText = alwaysItem:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    alwaysText:SetPoint("LEFT", 6, 0)
    alwaysText:SetText("Always Show")
    alwaysItem:SetScript("OnClick", function()
        p.selectedSpecTree = 0
        specBtnText:SetText("Always Show")
        specDrop:Hide()
    end)

    -- Tree 1, 2, 3 options (filled dynamically on show)
    p.specTreeItems = {}
    for t = 1, 3 do
        local item = CreateFrame("Button", nil, specDrop)
        item:SetSize(164, 20)
        item:SetPoint("TOPLEFT", 3, -3 - t * 20)
        local hl = item:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.3, 0.6, 0.3, 0.4)
        local txt = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", 6, 0)
        txt:SetText("Tree " .. t)
        item.label = txt
        item:SetScript("OnClick", function()
            p.selectedSpecTree = t
            specBtnText:SetText(txt:GetText())
            specDrop:Hide()
        end)
        p.specTreeItems[t] = item
    end

    specBtn:SetScript("OnClick", function()
        if specDrop:IsShown() then
            specDrop:Hide()
        else
            -- Update tree names from talent info
            local names = GetTreeNames()
            for t = 1, 3 do
                if names[t] then
                    p.specTreeItems[t].label:SetText(names[t])
                    p.specTreeItems[t]:Show()
                else
                    p.specTreeItems[t]:Hide()
                end
            end
            specDrop:Show()
        end
    end)

    ------------------------------------------------
    -- Profile row
    ------------------------------------------------
    local profLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    profLabel:SetPoint("TOPLEFT", padX, -84)
    profLabel:SetText("Profile:")

    local profBtn = CreateFrame("Button", "SimpleHealProfBtn", p)
    profBtn:SetSize(130, 22)
    profBtn:SetPoint("LEFT", profLabel, "RIGHT", 8, 0)
    local profBtnBg = profBtn:CreateTexture(nil, "BACKGROUND")
    profBtnBg:SetAllPoints()
    profBtnBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    local profBtnText = profBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profBtnText:SetPoint("LEFT", 6, 0)
    profBtnText:SetJustifyH("LEFT")
    profBtnText:SetText(db.activeProfile or "Default")
    p.profBtnText = profBtnText
    local profArrow = profBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profArrow:SetPoint("RIGHT", -6, 0)
    profArrow:SetText("v")

    local profDrop = CreateFrame("Frame", "SimpleHealProfDropdown", profBtn, "BackdropTemplate")
    profDrop:SetPoint("TOPLEFT", profBtn, "BOTTOMLEFT", 0, -2)
    profDrop:SetSize(130, 26)
    profDrop:SetFrameStrata("TOOLTIP")
    profDrop:Hide()
    profDrop:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    p.profDrop = profDrop

    local function RefreshProfDropdown()
        for _, child in ipairs({ profDrop:GetChildren() }) do child:Hide() end
        if not db.profiles then db.profiles = {} end
        local names = {}
        for name in pairs(db.profiles) do names[#names + 1] = name end
        table.sort(names)
        table.insert(names, 1, "Default")
        profDrop:SetSize(130, #names * 20 + 6)
        for i, name in ipairs(names) do
            local item = CreateFrame("Button", nil, profDrop)
            item:SetSize(124, 20)
            item:SetPoint("TOPLEFT", 3, -3 - (i - 1) * 20)
            local hl = item:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.3, 0.6, 0.3, 0.4)
            local txt = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", 6, 0)
            txt:SetText(name)
            item:SetScript("OnClick", function()
                profDrop:Hide()
                if name == db.activeProfile then return end
                -- Save current to old profile before switching
                p.saveCurrentToProfile()
                -- Load new profile
                if name == "Default" then
                    db.activeProfile = "Default"
                    -- Keep current spells/buffs (they are the defaults)
                else
                    local prof = db.profiles[name]
                    if prof then
                        for k, v in pairs(prof.spells) do db.spells[k] = v end
                        for i2 = 1, 4 do db.buffs[i2] = prof.buffs[i2] or "" end
                    end
                    db.activeProfile = name
                end
                profBtnText:SetText(name)
                -- Refresh UI
                for _, binding in ipairs(BINDINGS) do
                    p.editBoxes[binding.key]:SetText(db.spells[binding.key] or "")
                end
                for s = 1, 4 do
                    p.buffBoxes[s]:SetText(db.buffs[s] or "")
                end
                ApplyBindings()
                UpdateCanCastBuffs()
                print("|cff00ff00SimpleHeal:|r Loaded profile: " .. name)
            end)
        end
    end
    p.RefreshProfDropdown = RefreshProfDropdown

    profBtn:SetScript("OnClick", function()
        if profDrop:IsShown() then profDrop:Hide() else RefreshProfDropdown(); profDrop:Show() end
    end)

    -- Save As button
    local profSaveBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    profSaveBtn:SetSize(50, 20)
    profSaveBtn:SetPoint("LEFT", profBtn, "RIGHT", 4, 0)
    profSaveBtn:SetText("Save")
    profSaveBtn:SetScript("OnClick", function()
        StaticPopup_Show("SIMPLEHEAL_SAVE_PROFILE")
    end)

    -- Delete button
    local profDelBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    profDelBtn:SetSize(50, 20)
    profDelBtn:SetPoint("LEFT", profSaveBtn, "RIGHT", 2, 0)
    profDelBtn:SetText("Del")
    profDelBtn:SetScript("OnClick", function()
        local name = db.activeProfile or "Default"
        if name == "Default" then
            print("|cff00ff00SimpleHeal:|r Cannot delete Default profile.")
            return
        end
        if db.profiles then db.profiles[name] = nil end
        db.activeProfile = "Default"
        profBtnText:SetText("Default")
        print("|cff00ff00SimpleHeal:|r Deleted profile: " .. name)
    end)

    -- Undo button
    local profUndoBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    profUndoBtn:SetSize(50, 20)
    profUndoBtn:SetPoint("LEFT", profDelBtn, "RIGHT", 2, 0)
    profUndoBtn:SetText("Undo")
    p.profUndoBtn = profUndoBtn

    -- Save current spells/buffs to the active profile
    p.saveCurrentToProfile = function()
        local name = db.activeProfile or "Default"
        if name == "Default" then return end
        if not db.profiles then db.profiles = {} end
        db.profiles[name] = {
            spells = {},
            buffs = {},
        }
        for k, v in pairs(db.spells) do db.profiles[name].spells[k] = v end
        for i2 = 1, 4 do db.profiles[name].buffs[i2] = db.buffs[i2] or "" end
    end

    -- Undo snapshot
    p.undoSnapshot = nil
    p.takeSnapshot = function()
        p.undoSnapshot = { spells = {}, buffs = {} }
        for k, v in pairs(db.spells) do p.undoSnapshot.spells[k] = v end
        for i2 = 1, 4 do p.undoSnapshot.buffs[i2] = db.buffs[i2] or "" end
    end

    profUndoBtn:SetScript("OnClick", function()
        if not p.undoSnapshot then
            print("|cff00ff00SimpleHeal:|r Nothing to undo.")
            return
        end
        for k, v in pairs(p.undoSnapshot.spells) do db.spells[k] = v end
        for i2 = 1, 4 do db.buffs[i2] = p.undoSnapshot.buffs[i2] or "" end
        for _, binding in ipairs(BINDINGS) do
            p.editBoxes[binding.key]:SetText(db.spells[binding.key] or "")
        end
        for s = 1, 4 do
            p.buffBoxes[s]:SetText(db.buffs[s] or "")
        end
        ApplyBindings()
        UpdateCanCastBuffs()
        p.undoSnapshot = nil
        print("|cff00ff00SimpleHeal:|r Reverted to previous spells.")
    end)

    ------------------------------------------------
    -- Spell section header
    ------------------------------------------------
    local spellHeader = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellHeader:SetPoint("TOPLEFT", padX, -108)
    spellHeader:SetText("Spell Bindings")
    spellHeader:SetTextColor(1, 0.82, 0)

    ------------------------------------------------
    -- Spell edit rows
    ------------------------------------------------
    p.editBoxes = {}

    for i, binding in ipairs(BINDINGS) do
        local y = -padTop - (i - 1) * rowH

        local label = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", padX, y)
        label:SetWidth(120)
        label:SetJustifyH("RIGHT")
        label:SetText(binding.label)

        local eb = CreateFrame("EditBox", "SimpleHealEB" .. i, p, "InputBoxTemplate")
        eb:SetSize(170, 20)
        eb:SetPoint("TOPLEFT", padX + 128, y + 2)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(40)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

        p.editBoxes[binding.key] = eb
    end

    ------------------------------------------------
    -- Buff tracking section
    ------------------------------------------------
    local buffHeader = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buffHeader:SetPoint("TOPLEFT", padX, -buffTop + 20)
    buffHeader:SetText("Missing Buff Alerts")
    buffHeader:SetTextColor(1, 0.82, 0)

    local buffHint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    buffHint:SetPoint("TOPLEFT", buffHeader, "TOPRIGHT", 6, 0)
    buffHint:SetText("(comma = OR, e.g. MotW, GotW)")

    p.buffBoxes = {}

    for slot = 1, 4 do
        local y = -buffTop - (slot - 1) * rowH

        local colorSwatch = p:CreateTexture(nil, "OVERLAY")
        colorSwatch:SetSize(12, 12)
        colorSwatch:SetPoint("TOPLEFT", padX + 4, y + 1)
        local c = BUFF_COLORS[slot]
        colorSwatch:SetColorTexture(c[1], c[2], c[3], 1)

        local label = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", colorSwatch, "RIGHT", 4, 0)
        label:SetText("Buff " .. slot .. ":")

        local eb = CreateFrame("EditBox", "SimpleHealBuff" .. slot, p, "InputBoxTemplate")
        eb:SetSize(210, 20)
        eb:SetPoint("TOPLEFT", padX + 88, y + 2)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(80)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

        p.buffBoxes[slot] = eb
    end

    ------------------------------------------------
    -- Frame size sliders
    ------------------------------------------------
    local sliderTop = -buffTop - 4 * rowH - 10

    local function MakeSlider(name, minV, maxV, step, x, y, width)
        local s = CreateFrame("Slider", "SimpleHeal" .. name .. "Slider", p, "OptionsSliderTemplate")
        s:SetSize(width, 14)
        s:SetPoint("TOPLEFT", x, y)
        s:SetMinMaxValues(minV, maxV)
        s:SetValueStep(step)
        s:SetObeyStepOnDrag(true)
        s.Text = s.Text or _G[s:GetName() .. "Text"]
        s.Low = s.Low or _G[s:GetName() .. "Low"]
        s.High = s.High or _G[s:GetName() .. "High"]
        if s.Low then s.Low:SetText(minV) end
        if s.High then s.High:SetText(maxV) end
        return s
    end

    local sizeHeader = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeHeader:SetPoint("TOPLEFT", padX, sliderTop + 20)
    sizeHeader:SetText("Frame Size")
    sizeHeader:SetTextColor(1, 0.82, 0)

    local wSlider = MakeSlider("Width", 50, 200, 5, padX, sliderTop - 8, 130)
    wSlider:SetValue(db.frameW)
    if wSlider.Text then wSlider.Text:SetText("Width: " .. db.frameW) end
    wSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        if self.Text then self.Text:SetText("Width: " .. val) end
    end)
    p.wSlider = wSlider

    local hSlider = MakeSlider("Height", 16, 80, 2, padX + 170, sliderTop - 8, 130)
    hSlider:SetValue(db.frameH)
    if hSlider.Text then hSlider.Text:SetText("Height: " .. db.frameH) end
    hSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        if self.Text then self.Text:SetText("Height: " .. val) end
    end)
    p.hSlider = hSlider

    ------------------------------------------------
    -- Checkboxes
    ------------------------------------------------
    local cbTop = sliderTop - 40

    local function MakeCheckbox(label, x, y)
        local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", x, y)
        local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        text:SetText(label)
        cb.label = text
        return cb
    end

    local optHeader = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", padX, cbTop + 20)
    optHeader:SetText("Options")
    optHeader:SetTextColor(1, 0.82, 0)

    local cbLock = MakeCheckbox("Lock position", padX, cbTop - 4)
    cbLock:SetChecked(db.locked)
    p.cbLock = cbLock

    local cbTarget = MakeCheckbox("Click-to-target (no spells)", padX, cbTop - 28)
    cbTarget:SetChecked(db.clickTarget)
    p.cbTarget = cbTarget

    local cbHideBlizz = MakeCheckbox("Hide Blizzard raid frames", padX, cbTop - 52)
    cbHideBlizz:SetChecked(db.hideBlizzFrames or false)
    p.cbHideBlizz = cbHideBlizz

    local cbGroupOnly = MakeCheckbox("Only show in group/raid", padX, cbTop - 76)
    cbGroupOnly:SetChecked(db.groupOnly or false)
    p.cbGroupOnly = cbGroupOnly

    ------------------------------------------------
    -- Buttons
    ------------------------------------------------
    local saveBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    saveBtn:SetSize(100, 24)
    saveBtn:SetPoint("BOTTOMLEFT", padX + 40, 14)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        p.takeSnapshot()
        for _, binding in ipairs(BINDINGS) do
            local text = p.editBoxes[binding.key]:GetText()
            db.spells[binding.key] = (text and text ~= "") and text or ""
        end
        for slot = 1, 4 do
            local text = p.buffBoxes[slot]:GetText()
            db.buffs[slot] = (text and text ~= "") and text or ""
        end
        db.specTree = p.selectedSpecTree
        db.frameW = math.floor(p.wSlider:GetValue())
        db.frameH = math.floor(p.hSlider:GetValue())

        db.locked = p.cbLock:GetChecked() and true or false
        if db.locked then container.handle:Hide() else container.handle:Show() end

        db.clickTarget = p.cbTarget:GetChecked() and true or false

        db.hideBlizzFrames = p.cbHideBlizz:GetChecked() and true or false
        if db.hideBlizzFrames then
            SetBlizzardFrames(false)
        else
            SetBlizzardFrames(true)
        end

        db.groupOnly = p.cbGroupOnly:GetChecked() and true or false

        p.saveCurrentToProfile()
        ApplyBindings()
        UpdateCanCastBuffs()
        UpdateSpecVisibility()
        Layout()
        SavePosition()
        dropdown:Hide()
        specDrop:Hide()
        profDrop:Hide()
        p:Hide()
        print("|cff00ff00SimpleHeal:|r Settings saved!")
    end)

    local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetBtn:SetSize(100, 24)
    resetBtn:SetPoint("BOTTOMRIGHT", -padX - 40, 14)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        for _, binding in ipairs(BINDINGS) do
            p.editBoxes[binding.key]:SetText(DEFAULTS.spells[binding.key] or "")
        end
        for slot = 1, 4 do
            p.buffBoxes[slot]:SetText("")
        end
        p.selectedSpecTree = 0
        specBtnText:SetText("Always Show")
        presetBtnText:SetText("-- Choose class/spec --")
    end)

    configPanel = p
end

local function ShowConfig()
    if not configPanel then CreateConfigPanel() end
    for _, binding in ipairs(BINDINGS) do
        configPanel.editBoxes[binding.key]:SetText(db.spells[binding.key] or "")
    end
    for slot = 1, 4 do
        configPanel.buffBoxes[slot]:SetText(db.buffs[slot] or "")
    end
    -- Restore spec selection
    configPanel.selectedSpecTree = db.specTree or 0
    if db.specTree == 0 then
        configPanel.specBtnText:SetText("Always Show")
    else
        local names = GetTreeNames()
        configPanel.specBtnText:SetText(names[db.specTree] or ("Tree " .. db.specTree))
    end
    -- Restore size sliders
    configPanel.wSlider:SetValue(db.frameW)
    configPanel.hSlider:SetValue(db.frameH)
    -- Restore checkboxes
    configPanel.cbLock:SetChecked(db.locked)
    configPanel.cbTarget:SetChecked(db.clickTarget)
    configPanel.cbHideBlizz:SetChecked(db.hideBlizzFrames or false)
    configPanel.cbGroupOnly:SetChecked(db.groupOnly or false)
    configPanel.profBtnText:SetText(db.activeProfile or "Default")
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
    for _, f in pairs(allFrames) do
        f:ClearAllPoints()
        f:Hide()
    end
    for _, lbl in pairs(container.roleLabels) do lbl:Hide() end

    local fw = db.frameW
    local fh = db.frameH

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

    -- Layout as columns: TANK | HEALER | DPS
    local petH = math.floor(fh * 0.6)
    local col = 0
    local maxY = 0
    for _, roleKey in ipairs(ROLE_ORDER) do
        local members = roleGroups[roleKey]
        if #members > 0 then
            local lbl = container.roleLabels[roleKey]
            lbl:SetPoint("TOPLEFT", container, "TOPLEFT",
                col * (fw + GAP), 0)
            lbl:Show()

            local y = LABEL_HEIGHT
            for _, f in ipairs(members) do
                f:SetPoint("TOPLEFT", container, "TOPLEFT",
                    col * (fw + GAP), -y)
                f:Show()
                y = y + fh + GAP

                -- Show pet below owner
                local petUnit = f.unit == "pet" and "pet"
                    or f.unit:match("^party(%d)$") and ("partypet" .. f.unit:match("^party(%d)$"))
                    or f.unit:match("^raid(%d+)$") and ("raidpet" .. f.unit:match("^raid(%d+)$"))
                if petUnit then
                    local petKey = petUnit == "pet" and "playerpet" or petUnit
                    local pf = allFrames[petKey]
                    if pf and UnitExists(petUnit) then
                        pf:SetSize(fw, petH)
                        pf:SetPoint("TOPLEFT", container, "TOPLEFT",
                            col * (fw + GAP), -y)
                        pf:Show()
                        y = y + petH + GAP
                    end
                end

                if y > maxY then maxY = y end
            end
            col = col + 1
        end
    end

    if col == 0 then col = 1 end
    if maxY == 0 then maxY = fh + LABEL_HEIGHT end
    container:SetSize(
        col * (fw + GAP) - GAP,
        maxY - GAP)
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
    btn:SetFrameLevel(8)
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
    btn:RegisterForClicks("LeftButtonUp")

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
local function Init()
    if not SimpleHealDB then SimpleHealDB = {} end
    if not SimpleHealDB.spells then SimpleHealDB.spells = {} end
    for k, v in pairs(DEFAULTS.spells) do
        if SimpleHealDB.spells[k] == nil then
            SimpleHealDB.spells[k] = v
        end
    end
    if not SimpleHealDB.buffs then SimpleHealDB.buffs = {} end
    for i = 1, 4 do
        if SimpleHealDB.buffs[i] == nil then
            SimpleHealDB.buffs[i] = DEFAULTS.buffs[i]
        end
    end
    if SimpleHealDB.locked   == nil then SimpleHealDB.locked   = DEFAULTS.locked end
    if SimpleHealDB.frameW   == nil then SimpleHealDB.frameW   = DEFAULTS.frameW end
    if SimpleHealDB.frameH   == nil then SimpleHealDB.frameH   = DEFAULTS.frameH end
    if SimpleHealDB.specTree     == nil then SimpleHealDB.specTree     = DEFAULTS.specTree end
    if SimpleHealDB.minimapAngle == nil then SimpleHealDB.minimapAngle = 220 end
    if SimpleHealDB.clickTarget == nil then SimpleHealDB.clickTarget = DEFAULTS.clickTarget end
    if SimpleHealDB.hideBlizzFrames == nil then SimpleHealDB.hideBlizzFrames = false end
    if SimpleHealDB.groupOnly == nil then SimpleHealDB.groupOnly = false end
    if not SimpleHealDB.profiles then SimpleHealDB.profiles = {} end
    if not SimpleHealDB.activeProfile then SimpleHealDB.activeProfile = "Default" end
    db = SimpleHealDB

    -- Auto-apply class preset on first use
    if not db.presetApplied then
        local _, cls = UnitClass("player")
        local presetName = cls and CLASS_PRESET[cls]
        if presetName then
            for _, p in ipairs(PRESETS) do
                if p.name == presetName then
                    for k, v in pairs(p.spells) do db.spells[k] = v end
                    for i = 1, 4 do db.buffs[i] = p.buffs[i] or "" end
                    print("|cff00ff00SimpleHeal:|r Auto-selected preset: " .. presetName)
                    break
                end
            end
        end
        db.presetApplied = true
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
    RestorePosition()
    Layout()
    UpdateSpecVisibility()
    CreateMinimapButton()

    if db.locked then
        container.handle:Hide()
    end
end

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
SafeReg("READY_CHECK")
SafeReg("READY_CHECK_CONFIRM")
SafeReg("READY_CHECK_FINISHED")

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
        Layout()
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
    elseif msg == "config" or msg == "settings" or msg == "" then
        ShowConfig()
    else
        print("|cff00ff00SimpleHeal:|r /sh - open settings")
        print("  /sh lock - toggle lock")
        print("  /sh target - toggle click-to-target")
        print("  /sh blizz - toggle Blizzard raid frames")
        print("  /sh reset - reset position")
    end
end
