local ADDON, ns = ...

-- XIVPlates: FFXIV-style enemy nameplates (see Plates.lua), to go with XIVPlayer and XIVTarget.

-- The settings controls are FrogLib's (UI.lua); every change calls ns.Refresh().
local UI = FrogLib.UI.Kit({ refresh = function() ns.Refresh() end })

ns.defaults = {
    enabled = true,
    -- The gauge: "line" (a hair-thin glowing line, like XIVTarget's) or "framed" (the gold-rimmed
    -- parameter bar, like XIVPlayer's). width 0: as wide as Blizzard's plate.
    style = "line",
    width = 170,
    height = 3,
    scale = 1,
    texture = "Interface\\Buttons\\WHITE8X8",
    smooth = true,      -- the gauge eases to new values
    -- "xiv": FFXIV's colours (red engaged, yellow passive); "reaction": plain hostile / neutral.
    colorMode = "xiv",
    -- The text's colour: "gauge" (a light version of the gauge's, as FFXIV prints it), "reaction"
    -- (by hostility: hostile red, neutral yellow, whatever threat colour the gauge has) or "white".
    textColor = "gauge",
    tapGrey = true,     -- grey gauge and text once someone else got the first hit (colors.tapped)
    -- Michroma: wide, like FFXIV's (and XIVTarget's) gauge text.
    font = "Interface\\AddOns\\XIVPlates\\Fonts\\Michroma.ttf",
    outline = "OUTLINE",
    textSize = 9,
    levelColor = false, -- the level in the colour for how hard the enemy is for you
    nameRow = true,     -- the name centred on its own row above, never cut short
    belowBar = true,    -- the left and right texts (level, health) under the gauge, not over it
    -- Templates: words level, name, class, value, max, percent (percent.1 for a decimal).
    -- name: its own row (nameRow); left and right: over the gauge's ends.
    text = { name = "name", left = "Lv level", right = "percent" },
    castBar = true,     -- Blizzard's cast bar as a line under the gauge
    castHeight = 2,
    castGap = 6,
    castTextSize = 9,
    -- Each text's own size (0: the shared size above, or castTextSize for the cast's) and nudge
    -- (x right, y up), in plate units.
    texts = {
        name = { size = 0, x = 0, y = 0 }, left = { size = 0, x = 0, y = 0 },
        right = { size = 0, x = 0, y = 0 }, threat = { size = 0, x = 0, y = 0 },
        castName = { size = 0, x = 0, y = 0 }, castTime = { size = 0, x = 0, y = 0 },
    },
    castTime = true,
    castColor = true,   -- casts you can't interrupt in colors.uninterruptible
    auras = true,       -- your debuffs (Blizzard's) over the name
    allDebuffs = true,  -- every debuff of yours, not only the ones on Blizzard's list
    threat = true,      -- colour by threat while you're on its threat list
    role = "auto",      -- "auto" (a tanking stance, form or aura), "tank" or "damage"
    threatText = true,  -- your lead (or how far behind), or your threat %, past the gauge
    execute = true,     -- the gauge in colors.execute once the enemy is in your execute range
    questMarker = true, -- a "!" before enemies your quests still need
    raidMarks = true,
    markSize = 16,
    rankIcon = "rare",  -- an icon for rares and rare elites ("all": elites too; "off")
    rankSize = 14,
    -- Your target: bigger, its gauge a pixel thicker and its text in the target colour (gold
    -- chevrons either side, if you like); the others at otherAlpha.
    targetScale = 1.1,
    chevrons = false,
    targetText = true,
    otherAlpha = 0.7,
    -- Your combo points (rogues; druids in cat form) right under your target's gauge: gap from
    -- it, height and spacing of the pips; hideEmpty: see-through while you have none.
    combo = { enabled = true, height = 3, spacing = 4, gap = 3, hideEmpty = true,
        color = { r = 1, g = 0.82, b = 0.3 } },
    gameFade = false,   -- let the game dim plates behind terrain or far away
    colors = {
        safe = { r = 0.32, g = 0.66, b = 0.46 },   -- tanking: it's on you
        warn = { r = 0.95, g = 0.62, b = 0.22 },   -- it's slipping, or about to come to you
        danger = { r = 0.92, g = 0.24, b = 0.42 }, -- tanking: it's off you; otherwise: it's on you
        target = { r = 0.96, g = 0.86, b = 0.56 }, -- FFXIV's gold
        uninterruptible = { r = 0.58, g = 0.58, b = 0.62 },
        execute = { r = 0.66, g = 0.38, b = 0.96 },
        tapped = { r = 0.55, g = 0.55, b = 0.55 },
    },
}

