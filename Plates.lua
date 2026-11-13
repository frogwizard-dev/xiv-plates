local _, ns = ...

-- FFXIV-style enemy nameplates in XIVTarget's look (FrogLib's Gauge): the name centred on its own row,
-- level and health under the gauge's ends (or over: belowBar), the cast a thinner line underneath; your
-- target stands out, the others dim. FrogLib's Plates engine takes the plates over (Blizzard's cast bar and
-- debuffs kept and moved round ours, as FrogPlates does); values secret in combat only go to widgets.

local Plates = {}
ns.Plates = Plates

local Engine = FrogLib.Plates
local Combo = FrogLib.Combo
local combo -- your combo points: one row, on your target's plate (rogues; druids in cat form)
local Color, Unit, Icons = FrogLib.Color, FrogLib.Unit, FrogLib.Icons
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon" -- the yellow "!"
-- Rares and elites: Blizzard's own nameplate icons (a silver star for a rare, a silver dragon for a
-- rare elite, a gold one for an elite or a boss).
local RANK = {
    rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star",
    rareelite = "nameplates-icon-elite-silver",
    elite = "nameplates-icon-elite-gold",
    worldboss = "nameplates-icon-elite-gold",
}

-- "reaction": plain hostile red / neutral yellow, tapped grey, players in their class colour.
local REACTION = {
    tapped = { r = 0.55, g = 0.55, b = 0.55 }, class = true,
    hostile = { r = 0.90, g = 0.32, b = 0.25 }, neutral = { r = 0.95, g = 0.85, b = 0.35 },
    friendly = { r = 0.95, g = 0.85, b = 0.35 }, fallback = { r = 0.90, g = 0.32, b = 0.25 },
}

-- The text "by hostility" (textColor "reaction"): hostile red, neutral yellow, a little lighter
-- than the gauge's so it reads over the world; tapped grey comes first (see Tapped).
local HOSTILITY = {
    hostile = { r = 1, g = 0.45, b = 0.38 }, neutral = { r = 1, g = 0.9, b = 0.45 },
    friendly = { r = 0.55, g = 0.9, b = 0.55 }, fallback = { r = 1, g = 0.45, b = 0.38 },
}

-- Someone else got the first hit (tapGrey): its loot and credit aren't yours. May be secret in
-- combat; then it isn't grey.
local function Tapped(unit)
    return ns.db.tapGrey and FrogLib.Safe(UnitIsTapDenied(unit)) == true
end

