# 0002: Blueprints hold what each square should contain, applied as edits

Date: 2026-11-07

## Context

A blueprint could store a list of actions (remove couch here, add couch
there) or the end state of each square. Actions break as soon as the new
world differs a little, and the order of actions matters.

## Decision

A blueprint stores, for each saved square, the full list of object records
it should hold. Applying works out the smallest edit per square: objects
whose signature matches a target record stay exactly as they are (their
loot, damage and open state survive), unmatched objects are removed, missing
ones are built and inserted after the object before them in the blueprint,
and the floor is replaced in place. Applying the same blueprint twice
changes nothing the second time.

By default only changed squares are saved. "Save every tile" saves the whole
claim, for a building changed before it was claimed. That is safe for the
same reason: unchanged squares produce empty edits.

Files are text: a header line, one line of details, one line per square
(`x,y,z<TAB>records`), written with a small encoder (`codec.lua`) that never
runs file contents as code.

## How to reverse

Blueprint files start with `BaseBlueprints 1`. A new format gets a new
header and `Blueprint.fromLines` can keep reading the old one.
