# 0003: Tying uses the horse's reins, or a rope if it has none

Date: 2026-11-06

## Context

Vanilla tree tying uses up a Rope and returns it on untie. Max chose "free with
reins": a horse wearing the Horse mod's reins can be tied with them.

## Decision

`Tether.tieCost`: reins, if the horse wears any (`Attachments.getReins`), cost
nothing; otherwise one Rope is taken and comes back when you untie (by Detach,
by mounting, or dropped at the post if it's destroyed). With neither, the menu
option is greyed out with a tooltip. Animal cheat mode skips the rope.

## How to reverse

Change `Tether.tieCost` to always return `Tether.ROPE` when a rope is present,
and update its tests.
