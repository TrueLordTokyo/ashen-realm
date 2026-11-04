ASHEN REALM
A throne-war for Roblox Studio

This is a playable Roblox place inspired by epic house wars (a wall of ice,
a vacant throne, rival banners, a dragon overhead). It does NOT use Game of
Thrones names, sigils, or characters. Roblox removes games that copy that
show. If you publish this, keep the original houses.

HOUSES
  House Frostholm   The pale wall. Stronger at night. The snow heals them.
  House Goldmere    Extra coins on kills. Buys the rune blade sooner.
  House Wyrmreach   Immune to dragonfire. Harder sword hits.
  House Tideholm    Moves faster.

HOW TO PLAY
  1. Swear to a house on the opening screen.
  2. Click (or the Strike button) to swing. Hold Q (or Guard) to block.
  3. Stand inside a banner ring until it takes your colors.
     East, West, and the Pale Banner.
  4. Hold two banners, then stand on the Cinder Seat inside Cindergate.
     Three claims wins. An 8 minute horn ends the round if nobody does.
  5. Ash Marauders patrol the field. The ash wyrm marks a ring, then burns it.
     Wyrmreach walks through the fire. Past the Pale Wall, everyone but
     Frostholm freezes.
  6. The armory in the courtyard sells a Rune Blade for 45 coins.

OPEN IT IN ROBLOX STUDIO
  1. Install Roblox Studio (create.roblox.com) and sign in.
  2. Studio > File > Open from File.
  3. Choose AshenRealm.rbxlx.
  4. Press Play (F5). The castle, wall, and camps are built when the server
     starts. In edit mode you only see a baseplate and a "press play" marker.
  5. To try two houses at once: Test > Start Server > 2 Players.

PUT IT ON YOUR ROBLOX ACCOUNT
  I can't publish to your account from here. You do this part:
  1. Stop the playtest.
  2. File > Publish to Roblox > Create new experience.
  3. Name it Ashen Realm (or whatever you want).
  4. Game Settings > set the icon and description, then save.
  Friends join it from your profile like any other Roblox game.

WHAT TO EDIT
  ReplicatedStorage > AshenConfig
    Houses, colors, mottos, damage, coin prices, round length, map points.
  ServerScriptService > AshenServer
    The map builder, combat, banners, throne, dragon, marauders.
  StarterPlayer > StarterPlayerScripts > AshenClient
    The oath screen, HUD, minimap, and controls.

IF THE PLACE FILE WILL NOT OPEN
  1. Studio > File > New > Baseplate.
  2. In ReplicatedStorage, insert a ModuleScript named AshenConfig.
     Paste src/AshenConfig.lua into it.
  3. In ServerScriptService, insert a Script named AshenServer.
     Paste src/AshenServer.lua into it.
  4. In StarterPlayer > StarterPlayerScripts, insert a LocalScript named AshenClient.
     Paste src/AshenClient.lua into it.
  5. Press Play.
