local ADDON, ns = ...
local UI = ns.UI

-- XIVPlates: FFXIV-style enemy nameplates (see Plates.lua), to go with XIVPlayer and XIVTarget.

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
    tinted = true,      -- text in a light version of the gauge's colour, as FFXIV prints it
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
    allDebuffs = true,  -- every debuff of yours, not just the ones on Blizzard's list
    threat = true,      -- colour by threat while you're on its threat list
    role = "auto",      -- "auto" (a tanking stance, form or aura), "tank" or "damage"
    threatText = true,  -- your lead (or how far behind), or your threat %, past the gauge
    execute = true,     -- the gauge in colors.execute once the enemy is in your execute range
    questMarker = true, -- a "!" before enemies your quests still need
    raidMarks = true,
    markSize = 16,
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
    },
}

ns.Print = FrogLib.Util.Printer("XIVPlates", "f5dc8f")

function ns.Refresh()
    ns.Plates:Refresh()
end

------------------------------------------------------------------------------
-- Settings window: three pages, two columns of headed groups each (FrogLib's UI.Column)
------------------------------------------------------------------------------

local LEFT, RIGHT, COL_W, SUB = 0, 380, 360, 20
local STYLES = UI.Options("line", "Line (thin glow, like XIVTarget)", "framed", "Framed (gold rim, like XIVPlayer)")
local COLOR_MODES = UI.Options("xiv", "FFXIV colours", "reaction", "Hostile red, neutral yellow")
local ROLES = UI.Options("auto", "Auto (tanking stance, form or aura)", "tank", "Always tanking", "damage", "Never tanking")

local function Help(p, place, text, h, dx)
    place(UI.Help(p, text, COL_W - 10 - (dx or 0)), h, dx or 4)
end

local function Swatch(p, place, label, key, dx)
    local c = ns.db.colors
    place(UI.ColorSwatch(p, label, function() return c[key] end,
        function(r, g, b) c[key] = { r = r, g = g, b = b } end), 28, dx)
end

local function BuildLook(p)
    local db = ns.db
    local place, head = UI.Column(p, LEFT, COL_W)
    head("Plates")
    place(UI.Checkbox(p, "XIV-style enemy nameplates", function() return db.enabled end,
        function(v) db.enabled = v end), 28)
    place(UI.Dropdown(p, "Gauge", STYLES, function() return db.style end, function(v) db.style = v end), 30)
    place(UI.Dropdown(p, "Texture", function() return ns.Media:List("statusbar") end,
        function() return db.texture end, function(v) db.texture = v end), 30)
    place(UI.Checkbox(p, "The gauge eases to new values", function() return db.smooth end,
        function(v) db.smooth = v end), 30)
    head("Size")
    place(UI.Stepper(p, "Width (0 = Blizzard's)", 0, 300, 5, function() return db.width end,
        function(v) db.width = v end), 28)
    place(UI.Stepper(p, "Gauge height", 1, 16, 1, function() return db.height end,
        function(v) db.height = v end), 28)
    place(UI.Stepper(p, "Scale", 0.5, 2, 0.05, function() return db.scale end,
        function(v) db.scale = v end, "%.2f"), 28)
    place(UI.Checkbox(p, "Let the game dim plates behind terrain or far away", function() return db.gameFade end,
        function(v) db.gameFade = v end), 30)
    Help(p, place, "Friendly nameplates stay Blizzard's. The cast bar and your debuffs are Blizzard's own, "
        .. "moved round the gauge, so they keep working where the game hides cast and aura details.", 44)

    local right, rhead = UI.Column(p, RIGHT, COL_W)
    rhead("Text")
    right(UI.Dropdown(p, "Font", function() return ns.Media:List("font") end,
        function() return db.font end, function(v) db.font = v end), 30)
    right(UI.Dropdown(p, "Outline", UI.OUTLINES, function() return db.outline end,
        function(v) db.outline = v end), 30)
    right(UI.Stepper(p, "Size", 6, 20, 1, function() return db.textSize end, function(v) db.textSize = v end), 28)
    right(UI.Checkbox(p, "The name centred on its own row above", function() return db.nameRow end,
        function(v) db.nameRow = v end), 26)
    right(UI.TextBox(p, "Its row", function() return db.text.name end,
        function(v) db.text.name = v end), 28, SUB)
    right(UI.Checkbox(p, "The left and right texts under the gauge (off: over it)", function() return db.belowBar end,
        function(v) db.belowBar = v end), 26)
    right(UI.TextBox(p, "At the left end", function() return db.text.left end,
        function(v) db.text.left = v end), 28)
    right(UI.TextBox(p, "At the right end", function() return db.text.right end,
        function(v) db.text.right = v end), 28)
    Help(p, right, "Words: |cffffd100level|r, |cffffd100name|r, |cffffd100class|r, |cffffd100value|r, "
        .. "|cffffd100max|r, |cffffd100percent|r (|cffffd100percent.1|r for a decimal). Empty hides it.", 30)
    right(UI.Checkbox(p, "Text in a light version of the gauge's colour", function() return db.tinted end,
        function(v) db.tinted = v end), 26)
    right(UI.Checkbox(p, "The level coloured by how hard the enemy is", function() return db.levelColor end,
        function(v) db.levelColor = v end), 30)
end

local function BuildCasts(p)
    local db = ns.db
    local place, head = UI.Column(p, LEFT, COL_W)
    head("Cast bar")
    place(UI.Checkbox(p, "The cast as a line under the gauge", function() return db.castBar end,
        function(v) db.castBar = v end), 28)
    place(UI.Stepper(p, "Line height", 1, 12, 1, function() return db.castHeight end,
        function(v) db.castHeight = v end), 28, SUB)
    place(UI.Stepper(p, "Gap under the gauge", 0, 30, 1, function() return db.castGap end,
        function(v) db.castGap = v end), 28, SUB)
    place(UI.Stepper(p, "Spell name and time size", 6, 18, 1, function() return db.castTextSize end,
        function(v) db.castTextSize = v end), 28, SUB)
    place(UI.Checkbox(p, "Time left on the cast", function() return db.castTime end,
        function(v) db.castTime = v end), 26, SUB)
    place(UI.Checkbox(p, "Casts you can't interrupt in their own colour", function() return db.castColor end,
        function(v) db.castColor = v end), 28)
    Swatch(p, place, "Can't interrupt", "uninterruptible", SUB)

    local right, rhead = UI.Column(p, RIGHT, COL_W)
    rhead("Your debuffs")
    right(UI.Checkbox(p, "Your debuffs over the name (Blizzard's)", function() return db.auras end,
        function(v) db.auras = v end), 26)
    right(UI.Checkbox(p, "Every debuff of yours, not just Blizzard's list", function() return db.allDebuffs end,
        function(v) db.allDebuffs = v end), 26, SUB)
    Help(p, right, "Their size is the game's own (Options > Nameplates).", 20)
    rhead("Marks")
    right(UI.Checkbox(p, "Raid marks beside the gauge", function() return db.raidMarks end,
        function(v) db.raidMarks = v end), 26)
    right(UI.Stepper(p, "Raid mark size", 8, 40, 1, function() return db.markSize end,
        function(v) db.markSize = v end), 28, SUB)
    right(UI.Checkbox(p, "A \"!\" before enemies your quests still need", function() return db.questMarker end,
        function(v) db.questMarker = v end), 26)
end

local function BuildTarget(p)
    local db = ns.db
    local place, head = UI.Column(p, LEFT, COL_W)
    head("Your target")
    place(UI.Stepper(p, "Its plate's size", 1, 2, 0.05, function() return db.targetScale end,
        function(v) db.targetScale = v end, "%.2f"), 28)
    place(UI.Checkbox(p, "Gold chevrons either side of it", function() return db.chevrons end,
        function(v) db.chevrons = v end), 26)
    place(UI.Checkbox(p, "Its text in the target colour", function() return db.targetText end,
        function(v) db.targetText = v end), 26)
    Swatch(p, place, "Target colour", "target")
    place(UI.Stepper(p, "Other plates' opacity", 0.1, 1, 0.05, function() return db.otherAlpha end,
        function(v) db.otherAlpha = v end, "%.2f"), 30)
    local cb = db.combo
    head("Combo points")
    place(UI.Checkbox(p, "Under your target's gauge (rogues, druids in cat form)", function() return cb.enabled end,
        function(v) cb.enabled = v end), 26)
    place(UI.Checkbox(p, "See-through while you have none", function() return cb.hideEmpty end,
        function(v) cb.hideEmpty = v end), 26, SUB)
    place(UI.Stepper(p, "Height", 1, 10, 1, function() return cb.height end, function(v) cb.height = v end), 28, SUB)
    place(UI.Stepper(p, "Gap between them", 0, 12, 1, function() return cb.spacing end,
        function(v) cb.spacing = v end), 28, SUB)
    place(UI.Stepper(p, "Gap under the gauge", 0, 20, 1, function() return cb.gap end,
        function(v) cb.gap = v end), 28, SUB)
    place(UI.ColorSwatch(p, "Colour", function() return cb.color end,
        function(r, g, b) cb.color = { r = r, g = g, b = b } end), 30, SUB)
    head("Colours")
    place(UI.Dropdown(p, "Colours", COLOR_MODES, function() return db.colorMode end,
        function(v) db.colorMode = v end), 30)
    place(UI.Checkbox(p, "The gauge in the execute colour once it's in your execute range", function() return db.execute end,
        function(v) db.execute = v end), 26)
    Swatch(p, place, "Execute", "execute", SUB)

    local right, rhead = UI.Column(p, RIGHT, COL_W)
    rhead("Threat")
    right(UI.Checkbox(p, "Colour by threat while you're on its list", function() return db.threat end,
        function(v) db.threat = v end), 26)
    right(UI.Dropdown(p, "Role", ROLES, function() return db.role end, function(v) db.role = v end), 30, SUB)
    Swatch(p, right, "Tanking, it's on you / not tanking, it's not", "safe", SUB)
    Swatch(p, right, "Slipping, or coming your way", "warn", SUB)
    Swatch(p, right, "Tanking, it's off you / not tanking, it's on you", "danger", SUB)
    right(UI.Checkbox(p, "Your lead (or threat %) past the gauge", function() return db.threatText end,
        function(v) db.threatText = v end), 30)
    Help(p, right, "/xivplates threat: what the game shows addons of the threat on your target.", 30)
end

-- Every text: its own size (0: the shared one) and nudge, side by side.
local TEXT_PARTS = {
    { "name", "The name" }, { "left", "Left text (the level)" }, { "right", "Right text (the health)" },
    { "threat", "Threat text" }, { "castName", "The cast's spell name" }, { "castTime", "The cast's time left" },
}

local function BuildTexts(p)
    local db = ns.db
    local place, head = UI.Column(p, LEFT, COL_W)
    local right, rhead = UI.Column(p, RIGHT, COL_W)
    for i, part in ipairs(TEXT_PARTS) do
        local t = db.texts[part[1]]
        local put, title = place, head
        if i > 3 then put, title = right, rhead end
        title(part[2])
        put(UI.Stepper(p, "Size (0 = the shared size)", 0, 30, 1, function() return t.size end,
            function(v) t.size = v end), 28)
        put(UI.Pair(p, "Nudge", { "x", -60, 60, function() return t.x end, function(v) t.x = v end },
            { "y", -40, 40, function() return t.y end, function(v) t.y = v end }), 30)
    end
    Help(p, place, "x moves a text right (left when negative), y up (down). The rows above and below the "
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
loader:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        XIVPlatesDB = XIVPlatesDB or {}
        local db = XIVPlatesDB
        -- 0.1's first defaults, where left as they were: the newer ones (XIVTarget's font, wider
        -- plates with room for the name, no chevrons).
        if (db.version or 1) < 2 then
            local was = { width = 120, textSize = 10, targetScale = 1.15, chevrons = true,
                font = "Interface\\AddOns\\XIVPlates\\Fonts\\XIV.ttf" }
            for k, v in pairs(was) do
                if db[k] == v then db[k] = nil end
            end
            db.version = 2
        end
        -- The name moved to a row of its own: the left text left as it was is the level alone now.
        if db.version < 3 then
            if type(db.text) == "table" and db.text.left == "Lv level name" then db.text.left = nil end
            db.version = 3
        end
        FrogLib.Util.CopyDefaults(ns.defaults, XIVPlatesDB)
        ns.db = XIVPlatesDB
    elseif event == "PLAYER_LOGIN" then
        ns.Plates:Init()
    end
end)

SLASH_XIVPLATES1 = "/xivplates"
SLASH_XIVPLATES2 = "/xpl"
SlashCmdList.XIVPLATES = function(msg)
    if strtrim(msg or ""):lower() == "threat" then
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
