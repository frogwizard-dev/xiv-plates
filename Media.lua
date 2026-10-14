local ADDON, ns = ...

-- The bar textures and fonts the settings offer, and setting a font safely: FrogLib's Media
-- (Libs\FrogLib\Media.lua), with this addon's own fonts listed first. Fonts\XIV.ttf is also the
-- fallback (see Fonts\README.txt).
local FONTS = "Interface\\AddOns\\" .. ADDON .. "\\Fonts\\"
ns.Media = FrogLib.Media.New({
    fonts = {
        { "M PLUS 1p", FONTS .. "XIV.ttf" },
        { "Michroma (wide)", FONTS .. "Michroma.ttf" },
        { "Source Sans 3", FONTS .. "SourceSans3.ttf" },
    },
    fallbackFont = FONTS .. "XIV.ttf",
})
ns.FONTS = FONTS
