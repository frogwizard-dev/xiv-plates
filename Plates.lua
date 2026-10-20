local _, ns = ...

-- FFXIV-style enemy nameplates, in XIVTarget's look: a thin glowing gauge (FrogLib's Gauge, the
-- same as XIVPlayer's and XIVTarget's bars), the name centred on a row of its own above it (never
-- cut short), the level under the gauge's left end and the health under its right (or both over
-- it: belowBar), in a light version of the gauge's colour; the cast a thinner line
-- underneath, with the spell's name hanging below its right end. Your target stands out (bigger,
-- with gold chevrons either side), the others dim a little.
--
-- FrogLib's Plates engine takes the plates over (Blizzard's made see-through underneath, its cast
-- bar and debuffs kept and moved round ours, as FrogPlates does) and says when to build, lay out
-- and fill in each one. Values the game keeps secret in combat only ever go straight to widgets.

local Plates = {}
ns.Plates = Plates

local Engine = FrogLib.Plates
local Combo = FrogLib.Combo
local combo -- your combo points: one row, on your target's plate (rogues; druids in cat form)
local Color, Unit, Icons = FrogLib.Color, FrogLib.Unit, FrogLib.Icons
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon" -- the yellow "!"

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
        local c = db.colors.tapped
        return c.r, c.g, c.b
    end
    if db.threat then
        local r, g, b = Engine.ThreatColour(unit, db.colors, db.role)
        if r then return r, g, b end
    end
    if db.colorMode == "xiv" then return Color.XIVUnit(unit) end
    return Color.Unit(unit, REACTION)
end

-- How far above the gauge the text over it sits, and one row of it.
local function Lift(db) return db.style == "framed" and 4 or 2 end
-- Each text's size (db.texts[key].size; 0: the shared size, the cast's for the cast's texts)
-- and its nudge (x right, y up).
local function Size(db, key)
    local s = db.texts[key].size
    if s and s > 0 then return s end
    return (key == "castName" or key == "castTime") and db.castTextSize or db.textSize
end
local function Nudge(db, key)
    local t = db.texts[key]
    return t.x or 0, t.y or 0
end
-- The name's row, and the level and health's (the taller of the two).
local function NameRow(db) return Size(db, "name") + 4 end
local function DetailRow(db) return math.max(Size(db, "left"), Size(db, "right")) + 4 end
-- How far the text over the gauge reaches: the name's row, and the level and health's unless
-- they're under it.
local function TextOver(db)
    return (db.nameRow and NameRow(db) or 0) + (db.belowBar and 0 or DetailRow(db))
end
-- How far under the gauge the cast line starts: past the level and health when they're there.
-- Your combo points sit right under your target's gauge: this much room there, 0 elsewhere.
local function ComboRoom(f) return f and f.comboRoom or 0 end
-- How far under the gauge the cast line starts: past the combo points, and the level and health
-- when they're there.
local function CastDrop(db, f)
    return db.castGap + ComboRoom(f) + (db.belowBar and (Lift(db) + DetailRow(db)) or 0)
end

