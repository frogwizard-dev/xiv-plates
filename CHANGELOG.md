# XIVPlates

## 0.6.0

- **Friendly plates with a health bar**: with "Friendly names" on, turn on "With a health bar, as party plates are" under it, and other friendly players and NPCs get the full XIV look your group has: the gauge, the name above it and the level and health under it, in the party plates' colours (FFXIV's party green, or class colours for players). Off to start with, so friendly names stay names alone unless you ask.
- **Your own name in the XIV font**: "Names the game draws over heads in this font" (Look & text page, under Text) puts the names the game draws itself, your own above your head and anyone without a plate, in XIVPlates' font, so yours matches the friendly names around you. The game reads it as you log in, so log out and back in after turning it on or changing the font. Its size stays the game's. Off to start with.
- From FrogLib 1.18.0.

## 0.5.0

- **Friendly names**: every other friendly nameplate (NPCs, pets, and players outside your group, or inside it too while party plates are off) can show the name alone in XIVPlates' font, with no health bar. Turn on "Friendly names" on the Look & text page. Names are in class colours for players and green for NPCs, or white. Your target's name takes the target colour. Raid marks show beside the name, and the gamepad's interact icon still shows over an NPC. The name has its own size and nudge on the Text sizes & nudges page. Off to start with. Mailboxes and other objects, capture bars, and opposite-faction players keep Blizzard's plates.
- Friendly names need the game's Friendly Player Nameplates on, and Friendly NPC Nameplates for NPCs (Options > Gameplay > Nameplates). In dungeons and raids they're Blizzard's, as the game keeps friendly plates for itself there. An NPC that turns hostile gets an enemy plate at once, and someone joining your group gets a party plate (if those are on).
- From FrogLib 1.15.0.

## 0.4.1

- A plate coming up looks at its own target state only, not every plate's.
- Names in Russian, Korean or Chinese draw in every font.
- Mobs that turn hostile after their plate shows, duels and PvP flags get the right plate; the quest mark is for your own objectives only; no threat colours while you play alone as a damage dealer.
- Shared code (FrogLib 1.12.0): see its notes for the rest of what's fixed.

## 0.4.0

- **Party plates**: your party and raid members' nameplates in the XIV look too: the same thin gauge (or framed one), the name centred above and the level and health under it, from the same text templates. The gauge is FFXIV's party green (the HP green XIVPlayer uses) or each player's class colour, and the green is yours to set. Your target among them stands out as an enemy target does. No cast line, buffs, debuffs or threat on them, as FFXIV shows party casts in its party list rather than over heads; their pets keep Blizzard's plates. On to start with: "Party plates" on the Look & text page, a switch of its own, so you can have either kind without the other.
- **Not in dungeons or raids**: inside them the game keeps friendly nameplates for itself and no addon can change them, so your group has Blizzard's plates there; out in the world they're XIV again. The settings page says so under the checkbox, and the first time you're in a dungeon or raid with a group, XIVPlates says so once in chat.
- Party plates need the game's **Friendly Player Nameplates** on (Options > Gameplay > Nameplates). With its "Only Show Names" on too, strangers show only their names while your group still gets the XIV gauge (which, like those names, can't be clicked).
- Someone joining or leaving your group gets the XIV plate or Blizzard's at once, no reload needed. A party member who dies keeps their plate, so you can see who needs a res; one you duel gets an enemy's plate for the duel, so you can see their casts.
- Fixed: with "Rare / elite icon" set to None, a plate that had shown a rare's icon no longer keeps showing it.
- From FrogLib 1.11.0, which party plates need: each plate hears only its own unit's events, so busy raids cost far less, and the spell name on an enemy's cast bar is crisp rather than blurry. Fixed there too: a friendly player's plate no longer sometimes shows its cast bar, buffs or debuffs where an enemy's XIV plate had put them, and turning XIV plates off puts Blizzard's debuffs back in their own places.

## 0.3.1

- Russian, Korean and Chinese clients: names no longer show blank. The default font (Michroma) has no letters for those languages, so there it's drawn in M PLUS 1p (Russian) or the game's own font (Korean, Chinese); your font setting stays as it is. From FrogLib 1.10.1.
- Under the hood: tidier code, with more of it shared through FrogLib. Nothing else works differently.

## 0.3.0

- **Rare and elite icons**: Blizzard's own nameplate icons just after the name: a silver star for a rare, a silver dragon for a rare elite, and (if you like) a gold dragon for an elite or a boss. "Rare / elite icon" on the Casts & debuffs page: rares and rare elites (the default), elites too, or none; its size is yours to set. With the name not on its own row, it sits before the gauge.

## 0.2.1

- Options > AddOns with the gamepad interface: the Frog Wizard pages no longer upset the game's gamepad navigation (which could bring up errors on opening the settings). From FrogLib 1.5.0.

## 0.2.0

- **Grey once someone else got the first hit**: an enemy tapped by another player (no loot or credit for you) has its gauge and text in grey, whatever the colour mode or threat would make it. On to start with; the grey is yours to set (Target, colours & threat page).
- **Text colour by hostility**: the "Text colour" choice on the Look page can now colour the name, level and health by how the enemy feels about you (hostile red, neutral yellow), whatever colour the gauge shows for threat. The other choices: a light version of the gauge's colour (as before) or white. Your target's text still takes the target colour unless that's turned off.

## 0.1.0

- First version: FFXIV-style enemy nameplates, in XIVTarget's look, to go with XIVPlayer and XIVTarget. Friendly nameplates stay Blizzard's.
- A thin glowing gauge (or XIVPlayer's gold-rimmed one), in FFXIV's colours (or plain hostile red and neutral yellow), with the name, level and health over it, in a light version of the gauge's colour. Each text is a template (level, name, class, value, max, percent).
- The enemy's cast as a thinner line under the gauge, the spell's name hanging below its right end and the time left below its left. Casts you can't interrupt in their own colour, worked out by the game even when it keeps the cast's details hidden.
- In XIVTarget's own font (Michroma). The name is centred just above the gauge, as wide as it needs, so a long name is never cut short; the level and health sit under the gauge's ends (or over them, if you like), with the cast line below them. Each of the three is a template of its own.
- Your target a little bigger, its gauge a pixel thicker and its text in gold (gold chevrons either side too, if you like); the other plates a little dimmer.
- Your combo points (rogues, druids in cat form) as a row of small gauges right under your target's gauge, the level, health and cast making room on that plate. See-through while you have none, so nothing jumps; height, spacing, gap and colour are yours to set.
- Threat colours while you're on an enemy's threat list (tanking or not, picked from your stance, form or aura, or set), and your lead over the next highest (or your threat %) past the gauge. `/xivplates threat` shows what the game tells addons about the threat on your target.
- Your debuffs over the name (Blizzard's own, every one of yours if you like), raid marks, a "!" before enemies your quests still need, and the gauge in the execute colour once an enemy is in your execute range (warriors and paladins).
- Every text has its own size and nudge (left/right, up/down): the name, the level, the health, the threat text, and the cast's spell name and time left. The rows above and below the gauge make room for each text's size.
- Settings: `/xivplates` (or `/xpl`), the AddOn compartment, or Options > AddOns > Frog Wizard. Width, gauge height, scale, texture, font, outline and sizes are yours to set.
- Built on the same nameplate engine as FrogPlates (in FrogLib). Run one of the two: with both on, the second leaves the plates to the first and says so.