-- Tapped grey first, then threat (while you're on its list and threat colours are on), then
-- FFXIV's colours or the plain reaction ones.
local function Colour(unit)
    local db = ns.db
    if Tapped(unit) then
        local tapped = db.colors.tapped
        return tapped.r, tapped.g, tapped.b
    end
    if db.threat then
        local r, g, b = Engine.ThreatColour(unit, db.colors, db.role)
        if r then return r, g, b end
    end
    if db.colorMode == "xiv" then return Color.XIVUnit(unit) end
    return Color.Unit(unit, REACTION)
end

-- How far above the gauge the text over it sits.
local function Lift(db) return db.style == "framed" and 4 or 2 end
-- Each text's size (db.texts[key].size; 0: the shared size, the cast's for the cast's texts)
-- and its nudge (x right, y up).
local function Size(db, key)
    local size = db.texts[key].size
    if size and size > 0 then return size end
    return (key == "castName" or key == "castTime") and db.castTextSize or db.textSize
end
local function Nudge(db, key)
    local settings = db.texts[key]
    return settings.x or 0, settings.y or 0
end
-- The name's row, and the level and health's (the taller of the two).
local function NameRow(db) return Size(db, "name") + 4 end
local function DetailRow(db) return math.max(Size(db, "left"), Size(db, "right")) + 4 end
-- How far the text over the gauge reaches: the name's row, and the level and health's unless
-- they're under it.
local function TextOver(db)
    return (db.nameRow and NameRow(db) or 0) + (db.belowBar and 0 or DetailRow(db))
end
-- Your combo points sit right under your target's gauge: this much room there, 0 elsewhere.
local function ComboRoom(plate) return plate and plate.comboRoom or 0 end
-- How far under the gauge the cast line starts: past the combo points, and the level and health
-- when they're there.
local function CastDrop(db, plate)
    return db.castGap + ComboRoom(plate) + (db.belowBar and (Lift(db) + DetailRow(db)) or 0)
end

local function Text(parent, justify)
    local text = FrogLib.Text.Shadowed(parent)
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    return text
end

------------------------------------------------------------------------------
-- Building (plate: the engine's frame over Blizzard's, with plate.base and plate.slot)
------------------------------------------------------------------------------

local function Create(plate)
    local gauge = FrogLib.Gauge.New(plate)
    plate.gauge, plate.bar = gauge, gauge.bar
    -- Execute range: the fill again in the execute colour, over it (see UpdateExecute).
    plate.execute = gauge.bar:CreateTexture(nil, "ARTWORK", nil, 6)
    plate.execute:Hide()
    local words = CreateFrame("Frame", nil, plate)
    words:SetAllPoints(gauge.bar)
    words:SetFrameLevel(gauge.bar:GetFrameLevel() + 4)
    plate.name = Text(words, "CENTER")
    plate.left = Text(words, "LEFT")
    plate.right = Text(words, "RIGHT")
    plate.threat = Text(words, "LEFT")
    -- The raid mark: an icon written into text, since which mark it is can be secret in combat.
    plate.mark = words:CreateFontString(nil, "OVERLAY")
    plate.mark:SetFont(STANDARD_TEXT_FONT, 12, "")
    plate.mark:Hide()
    plate.quest = words:CreateTexture(nil, "OVERLAY")
    plate.quest:SetTexture(QUEST_ICON)
    plate.quest:Hide()
    plate.rank = words:CreateTexture(nil, "OVERLAY")
    plate.rank:Hide()
    -- Your target: gold chevrons either side of the gauge, as FFXIV links a target.
    plate.chevronLeft = Text(words, "RIGHT")
    plate.chevronLeft:SetText(">")
    plate.chevronRight = Text(words, "LEFT")
    plate.chevronRight:SetText("<")
    plate.chevronLeft:Hide()
    plate.chevronRight:Hide()
end

------------------------------------------------------------------------------
-- Casts: Blizzard's cast bar thinned to a line under the gauge (its border, icon and target name out of
-- sight, spell name and time under its ends in our font). Casts you can't interrupt: our fill over
-- Blizzard's in their colour, following Blizzard's own "can't interrupt" state (the engine passes it on).
------------------------------------------------------------------------------

local casts = {} -- Blizzard cast bar -> our fill over it

local function CastFill(cast)
    local fill = casts[cast]
    if not fill then
        fill = cast:CreateTexture(nil, "ARTWORK", nil, 7)
        fill:SetAlpha(0)
        casts[cast] = fill
    end
    return fill
end

function Plates:CastShield(_, cast, shown, ours)
    local db = ns.db
    local on = ours and db.enabled and db.castBar
    if cast.BorderShield then cast.BorderShield:SetAlpha(on and 0 or 1) end
    Engine.AlphaFrom(CastFill(cast), shown, on and db.castColor)
end

