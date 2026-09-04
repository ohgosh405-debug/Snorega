# Snorega v1.0.3 for HorizonXI (Ashita v4)

Snorega is a **player-started, display-only timer** created by **Afoofa** for
Red Mages coordinating Sleepga cycles with Black Mage parties.

It does not observe the game to decide when to run. The player must start every
timer by entering a command or pressing a macro that contains that command.

> **Approval status:** This source is being submitted to HorizonXI staff for
> review. Do not use it on HorizonXI until staff explicitly approve this
> version.

## What it does

After the player enters `/sn start`, Snorega:

1. Displays the remaining time locally.
2. Shows a local `3 - 2 - 1 - NUKE` countdown at the configured points.
3. Displays a local reminder to begin Sleepga 5.5 seconds after the timer's
   NUKE point.
4. Stops at the end and waits for another manual command.

The player may instead enter `/sn nuke` when they personally observe the real
nuke start. This starts a new 5.5-second local countdown. The addon does not
observe the BLM, spell, party, chat log, target, or packets.

## What it does not do

Snorega does **not**:

- Detect Sleepga casts or completions.
- Detect BLM casts, spell names, jobs, party members, or alliance members.
- Read or parse incoming or outgoing action packets.
- Start, restart, stop, or adjust a timer because of a game event.
- Cast spells, use abilities, change targets, move the character, or equip gear.
- Send party, alliance, linkshell, tell, say, shout, or yell messages.
- Inject gameplay commands.
- Choose a target or determine which mob has the highest HP.

Every gameplay action and every timer start requires direct player input.

## Installation

1. Extract the `Snorega` folder into `HorizonXI\Game\addons\`.
2. After approval, load it with `/addon load Snorega`.
3. Drag the overlay to the desired screen position.

## Recommended macro

Start the timer manually after confirming that Sleepga landed:

```text
/console /sn start
```

If `/console` is not required by your macro setup, use:

```text
/sn start
```

This macro does not cast Sleepga. Casting and starting the timer are separate
player actions.

## Commands

| Command | Function |
| --- | --- |
| `/sn start [seconds]` | Manually starts a timer; default is 60 seconds. |
| `/sn nuke` | Manually starts the configured 5.5-second Sleepga countdown. |
| `/sn stop` | Stops and clears the timer. |
| `/sn reset` | Alias for `/sn stop`. |
| `/sn show` | Shows the overlay. |
| `/sn hide` | Hides the overlay without unloading. |
| `/sn duration 60` | Changes the default timer duration. |
| `/sn delay 5.5` | Changes the manual nuke-to-Sleepga delay. |
| `/sn unload` | Unloads the addon and removes the overlay. |
| `/sn help` | Prints the command list locally. |

## Default timing

- Sleep timer: 60 seconds.
- Countdown begins: 40 seconds remaining.
- NUKE reminder: 37 seconds remaining.
- Sleepga reminder: 5.5 seconds after the NUKE reminder.

These values are advisory. Resists, latency, interruptions, Fast Cast, player
reaction, and party timing can change what is safe. The player remains
responsible for observing the fight and deciding when to act.

## Privacy and network use

Snorega makes no web requests and collects, stores, or transmits no character,
account, party, combat, or chat information. Its settings file contains only
timer values, overlay visibility, and overlay position.

## Credits

Created by **Afoofa**.

