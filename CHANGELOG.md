# XIVPlates

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