local function LayoutCast(plate, db)
    local unitFrame = plate.uf
    local cast = Engine.BlizzardCast(unitFrame)
    if not cast then return end
    cast:SetIgnoreParentAlpha(db.castBar)
    if not db.castBar then return end
    local scale = db.scale or 1
    cast:ClearAllPoints()
    cast:SetPoint("TOPLEFT", plate.bar, "BOTTOMLEFT", 0, -CastDrop(db, plate) * scale)
    cast:SetPoint("TOPRIGHT", plate.bar, "BOTTOMRIGHT", 0, -CastDrop(db, plate) * scale)
    cast:SetHeight(db.castHeight * scale)
    for _, key in ipairs(Engine.CAST_EXTRAS) do
        if cast[key] then cast[key]:SetAlpha(0) end
    end
    if cast.Icon then cast.Icon:SetAlpha(0) end
    if cast.Text then
        local x, y = Nudge(db, "castName")
        ns.Media:SetFont(cast.Text, db.font, Size(db, "castName") * scale, db.outline)
        cast.Text:ClearAllPoints()
        cast.Text:SetPoint("TOPRIGHT", cast, "BOTTOMRIGHT", x * scale, (y - 2) * scale)
        cast.Text:SetJustifyH("RIGHT")
    end
    local time = Engine.CastParts(cast).time
    if time then
        time:SetShown(db.castTime and true or false)
        local x, y = Nudge(db, "castTime")
        ns.Media:SetFont(time, db.font, Size(db, "castTime") * scale, db.outline)
        time:ClearAllPoints()
        time:SetPoint("TOPLEFT", cast, "BOTTOMLEFT", x * scale, (y - 2) * scale)
    end
    local color = db.colors.uninterruptible
    local fill = CastFill(cast)
    Engine.OverFill(fill, cast)
    fill:SetTexture(FrogLib.Media.Usable(db.texture) and db.texture or "Interface\\Buttons\\WHITE8X8")
    fill:SetVertexColor(color.r, color.g, color.b)
    -- The last shield state Blizzard set, put back now the plate is ours. It may be secret, so
    -- it's only handed on, never tested ("seen and last or false" would test it).
    local parts = Engine.CastParts(cast)
    if parts.seen then
        Plates:CastShield(unitFrame, cast, parts.last, true)
    else
        Plates:CastShield(unitFrame, cast, false, true)
    end
end

------------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------------

function Plates:Layout(plate)
    local db = ns.db
    Engine.PlaceSlot(plate)
    local gauge, bar = plate.gauge, plate.bar
    gauge:SetStyle(db.style)
    gauge:SetHeight(db.height + (plate.isTarget and 1 or 0)) -- your target's a pixel thicker
    gauge:SetTexture(db.texture)
    bar:ClearAllPoints()
    if db.width > 0 then
        bar:SetPoint("CENTER", plate.slot, "CENTER")
        bar:SetWidth(db.width)
    else
        bar:SetPoint("LEFT", plate.slot, "LEFT")
        bar:SetPoint("RIGHT", plate.slot, "RIGHT")
    end
    Engine.OverFill(plate.execute, bar)
    plate.execute:SetTexture(db.texture)
    local execute = db.colors.execute
    plate.execute:SetVertexColor(execute.r, execute.g, execute.b)
    -- The game dims a plate whose enemy is behind terrain or far off; without gameFade ours keeps
    -- its own opacity, like the cast bar and debuffs do.
    plate:SetIgnoreParentAlpha(not db.gameFade)

    for _, key in ipairs({ "name", "left", "right", "threat" }) do
        ns.Media:SetFont(plate[key], db.font, Size(db, key), db.outline)
    end
    local targetColor = db.colors.target
    for _, chevron in ipairs({ plate.chevronLeft, plate.chevronRight }) do
        ns.Media:SetFont(chevron, db.font, db.textSize + 2, db.outline)
        chevron:SetTextColor(targetColor.r, targetColor.g, targetColor.b)
    end
    local lift = Lift(db)
    plate.right:ClearAllPoints()
    local rightX, rightY = Nudge(db, "right")
    if db.belowBar then
        plate.right:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -1 + rightX, -lift - ComboRoom(plate) + rightY)
    else
        plate.right:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -1 + rightX, lift + rightY)
    end
    plate.chevronLeft:ClearAllPoints()
    plate.chevronLeft:SetPoint("RIGHT", bar, "LEFT", -4, 0)
    plate.chevronRight:ClearAllPoints()
    plate.chevronRight:SetPoint("LEFT", bar, "RIGHT", 4, 0)
    plate.mark:ClearAllPoints()
    plate.mark:SetPoint("RIGHT", bar, "LEFT", -4 - db.textSize, 0)
    -- The rare / elite icon: right after the name on its own row; otherwise before the gauge,
    -- past the raid mark.
    plate.rank:SetSize(db.rankSize, db.rankSize)
    plate.rank:ClearAllPoints()
    if db.nameRow then
        plate.rank:SetPoint("LEFT", plate.name, "RIGHT", 2, 0)
    else
        plate.rank:SetPoint("RIGHT", bar, "LEFT", -8 - db.textSize - (db.raidMarks and db.markSize or 0), 0)
    end
    plate.threat:ClearAllPoints()
    local threatX, threatY = Nudge(db, "threat")
    plate.threat:SetPoint("LEFT", bar, "RIGHT", 6 + db.textSize + threatX, threatY)
    self:UpdateQuest(plate)

    LayoutCast(plate, db)
    -- Your debuffs over the name, crowd control past the gauge's right end.
    local scale = db.scale or 1
    local over = lift + TextOver(db) + 2
    Engine.PlaceAuras(plate.uf, bar, db.auras and true or false, over * scale, false, (8 + db.textSize) * scale)