local function Text(parent, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

------------------------------------------------------------------------------
-- Building (f: the engine's frame over the plate, with f.base and f.slot)
------------------------------------------------------------------------------

local function Create(f)
    local g = FrogLib.Gauge.New(f)
    f.gauge, f.bar = g, g.bar
    -- Execute range: the fill again in the execute colour, over it (see UpdateExecute).
    f.execute = g.bar:CreateTexture(nil, "ARTWORK", nil, 6)
    f.execute:Hide()
    local words = CreateFrame("Frame", nil, f)
    words:SetAllPoints(g.bar)
    words:SetFrameLevel(g.bar:GetFrameLevel() + 4)
    f.name = Text(words, "CENTER")
    f.left = Text(words, "LEFT")
    f.right = Text(words, "RIGHT")
    f.threat = Text(words, "LEFT")
    -- The raid mark: an icon written into text, since which mark it is can be secret in combat.
    f.mark = words:CreateFontString(nil, "OVERLAY")
    f.mark:SetFont(STANDARD_TEXT_FONT, 12, "")
    f.mark:Hide()
    f.quest = words:CreateTexture(nil, "OVERLAY")
    f.quest:SetTexture(QUEST_ICON)
    f.quest:Hide()
    -- Your target: gold chevrons either side of the gauge, as FFXIV links a target.
    f.chevronLeft = Text(words, "RIGHT")
    f.chevronLeft:SetText(">")
    f.chevronRight = Text(words, "LEFT")
    f.chevronRight:SetText("<")
    f.chevronLeft:Hide()
    f.chevronRight:Hide()
end

------------------------------------------------------------------------------
-- Casts: Blizzard's cast bar under the gauge, thinned to a line in our texture's place, its
-- border, icon and target name out of sight, its spell name below its right end in our font, the
-- time left below its left end. Casts you can't interrupt: our fill over Blizzard's in their
-- colour (following Blizzard's own "can't interrupt" state, which the engine passes on).
------------------------------------------------------------------------------

local casts = {} -- Blizzard cast bar -> our fill over it

local function CastFill(cast)
    local t = casts[cast]
    if not t then
        t = cast:CreateTexture(nil, "ARTWORK", nil, 7)
        t:SetAlpha(0)
        casts[cast] = t
    end
    return t
end

function Plates:CastShield(uf, cast, shown, ours)
    local db = ns.db
    local on = ours and db.enabled and db.castBar
    if cast.BorderShield then cast.BorderShield:SetAlpha(on and 0 or 1) end
    Engine.AlphaFrom(CastFill(cast), shown, on and db.castColor)
end

local function LayoutCast(f, db)
    local uf = f.uf
    local cast = Engine.BlizzardCast(uf)
    if not cast then return end
    cast:SetIgnoreParentAlpha(db.castBar)
    if not db.castBar then return end
    local scale = db.scale or 1
    cast:ClearAllPoints()
    cast:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 0, -CastDrop(db, f) * scale)
    cast:SetPoint("TOPRIGHT", f.bar, "BOTTOMRIGHT", 0, -CastDrop(db, f) * scale)
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
    local c = db.colors.uninterruptible
    local fill = CastFill(cast)
    Engine.OverFill(fill, cast)
    fill:SetTexture(FrogLib.Media.Usable(db.texture) and db.texture or "Interface\\Buttons\\WHITE8X8")
    fill:SetVertexColor(c.r, c.g, c.b)
    -- The last shield state Blizzard set, put back now the plate is ours. It may be secret, so
    -- it's only handed on, never tested ("seen and last or false" would test it).
    local parts = Engine.CastParts(cast)
    if parts.seen then
        Plates:CastShield(uf, cast, parts.last, true)
    else
        Plates:CastShield(uf, cast, false, true)
    end
end

------------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------------

function Plates:Layout(f)
    local db = ns.db
    Engine.PlaceSlot(f)
    local g, bar = f.gauge, f.bar
    g:SetStyle(db.style)
    g:SetHeight(db.height + (f.isTarget and 1 or 0)) -- your target's a pixel thicker
    g:SetTexture(db.texture)
    bar:ClearAllPoints()
    if db.width > 0 then
        bar:SetPoint("CENTER", f.slot, "CENTER")
        bar:SetWidth(db.width)
    else
        bar:SetPoint("LEFT", f.slot, "LEFT")
        bar:SetPoint("RIGHT", f.slot, "RIGHT")
    end
    Engine.OverFill(f.execute, bar)
    f.execute:SetTexture(db.texture)
    local ex = db.colors.execute
    f.execute:SetVertexColor(ex.r, ex.g, ex.b)
    -- The game dims a plate whose enemy is behind terrain or far off; without gameFade ours keeps
    -- its own opacity, like the cast bar and debuffs do.
    f:SetIgnoreParentAlpha(not db.gameFade)

    for _, key in ipairs({ "name", "left", "right", "threat" }) do
        ns.Media:SetFont(f[key], db.font, Size(db, key), db.outline)
    end
    for _, fs in ipairs({ f.chevronLeft, f.chevronRight }) do
        ns.Media:SetFont(fs, db.font, db.textSize + 2, db.outline)
        local c = db.colors.target
        fs:SetTextColor(c.r, c.g, c.b)
    end
    local lift = db.style == "framed" and 4 or 2
    f.right:ClearAllPoints()
    local rx, ry = Nudge(db, "right")
    if db.belowBar then
        f.right:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -1 + rx, -lift - ComboRoom(f) + ry)
    else
        f.right:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -1 + rx, lift + ry)
    end
    f.chevronLeft:ClearAllPoints()
    f.chevronLeft:SetPoint("RIGHT", bar, "LEFT", -4, 0)
    f.chevronRight:ClearAllPoints()
    f.chevronRight:SetPoint("LEFT", bar, "RIGHT", 4, 0)
    f.mark:ClearAllPoints()
    f.mark:SetPoint("RIGHT", bar, "LEFT", -4 - db.textSize, 0)
    f.threat:ClearAllPoints()
    local tx, ty = Nudge(db, "threat")
    f.threat:SetPoint("LEFT", bar, "RIGHT", 6 + db.textSize + tx, ty)
    self:UpdateQuest(f)

    LayoutCast(f, db)
    -- Your debuffs over the name, crowd control past the gauge's right end.
    local scale = db.scale or 1
    local over = Lift(db) + TextOver(db) + 2
    Engine.PlaceAuras(f.uf, bar, db.auras and true or false, over * scale, false, (8 + db.textSize) * scale)
