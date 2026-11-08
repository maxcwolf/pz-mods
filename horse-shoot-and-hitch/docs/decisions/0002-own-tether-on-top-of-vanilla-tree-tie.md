# 0002: Keep our own tie record, layered on vanilla's tree tie

Date: 2026-11-06

## Context

Vanilla ties a leashed animal to a tree or a `CanAttachAnimal` object via
`AnimalData.setAttachedTree`. Two problems for fences and poles:

- After a reload, `IsoAnimal.checkTreeExists` only finds a square's tree or a
  `CanAttachAnimal` object among its special objects. Fences aren't special
  objects, so the tie is silently dropped. The Horse team tried flagging fence
  sprites and removed the code on 2026-02-05.
- A tied animal may roam 15 tiles (hardcoded in `IsoAnimal.canGoThere`). Max wants
  about 2.

## Decision

Store the tie (post square, sprite, reins or rope) in the horse's mod data
under `HorseShootAndHitch`, and also set vanilla's attached tree so we get the
rope drawing, a wander anchor and the Detach option for free. A Horse mod
`HorseManager` system (server or single player only) re-links the tie after a
reload, frees the horse if the post is gone, and every 20 ticks walks a horse
past the radius back toward the post. A horse more than 8 tiles past the
radius is put back directly. Vanilla's Detach and leash actions are wrapped to
clear our record and only hand back a rope if one was used.

## How to reverse

Delete `tether-world.lua`, `tie-horse-action.lua` and `tie-menu.lua`. Horses
already tied keep a vanilla attached tree until the next reload, then go free.
The leftover `HorseShootAndHitch` mod data on each horse is harmless.
