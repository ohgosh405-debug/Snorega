# Snorega v1.0.3 — HorizonXI Staff Review Notes

## Reason for this revision

The earlier design automatically observed successful Sleepga completions and
party/alliance BLM spell starts. HorizonXI staff explained that this went too
far by removing player skill requirements.

Aerec subsequently clarified that timer addons are acceptable when the player
starts the timer themselves. Version 1.0.3 was rewritten around that condition.

## Player-input boundary

Snorega remains idle until the player enters `/sn start` or `/sn nuke`. It has
no code path that starts or modifies a timer in response to gameplay state.
When a timer expires, it does not restart. The next cycle requires another
player command.

## Removed functionality

The following functionality from the earlier design has been removed:

- The `packet_in` event handler.
- Parsing of action packet `0x028`.
- Detection of the player's Sleepga start, interruption, or completion.
- Detection of elemental spells started by BLMs.
- Party/alliance member and job inspection.
- Automatic late-caster adjustment.
- Automatic mid-pull arming.
- Haste/buff inspection.
- Named-caster tracking and all BLM tracking commands.

## Remaining functionality

Version 1.0.3 contains only:

- Player-entered addon commands.
- A clock calculation using `os.clock()` after a manual start.
- A draggable local text overlay.
- Local text printed with `print()`.
- Local settings for duration, delay, visibility, and overlay position.
- A self-unload convenience command.

It never sends gameplay or communication commands. The sole queued command is
`/addon unload Snorega`, used only when the player directly enters
`/sn unload`; this affects only the addon's own loaded state.

## Why the player remains responsible

The addon cannot know whether Sleepga landed, partially resisted, missed,
expired, or was interrupted. It cannot know whether a BLM started late or
whether the selected target is appropriate. The player must observe all of
those conditions, decide when to start or correct the timer, select the target,
and cast every spell.

The display is therefore comparable to a stopwatch with configurable reminder
marks. It reduces manual arithmetic after the player starts the stopwatch, but
does not observe or respond to combat.

## Staff-verifiable implementation facts

- Registered events: `load`, `command`, `d3d_present`, and `unload` only.
- No `packet_in` or `packet_out` registration.
- No `GetMemoryManager()` calls.
- No resource-manager spell lookup.
- No network, file-import, IPC, or inter-addon communication.
- No party-chat or gameplay command queueing.

Created by **Afoofa**.

