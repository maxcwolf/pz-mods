# A-Life Reputation Editor

A Project Zomboid Build 42 add-on for
[Project A-Life](https://steamcommunity.com/sharedfiles/filedetails/?id=3803984183)
(mod id `ProjectALifeNPCs`, written against 1.5.2). Mod id: `ALifeRepEditor`.

Fix or set your A-Life reputation from one small window, for example when an NPC
steps into the tile of the zombie you were shooting.

## Opening it

- Click the small **Rep: <your level>** button just below the watch clock in
  the top-right corner. Drag it anywhere; right-click it to hide it.
- Or right-click the world and choose **Reputation editor**. When the button is
  hidden, the same menu has **Show reputation button**.
- Right-click an A-Life NPC and choose **Edit relationship with <name>** to
  open the People tab on that person, even if you've never met them.

The game pauses while the window is open (single player) and goes back to the
speed it was at when you close it. If you had already paused, it stays paused.

## What's in the window

The window has three tabs.

### Reputation

- **Your level and score**, with a bar across all eleven A-Life levels from
  The Villain (-1000) to The Legend (+1000).
- **Adjust**: -100, -25, -5, +5, +25, +100.
- **Set level**: jump straight to any level (the middle of its score band).
- **Recent kills**: the last six NPCs you killed, each with what A-Life thought
  of it ("meant you no harm. Reputation -40") and an **Undo** button. Undo takes
  back the score change, the faction turning hostile (back to before your first
  hit in that fight), the grudges that NPC's squad and faction picked up, the
  humans-killed count, the "story" NPCs tell about you, and the pending revenge
  tally. Reputation you earned after the kill is kept.
- **Factions**: every A-Life faction's attitude toward you and why, with
  **Forgive** (back to its usual attitude and clear its NPCs' grudges) and
  **Make hostile**. **Forgive everyone** does all of them.

Kills are recorded from the moment the mod is enabled; older kills can still be
fixed with Adjust, Set level and Forgive.

### People

Each A-Life NPC keeps its own opinion of you, from -100 to 100, named "Hates
you", "Resents you", "Distrusts you", "Unsure of you", "Likes you", "Trusts
you" and "Would stand by you". It changes their prices, whether they'll trade
or share information, whether they'll walk with you, and how they greet you.

- A **search box** and a list of everyone with an opinion of you, most recently
  changed first, each with their opinion, faction and how they treat you.
- Pick someone to see their **opinion bar** (the dark tick is where it drifts back
  to when left alone), the reason A-Life gives for it, and:
  - **Adjust**: -25, -5, +5, +25.
  - **Set to**: jump to any of the seven labels (the middle of its range).
  - **Forget me**: they treat you as a stranger again.
  - **Calm down**: ends their personal grudge and wariness. If their whole
    faction is hostile, forgive the faction on the Reputation tab as well.
  - **Make hostile**: they hold a personal grudge against you.
  - **Join my crew**: they become one of your A-Life companions, the same as
    asking them in conversation, but anyone can be asked and they always say
    yes. Someone loaded nearby but out of earshot walks over first. A-Life's
    limit of five companions still applies. Once they're in, the button reads
    **Leave my crew**, and **Skills and gear** opens them on the Crew tab.

A set opinion still drifts back toward that NPC's usual feeling a few points a
day, the same as any opinion in A-Life.

### Crew

Pick someone in your crew to change their skills and loadout.

- **Skills**: A-Life's nine companion skills (melee, aiming, first aid, cooking,
  carpentry, mechanics, music, stealth, foraging), 0 to 10 each, with - and +.
  They show on A-Life's Companions sheet and set their role there. First aid
  is the one A-Life acts on: at 1 they bandage themselves, at 2 they bandage you.
- **Fighting**: **Strength** (how hard they hit in melee) and **Accuracy** (how
  well they shoot), 0 to 10. These are what A-Life's combat actually reads, and
  they're kept when the NPC unloads and loads back in.
- **Max everything** sets all of the above to 10.
- **Gear** shows what they're holding (and a gun's loaded and spare rounds),
  with **+30 ammo** and **+120 ammo**, and everything they carry, with **Hold**
  for weapons and **Remove** (or **Take off** for clothing).
- **Give any item**: search every item in the game. Weapons are handed over and
  held (a gun comes with 60 rounds, and they're allowed to use guns from then
  on), clothing is worn in place of whatever is on that spot, and anything else
  is handed over (**Give** or **Give 10**).

Gear can only change while they're loaded near you; skills can be set any time.
Their outfit is kept through reloads and A-Life's seasonal wardrobe leaves it
alone. Weapons, ammo and handed-over items are kept the way A-Life keeps a
companion's own: up to 8 weapons and 24 other items.

## Multiplayer

Only admins and moderators can use it, unless the server turns on the sandbox
option **Everyone can edit reputation** (A-Life Reputation Editor page). The game
does not pause in multiplayer.

## Development

- `scripts/install.sh` symlinks the mod into `~/Zomboid/mods`.
- `luajit test/run.lua` runs the tests. The editor, hook and UI tests load
  Project A-Life's own reputation, opinion and registry code from the Steam
  workshop folder (override with `ALIFE_LUA=/path/to/ProjectALifeNPCs/42.20/media/lua`),
  so they fail if an A-Life update changes what the editor relies on.
- Pure logic lives in `media/lua/shared/ALifeRepEditor/`, the A-Life glue in
  `server/`, the window, button and menu in `client/`.
- Decisions are in `docs/decisions/`; open checks in `todo.md`.