end

------------------------------------------------------------------------------
-- Filling it in
------------------------------------------------------------------------------

local textOptions = {}

function Plates:UpdateText(plate)
    local db = ns.db
    textOptions.levelColor = db.levelColor
    textOptions.classColor = true
    Unit.SetText(plate.name, db.nameRow and db.text.name or "", plate.unit, textOptions)
    Unit.SetText(plate.left, db.text.left, plate.unit, textOptions)
    Unit.SetText(plate.right, db.text.right, plate.unit, textOptions)
end

function Plates:UpdateHealth(plate)
    plate.gauge:SetValues(UnitHealth(plate.unit), UnitHealthMax(plate.unit), not ns.db.smooth)
    self:UpdateText(plate)
    self:UpdateExecute(plate)
end

function Plates:UpdateExecute(plate)
    local below = ns.db.execute and Engine.ExecuteBelow()
    if not below then
        plate.execute:Hide()
        return
    end
    plate.execute:SetAlpha(Engine.ExecuteAlpha(plate.unit, below))
    plate.execute:Show()
end

-- The gauge's colour, and the text in a light version of it as FFXIV prints it, by hostility
-- (whatever the gauge shows for threat), or white. Your target's text in the target colour.
function Plates:UpdateColour(plate)
    local r, g, b = Colour(plate.unit)
    if not r then r, g, b = 0.9, 0.32, 0.25 end
    plate.gauge:SetColor(r, g, b)
    local db = ns.db
    local textR, textG, textB = 1, 1, 1
    if plate.isTarget and db.targetText then
        local target = db.colors.target
        textR, textG, textB = target.r, target.g, target.b
    elseif db.textColor == "reaction" then
        if Tapped(plate.unit) then
            textR, textG, textB = Color.Lighten(r, g, b, 0.3)
        else
            textR, textG, textB = Color.Unit(plate.unit, HOSTILITY)
        end
    elseif db.textColor == "gauge" then
        textR, textG, textB = Color.Lighten(r, g, b, 0.55)
    end
    plate.name:SetTextColor(textR, textG, textB)
    plate.left:SetTextColor(textR, textG, textB)
    plate.right:SetTextColor(textR, textG, textB)
end

function Plates:UpdateThreat(plate)
    local db = ns.db
    local shown = db.threatText and Engine.ThreatText(plate.threat, plate.unit, db.colors)
    plate.threat:SetShown(shown and true or false)
end

function Plates:UpdateMark(plate)
    local db = ns.db
    plate.mark:SetShown(db.raidMarks and Icons.RaidMark(plate.mark, plate.unit, db.markSize) or false)
end

-- The rare / elite icon (rankIcon: "rare" rares and rare elites, "all" elites too, "off").
function Plates:UpdateRank(plate)
    local mode = ns.db.rankIcon
    local classification = mode ~= "off" and plate.unit and FrogLib.Safe(UnitClassification(plate.unit))
    local atlas = classification and RANK[classification]
    if mode == "rare" and (classification == "elite" or classification == "worldboss") then atlas = nil end
    if atlas then plate.rank:SetAtlas(atlas) end
    plate.rank:SetShown(atlas ~= nil)
