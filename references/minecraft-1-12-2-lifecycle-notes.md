# Minecraft 1.12.2 Lifecycle Notes

Facts verified while building Forge 1.12.2 mods with this workflow. Verify them again when a mod depends on them in another setting.

## Ending A Singleplayer Session From The Server Side

- A mod that disconnects the singleplayer host from the server side (`player.connection.disconnect(...)` on the integrated server) can freeze the client. On the disconnect the client closes its world, which calls `IntegratedServer.initiateShutdown`. That method schedules a task on the server thread and waits for it. When the host's logout has already made the integrated server stop, the task never runs, and the client thread waits in `FutureTask.get` with no end. Observed in Some Pack Defaults (2026-11, standard Forge 14.23.5.2847): 1 freeze in 43 stops.
- The order that removed it: in the same server tick, call `server.initiateShutdown()` first and then `player.connection.disconnect(...)`. Catch and log a `RuntimeException` from the shutdown call and still send the disconnect. With this order, 40 stops showed no freeze. The claim that the race is gone is inferred from those runs, not proven.
- The same race sits in Agent Diagnostics Toolkit `1.8.0`'s `client reconnect <seconds> logout`. Use a plain `client reconnect`, or `quit` and a new launch, for a reopen.
- A race like this shows once in tens of runs. Test such a path in a loop (Agent Diagnostics Toolkit-Assisted Validation in `stages/7-implementation.md`), and read the thread dump of a hung client: the client thread parked in `IntegratedServer.initiateShutdown` with no server thread left is this race.