end

------------------------------------------------------------------------------
-- Filling it in
------------------------------------------------------------------------------

local textOpts = {}

function Plates:UpdateText(f)
    local db = ns.db
    textOpts.levelColor = db.levelColor
    textOpts.classColor = true
    Unit.SetText(f.name, db.nameRow and db.text.name or "", f.unit, textOpts)
    Unit.SetText(f.left, db.text.left, f.unit, textOpts)
    Unit.SetText(f.right, db.text.right, f.unit, textOpts)
end

function Plates:UpdateHealth(f)
    f.gauge:SetValues(UnitHealth(f.unit), UnitHealthMax(f.unit), not ns.db.smooth)
    self:UpdateText(f)
    self:UpdateExecute(f)
end

function Plates:UpdateExecute(f)
    local below = ns.db.execute and Engine.ExecuteBelow()
    if not below then
        f.execute:Hide()
        return
    end
    f.execute:SetAlpha(Engine.ExecuteAlpha(f.unit, below))
    f.execute:Show()
end

-- The gauge's colour, and the text in a light version of it as FFXIV prints it, by hostility
-- (whatever the gauge shows for threat), or white. Your target's text in the target colour.
function Plates:UpdateColour(f)
    local r, g, b = Colour(f.unit)
    if not r then r, g, b = 0.9, 0.32, 0.25 end
    f.gauge:SetColor(r, g, b)
    local db = ns.db
    local tr, tg, tb = 1, 1, 1
    if f.isTarget and db.targetText then
        local c = db.colors.target
        tr, tg, tb = c.r, c.g, c.b
    elseif db.textColor == "reaction" then
        if Tapped(f.unit) then
            tr, tg, tb = Color.Lighten(r, g, b, 0.3)
        else
            tr, tg, tb = Color.Unit(f.unit, HOSTILITY)
        end
    elseif db.textColor == "gauge" then
        tr, tg, tb = Color.Lighten(r, g, b, 0.55)
    end
    f.name:SetTextColor(tr, tg, tb)
    f.left:SetTextColor(tr, tg, tb)
    f.right:SetTextColor(tr, tg, tb)
end

function Plates:UpdateThreat(f)
    local db = ns.db
    local shown = db.threatText and Engine.ThreatText(f.threat, f.unit, db.colors)
    f.threat:SetShown(shown and true or false)
end

function Plates:UpdateMark(f)
    local db = ns.db
    f.mark:SetShown(db.raidMarks and Icons.RaidMark(f.mark, f.unit, db.markSize) or false)
end

-- A "!" before the level and name when your quests still need this enemy. The level and name sit
-- on their own row above the health (nameRow), as long as they need to be, or beside it.
function Plates:UpdateQuest(f)
    local db = ns.db
    local shown = f.unit and db.questMarker and Engine.OnQuest(f.unit) or false
    local q = Size(db, db.nameRow and "name" or "left") + 4
    f.quest:SetSize(q, q)
    f.quest:SetShown(shown)
    local lift = Lift(db)
    f.quest:ClearAllPoints()
    f.left:ClearAllPoints()
    f.name:ClearAllPoints()
    local lx, ly = Nudge(db, "left")
    if db.nameRow then
        -- The name centred over the gauge (a row up when the level and health are over it too),
        -- as wide as it needs, the "!" just before it.
        local nx, ny = Nudge(db, "name")
        local up = lift + (db.belowBar and 0 or DetailRow(db))
        f.name:SetPoint("BOTTOM", f.bar, "TOP", (shown and math.floor(q * 0.25 + 0.5) or 0) + nx, up + ny)
        f.quest:SetPoint("RIGHT", f.name, "LEFT", math.floor(q * 0.3 + 0.5), 0)
        if db.belowBar then
            f.left:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 1 + lx, -lift - ComboRoom(f) + ly)
        else
            f.left:SetPoint("BOTTOMLEFT", f.bar, "TOPLEFT", 1 + lx, lift + ly)
        end
    elseif db.belowBar then
        f.quest:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", -math.floor(q * 0.3 + 0.5) + lx, -lift - ComboRoom(f) + 2 + ly)
        f.left:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", (shown and math.floor(q * 0.45 + 0.5) or 0) + 1 + lx,
            -lift - ComboRoom(f) + ly)
    else
        f.quest:SetPoint("BOTTOMLEFT", f.bar, "TOPLEFT", -math.floor(q * 0.3 + 0.5) + lx, lift - 2 + ly)
        f.left:SetPoint("BOTTOMLEFT", f.bar, "TOPLEFT", (shown and math.floor(q * 0.45 + 0.5) or 0) + 1 + lx, lift + ly)
    end
    f.left:SetPoint("RIGHT", f.right, "LEFT", -4, 0)