end

-- A "!" before the level and name when your quests still need this enemy. The level and name sit
-- on their own row above the health (nameRow), as long as they need to be, or beside it.
function Plates:UpdateQuest(plate)
    local db = ns.db
    local shown = plate.unit and db.questMarker and Engine.OnQuest(plate.unit) or false
    local size = Size(db, db.nameRow and "name" or "left") + 4
    local tuck = math.floor(size * 0.3 + 0.5)                     -- how far the "!" tucks under the text
    local shift = shown and math.floor(size * 0.45 + 0.5) or 0    -- the left text moved over for it
    plate.quest:SetSize(size, size)
    plate.quest:SetShown(shown)
    local lift = Lift(db)
    plate.quest:ClearAllPoints()
    plate.left:ClearAllPoints()
    plate.name:ClearAllPoints()
    local leftX, leftY = Nudge(db, "left")
    if db.nameRow then
        -- The name centred over the gauge (a row up when the level and health are over it too),
        -- as wide as it needs, the "!" right before it.
        local nameX, nameY = Nudge(db, "name")
        local up = lift + (db.belowBar and 0 or DetailRow(db))
        plate.name:SetPoint("BOTTOM", plate.bar, "TOP", (shown and math.floor(size * 0.25 + 0.5) or 0) + nameX, up + nameY)
        plate.quest:SetPoint("RIGHT", plate.name, "LEFT", tuck, 0)
        if db.belowBar then
            plate.left:SetPoint("TOPLEFT", plate.bar, "BOTTOMLEFT", 1 + leftX, -lift - ComboRoom(plate) + leftY)
        else
            plate.left:SetPoint("BOTTOMLEFT", plate.bar, "TOPLEFT", 1 + leftX, lift + leftY)
        end
    elseif db.belowBar then
        plate.quest:SetPoint("TOPLEFT", plate.bar, "BOTTOMLEFT", -tuck + leftX, -lift - ComboRoom(plate) + 2 + leftY)
        plate.left:SetPoint("TOPLEFT", plate.bar, "BOTTOMLEFT", shift + 1 + leftX, -lift - ComboRoom(plate) + leftY)
    else
        plate.quest:SetPoint("BOTTOMLEFT", plate.bar, "TOPLEFT", -tuck + leftX, lift - 2 + leftY)
        plate.left:SetPoint("BOTTOMLEFT", plate.bar, "TOPLEFT", shift + 1 + leftX, lift + leftY)
    end
    plate.left:SetPoint("RIGHT", plate.right, "LEFT", -4, 0)
end

function Plates:UpdateTarget()
    local db = ns.db
    local target = C_NamePlate.GetNamePlateForUnit("target")
    Engine.Each(function(plate)
        local isTarget = target == plate.base
        plate.isTarget = isTarget
        -- Your target's gauge a pixel thicker.
        plate.gauge:SetHeight(db.height + (isTarget and 1 or 0))
        plate.chevronLeft:SetShown(isTarget and db.chevrons)
        plate.chevronRight:SetShown(isTarget and db.chevrons)
        plate:SetScale((isTarget and db.targetScale or 1) * (db.scale or 1))
        plate:SetAlpha((target and not isTarget) and db.otherAlpha or 1)
        self:UpdateColour(plate)
    end)
    self:PlaceCombo()
end

------------------------------------------------------------------------------
-- Your combo points: a row of small gauges in the plate's style (FrogLib's Combo, as XIVTarget's)
-- right under your target's gauge, the level, health and cast moving down to make room on that
-- plate. While you have none they're see-through (hideEmpty), the room kept, so nothing jumps.
------------------------------------------------------------------------------

