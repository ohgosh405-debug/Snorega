# Snorega for HorizonXI (Ashita v4)

**Created by Afoofa**

Snorega is an advisory RDM timing addon for coordinated BLM AoE camps. It
tracks your Sleepga cycle, watches party/alliance BLMs begin elemental nukes,
and shows exactly when you should **begin casting** the next Sleepga.

Version 1.0 uses a compact five-row color panel. Cyan shows normal timing,
green means ready/casting, yellow and orange signal an approaching action, and
the `CAST SLEEPGA NOW` instruction flashes red and yellow. Drag the cyan title
bar to move the complete panel.

It never casts a spell, changes your target, or sends party chat automatically.

> **HorizonXI approval required:** HorizonXI's current rules prohibit addons
> that are not on its approved list. Do not load Snorega on HorizonXI unless
> HorizonXI staff approve it first. Submit the source folder for review and
> check the current rules at <https://horizonxi.com/rules>.

## Default timing

- Your successful Sleepga completion starts a 60-second cycle.
- At 40 seconds remaining it prints `3`, then `2`, then `1`.
- At 37 seconds remaining it prints the `NUKE` call.
- It initially recommends beginning Sleepga 5.5 seconds after that call.
- If a BLM begins their first elemental nuke late, the recommendation moves
  later by the same amount (capped at 4 seconds of adjustment).
- The overlay warns when Haste is missing and reminds you to select the
  highest-HP mob.

These defaults implement the supplied camp instructions. They are timing
guidance, not a guarantee: latency, spell interruption, resists, Fast Cast,
and the actual BLM spell can still require RDM judgment.

## Install

1. Extract the `Snorega` folder into:
   `HorizonXI\Game\addons\`
2. In game, run:
   `/addon load Snorega`
3. Move the overlay by dragging it.

To load it every launch, add this line to the Ashita boot configuration:

```text
/addon load Snorega
```

## Normal use

1. Haste yourself.
2. Cast Sleepga normally. The timer begins when the successful cast completes.
3. Follow the `3 - 2 - 1 - NUKE` alerts.
4. Watch `BEGIN SLEEPGA IN` after the BLMs start casting.
5. Begin Sleepga when the overlay says `CAST SLEEPGA NOW`.

If the addon is loaded in the middle of a pull, `/sn start` starts a fresh
60-second timer. `/sn nuke` marks a manual nuke call immediately.

## Commands

| Command | Purpose |
| --- | --- |
| `/sn start [seconds]` | Manually starts the sleep timer. |
| `/sn nuke` | Marks the NUKE call now and begins the 5.5s calculation. |
| `/sn reset` | Clears the current cycle. |
| `/sn delay 5.5` | Changes BLM-start/NUKE-to-Sleepga-start delay. |
| `/sn duration 60` | Changes the default Sleepga duration. |
| `/sn add Name` | Tracks a named caster even if alliance job data is unavailable. |
| `/sn remove Name` | Removes a manually tracked caster. |
| `/sn blms` | Lists detected and manually configured BLMs. |
| `/sn on` / `/sn off` | Enables or disables monitoring. |
| `/sn help` | Prints the command list. |

## Detection details

- BLM casts are read from incoming action packets, so chat filters do not
  affect detection.
- Only party/alliance members whose main job is BLM are automatically tracked.
- Fire, Blizzard, Aero, Stone, Thunder, Water, -ga lines, and the six classic
  ancient-magic nukes are accepted. Stun, Drain, Aspir, cures, and buffs do not
  shift the sleep timing.
- Only each BLM's first qualifying nuke in a cycle is used. This prevents a
  later second spell from incorrectly moving the Sleepga recommendation.

## First-run check

Before relying on it in a live pull, test once in a safe party:

1. Run `/sn start 45`.
2. Confirm the countdown begins after about 5 seconds and the NUKE alert
   follows 3 seconds later.
3. At the NUKE alert, have a BLM cast an elemental spell and confirm their
   name/spell appears.
4. If the BLM is not detected, run `/sn add TheirName` and retest.

The older `/ns`, `/nukeandsnooze`, `/sw`, and `/sleepwatch` commands remain available as compatibility aliases.
