# 0003: Staff only in multiplayer, with a sandbox switch for everyone

Date: 2026-11-06

## Context

The editor is a cheat. In single player that's the point; on a shared server
one player rewriting their reputation affects everyone's game.

## Decision

Single player: always allowed. Multiplayer: allowed for any access level other
than none/player/user, or for everyone when the server's sandbox option
`ALifeRepEditor.AllowEveryone` is on. The server checks, not the client.

## How to reverse

Set `AllowEveryone` to default true in `media/sandbox-options.txt`, or return
true from `Permissions.allowed`.