function Plates:PlaceCombo()
    if not combo then return end
    local db, cfg = ns.db, ns.db.combo
    local target = C_NamePlate.GetNamePlateForUnit("target")
    local here
    Engine.Each(function(plate)
        if plate.base == target then here = plate end
    end)
    local shown = (cfg.enabled and here and db.enabled and combo:Refresh(false)) and true or false
    if not shown then combo.holder:Hide() end
    -- The room: on your target's plate only, and only while the points show.
    local room = shown and (cfg.gap + cfg.height) or 0
    Engine.Each(function(plate)
        local want = (plate == here) and room or 0
        if (plate.comboRoom or 0) ~= want then
            plate.comboRoom = want
            self:Layout(plate)
        end
    end)
    if not shown then return end
    local holder = combo.holder
    holder:SetParent(here)
    holder:SetFrameLevel(here.bar:GetFrameLevel() + 2)
    local width = db.width > 0 and db.width or math.max(20, here.bar:GetWidth() or 0)
    local color = cfg.color
    combo:Layout(width, cfg.height, cfg.spacing, function(gauge, pipWidth, pipHeight)
        gauge:SetStyle(db.style)
        gauge:SetHeight(pipHeight)
        gauge:SetTexture(db.texture)
        gauge.bar:SetWidth(pipWidth)
        gauge:SetColor(color.r, color.g, color.b)
    end)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", here.bar, "BOTTOMLEFT", 0, -cfg.gap)
    combo:Update(false, cfg.hideEmpty)
end

------------------------------------------------------------------------------
-- The skin the engine drives
------------------------------------------------------------------------------

local UPDATES = {
    all = function(plate)
        Plates:UpdateHealth(plate)
        Plates:UpdateColour(plate)
        Plates:UpdateThreat(plate)
        Plates:UpdateMark(plate)
        Plates:UpdateQuest(plate)
        Plates:UpdateRank(plate)
    end,
    health = function(plate) Plates:UpdateHealth(plate) end,
    name = function(plate) Plates:UpdateText(plate) end,
    class = function(plate)
        Plates:UpdateText(plate)
        Plates:UpdateRank(plate)
    end,
    threat = function(plate)
        Plates:UpdateColour(plate)
        Plates:UpdateThreat(plate)
    end,
    mark = function(plate) Plates:UpdateMark(plate) end,
    quest = function(plate) Plates:UpdateQuest(plate) end,
    execute = function(plate)
        Plates:UpdateColour(plate)
        Plates:UpdateExecute(plate)
    end,
}

local skin = {
    owner = "XIVPlates",
    enabled = function() return ns.db.enabled end,
    create = Create,
    layout = function(plate) Plates:Layout(plate) end,
    update = function(plate, what)
        local Update = UPDATES[what]
        if Update then Update(plate) end
    end,
    target = function() Plates:UpdateTarget() end,
    castShield = function(unitFrame, cast, shown, ours) Plates:CastShield(unitFrame, cast, shown, ours) end,
    castFill = function(cast) Engine.OverFill(CastFill(cast), cast) end,
    -- An interrupted cast turns red, which ours mustn't cover; the next cast sets it again.
    castInterrupted = function(cast) CastFill(cast):SetAlpha(0) end,
    -- Given back to Blizzard (a friendly plate next): its icon back, our fill away.
    release = function(_, cast)
        if cast.Icon then cast.Icon:SetAlpha(1) end
        if casts[cast] then casts[cast]:SetAlpha(0) end
    end,
}

function Plates:Refresh()
    local db = ns.db
    Engine.AuraSettings({ auras = db.enabled and db.auras, allDebuffs = db.allDebuffs })
    Engine.Refresh()
end

function Plates:ThreatReport()
    Engine.ThreatReport(ns.Print)
end

function Plates:Init()
    local ok, other = Engine.Register(skin)
    if not ok then
        ns.Print(other .. " is already styling the nameplates; turn one of the two off.")
        return
    end
    if Combo.Has() then
        combo = Combo.NewRow(UIParent, function(_, holder)
            local gauge = FrogLib.Gauge.New(holder)
            return gauge, gauge.bar
        end)
        combo.holder:Hide()
        Combo.Watch(function()
            if combo.holder:IsShown() then combo:Update(false, ns.db.combo.hideEmpty) end
        end, function() Plates:PlaceCombo() end)
    end
    self:Refresh()
end
