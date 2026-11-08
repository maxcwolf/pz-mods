# To do

Nothing here has run in game yet. Everything is checked against the 42.21 jar's
bytecode, the Horse mod's v1.1.2 source and stubbed tests (`luajit test/run.lua`).

## First in-game run

- [ ] Enable the mod (after the Horse mod), load a save and confirm
  `~/Zomboid/console.txt` has no stack trace and no
  `[HorseShootAndHitch] cannot find IsoPlayer.` line. That line would mean a
  method this mod wraps isn't in IsoPlayer's Lua method table (likely
  `setIgnoreAimingInput`, an interface default method).
- [ ] Confirm the "Horse Shooting and Hitching" sandbox page shows six options
  with labels and tooltips.

## Shooting from the saddle

- [ ] Equip a pistol and a rifle while mounted (inventory and hotbar).
- [ ] Hold aim: does the rider enter the aim pose? The Horse mod ships
  `Horse_aim_*` nodes; check whether the legs stay seated or snap to the
  standing aim pose and clip into the horse. If they clip, it needs mounted aim
  and shoot animation nodes (upper body only); see ADR 0004.
- [ ] Fire at a zombie in front, to the side and behind. Confirm the bullet
  goes toward the mouse, not along the horse's heading. If shots follow the
  heading, the Horse mod's pin runs after our hook in the frame; move
  `applyAim` to a later event.
- [ ] Check the upper body twists toward the aim (we set the animation
  player's target direction; the engine caps twist at 70°).
- [ ] Confirm a click without aiming doesn't shove, and the spacebar kick still works.
- [ ] Gallop and fire: hit chance should drop 20 points. Use the debug combat
  window or count misses; confirm the weapon's hit chance is back to normal
  afterward (inspect the item, or save, reload and compare).
- [ ] Reload and rack while mounted (the Horse mod already allows these actions).
- [ ] Controller players: aiming uses the mouse only, so a controller rider
  shoots along the horse's heading. Add right-stick aim if needed.

## Tying up

- [ ] Ride up to a low wooden fence, a chain-link fence, a lamp post, a road
  sign and a tree; confirm "Dismount and tie to …" shows and works.
- [ ] Confirm the rope is drawn from the horse to the post (vanilla draws it
  from the attached tree).
- [ ] Watch a tied horse for a few in-game hours: it should stay within 2
  tiles and not jitter. If it keeps fighting vanilla's wander (15 tiles
  around a tied tree), also block its wander while tied.
- [ ] Save and reload with a horse tied to a fence: it should stay tied
  (fences aren't "special objects", so vanilla alone would lose the tie).
- [ ] Untie with vanilla "Detach animal from …": a reins tie gives no rope, a
  rope tie gives one back. Note that vanilla then leads the horse by hand.
- [ ] Mount a tied horse: it should untie, with a rope back if one was used.
- [ ] Destroy the post (sledgehammer): the horse should be freed and the rope
  dropped at the post.
- [ ] Sprite prefixes in `tether.lua` (`fencing_`, `lighting_outdoor_`, …) are
  a best guess from the Horse team's old hitching list. Check some lamp posts
  and fence posts actually match, and that nothing silly does.

## Later

- [ ] Spears and other melee from the saddle (deferred, ADR 0004): needs a
  mounted thrust animation; the standing animation clips into the horse.
- [ ] Multiplayer is untested. The tie runs server-side (timed action
  `complete()`, Horse manager system on the server), but mod data and the
  post's new name may not sync to other clients right away.
- [ ] Translations other than English.