end

function Plates:UpdateTarget()
    local db = ns.db
    local target = C_NamePlate.GetNamePlateForUnit("target")
    Engine.Each(function(f)
        local isTarget = target == f.base
        f.isTarget = isTarget
        -- Your target's gauge a pixel thicker.
        f.gauge:SetHeight(db.height + (isTarget and 1 or 0))
        f.chevronLeft:SetShown(isTarget and db.chevrons)
        f.chevronRight:SetShown(isTarget and db.chevrons)
        f:SetScale((isTarget and db.targetScale or 1) * (db.scale or 1))
        f:SetAlpha((target and not isTarget) and db.otherAlpha or 1)
        self:UpdateColour(f)
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
    Engine.Each(function(f)
        if f.base == target then here = f end
    end)
    local shown = (cfg.enabled and here and db.enabled and combo:Refresh(false)) and true or false
    if not shown then combo.holder:Hide() end
    -- The room: on your target's plate only, and only while the points show.
    local room = shown and (cfg.gap + cfg.height) or 0
    Engine.Each(function(f)
        local want = (f == here) and room or 0
        if (f.comboRoom or 0) ~= want then
            f.comboRoom = want
            self:Layout(f)
        end
    end)
    if not shown then return end
    local holder = combo.holder
    holder:SetParent(here)
    holder:SetFrameLevel(here.bar:GetFrameLevel() + 2)
    local width = db.width > 0 and db.width or math.max(20, here.bar:GetWidth() or 0)
    local c = cfg.color
    combo:Layout(width, cfg.height, cfg.spacing, function(g, w, h)
        g:SetStyle(db.style)
        g:SetHeight(h)
        g:SetTexture(db.texture)
        g.bar:SetWidth(w)
        g:SetColor(c.r, c.g, c.b)
    end)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", here.bar, "BOTTOMLEFT", 0, -cfg.gap)
    combo:Update(false, cfg.hideEmpty)
end

------------------------------------------------------------------------------
-- The skin the engine drives
------------------------------------------------------------------------------

local UPDATES = {
    all = function(f)
        Plates:UpdateHealth(f)
        Plates:UpdateColour(f)
        Plates:UpdateThreat(f)
        Plates:UpdateMark(f)
        Plates:UpdateQuest(f)
    end,
    health = function(f) Plates:UpdateHealth(f) end,
    name = function(f) Plates:UpdateText(f) end,
    class = function(f) Plates:UpdateText(f) end,
    threat = function(f)
        Plates:UpdateColour(f)
        Plates:UpdateThreat(f)
    end,
    mark = function(f) Plates:UpdateMark(f) end,
    quest = function(f) Plates:UpdateQuest(f) end,
    execute = function(f)
        Plates:UpdateColour(f)
        Plates:UpdateExecute(f)
    end,
}

local skin = {
    owner = "XIVPlates",
    enabled = function() return ns.db.enabled end,
    create = Create,
    layout = function(f) Plates:Layout(f) end,
    update = function(f, what)
        local fn = UPDATES[what]
        if fn then fn(f) end
    end,
    target = function() Plates:UpdateTarget() end,
    castShield = function(uf, cast, shown, ours) Plates:CastShield(uf, cast, shown, ours) end,
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
            local g = FrogLib.Gauge.New(holder)
            return g, g.bar
        end)
        combo.holder:Hide()
        Combo.Watch(function()
            if combo.holder:IsShown() then combo:Update(false, ns.db.combo.hideEmpty) end
        end, function() Plates:PlaceCombo() end)
    end
    self:Refresh()
end