ns.Print = FrogLib.Util.Printer("XIVPlates", "f5dc8f")

function ns.Refresh()
    ns.Plates:Refresh()
end

------------------------------------------------------------------------------
-- Settings window: four pages, two columns of headed groups each (FrogLib's UI.Column)
------------------------------------------------------------------------------

local LEFT, RIGHT, COLUMN_WIDTH, INDENT = 0, 380, 360, 20
local STYLES = UI.Options("line", "Line (thin glow, like XIVTarget)", "framed", "Framed (gold rim, like XIVPlayer)")
local COLOR_MODES = UI.Options("xiv", "FFXIV colours", "reaction", "Hostile red, neutral yellow")
local TEXT_COLORS = UI.Options("gauge", "A light version of the gauge's", "reaction",
    "By hostility (hostile red, neutral yellow)", "white", "White")
local RANKS = UI.Options("rare", "Rares and rare elites", "all", "Rares and elites", "off", "None")
local ROLES = UI.Options("auto", "Auto (tanking stance, form or aura)", "tank", "Always tanking", "damage", "Never tanking")

local function Help(page, place, text, height, indent)
    place(UI.Help(page, text, COLUMN_WIDTH - 10 - (indent or 0)), height, indent or 4)
end

local function Swatch(page, place, label, key, indent)
    place(UI.ColorSwatch(page, label, ns.db.colors, key), 28, indent)
end

local function BuildLook(page)
    local db = ns.db
    local place, head = UI.Column(page, LEFT, COLUMN_WIDTH)
    head("Plates")
    place(UI.Checkbox(page, "XIV-style enemy nameplates", db, "enabled"), 28)
    place(UI.Dropdown(page, "Gauge", STYLES, db, "style"), 30)
    place(UI.Dropdown(page, "Texture", function() return ns.Media:List("statusbar") end, db, "texture"), 30)
    place(UI.Checkbox(page, "The gauge eases to new values", db, "smooth"), 30)
    head("Size")
    place(UI.Stepper(page, "Width (0 = Blizzard's)", 0, 300, 5, db, "width"), 28)
    place(UI.Stepper(page, "Gauge height", 1, 16, 1, db, "height"), 28)
    place(UI.Stepper(page, "Scale", 0.5, 2, 0.05, db, "scale", "%.2f"), 28)
    place(UI.Checkbox(page, "Let the game dim plates behind terrain or far away", db, "gameFade"), 30)
    Help(page, place, "Friendly nameplates stay Blizzard's. The cast bar and your debuffs are Blizzard's own, "
        .. "moved round the gauge, so they keep working where the game hides cast and aura details.", 44)

    local right, rightHead = UI.Column(page, RIGHT, COLUMN_WIDTH)
    rightHead("Text")
    right(UI.Dropdown(page, "Font", function() return ns.Media:List("font") end, db, "font"), 30)
    right(UI.Dropdown(page, "Outline", UI.OUTLINES, db, "outline"), 30)
    right(UI.Stepper(page, "Size", 6, 20, 1, db, "textSize"), 28)
    right(UI.Checkbox(page, "The name centred on its own row above", db, "nameRow"), 26)
    right(UI.TextBox(page, "Its row", db.text, "name"), 28, INDENT)
    right(UI.Checkbox(page, "The left and right texts under the gauge (off: over it)", db, "belowBar"), 26)
    right(UI.TextBox(page, "At the left end", db.text, "left"), 28)
    right(UI.TextBox(page, "At the right end", db.text, "right"), 28)
    Help(page, right, "Words: |cffffd100level|r, |cffffd100name|r, |cffffd100class|r, |cffffd100value|r, "
        .. "|cffffd100max|r, |cffffd100percent|r (|cffffd100percent.1|r for a decimal). Empty hides it.", 30)
    right(UI.Dropdown(page, "Text colour", TEXT_COLORS, db, "textColor"), 30)
    right(UI.Checkbox(page, "The level coloured by how hard the enemy is", db, "levelColor"), 30)
end

local function BuildCasts(page)
    local db = ns.db
    local place, head = UI.Column(page, LEFT, COLUMN_WIDTH)
    head("Cast bar")
    place(UI.Checkbox(page, "The cast as a line under the gauge", db, "castBar"), 28)
    place(UI.Stepper(page, "Line height", 1, 12, 1, db, "castHeight"), 28, INDENT)
    place(UI.Stepper(page, "Gap under the gauge", 0, 30, 1, db, "castGap"), 28, INDENT)
    place(UI.Stepper(page, "Spell name and time size", 6, 18, 1, db, "castTextSize"), 28, INDENT)
    place(UI.Checkbox(page, "Time left on the cast", db, "castTime"), 26, INDENT)
    place(UI.Checkbox(page, "Casts you can't interrupt in their own colour", db, "castColor"), 28)
    Swatch(page, place, "Can't interrupt", "uninterruptible", INDENT)

    local right, rightHead = UI.Column(page, RIGHT, COLUMN_WIDTH)
    rightHead("Your debuffs")
    right(UI.Checkbox(page, "Your debuffs over the name (Blizzard's)", db, "auras"), 26)
    right(UI.Checkbox(page, "Every debuff of yours, not only Blizzard's list", db, "allDebuffs"), 26, INDENT)
    Help(page, right, "Their size is the game's own (Options > Nameplates).", 20)
    rightHead("Marks")
    right(UI.Checkbox(page, "Raid marks beside the gauge", db, "raidMarks"), 26)
    right(UI.Stepper(page, "Raid mark size", 8, 40, 1, db, "markSize"), 28, INDENT)
    right(UI.Checkbox(page, "A \"!\" before enemies your quests still need", db, "questMarker"), 26)
    right(UI.Dropdown(page, "Rare / elite icon", RANKS, db, "rankIcon"), 30)
    right(UI.Stepper(page, "Its size", 8, 32, 1, db, "rankSize"), 28, INDENT)
    Help(page, right, "After the name: a silver star for a rare, a silver dragon for a rare elite, gold for an elite.", 30)
end

local function BuildTarget(page)
    local db = ns.db
    local place, head = UI.Column(page, LEFT, COLUMN_WIDTH)
    head("Your target")
    place(UI.Stepper(page, "Its plate's size", 1, 2, 0.05, db, "targetScale", "%.2f"), 28)
    place(UI.Checkbox(page, "Gold chevrons either side of it", db, "chevrons"), 26)
    place(UI.Checkbox(page, "Its text in the target colour", db, "targetText"), 26)
    Swatch(page, place, "Target colour", "target")
    place(UI.Stepper(page, "Other plates' opacity", 0.1, 1, 0.05, db, "otherAlpha", "%.2f"), 30)
    local combo = db.combo
    head("Combo points")
    place(UI.Checkbox(page, "Under your target's gauge (rogues, druids in cat form)", combo, "enabled"), 26)
    place(UI.Checkbox(page, "See-through while you have none", combo, "hideEmpty"), 26, INDENT)
    place(UI.Stepper(page, "Height", 1, 10, 1, combo, "height"), 28, INDENT)
    place(UI.Stepper(page, "Gap between them", 0, 12, 1, combo, "spacing"), 28, INDENT)
    place(UI.Stepper(page, "Gap under the gauge", 0, 20, 1, combo, "gap"), 28, INDENT)
    place(UI.ColorSwatch(page, "Colour", combo, "color"), 30, INDENT)
    head("Colours")
    place(UI.Dropdown(page, "Colours", COLOR_MODES, db, "colorMode"), 30)
    place(UI.Checkbox(page, "The gauge in the execute colour once it's in your execute range", db, "execute"), 26)
    Swatch(page, place, "Execute", "execute", INDENT)
    place(UI.Checkbox(page, "Grey once someone else got the first hit", db, "tapGrey"), 26)
    Swatch(page, place, "Tapped", "tapped", INDENT)

    local right, rightHead = UI.Column(page, RIGHT, COLUMN_WIDTH)
    rightHead("Threat")
    right(UI.Checkbox(page, "Colour by threat while you're on its list", db, "threat"), 26)
    right(UI.Dropdown(page, "Role", ROLES, db, "role"), 30, INDENT)
    Swatch(page, right, "Tanking, it's on you / not tanking, it's not", "safe", INDENT)
    Swatch(page, right, "Slipping, or coming your way", "warn", INDENT)
    Swatch(page, right, "Tanking, it's off you / not tanking, it's on you", "danger", INDENT)
    right(UI.Checkbox(page, "Your lead (or threat %) past the gauge", db, "threatText"), 30)
    Help(page, right, "/xivplates threat: what the game shows addons of the threat on your target.", 30)
end

-- Every text: its own size (0: the shared one) and nudge, side by side.
local TEXT_PARTS = {
    { "name", "The name" }, { "left", "Left text (the level)" }, { "right", "Right text (the health)" },
    { "threat", "Threat text" }, { "castName", "The cast's spell name" }, { "castTime", "The cast's time left" },
}

local function BuildTexts(page)
    local db = ns.db
    local place, head = UI.Column(page, LEFT, COLUMN_WIDTH)
    local right, rightHead = UI.Column(page, RIGHT, COLUMN_WIDTH)
    for i, part in ipairs(TEXT_PARTS) do
        local settings = db.texts[part[1]]
        local put, title = place, head
        if i > 3 then put, title = right, rightHead end
        title(part[2])
        put(UI.Stepper(page, "Size (0 = the shared size)", 0, 30, 1, settings, "size"), 28)
        put(UI.Pair(page, "Nudge", { "x", -60, 60, settings, "x" }, { "y", -40, 40, settings, "y" }), 30)
    end
    Help(page, place, "x moves a text right (left when negative), y up (down). The rows above and below the "
        .. "gauge make room for each text's size.", 30)
end

function ns.ToggleConfig()
    if not ns.window then
        ns.window = UI.Window("XIVPlatesConfig", "XIVPlates", 780, 660, {
            { "look", "Look & text", BuildLook },
            { "casts", "Casts & debuffs", BuildCasts },
            { "target", "Target, colours & threat", BuildTarget },
            { "texts", "Text sizes & nudges", BuildTexts },
        }, { fitTabs = true })
        return
    end
    ns.window:SetShown(not ns.window:IsShown())
end

------------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON then
        XIVPlatesDB = XIVPlatesDB or {}
        local db = XIVPlatesDB
        -- 0.1's first defaults, where left as they were: the newer ones (XIVTarget's font, wider
        -- plates with room for the name, no chevrons).
        if (db.version or 1) < 2 then
            local was = { width = 120, textSize = 10, targetScale = 1.15, chevrons = true,
                font = "Interface\\AddOns\\XIVPlates\\Fonts\\XIV.ttf" }
            for key, old in pairs(was) do
                if db[key] == old then db[key] = nil end
            end
            db.version = 2
        end
        -- The name moved to a row of its own: the left text left as it was is the level alone now.
        if db.version < 3 then
            if type(db.text) == "table" and db.text.left == "Lv level name" then db.text.left = nil end
            db.version = 3
        end
        -- 0.2: the text colour became a choice (by hostility too).
        if db.version < 4 then
            if db.tinted == false then db.textColor = "white" end
            db.tinted = nil
            db.version = 4
        end
        FrogLib.Util.CopyDefaults(ns.defaults, XIVPlatesDB)
        ns.db = XIVPlatesDB
    elseif event == "PLAYER_LOGIN" then
        ns.Plates:Init()
    end
end)

SLASH_XIVPLATES1 = "/xivplates"
SLASH_XIVPLATES2 = "/xpl"
SlashCmdList.XIVPLATES = function(text)
    if strtrim(text or ""):lower() == "threat" then
        ns.Plates:ThreatReport()
    else
        ns.ToggleConfig()
    end
end
function XIVPlates_OnCompartmentClick() ns.ToggleConfig() end

FrogLib.Options.Add("XIVPlates", ns, {
    open = function()
        if not (ns.window and ns.window:IsShown()) then ns.ToggleConfig() end
    end,
    commands = { { "/xivplates", "open or close the settings (or /xpl)" },
        { "/xivplates threat", "what the game shows addons of the threat on your target" } },
})
