# 0002: Four categories from part data, no per-mod list

Date: 2026-11-07

## Context

Max asked for storage capacity in the sandbox settings that works with
vanilla and all major vehicle mods, especially KI5. Customizable Containers
does vehicles with hand-written per-mod tables, which miss new mods.
A survey of the installed scripts (vanilla plus about 28 KI5 mods) found
148 distinct storage part ids: `TruckBed`, `GloveBox`, seats, and KI5's
`<prefix>Trunk`, `Roofrack`, `SideStorage*`, `Toolbox*`, camper `KI5CRCabs*`,
beds and stretchers that are seats, and window armor that holds 15.

## Decision

Four percent options: trunks and cargo, seats, glove boxes and consoles,
trailers and campers. A part is a seat when its container has a seat index
or its id starts with "Seat"; a glove box when its id contains "GloveBox" or
"Console" or it takes a GloveBox item; otherwise trailer storage on a
trailer and trunk storage elsewhere. A vehicle is a trailer when its script
name contains "trailer" or it has no Engine part (all KI5 trailers and
campers are named `Trailer...` and have none). Parts holding fluids
(`contentType`: fuel, air, water) are skipped. `test/real-scripts_test.lua`
classifies every storage part in the installed scripts to catch misfiles.

## How to reverse

Add or merge categories in `classify.lua`, `settings.lua`,
`sandbox-options.txt` and the translations; the capacity rule does not care
how many there are.
