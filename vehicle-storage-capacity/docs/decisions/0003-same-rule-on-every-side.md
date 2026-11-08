# 0003: Run the same rule on server and clients instead of syncing

Date: 2026-11-07

## Context

In multiplayer, the part item packet makes clients call `setInventoryItem`,
so they recompute capacity locally; the part mod data packet
(`VehiclePartModData`) carries mod data and content amount but not capacity.
Only a full vehicle update (`BaseVehicle.save`) carries it. So a capacity
set on the server would not reach clients reliably.

## Decision

The rule is deterministic: the same sandbox values and the same game-computed
base give the same result. The hooks are in shared Lua and run wherever they
fire: the once-a-minute sweep of loaded vehicles, `OnEnterVehicle`, and on
clients the loot window's `OnRefreshInventoryWindowContainers` "begin" stage
for vehicles within 6 tiles. Nothing is transmitted.

## How to reverse

To make the server authoritative instead, run the sweep only where
`isClient()` is false and send capacities to clients with a server command;
clients would then need a handler that calls `setContainerCapacity`.
